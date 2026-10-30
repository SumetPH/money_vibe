# Contract: `SyncWriteObserver` (repository → sync)

**Declared in**: `lib/repositories/database_repository.dart` (Constitution III: declared on the abstraction first)
**Implemented by**: `SyncProvider`
**Invoked by**: `SupabaseRepository` write delegates

```dart
/// Notified around every write to a table that has a sync_logs trigger.
/// Module keys are sync_logs.module_name values (e.g. 'transactions').
abstract interface class SyncWriteObserver {
  Future<void> beforeWrite(Set<String> moduleKeys);
  void afterWrite(Set<String> moduleKeys, {required bool success});
}

abstract class DatabaseRepository {
  // ...existing members...
  SyncWriteObserver? syncWriteObserver; // set once in main.dart after SyncProvider is built
}
```

## Rules for `SupabaseRepository`

1. Every method that inserts, updates, upserts, or deletes rows in a trigger-backed table MUST be wrapped:

   ```dart
   Future<T> _trackWrite<T>(Set<String> modules, Future<T> Function() write)
   ```

   The wrapper awaits `beforeWrite`, runs `write`, calls `afterWrite(success: true|false)`, and rethrows the original error.
2. The module set MUST equal the trigger mapping in [data-model.md](../data-model.md). Only the **directly written** table's module goes in it. Side effects from server triggers are discovered by the acknowledgement read and reloaded.
3. Read methods and `getSyncLogs()` MUST NOT be wrapped.
4. If `syncWriteObserver` is `null` (not signed in, tests, setup), the wrapper is a pass-through.
5. `beforeWrite` failures are swallowed by the observer and never fail the write.
