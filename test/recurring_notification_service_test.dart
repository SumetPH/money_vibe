import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/services/recurring_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getNotificationAppLaunchDetails' => null,
            'pendingNotificationRequests' => <Map<String, Object?>>[
              {
                'id': 1,
                'title': 'รายการประจำ',
                'body': 'ครบกำหนด',
                'payload': 'recurring:one',
              },
              {
                'id': 713740101,
                'title': 'ติดตั้งใหม่',
                'body': 'ครบ 5 วัน',
                'payload': '',
              },
            ],
            'requestPermissions' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'rescheduling recurring items preserves the reinstall reminder',
    () async {
      await RecurringNotificationService.instance.rescheduleAllNotifications(
        recurring: const [],
        occurrences: const [],
      );

      expect(calls.where((call) => call.method == 'cancelAll'), isEmpty);
      expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments),
        contains(1),
      );
      expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments),
        isNot(contains(713740101)),
      );
    },
  );

  test('reinstall reminder schedules an iOS home-screen badge', () async {
    await RecurringNotificationService.instance.scheduleReinstallReminder(
      DateTime.now().add(const Duration(hours: 1)),
    );

    final schedule = calls.singleWhere(
      (call) => call.method == 'zonedSchedule',
    );
    final arguments = Map<String, Object?>.from(schedule.arguments as Map);
    final platformSpecifics = Map<String, Object?>.from(
      arguments['platformSpecifics']! as Map,
    );

    expect(platformSpecifics['badgeNumber'], 1);
  });
}
