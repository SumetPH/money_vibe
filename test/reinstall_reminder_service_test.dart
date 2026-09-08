import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/services/reinstall_reminder_service.dart';

void main() {
  test('starts a five-day deadline on first launch', () {
    final now = DateTime(2026, 9, 5, 14, 30);

    final state = ReinstallReminderService.resolveState(
      installationId: '/Bundle/installation-a/Runner.app',
      storedInstallationId: null,
      storedFirstLaunch: null,
      now: now,
    );

    expect(state.firstLaunch, now);
    expect(state.deadline, DateTime(2026, 9, 10, 14, 30));
  });

  test('starts a new five-day deadline after reinstalling the same IPA', () {
    final now = DateTime(2026, 9, 5, 14, 30);

    final state = ReinstallReminderService.resolveState(
      installationId: '/Bundle/installation-b/Runner.app',
      storedInstallationId: '/Bundle/installation-a/Runner.app',
      storedFirstLaunch: DateTime(2026, 9, 1),
      now: now,
    );

    expect(state.firstLaunch, now);
    expect(state.deadline, DateTime(2026, 9, 10, 14, 30));
  });

  test(
    'keeps an installation deadline and reports whole remaining days and hours',
    () {
      final state = ReinstallReminderService.resolveState(
        installationId: '/Bundle/installation-a/Runner.app',
        storedInstallationId: '/Bundle/installation-a/Runner.app',
        storedFirstLaunch: DateTime(2026, 9, 1, 14, 30),
        now: DateTime(2026, 9, 5),
      );

      expect(state.deadline, DateTime(2026, 9, 6, 14, 30));
      expect(
        state.remainingLabelAt(DateTime(2026, 9, 5, 14, 30)),
        '1 วัน 0 ชั่วโมง',
      );
      expect(
        state.statusAt(DateTime(2026, 9, 5, 14, 30)),
        ReinstallStatus.warning,
      );
      expect(
        state.statusAt(DateTime(2026, 9, 6, 14, 30)),
        ReinstallStatus.expired,
      );
      expect(
        ReinstallReminderService.shouldScheduleReminder(
          notificationEnabled: true,
          state: state,
          now: DateTime(2026, 9, 5),
        ),
        isTrue,
      );
      expect(
        ReinstallReminderService.shouldScheduleReminder(
          notificationEnabled: false,
          state: state,
          now: DateTime(2026, 9, 5),
        ),
        isFalse,
      );
    },
  );
}
