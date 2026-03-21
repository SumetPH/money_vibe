import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/recurring_transaction.dart';

class RecurringNotificationService {
  RecurringNotificationService._();

  static final RecurringNotificationService instance =
      RecurringNotificationService._();

  static const _channelId = 'recurring_due_channel';
  static const _channelName = 'Recurring Due Reminders';
  static const _channelDescription = 'Notifications for recurring due items';

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
        'RecurringNotificationService: Failed to detect timezone, '
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
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.initialize(settings);

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

  Future<bool> syncRecurringNotification({
    required RecurringTransaction recurring,
    required List<RecurringOccurrence> occurrences,
  }) async {
    if (kIsWeb) return false;

    await init();
    await cancelRecurringNotification(recurring.id);

    if (!recurring.notificationEnabled) return true;

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint(
        'RecurringNotificationService: Notification permission not granted',
      );
      return false;
    }

    final scheduledDateTime = _findNextScheduledDateTime(
      recurring: recurring,
      occurrences: occurrences,
    );

    if (scheduledDateTime == null) return true;

    await _plugin.zonedSchedule(
      _notificationIdFor(recurring.id),
      recurring.name,
      'ครบกำหนด ${_formatAmount(recurring.amount)} บาท',
      tz.TZDateTime.from(scheduledDateTime, tz.local),
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: recurring.id,
    );

    debugPrint(
      'RecurringNotificationService: Scheduled ${recurring.id} at '
      '$scheduledDateTime',
    );

    return true;
  }

  Future<void> rescheduleAllNotifications({
    required List<RecurringTransaction> recurring,
    required List<RecurringOccurrence> occurrences,
  }) async {
    if (kIsWeb) return;

    await init();
    await _plugin.cancelAll();

    if (!recurring.any((item) => item.notificationEnabled)) return;

    final granted = await requestPermissions();
    if (!granted) return;

    for (final item in recurring) {
      if (!item.notificationEnabled) continue;

      final scheduledDateTime = _findNextScheduledDateTime(
        recurring: item,
        occurrences: occurrences,
      );

      if (scheduledDateTime == null) continue;

      await _plugin.zonedSchedule(
        _notificationIdFor(item.id),
        item.name,
        'ครบกำหนด ${_formatAmount(item.amount)} บาท',
        tz.TZDateTime.from(scheduledDateTime, tz.local),
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
    }
  }

  Future<void> cancelRecurringNotification(String recurringId) async {
    if (kIsWeb) return;

    await init();
    await _plugin.cancel(_notificationIdFor(recurringId));
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    await init();

    var granted = true;

    final darwinPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final darwinGranted = await darwinPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (darwinGranted != null) {
      granted = granted && darwinGranted;
    }

    final androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      granted = granted && androidGranted;
    }

    return granted;
  }

  DateTime? _findNextScheduledDateTime({
    required RecurringTransaction recurring,
    required List<RecurringOccurrence> occurrences,
  }) {
    final now = DateTime.now();
    final searchEnd = recurring.endDate ?? now.add(const Duration(days: 400));
    final dates = recurring.generateOccurrenceDates(upTo: searchEnd);

    for (final date in dates) {
      final occurrence = _findOccurrence(occurrences, recurring.id, date);
      if (occurrence != null && occurrence.status != OccurrenceStatus.pending) {
        continue;
      }

      final scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        recurring.notificationHour,
        recurring.notificationMinute,
      );

      if (scheduled.isAfter(now)) {
        return scheduled;
      }
    }

    return null;
  }

  RecurringOccurrence? _findOccurrence(
    List<RecurringOccurrence> occurrences,
    String recurringId,
    DateTime dueDate,
  ) {
    for (final occurrence in occurrences) {
      if (occurrence.recurringId == recurringId &&
          _isSameDate(occurrence.dueDate, dueDate)) {
        return occurrence;
      }
    }
    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _notificationIdFor(String recurringId) {
    var hash = 0;
    for (final codeUnit in recurringId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }
}
