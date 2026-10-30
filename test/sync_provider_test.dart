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

  group('local write acknowledgement', () {
    final baseline = DateTime.utc(2026, 10, 30, 1);
    final afterWrite = DateTime.utc(2026, 10, 30, 1, 5);
    final foreign = DateTime.utc(2026, 10, 30, 1, 2);

    // รอให้ ack timer (Duration.zero) และ async chain ทำงานจบ
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));

    Future<SyncProvider> createProvider({
      required Map<String, DateTime> Function() logs,
      required Map<SyncModule, SyncRefreshCallback> refreshers,
      DateTime Function()? now,
    }) async {
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => logs(),
        refreshers: refreshers,
        now: now,
        snapshotMaxAge: Duration.zero,
        ackDebounce: Duration.zero,
      );
      await provider.initialize(() async {});
      return provider;
    }

    test('own write is acknowledged without reloading', () async {
      var logs = {'transactions': baseline};
      var now = DateTime.utc(2026, 10, 30, 2);
      var reloads = 0;
      final provider = await createProvider(
        logs: () => logs,
        refreshers: {SyncModule.transactions: () async => reloads++},
        now: () => now,
      );

      await provider.beforeWrite({'transactions'});
      logs = {'transactions': afterWrite};
      provider.afterWrite({'transactions'}, success: true);
      await settle();
      now = now.add(const Duration(seconds: 31));
      await provider.checkAndSync();

      expect(reloads, 0);
    });

    test('foreign change before the write still reloads', () async {
      var logs = {'transactions': baseline};
      var reloads = 0;
      final provider = await createProvider(
        logs: () => logs,
        refreshers: {SyncModule.transactions: () async => reloads++},
      );

      logs = {'transactions': foreign};
      await provider.beforeWrite({'transactions'});
      logs = {'transactions': afterWrite};
      provider.afterWrite({'transactions'}, success: true);
      await settle();

      expect(reloads, 1);
    });

    test(
      'side-effect module reloads once while own module is acknowledged',
      () async {
        var logs = {'transactions': baseline, 'accounts': baseline};
        var transactionReloads = 0;
        var accountReloads = 0;
        final provider = await createProvider(
          logs: () => logs,
          refreshers: {
            SyncModule.transactions: () async => transactionReloads++,
            SyncModule.accounts: () async => accountReloads++,
          },
        );

        await provider.beforeWrite({'transactions'});
        logs = {'transactions': afterWrite, 'accounts': afterWrite};
        provider.afterWrite({'transactions'}, success: true);
        await settle();

        expect(transactionReloads, 0);
        expect(accountReloads, 1);
      },
    );

    test('failed write is not acknowledged', () async {
      var logs = {'transactions': baseline};
      var now = DateTime.utc(2026, 10, 30, 2);
      var reloads = 0;
      final provider = await createProvider(
        logs: () => logs,
        refreshers: {SyncModule.transactions: () async => reloads++},
        now: () => now,
      );

      await provider.beforeWrite({'transactions'});
      logs = {'transactions': afterWrite};
      provider.afterWrite({'transactions'}, success: false);
      await settle();
      now = now.add(const Duration(seconds: 31));
      await provider.checkAndSync();

      expect(reloads, 1);
    });

    test(
      'acknowledgement read failure falls back to a normal reload',
      () async {
        var logs = {'transactions': baseline};
        var failReads = false;
        var now = DateTime.utc(2026, 10, 30, 2);
        var reloads = 0;
        final provider = await createProvider(
          logs: () {
            if (failReads) throw StateError('offline');
            return logs;
          },
          refreshers: {SyncModule.transactions: () async => reloads++},
          now: () => now,
        );

        await provider.beforeWrite({'transactions'});
        logs = {'transactions': afterWrite};
        failReads = true;
        provider.afterWrite({'transactions'}, success: true);
        await settle();
        failReads = false;
        now = now.add(const Duration(seconds: 31));
        await provider.checkAndSync();

        expect(reloads, 1);
      },
    );

    test('snapshot read failure does not fail the write', () async {
      var failReads = false;
      final provider = await createProvider(
        logs: () {
          if (failReads) throw StateError('offline');
          return {'transactions': baseline};
        },
        refreshers: {SyncModule.transactions: () async {}},
      );

      failReads = true;
      await expectLater(provider.beforeWrite({'transactions'}), completes);
    });

    test('reset drops a pending acknowledgement', () async {
      var logs = {'transactions': baseline};
      var reloads = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => logs,
        refreshers: {SyncModule.transactions: () async => reloads++},
        snapshotMaxAge: Duration.zero,
        ackDebounce: const Duration(milliseconds: 5),
      );
      await provider.initialize(() async {});

      await provider.beforeWrite({'transactions'});
      logs = {'transactions': afterWrite};
      provider.afterWrite({'transactions'}, success: true);
      provider.reset();
      await settle();

      expect(reloads, 0);
      expect(provider.hasBaseline, isFalse);
    });
  });

  group('pull to refresh', () {
    final changedAt = DateTime.utc(2026, 10, 30, 1);

    test('runs within the cooldown and forces the screen module', () async {
      var logReads = 0;
      var reloads = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async {
          logReads++;
          return {'transactions': changedAt};
        },
        refreshers: {SyncModule.transactions: () async => reloads++},
      );
      await provider.initialize(() async {});

      await provider.checkAndSync(); // ถูก cooldown ข้าม
      await provider.refresh(forceModules: {SyncModule.transactions});

      expect(logReads, 3);
      expect(reloads, 1);
    });

    test('portfolio change and forced accounts reload only once', () async {
      var reloads = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {'portfolio': changedAt},
        refreshers: {SyncModule.accounts: () async => reloads++},
      );

      await provider.refresh(forceModules: {SyncModule.accounts});

      expect(reloads, 1);
    });

    test('rethrows when sync logs cannot be read', () async {
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => throw StateError('offline'),
        refreshers: const {},
      );

      await expectLater(
        provider.refresh(forceModules: {SyncModule.budgets}),
        throwsStateError,
      );
    });

    test('rethrows when a forced reload fails', () async {
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        refreshers: {
          SyncModule.budgets: () async => throw StateError('offline'),
        },
      );

      await expectLater(
        provider.refresh(forceModules: {SyncModule.budgets}),
        throwsStateError,
      );
    });

    test('concurrent pulls share one execution', () async {
      var reloads = 0;
      final response = Completer<Map<String, DateTime>>();
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () => response.future,
        refreshers: {SyncModule.budgets: () async => reloads++},
      );

      final first = provider.refresh(forceModules: {SyncModule.budgets});
      final second = provider.refresh(forceModules: {SyncModule.budgets});
      response.complete({});
      await Future.wait([first, second]);

      expect(reloads, 1);
    });
  });
}
