# Phase 0 Research: Reduce Automatic Sync and Add Pull-to-Refresh

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-30

All findings are based on reading the current code. Evidence from the assessment is in `.specify/assessments/pull-to-refresh/research.md`.

## R1. How to recognize "my own write" (FR-001 – FR-003)

**Context**:

- Every write to a synced table fires a DB trigger. The trigger bumps `sync_logs.last_updated_at` for that table's module using the server's `clock_timestamp()` (`supabase/migrations/20260923000000_harden_background_sync.sql`).
- `SyncProvider` advances its local baseline only inside `_refreshChanged`, so the next check reloads every module this device wrote.
- Providers already apply their own writes optimistically (for example, `TransactionProvider.addTransaction`).

**Decision**: Use **write bracketing with a pre-write snapshot and a post-write acknowledgement**. It is driven from the repository layer.

1. `SupabaseRepository` wraps each write delegate in a small helper. The helper tells a `SyncWriteObserver` which sync module (`sync_logs.module_name`) it is about to write and whether the write succeeded. The table→module mapping mirrors the DB triggers exactly.
2. **Before the write** (`beforeWrite`), `SyncProvider` makes sure it has a remote snapshot that is at most a few seconds old (`snapshotMaxAge`, default 5 s). If the snapshot is older, it reads `sync_logs` once. For each module about to be written, it checks the remote timestamp against the local baseline:
   - If they are equal, nobody else has changed that module since our baseline, so the module is marked *ack-eligible*.
   - If the remote is newer, another device changed it, so the module is marked *foreign-dirty* and will not be acknowledged.
3. **After a successful write** (`afterWrite(success: true)`), `SyncProvider` schedules a debounced acknowledgement (`ackDebounce`, default 400 ms) that coalesces bursts such as reorders and batch updates. The acknowledgement reads `sync_logs` once:
   - **Ack-eligible modules**: the baseline adopts the new remote timestamp and no reload happens (FR-001).
   - **All other modules whose remote is newer** (trigger side effects such as `sync_transfer_portfolio_cash` touching `accounts`, or changes from other devices): run the normal `_refreshChanged` path, which reloads each changed target once (FR-002, FR-003).
4. **After a failed write**, the module is not acknowledged. A later check reloads it normally, as it does today.
5. **If the acknowledgement read fails** (for example, offline), nothing is adopted. The next check falls back to today's behavior and reloads the module. This is safe, though not optimal.

**Rationale**:

- This needs no schema change, which the decision keeps out of scope.
- The pre-write snapshot closes the masking hole: without it, a change from device B since our last check would be adopted and hidden forever.
- Each write costs at most two tiny `sync_logs` reads (≤7 rows each), in place of one full module reload. Bursts share a single snapshot and a single acknowledgement.

**Residual risk (accepted)**: a change from another device can still be masked if it lands on the same module within about `snapshotMaxAge` before our write, or between our write and the acknowledgement read (well under a second plus `ackDebounce`). There are two mitigations:

- A pull-to-refresh on that screen always force-reloads its primary module (R4).
- App restart and sign-in perform a full load.

**Alternatives considered**:

- **Adopt without a pre-write snapshot (post-write read only).** Rejected. With navigation triggers removed, the baseline can be hours old, so a write would silently mask any change another device made in the meantime. Multi-device use is confirmed.
- **Lazily skip reloads of self-written modules at the next check (no extra reads).** Rejected for the same reason: the masking window spans the whole interval between checks.
- **Server-side writer id (column on `sync_logs` filled from a request header).** This is precise and has no masking window. Rejected because it needs a schema migration and trigger changes, which are explicitly out of scope. It is recorded as a future upgrade path.
- **Hook every provider write method (~60 methods).** Rejected. Repository delegates are one-liners in a single file, and the mapping there mirrors the triggers 1:1, so the change is smaller and harder to miss (Principle III).

## R2. Which automatic triggers to remove or keep (FR-004, FR-005)

**Current triggers of `checkAndSync()`**:

| Trigger | Location | Decision |
|---------|----------|----------|
| GoRouter `routeInformationProvider` listener (every route change) | `lib/main.dart:296-302` | **Remove the sync call.** Keep `setState` |
| Bottom tab switch | `lib/screens/main_tab_screen.dart:38-46` | **Remove** |
| `AppLifecycleState.resumed` | `lib/main.dart:322-328` | **Keep**, with the 30 s cooldown unchanged |

**Rationale**: these choices match the decision handoff and FR-004 / FR-005.

**Alternatives considered**: keeping the tab-switch trigger with a longer cooldown. Rejected because the owner preferred on-demand control, and the resume check plus pull-to-refresh already cover freshness.

## R3. Pull-to-refresh widget and design-system fit (FR-006, FR-009, FR-012)

**Decision**: Add a shared `AppRefreshIndicator` in `lib/widgets/app_refresh_indicator.dart` that wraps Flutter's `RefreshIndicator.adaptive`. That gives the Cupertino-style activity indicator on iOS and the Material one on Android, both tinted with `AppColors.accentFor`. The widget:

