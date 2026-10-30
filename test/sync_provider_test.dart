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
      loaders: const {},
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
        loaders: {SyncModule.accounts: () async => initialLoads++},
        refreshers: {SyncModule.accounts: () async => refreshes++},
      );

      await provider.initialize();

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
        loaders: {SyncModule.transactions: () async {}},
        refreshers: {SyncModule.transactions: () async => refreshes++},
      );

      await provider.initialize();

      expect(refreshes, 1);
    },
  );

  test('failed refresh remains eligible after the cooldown', () async {
    var now = DateTime.utc(2026, 9, 23, 1);
    var attempts = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {'budgets': DateTime.utc(2026, 9, 23)},
      loaders: const {},
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
      loaders: const {},
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
      loaders: {SyncModule.accounts: () => initialLoad.future},
      refreshers: const {},
    );

    final initialization = provider.initialize();
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
      loaders: const {},
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
      loaders: const {},
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
        loaders: const {},
        refreshers: const {},
        now: () => now,
      );

      await expectLater(provider.checkAndSync(), throwsStateError);
      now = now.add(const Duration(seconds: 31));
      await provider.checkAndSync();

      expect(reads, 2);
    },
  );

  test(
    'initial load marks loaded modules ready and failed modules failed',
    () async {
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        loaders: {
          SyncModule.accounts: () async {},
          SyncModule.transactions: () async => throw StateError('offline'),
        },
        refreshers: const {},
      );

      await expectLater(provider.initialize(), throwsStateError);

      expect(provider.readinessOf({SyncModule.accounts}), DataReadiness.ready);
      expect(
        provider.readinessOf({SyncModule.transactions}),
        DataReadiness.failed,
      );
      expect(
        provider.readinessOf({SyncModule.accounts, SyncModule.transactions}),
        DataReadiness.failed,
      );
    },
  );

  test('portfolio readiness follows accounts', () async {
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {},
      loaders: {SyncModule.accounts: () async {}},
      refreshers: const {},
    );

    expect(
      provider.readinessOf({SyncModule.portfolio}),
      DataReadiness.notLoaded,
    );
    await provider.initialize();

    expect(provider.readinessOf({SyncModule.portfolio}), DataReadiness.ready);
  });

  test('initial load does not background-refresh a failed module', () async {
    var logReads = 0;
    var refreshes = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {
        'budgets': DateTime.utc(2026, 9, 23, 1, logReads++),
      },
      loaders: {SyncModule.budgets: () async => throw StateError('offline')},
      refreshers: {SyncModule.budgets: () async => refreshes++},
    );

    await expectLater(provider.initialize(), throwsStateError);

    expect(refreshes, 0);
    expect(provider.readinessOf({SyncModule.budgets}), DataReadiness.failed);
  });

  test('reset returns every module to not loaded', () async {
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async => {},
      loaders: {SyncModule.categories: () async {}},
      refreshers: const {},
    );

    await provider.initialize();
    provider.reset();

    expect(
      provider.readinessOf({SyncModule.categories}),
      DataReadiness.notLoaded,
    );
  });

  test('reset clears checkpoints and cooldown for a new user', () async {
    var reads = 0;
    final provider = SyncProvider(
      isAuthenticated: () => true,
      getSyncLogs: () async {
        reads++;
        return {};
      },
      loaders: const {},
      refreshers: const {},
    );

    await provider.checkAndSync();
    provider.reset();
    await provider.checkAndSync();

    expect(reads, 2);
  });

  group('manual refresh', () {
    test('reloads modules even when sync logs are unchanged', () async {
      var now = DateTime.utc(2026, 9, 23, 1);
      var loads = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {'accounts': DateTime.utc(2026, 9, 23)},
        loaders: {SyncModule.accounts: () async => loads++},
        refreshers: const {},
        now: () => now,
      );

      await provider.initialize();
      await provider.refresh({SyncModule.portfolio});
      await provider.refresh({SyncModule.accounts});

      expect(loads, 3);
    });

    test('waits for an in-flight initial load instead of reloading', () async {
      var loads = 0;
      final initialLoad = Completer<void>();
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        loaders: {
          SyncModule.budgets: () {
            loads++;
            return initialLoad.future;
          },
        },
        refreshers: const {},
      );

      final initialization = provider.initialize();
      final refresh = provider.refresh({SyncModule.budgets});
      initialLoad.complete();
      await Future.wait([initialization, refresh]);

      expect(loads, 1);
      expect(provider.readinessOf({SyncModule.budgets}), DataReadiness.ready);
    });

    test('recovers a module whose initial load failed', () async {
      var attempts = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        loaders: {
          SyncModule.transactions: () async {
            if (attempts++ == 0) throw StateError('offline');
          },
        },
        refreshers: const {},
      );

      await expectLater(provider.initialize(), throwsStateError);
      await provider.refresh({SyncModule.transactions});

      expect(
        provider.readinessOf({SyncModule.transactions}),
        DataReadiness.ready,
      );
    });

    test('keeps a ready module ready when the refresh fails', () async {
      var attempts = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        loaders: {
          SyncModule.categories: () async {
            if (attempts++ > 0) throw StateError('offline');
          },
        },
        refreshers: const {},
      );

      await provider.initialize();

      await expectLater(
        provider.refresh({SyncModule.categories}),
        throwsStateError,
      );
      expect(
        provider.readinessOf({SyncModule.categories}),
        DataReadiness.ready,
      );
    });

    test('background sync skips modules it just reloaded', () async {
      var now = DateTime.utc(2026, 9, 23, 1);
      var changedAt = DateTime.utc(2026, 9, 23);
      var refreshes = 0;
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {'recurring': changedAt},
        loaders: {SyncModule.recurring: () async {}},
        refreshers: {SyncModule.recurring: () async => refreshes++},
        now: () => now,
      );

      await provider.initialize();
      changedAt = DateTime.utc(2026, 9, 23, 1);
      await provider.refresh({SyncModule.recurring});
      now = now.add(const Duration(minutes: 1));
      await provider.checkAndSync();

      expect(refreshes, 0);
    });

    test('concurrent refreshes of the same modules share one load', () async {
      var loads = 0;
      final load = Completer<void>();
      final provider = SyncProvider(
        isAuthenticated: () => true,
        getSyncLogs: () async => {},
        loaders: {
          SyncModule.cashFlow: () {
            loads++;
            return load.future;
          },
        },
        refreshers: const {},
      );

      final first = provider.refresh({SyncModule.cashFlow});
      final second = provider.refresh({SyncModule.cashFlow});
      load.complete();
      await Future.wait([first, second]);

      expect(loads, 1);
    });
  });
}
