import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/services/reinstall_reminder_service.dart';

void main() {
  test('starts a seven-day deadline on first launch', () {
    final now = DateTime(2026, 9, 5, 14, 30);

    final state = ReinstallReminderService.resolveState(
      buildNumber: '1',
      storedBuildNumber: null,
      storedFirstLaunch: null,
      now: now,
    );

    expect(state.firstLaunch, now);
    expect(state.deadline, DateTime(2026, 9, 12, 14, 30));
  });

  test('starts a new seven-day deadline for a new build', () {
    final now = DateTime(2026, 9, 5, 14, 30);

    final state = ReinstallReminderService.resolveState(
      buildNumber: '2',
      storedBuildNumber: '1',
      storedFirstLaunch: DateTime(2026, 9, 1),
      now: now,
    );

    expect(state.firstLaunch, now);
    expect(state.deadline, DateTime(2026, 9, 12, 14, 30));
  });

  test('keeps a build deadline and reports whole remaining days and hours', () {
    final state = ReinstallReminderService.resolveState(
      buildNumber: '1',
      storedBuildNumber: '1',
      storedFirstLaunch: DateTime(2026, 9, 1, 14, 30),
      now: DateTime(2026, 9, 5),
    );

    expect(state.deadline, DateTime(2026, 9, 8, 14, 30));
    expect(
      state.remainingLabelAt(DateTime(2026, 9, 5, 14, 30)),
      '3 วัน 0 ชั่วโมง',
    );
    expect(
      state.statusAt(DateTime(2026, 9, 7, 14, 30)),
      ReinstallStatus.warning,
    );
    expect(
      state.statusAt(DateTime(2026, 9, 8, 14, 30)),
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
  });
}