- takes `Future<void> Function() onRefresh`
- adds the `MediaQuery.paddingOf(context).top`-aware edge offset
- is documented in `docs/design.md` (Shared widgets table)
- is enforced by a new `tool/check_design.sh` rule that forbids a raw `RefreshIndicator(` outside this file

**Rationale**:

- `RefreshIndicator` works with any descendant scrollable (`CustomScrollView`, `ReorderableListView`) through scroll notifications, so the existing layouts need only wrapping.
- `.adaptive` respects the iOS-first visual language in `docs/design.md`.
- Constitution IV requires a shared widget plus documentation.

**Scroll physics**: short or empty lists must still be pullable, so the wrapped scrollables need `AlwaysScrollableScrollPhysics` (parented to the existing physics where specified). This is an established Flutter requirement for `RefreshIndicator`.

**Duplicate refresh (FR-009)**: `RefreshIndicator` does not re-trigger `onRefresh` while the previous future is pending. `SyncProvider.refresh` also joins any in-flight check or initialization instead of running a parallel one.

**Alternatives considered**:

- `CupertinoSliverRefreshControl` only works inside a `CustomScrollView` as a sliver. It would not fit the `ReorderableListView`-based budget list and would need different integration per screen. Rejected.
- A refresh button in the AppBar is less discoverable as a list convention and clutters the main-tab headers. Rejected.

## R4. What a pull refreshes (FR-007, FR-008, FR-010)

**Decision**: Each screen calls `SyncProvider.refresh(forceModules: {...})`. The call:

1. Ignores the cooldown (FR-007).
2. Reads `sync_logs` and reloads every changed target via `_refreshChanged`.
3. Force-reloads the screen's primary target module(s) if step 2 did not already reload them (FR-008). This is the recovery path for any masked change from R1.
4. Updates `_lastCheckTime`.
5. **Rethrows** errors (unlike background checks, which swallow them) so the screen can show a SnackBar and keep its data (FR-010).

Provider `reload()` methods already rethrow load errors (for example, `TransactionProvider.init`). The current state is retained because providers only replace their lists after a successful fetch.

| Screen | `forceModules` |
|--------|----------------|
| Account list | `{accounts}` (covers portfolio through `refreshTarget`) |
| Transaction list | `{transactions}` |
| Budget list | `{budgets}` |

Other modules shown on these screens, such as categories and transactions used for budget spend, are refreshed only if `sync_logs` shows a change. They are never force-reloaded, which keeps a pull cheap.

**Alternatives considered**:

- Force-reloading every module on each pull. Rejected because it is expensive and works against the goal.
- Changed-only with no forcing. Rejected because it leaves no recovery path for a masked change.

## R5. Portfolio Detail screen (FR-006 "SHOULD")

**Decision**: **Defer** the Portfolio Detail screen. `lib/screens/account/portfolio_detail_screen.dart` is already exactly 800 lines, so adding a refresh wrapper would exceed the hard limit in Constitution V and force an unrelated refactor. Its content uses per-tab `SingleChildScrollView`s inside `AppSegmentedTabs`. The Account list pull already refreshes accounts and portfolio data, and resume covers the rest.

**Alternatives considered**: extracting part of `portfolio_detail_screen.dart` to make room. Rejected as out of scope for this feature ("avoid touching unrelated code").

## R6. Diagnostics (FR-013)

**Decision**: Add a `SyncTrigger` enum (`initialLoad`, `resume`, `pull`, `localWriteAck`). Every check, reload, and acknowledgement prints one `debugPrint` line from `SyncProvider`:

```text
[SyncProvider] trigger=<t> reloaded=[...] acknowledged=[...] skipped(cooldown)
```

**Rationale**: this follows the existing `debugPrint('[SyncProvider] ...')` convention and adds no telemetry dependency. It is enough to count checks and reloads before and after the change during manual verification (SC-001, SC-002).

## R7. Sign-out and user switch (FR-014)

**Decision**: Extend `SyncProvider.reset()` to also clear the remote snapshot, the pending ack-eligible and foreign-dirty sets, and any scheduled acknowledgement timer. `reset()` is already called on auth user change (`lib/main.dart:306-311`).

## R8. Testing approach

**Decision**: Extend `test/sync_provider_test.dart` with fake `getSyncLogs` and refreshers, using the existing style and an injectable `now`. Add tests for:

- self-write acknowledgement with no reload
- foreign change before the write still reloading
- side-effect module reload
- failed write not acknowledged
- acknowledgement read failure falling back
- pull bypassing the cooldown and forcing the primary module
- pull rethrowing errors
- reset clearing the acknowledgement state

The debounce timer becomes testable through an injectable `ackDebounce` (`Duration.zero` in tests) or `fake_async`, if it is already a dependency; otherwise use zero. The repository wrapper mapping gets a focused unit test only if a fake observer can be attached without a Supabase client. Otherwise the mapping is covered by the quickstart manual checks.
