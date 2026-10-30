# Contract: `SyncProvider` public API

**File**: `lib/providers/sync_provider.dart` | **Consumers**: `lib/main.dart`, list screens, `SupabaseRepository` (via `SyncWriteObserver`)

## Constructor (additive, backward compatible)

```dart
SyncProvider({
  required bool Function() isAuthenticated,
  required SyncLogReader getSyncLogs,
  required Map<SyncModule, SyncRefreshCallback> refreshers,
  DateTime Function()? now,
  Duration cooldown = const Duration(seconds: 30),          // existing
  Duration snapshotMaxAge = const Duration(seconds: 5),     // new
  Duration ackDebounce = const Duration(milliseconds: 400), // new
})
```

## Methods

| Method | Behavior | Errors |
|--------|----------|--------|
| `Future<void> initialize(loadInitialData)` | Unchanged. Logs `trigger=initialLoad` | Propagates (unchanged) |
| `Future<void> checkAndSync()` | Unchanged semantics: respects `cooldown` and joins in-flight work. Now called **only** on app resume. Logs `trigger=resume` | Propagates; the caller in `main.dart` swallows and logs (unchanged) |
| `Future<void> refresh({Set<SyncModule> forceModules = const {}})` *(new)* | Ignores `cooldown`. Waits for any in-flight initialization or check, then reads logs, reloads changed targets, and force-reloads `forceModules` (mapped by `refreshTarget`) that were not already reloaded. Sets `_lastCheckTime`. Concurrent calls share one future. Logs `trigger=pull` | **Rethrows** log-read or reload errors so the UI can report them |
| `void reset()` | Clears baseline, cooldown, snapshot, ack sets, and ack timer | none |

## `SyncWriteObserver` implementation

`SyncProvider implements SyncWriteObserver`. See [sync-write-observer.md](sync-write-observer.md).

- `beforeWrite(modules)`: refreshes the snapshot if it is older than `snapshotMaxAge`, then marks each module ack-eligible or foreign-dirty. A failed snapshot read MUST NOT block or fail the write: the modules are left neither eligible nor dirty, and the normal reload happens later.
- `afterWrite(modules, {required bool success})`: on success, schedules the debounced acknowledgement. On failure, removes the modules from `_ackEligible`.
- Acknowledgement run: reads logs once, adopts timestamps for eligible modules, and passes the rest to `_refreshChanged`. Errors are logged and swallowed (this is a background process). Logs `trigger=localWriteAck acknowledged=[...] reloaded=[...]`.
