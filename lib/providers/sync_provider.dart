import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/database_repository.dart';

typedef SyncLogReader = Future<Map<String, DateTime>> Function();
typedef SyncRefreshCallback = Future<void> Function();

enum SyncModule {
  accounts,
  portfolio,
  categories,
  transactions,
  budgets,
  recurring,
  cashFlow;

  SyncModule get refreshTarget => this == portfolio ? accounts : this;

  /// ชื่อ module ใน sync_logs (module_name)
  String get key => this == cashFlow ? 'cash_flow' : name;

  static SyncModule? fromKey(String key) {
    for (final module in values) {
      if (module.key == key) return module;
    }
    return null;
  }
}

/// เหตุที่ทำให้เกิดการเช็ก sync (ใช้สำหรับ debug log)
enum SyncTrigger { initialLoad, resume, pull, localWriteAck }

class SyncProvider extends ChangeNotifier implements SyncWriteObserver {
  final bool Function() isAuthenticated;
  final SyncLogReader getSyncLogs;
  final Map<SyncModule, SyncRefreshCallback> refreshers;
  final DateTime Function() _now;
  final Duration cooldown;
  final Duration snapshotMaxAge;
  final Duration ackDebounce;

  final Map<SyncModule, DateTime> _localTimestamps = {};
  Future<void>? _activeCheck;
  Future<void>? _activeInitialization;
  Future<void>? _activeRefresh;
  Future<Map<SyncModule, DateTime>>? _activeSnapshotRead;
  DateTime? _lastCheckTime;
  bool _hasBaseline = false;

  Map<SyncModule, DateTime>? _remoteSnapshot;
  DateTime? _snapshotAt;
  final Set<SyncModule> _ackEligible = {};
  final Set<SyncModule> _foreignDirty = {};
  final Set<SyncModule> _pendingAck = {};
  Timer? _ackTimer;
  int _generation = 0;

  bool get hasBaseline => _hasBaseline;

  SyncProvider({
    required this.isAuthenticated,
    required this.getSyncLogs,
    required this.refreshers,
    DateTime Function()? now,
    this.cooldown = const Duration(seconds: 30),
    this.snapshotMaxAge = const Duration(seconds: 5),
    this.ackDebounce = const Duration(milliseconds: 400),
  }) : _now = now ?? DateTime.now;

  Future<void> checkAndSync() {
    final activeInitialization = _activeInitialization;
    if (activeInitialization != null) return activeInitialization;

    final activeCheck = _activeCheck;
    if (activeCheck != null) return activeCheck;

    final check = _runCheck();
    _activeCheck = check;
    return check;
  }

  Future<void> _runCheck() async {
    try {
      await _checkAndSync();
    } finally {
      _activeCheck = null;
    }
  }

  Future<void> initialize(Future<void> Function() loadInitialData) {
    final activeInitialization = _activeInitialization;
    if (activeInitialization != null) return activeInitialization;

    final initialization = _runInitialization(loadInitialData);
    _activeInitialization = initialization;
    return initialization;
  }

  Future<void> _runInitialization(
    Future<void> Function() loadInitialData,
  ) async {
    try {
      final activeCheck = _activeCheck;
      if (activeCheck != null) await activeCheck;
      await _initialize(loadInitialData);
    } finally {
      _activeInitialization = null;
    }
  }

  Future<void> _initialize(Future<void> Function() loadInitialData) async {
    if (!isAuthenticated()) {
      await loadInitialData();
      return;
    }

    final before = await _readRemoteLogs();
    await loadInitialData();
    final after = await _readRemoteLogs();

    _localTimestamps
      ..clear()
      ..addAll(before);
    _hasBaseline = true;
    final reloaded = await _refreshChanged(after);
    _lastCheckTime = _now();
    _log(SyncTrigger.initialLoad, reloaded: reloaded);
  }

  Future<void> _checkAndSync() async {
    if (!isAuthenticated()) return;

    final now = _now();
    if (_lastCheckTime != null && now.difference(_lastCheckTime!) < cooldown) {
      _log(SyncTrigger.resume, skippedCooldown: true);
      return;
    }
    _lastCheckTime = now;

    final reloaded = await _refreshChanged(await _readRemoteLogs());
    _log(SyncTrigger.resume, reloaded: reloaded);
  }

