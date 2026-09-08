import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recurring_notification_service.dart';

enum ReinstallStatus { active, warning, expired }

class ReinstallReminderState {
  static const duration = Duration(days: 5);

  final DateTime firstLaunch;
  final DateTime deadline;

  const ReinstallReminderState({
    required this.firstLaunch,
    required this.deadline,
  });

  Duration remainingAt(DateTime now) {
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  ReinstallStatus statusAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining == Duration.zero) return ReinstallStatus.expired;
    if (remaining <= const Duration(days: 1)) return ReinstallStatus.warning;
    return ReinstallStatus.active;
  }

  String remainingLabelAt(DateTime now) {
    final remaining = remainingAt(now);
    return '${remaining.inDays} วัน ${remaining.inHours.remainder(24)} ชั่วโมง';
  }
}

class ReinstallReminderService extends ChangeNotifier {
  ReinstallReminderService._();

  static final instance = ReinstallReminderService._();

  static const _installationIdKey = 'reinstall_reminder_installation_id';
  static const _firstLaunchKey = 'reinstall_reminder_first_launch';
  static const _notificationEnabledKey =
      'reinstall_reminder_notification_enabled';

  ReinstallReminderState? _state;
  bool _notificationEnabled = true;
  bool _isSupported = false;
  Timer? _refreshTimer;

  bool get isSupported => _isSupported;
  bool get notificationEnabled => _notificationEnabled;
  ReinstallReminderState? get state => _state;
  ReinstallStatus? get status => _state?.statusAt(DateTime.now());
  bool get needsWarningBadge => status == ReinstallStatus.warning;
  bool get needsExpiredBadge => status == ReinstallStatus.expired;
  String? get remainingLabel => _state?.remainingLabelAt(DateTime.now());

  static ReinstallReminderState resolveState({
    required String installationId,
    required String? storedInstallationId,
    required DateTime? storedFirstLaunch,
    required DateTime now,
  }) {
    final firstLaunch =
        storedInstallationId == installationId && storedFirstLaunch != null
        ? storedFirstLaunch
        : now;
    return ReinstallReminderState(
      firstLaunch: firstLaunch,
      deadline: firstLaunch.add(ReinstallReminderState.duration),
    );
  }

  static bool shouldScheduleReminder({
    required bool notificationEnabled,
    required ReinstallReminderState state,
    required DateTime now,
  }) => notificationEnabled && state.deadline.isAfter(now);

  Future<void> initialize() async {
    _isSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (!_isSupported) return;

    final installationId = await const MethodChannel(
      'money_vibe/installation',
    ).invokeMethod<String>('getInstallationId');
    if (installationId == null || installationId.isEmpty) {
      throw StateError('iOS installation identity is unavailable');
    }
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final storedFirstLaunch = prefs.getString(_firstLaunchKey);
    _state = resolveState(
      installationId: installationId,
      storedInstallationId: prefs.getString(_installationIdKey),
      storedFirstLaunch: storedFirstLaunch == null
          ? null
          : DateTime.tryParse(storedFirstLaunch),
      now: now,
    );
    _notificationEnabled = prefs.getBool(_notificationEnabledKey) ?? true;

    await prefs.setString(_installationIdKey, installationId);
    await prefs.setString(
      _firstLaunchKey,
      _state!.firstLaunch.toIso8601String(),
    );

    await _scheduleReminder();
    _refreshTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    if (!_isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);
    _notificationEnabled = enabled;

    if (enabled) {
      await _scheduleReminder();
    } else {
      await RecurringNotificationService.instance.cancelReinstallReminder();
    }
    notifyListeners();
  }

  Future<void> _scheduleReminder() async {
    final state = _state;
    final now = DateTime.now();
    if (state == null ||
        !shouldScheduleReminder(
          notificationEnabled: _notificationEnabled,
          state: state,
          now: now,
        )) {
      await RecurringNotificationService.instance.cancelReinstallReminder();
      return;
    }
    await RecurringNotificationService.instance.scheduleReinstallReminder(
      state.deadline,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
