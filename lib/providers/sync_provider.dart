import 'package:flutter/foundation.dart';

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

/// ความพร้อมของข้อมูล module: `ready` คือเคยโหลดสำเร็จแล้วอย่างน้อยหนึ่งครั้ง
/// ส่วน `failed` ใช้เฉพาะ module ที่ยังไม่เคยโหลดสำเร็จ
enum DataReadiness { notLoaded, loading, ready, failed }

class SyncProvider extends ChangeNotifier {
  final bool Function() isAuthenticated;
  final SyncLogReader getSyncLogs;

  /// โหลดข้อมูลเต็มของแต่ละ module (ใช้ตอน Initial Load)
  final Map<SyncModule, SyncRefreshCallback> loaders;

  /// โหลดเฉพาะข้อมูลที่ Background Sync ต้องใช้
  final Map<SyncModule, SyncRefreshCallback> refreshers;
  final DateTime Function() _now;
  final Duration cooldown;

  final Map<SyncModule, DateTime> _localTimestamps = {};
  final Map<SyncModule, DataReadiness> _readiness = {};
  Future<void>? _activeCheck;
  Future<void>? _activeInitialization;
  DateTime? _lastCheckTime;
  bool _hasBaseline = false;

  bool get hasBaseline => _hasBaseline;

  /// สถานะรวม: มีตัวไหนล้มเหลวถือว่าล้มเหลว, ทุกตัวพร้อมถือว่าพร้อม
  DataReadiness readinessOf(Iterable<SyncModule> modules) {
    final states = modules
        .map((module) => _readiness[module.refreshTarget])
        .toList();
    if (states.contains(DataReadiness.failed)) return DataReadiness.failed;
    if (states.every((state) => state == DataReadiness.ready)) {
      return DataReadiness.ready;
    }
    if (states.contains(DataReadiness.loading)) return DataReadiness.loading;
    return DataReadiness.notLoaded;
  }

  SyncProvider({
    required this.isAuthenticated,
    required this.getSyncLogs,
    required this.loaders,
    required this.refreshers,
    DateTime Function()? now,
    this.cooldown = const Duration(seconds: 30),
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

  Future<void> initialize() {
    final activeInitialization = _activeInitialization;
    if (activeInitialization != null) return activeInitialization;

    final initialization = _runInitialization();
    _activeInitialization = initialization;
    return initialization;
  }

  Future<void> _runInitialization() async {
    try {
      final activeCheck = _activeCheck;
      if (activeCheck != null) await activeCheck;
      await _initialize();
    } finally {
      _activeInitialization = null;
    }
  }

  Future<void> _initialize() async {
    if (!isAuthenticated()) {
      _throwFirstError(await _loadModules(loaders.keys));
      return;
    }

    final before = await _readRemoteLogs();
    final errors = await _loadModules(loaders.keys);
    final after = await _readRemoteLogs();

    // ตั้ง baseline เฉพาะ module ที่โหลดสำเร็จ module ที่ล้มเหลวรอ Manual Refresh
    final loaded = {
      for (final module in SyncModule.values)
        if (_readiness[module.refreshTarget] == DataReadiness.ready) module,
    };
    _localTimestamps
      ..clear()
      ..addEntries(before.entries.where((e) => loaded.contains(e.key)));
    _hasBaseline = true;
    await _refreshChanged({
      for (final entry in after.entries)
        if (loaded.contains(entry.key)) entry.key: entry.value,
    });
    _lastCheckTime = _now();
    _throwFirstError(errors);
  }

  /// โหลดทุก module ขนานกัน module ที่ล้มเหลวไม่ทำให้ตัวอื่นหยุด คืน error ที่เกิดขึ้น
  Future<List<(Object, StackTrace)>> _loadModules(
    Iterable<SyncModule> modules,
  ) async {
    final targets = modules.toSet();
    for (final module in targets) {
      if (_readiness[module] != DataReadiness.ready) {
        _readiness[module] = DataReadiness.loading;
      }
    }
    notifyListeners();

    final errors = <(Object, StackTrace)>[];
    await Future.wait(
      targets.map((module) async {
        try {
          await loaders[module]!();
          _readiness[module] = DataReadiness.ready;
        } catch (error, stackTrace) {
          if (_readiness[module] != DataReadiness.ready) {
            _readiness[module] = DataReadiness.failed;
          }
          errors.add((error, stackTrace));
        }
      }),
    );
    notifyListeners();
    return errors;
  }

  void _throwFirstError(List<(Object, StackTrace)> errors) {
    if (errors.isEmpty) return;
    final (error, stackTrace) = errors.first;
    Error.throwWithStackTrace(error, stackTrace);
  }

  Future<void> _checkAndSync() async {
    if (!isAuthenticated()) return;

    final now = _now();
    if (_lastCheckTime != null && now.difference(_lastCheckTime!) < cooldown) {
      return;
    }
    _lastCheckTime = now;

    await _refreshChanged(await _readRemoteLogs());
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
    return normalized;
  }

  Future<void> _refreshChanged(Map<SyncModule, DateTime> remoteLogs) async {
    final changedByTarget = <SyncModule, Map<SyncModule, DateTime>>{};

    for (final entry in remoteLogs.entries) {
      final module = entry.key;
      final localTime = _localTimestamps[module];
      if (localTime == null || entry.value.isAfter(localTime)) {
        (changedByTarget[module.refreshTarget] ??= {})[module] = entry.value;
      }
    }

    for (final entry in changedByTarget.entries) {
      final refresh = refreshers[entry.key];
      if (refresh == null) {
        debugPrint('[SyncProvider] No refresher for ${entry.key.name}');
        continue;
      }
      await refresh();
      _localTimestamps.addAll(entry.value);
      if (_readiness[entry.key] != DataReadiness.ready) {
        _readiness[entry.key] = DataReadiness.ready;
        notifyListeners();
      }
    }
  }

  void reset() {
    _localTimestamps.clear();
    _readiness.clear();
    _lastCheckTime = null;
    _hasBaseline = false;
    notifyListeners();
  }
}