  /// Pull-to-refresh: ข้าม cooldown, โหลด module ที่เปลี่ยน และบังคับโหลด
  /// [forceModules] ของหน้าจอนั้นเสมอ (กู้คืนกรณีการเปลี่ยนจากเครื่องอื่นถูกกลบ)
  /// error จะถูก rethrow เพื่อให้ UI แจ้งผู้ใช้
  Future<void> refresh({Set<SyncModule> forceModules = const {}}) {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _runRefresh(forceModules);
    _activeRefresh = refresh;
    return refresh;
  }

  Future<void> _runRefresh(Set<SyncModule> forceModules) async {
    try {
      await _waitForBackgroundWork();
      if (!isAuthenticated()) return;

      final logs = await _readRemoteLogs();
      final reloaded = await _refreshChanged(logs);

      for (final target in forceModules.map((m) => m.refreshTarget).toSet()) {
        if (reloaded.contains(target)) continue;
        final refresh = refreshers[target];
        if (refresh == null) continue;
        await refresh();
        reloaded.add(target);
        for (final module in SyncModule.values) {
          if (module.refreshTarget != target) continue;
          final remote = logs[module];
          if (remote != null) _localTimestamps[module] = remote;
          _foreignDirty.remove(module);
        }
      }

      _lastCheckTime = _now();
      _log(SyncTrigger.pull, reloaded: reloaded);
    } finally {
      _activeRefresh = null;
    }
  }

  // ── SyncWriteObserver ──────────────────────────────────────────────────────
  //
  // ก่อนเขียน: ดู snapshot ของ sync_logs (อ่านใหม่ถ้าเก่ากว่า snapshotMaxAge)
  // ถ้า remote ของ module ยังเท่ากับ baseline แปลว่าไม่มีใครแก้ module นั้น
  // หลังจาก baseline → หลังเขียนสำเร็จ ยอมรับ timestamp ใหม่ได้โดยไม่ต้องโหลดซ้ำ
  // ถ้า remote ใหม่กว่า baseline (เครื่องอื่นแก้ไว้) จะไม่ยอมรับ และโหลดตามปกติ

  @override
  Future<void> beforeWrite(Set<String> moduleKeys) async {
    if (!isAuthenticated() || !_hasBaseline) return;
    final modules = _modulesFromKeys(moduleKeys);
    if (modules.isEmpty) return;

    final generation = _generation;
    try {
      final snapshot = await _freshSnapshot();
      if (generation != _generation) return;
      for (final module in modules) {
        final remote = snapshot[module];
        final local = _localTimestamps[module];
        final unchanged =
            remote == null || (local != null && !remote.isAfter(local));
        if (unchanged && !_foreignDirty.contains(module)) {
          _ackEligible.add(module);
        } else {
          _ackEligible.remove(module);
          _foreignDirty.add(module);
        }
      }
    } catch (e) {
      // ไม่ขวางการเขียน: module ที่อ่าน snapshot ไม่ได้จะถูกโหลดตามปกติภายหลัง
      debugPrint('[SyncProvider] beforeWrite snapshot failed: $e');
      _ackEligible.removeAll(modules);
    }
  }

  @override
  void afterWrite(Set<String> moduleKeys, {required bool success}) {
    if (!_hasBaseline) return;
    final modules = _modulesFromKeys(moduleKeys);
    if (modules.isEmpty) return;

    if (!success) {
      _ackEligible.removeAll(modules);
      return;
    }
    _pendingAck.addAll(modules);
    _ackTimer?.cancel();
    _ackTimer = Timer(ackDebounce, () {
      _ackTimer = null;
      _runAck();
    });
  }

