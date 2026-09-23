import 'package:flutter/foundation.dart';

typedef SyncLogReader = Future<Map<String, DateTime>> Function();
typedef SyncRefreshCallback = Future<void> Function();

enum SyncModule {
  accounts,
  portfolio,
  categories,
  transactions,
  budgets,
  recurring;

  SyncModule get refreshTarget => this == portfolio ? accounts : this;

  static SyncModule? fromKey(String key) {
    for (final module in values) {
      if (module.name == key) return module;
    }
    return null;
  }
}

class SyncProvider extends ChangeNotifier {
  final bool Function() isAuthenticated;
  final SyncLogReader getSyncLogs;
  final Map<SyncModule, SyncRefreshCallback> refreshers;
  final DateTime Function() _now;
  final Duration cooldown;

  final Map<SyncModule, DateTime> _localTimestamps = {};
  Future<void>? _activeCheck;
  Future<void>? _activeInitialization;
  DateTime? _lastCheckTime;
  bool _hasBaseline = false;

  bool get hasBaseline => _hasBaseline;

  SyncProvider({
    required this.isAuthenticated,
    required this.getSyncLogs,
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
    await _refreshChanged(after);
    _lastCheckTime = _now();
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
    }
  }

  void reset() {
    _localTimestamps.clear();
    _lastCheckTime = null;
    _hasBaseline = false;
  }
}
