import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/providers/sync_provider.dart';

import 'dart:async';

void main() {
  test('account and portfolio changes refresh shared data once', () async {
    var refreshCount = 0;
    final changedAt = DateTime.utc(2026, 9, 23, 1);
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {'accounts': changedAt, 'portfolio': changedAt},
      refreshers: {SyncModule.accounts: () async => refreshCount++},
    );

    await provider.checkAndSync();

    expect(refreshCount, 1);
  });

  test(
    'initial load establishes checkpoints without reloading providers',
    () async {
      var logReads = 0;
      var initialLoads = 0;
      var refreshes = 0;
      final baseline = DateTime.utc(2026, 9, 23, 1);
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async {
          logReads++;
          return {'accounts': baseline};
        },
        refreshers: {SyncModule.accounts: () async => refreshes++},
      );

      await provider.initialize(() async => initialLoads++);

      expect(logReads, 2);
      expect(initialLoads, 1);
      expect(refreshes, 0);
    },
  );

  test(
    'initial load refreshes a module changed while data was loading',
    () async {
      var logReads = 0;
      var refreshes = 0;
      final before = DateTime.utc(2026, 9, 23, 1);
      final after = DateTime.utc(2026, 9, 23, 1, 1);
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {
          'transactions': logReads++ == 0 ? before : after,
        },
        refreshers: {SyncModule.transactions: () async => refreshes++},
      );

      await provider.initialize(() async {});

      expect(refreshes, 1);
    },
  );

  test('failed refresh remains eligible after the cooldown', () async {
    var now = DateTime.utc(2026, 9, 23, 1);
    var attempts = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {'budgets': DateTime.utc(2026, 9, 23)},
      refreshers: {
        SyncModule.budgets: () async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
        },
      },
      now: () => now,
    );

    await expectLater(provider.checkAndSync(), throwsStateError);
    now = now.add(const Duration(seconds: 31));
    await provider.checkAndSync();

    expect(attempts, 2);
  });

  test('concurrent checks share one remote read', () async {
    var logReads = 0;
    final response = Completer<Map<String, DateTime>>();
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () {
        logReads++;
        return response.future;
      },
      refreshers: const {},
    );

    final first = provider.checkAndSync();
    final second = provider.checkAndSync();
    response.complete({});
    await Future.wait([first, second]);

    expect(logReads, 1);
  });

  test('checks wait for an in-flight initial load', () async {
    var logReads = 0;
    final initialLoad = Completer<void>();
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async {
        logReads++;
        return {};
      },
      refreshers: const {},
    );

    final initialization = provider.initialize(() => initialLoad.future);
    final check = provider.checkAndSync();
    expect(identical(initialization, check), isTrue);

    initialLoad.complete();
    await Future.wait([initialization, check]);

    expect(logReads, 2);
  });

  test('cooldown suppresses repeated eligible triggers', () async {
    var now = DateTime.utc(2026, 9, 23, 1);
    var logReads = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async {
        logReads++;
        return {};
      },
      refreshers: const {},
      now: () => now,
    );

    await provider.checkAndSync();
    now = now.add(const Duration(seconds: 29));
    await provider.checkAndSync();
    now = now.add(const Duration(seconds: 2));
    await provider.checkAndSync();

    expect(logReads, 2);
  });

  test('signed-out checks perform no remote work', () async {
    var logReads = 0;
    final provider = SyncProvider(
      isAuthenticated: () => false,
      getSyncLogs: () async {
        logReads++;
        return {};
      },
      refreshers: const {},
    );

    await provider.checkAndSync();

    expect(logReads, 0);
  });

  test(
    'failed sync-log reads remain distinguishable from empty logs',
    () async {
      var now = DateTime.utc(2026, 9, 23, 1);
      var reads = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async {
          reads++;
          if (reads == 1) throw StateError('offline');
          return {};
        },
        refreshers: const {},
        now: () => now,
      );

      await expectLater(provider.checkAndSync(), throwsStateError);
      now = now.add(const Duration(seconds: 31));
      await provider.checkAndSync();

      expect(reads, 2);
    },
  );

  test('reset clears checkpoints and cooldown for a new user', () async {
    var reads = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async {
        reads++;
        return {};
      },
      refreshers: const {},
    );

    await provider.checkAndSync();
    provider.reset();
    await provider.checkAndSync();

    expect(reads, 2);
  });
}
