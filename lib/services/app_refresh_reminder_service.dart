import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class AppRefreshReminderService {
  AppRefreshReminderService._();

  static const _buildMarkerFromEnvironment = String.fromEnvironment(
    'APP_BUILD_MARKER',
    defaultValue: '',
  );

  static final AppRefreshReminderService instance =
      AppRefreshReminderService._();

  static const _notificationId = 910001;
  static const _channelId = 'app_refresh_reminder_channel';
  static const _channelName = 'App Refresh Reminder';
  static const _channelDescription = 'Reminder to rebuild or reinstall the app';
  static const _lastSeenBuildKey = 'app_refresh_last_seen_build_v1';
  static const _installStartedAtKey = 'app_refresh_install_started_at_v1';
  static const _scheduledForKey = 'app_refresh_scheduled_for_v1';
  static const _reminderAfter = Duration(days: 5);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();

    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      debugPrint(
        'AppRefreshReminderService: Failed to detect timezone, '
        'using default timezone: $e',
      );
    }

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> ensureScheduled() async {
    if (kIsWeb) return;

    await init();

    final granted = await _requestPermissions();
    if (!granted) {
      debugPrint(
        'AppRefreshReminderService: Notification permission not granted',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = await _plugin.pendingNotificationRequests();
    final alreadyScheduled = existing.any((n) => n.id == _notificationId);
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildKey = _buildMarkerFromEnvironment.isNotEmpty
        ? 'marker:$_buildMarkerFromEnvironment'
        : '${packageInfo.version}+${packageInfo.buildNumber}';
    final lastSeenBuildKey = prefs.getString(_lastSeenBuildKey);

    final now = DateTime.now();
    final installStartedAt =
        DateTime.tryParse(prefs.getString(_installStartedAtKey) ?? '') ?? now;
    final scheduledFor =
        DateTime.tryParse(prefs.getString(_scheduledForKey) ?? '') ??
        installStartedAt.add(_reminderAfter);

    if (!prefs.containsKey(_installStartedAtKey) ||
        lastSeenBuildKey == null ||
        lastSeenBuildKey != currentBuildKey) {
      debugPrint(
        'AppRefreshReminderService: detected new build, reset 5-day reminder '
        '(old: ${lastSeenBuildKey ?? 'none'}, new: $currentBuildKey)',
      );
      await _plugin.cancel(_notificationId);
      await prefs.setString(_installStartedAtKey, now.toIso8601String());
      await prefs.setString(_lastSeenBuildKey, currentBuildKey);
      final nextReminder = now.add(_reminderAfter);
      await prefs.setString(_scheduledForKey, nextReminder.toIso8601String());
      await _schedule(nextReminder);
      return;
    }

    if (alreadyScheduled) {
      debugPrint(
        'AppRefreshReminderService: existing reminder kept for build '
        '$currentBuildKey at $scheduledFor',
      );
      return;
    }

    if (scheduledFor.isAfter(now)) {
      debugPrint(
        'AppRefreshReminderService: restore pending reminder for build '
        '$currentBuildKey at $scheduledFor',
      );
      await _schedule(scheduledFor);
      return;
    }

    debugPrint(
      'AppRefreshReminderService: previous reminder expired for build '
      '$currentBuildKey, scheduling a new 5-day reminder',
    );
    final nextReminder = now.add(_reminderAfter);
    await prefs.setString(_installStartedAtKey, now.toIso8601String());
    await prefs.setString(_lastSeenBuildKey, currentBuildKey);
    await prefs.setString(_scheduledForKey, nextReminder.toIso8601String());
    await _schedule(nextReminder);
  }

  Future<void> _schedule(DateTime when) async {
    await _plugin.zonedSchedule(
      _notificationId,
      'ถึงเวลาควร build ใหม่',
      'ผ่านมา 5 วันแล้ว ควร build/install แอปใหม่',
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'app_refresh_reminder',
    );

    debugPrint(
      'AppRefreshReminderService: Scheduled refresh reminder at $when',
    );
  }

  Future<bool> _requestPermissions() async {
    await init();

    var granted = true;

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      granted = granted && iosGranted;
    }

    final androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      granted = granted && androidGranted;
    }

    return granted;
  }

  Future<String> getBuildLabel() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }

  Future<String> getReminderStatusLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledForRaw = prefs.getString(_scheduledForKey);
    if (scheduledForRaw == null || scheduledForRaw.isEmpty) {
      return 'ยังไม่ได้ตั้งเตือน';
    }

    final scheduledFor = DateTime.tryParse(scheduledForRaw);
    if (scheduledFor == null) {
      return 'ยังไม่ได้ตั้งเตือน';
    }

    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'en_US');
    return 'ครั้งถัดไป: ${formatter.format(scheduledFor)}';
  }
}