  Future<void> _runAck() async {
    final generation = _generation;
    final written = Set<SyncModule>.of(_pendingAck);
    _pendingAck.clear();

    try {
      await _waitForBackgroundWork();
      if (generation != _generation || !isAuthenticated()) return;

      final logs = await _readRemoteLogs();
      if (generation != _generation) return;

      final acknowledged = <SyncModule>{};
      for (final module in written) {
        if (!_ackEligible.contains(module)) continue;
        if (_foreignDirty.contains(module)) continue;
        final remote = logs[module];
        if (remote != null) _localTimestamps[module] = remote;
        acknowledged.add(module);
      }
      _ackEligible.removeAll(written);

      // module ที่เหลือ (side effect จาก trigger หรือเครื่องอื่นแก้) โหลดตามปกติ
      final reloaded = await _refreshChanged(logs);
      _log(
        SyncTrigger.localWriteAck,
        reloaded: reloaded,
        acknowledged: acknowledged,
      );
    } catch (e) {
      // ยังไม่ adopt อะไร → การเช็กครั้งถัดไปจะโหลดตามพฤติกรรมเดิม
      debugPrint('[SyncProvider] Local write acknowledgement failed: $e');
      _ackEligible.removeAll(written);
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Set<SyncModule> _modulesFromKeys(Set<String> keys) =>
      keys.map(SyncModule.fromKey).whereType<SyncModule>().toSet();

  Future<void> _waitForBackgroundWork() async {
    for (final work in [_activeInitialization, _activeCheck]) {
      if (work == null) continue;
      try {
        await work;
      } catch (_) {
        // งานเบื้องหลังจัดการ error ของตัวเองแล้ว
      }
    }
  }

  Future<Map<SyncModule, DateTime>> _freshSnapshot() {
    final snapshot = _remoteSnapshot;
    final snapshotAt = _snapshotAt;
    if (snapshot != null &&
        snapshotAt != null &&
        _now().difference(snapshotAt) < snapshotMaxAge) {
      return Future.value(snapshot);
    }

    final activeRead = _activeSnapshotRead;
    if (activeRead != null) return activeRead;

    final read = _readRemoteLogs().whenComplete(
      () => _activeSnapshotRead = null,
    );
    _activeSnapshotRead = read;
    return read;
  }

  Future<Map<SyncModule, DateTime>> _readRemoteLogs() async {
    final remoteLogs = await getSyncLogs();
    final normalized = <SyncModule, DateTime>{};

    for (final entry in remoteLogs.entries) {
      final module = SyncModule.fromKey(entry.key);
      if (module == null) {
        debugPrint('[SyncProvider] Unknown module: ${entry.key}');
        continue;
      }
      normalized[module] = entry.value;
    }
    _remoteSnapshot = normalized;
    _snapshotAt = _now();
    return normalized;
  }

  /// โหลด module ที่ remote ใหม่กว่า baseline และคืนค่า refresh target ที่โหลดแล้ว
  Future<Set<SyncModule>> _refreshChanged(
    Map<SyncModule, DateTime> remoteLogs,
  ) async {
    final changedByTarget = <SyncModule, Map<SyncModule, DateTime>>{};

    for (final entry in remoteLogs.entries) {
      final module = entry.key;
      final localTime = _localTimestamps[module];
      if (localTime == null || entry.value.isAfter(localTime)) {
        (changedByTarget[module.refreshTarget] ??= {})[module] = entry.value;
      }
    }

    final reloaded = <SyncModule>{};
    for (final entry in changedByTarget.entries) {
      final refresh = refreshers[entry.key];
      if (refresh == null) {
        debugPrint('[SyncProvider] No refresher for ${entry.key.name}');
        continue;
      }
      await refresh();
      _localTimestamps.addAll(entry.value);
      _foreignDirty.removeAll(entry.value.keys);
      reloaded.add(entry.key);
    }
    return reloaded;
  }

  void _log(
    SyncTrigger trigger, {
    Iterable<SyncModule> reloaded = const [],
    Iterable<SyncModule> acknowledged = const [],
    bool skippedCooldown = false,
  }) {
    String names(Iterable<SyncModule> modules) =>
        modules.map((m) => m.key).join(', ');
    debugPrint(
      '[SyncProvider] trigger=${trigger.name} '
      'reloaded=[${names(reloaded)}] '
      'acknowledged=[${names(acknowledged)}]'
      '${skippedCooldown ? ' skipped(cooldown)' : ''}',
    );
  }

  void reset() {
    _generation++;
    _ackTimer?.cancel();
    _ackTimer = null;
    _localTimestamps.clear();
    _lastCheckTime = null;
    _hasBaseline = false;
    _remoteSnapshot = null;
    _snapshotAt = null;
    _ackEligible.clear();
    _foreignDirty.clear();
    _pendingAck.clear();
  }

  @override
  void dispose() {
    _ackTimer?.cancel();
    super.dispose();
  }
}
