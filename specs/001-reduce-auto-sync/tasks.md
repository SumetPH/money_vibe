---

description: "Task list for Reduce Automatic Sync and Add Pull-to-Refresh"
---

# Tasks: Reduce Automatic Sync and Add Pull-to-Refresh

**Input**: Design documents from `specs/001-reduce-auto-sync/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. Research R8 calls for extending `test/sync_provider_test.dart`, and AGENTS.md requires `flutter test` to pass because that file already exists.

**Organization**: Tasks are grouped by user story (US1 = no redundant re-downloads after own writes, US2 = fewer background checks, US3 = pull-to-refresh) so each can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story the task belongs to (US1, US2, US3)

## Path Conventions

Single Flutter app: `lib/`, `test/`, `docs/`, `tool/` at the repository root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Get the working branch and baseline ready

- [X] T001 Create and switch to the feature branch `001-reduce-auto-sync` from the current `speckit` branch (git), then run `flutter test test/sync_provider_test.dart` to record that the existing tests pass before any change
- [ ] T002 Capture a baseline for SC-001/SC-002. Run the app in debug, navigate between the 4 main tabs for 1 minute, save one transaction, then resume after 30 s. Note the number of `[SyncProvider]` log lines and reloads in `specs/001-reduce-auto-sync/quickstart.md` under a new "Baseline (before)" heading — **NOT DONE**: needs a running app on a device; do this manually before merging

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared `SyncProvider` plumbing that US1 and US3 both depend on: trigger-tagged diagnostics (FR-013) and a refactor so a log read can run with or without the cooldown

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Add `enum SyncTrigger { initialLoad, resume, pull, localWriteAck }` in `lib/providers/sync_provider.dart`. Add a private `_log(SyncTrigger trigger, {Iterable<SyncModule> reloaded = const [], Iterable<SyncModule> acknowledged = const [], bool skippedCooldown = false})` that prints one line in the format `[SyncProvider] trigger=<name> reloaded=[...] acknowledged=[...]` (append ` skipped(cooldown)` when skipped)
- [X] T004 In `lib/providers/sync_provider.dart`:
  - Make `_refreshChanged` return the `Set<SyncModule>` of refresh targets it reloaded, without changing its existing semantics.
  - Make `_readRemoteLogs` also store the result in a new `_remoteSnapshot` (`Map<SyncModule, DateTime>?`) with `_snapshotAt = _now()`.
  - Call `_log` from `_initialize` (`SyncTrigger.initialLoad`) and from `_checkAndSync` (`SyncTrigger.resume`, including the cooldown-skip path).
- [X] T005 Extend `reset()` in `lib/providers/sync_provider.dart` to also clear `_remoteSnapshot` and `_snapshotAt` (FR-014). Leave placeholders for the US1 ack state, which T010 extends.
- [X] T006 Run `flutter test test/sync_provider_test.dart` and confirm the existing tests still pass after the refactor

**Checkpoint**: Foundation ready. Behavior is unchanged except for the extra log lines.

---

## Phase 3: User Story 1 - No redundant re-downloads after my own changes (Priority: P1) 🎯 MVP

**Goal**: A save on this device does not cause a later reload of the same module. Changes from other devices and server-trigger side effects are still reloaded (FR-001 – FR-003).

**Independent Test**: Quickstart scenarios 2, 3, and 6. Save on device A and resume after 30 s: the log shows `acknowledged=[transactions]` and no `transactions` reload. A portfolio transfer reloads `accounts` once. A change from device B made before A's save is still reloaded.

### Tests for User Story 1

- [X] T007 [P] [US1] Add tests to `test/sync_provider_test.dart`, using fake `getSyncLogs` and refreshers in the existing style, with `ackDebounce: Duration.zero` and `snapshotMaxAge: Duration.zero`:
  - (a) `beforeWrite({'transactions'})` with remote == baseline, then `afterWrite(success: true)` with remote bumped → ack adopts the timestamp, and a following `checkAndSync()` after the cooldown does **not** call the transactions refresher.
  - (b) Remote transactions newer than the baseline **before** `beforeWrite` → after the ack, the transactions refresher **is** called once.
  - (c) Write to `transactions` where the ack read also shows `accounts` newer → the accounts refresher is called once, and transactions is acknowledged.
  - (d) `afterWrite(success: false)` → no adoption, and the next check reloads transactions.
  - (e) The ack read throws → nothing adopted, the error is swallowed, and the next check reloads.
  - (f) `beforeWrite` snapshot read throws → `beforeWrite` completes normally (does not throw).
  - (g) `reset()` clears pending ack state, so an ack scheduled before reset adopts nothing.

### Implementation for User Story 1

- [X] T008 [US1] Declare `abstract interface class SyncWriteObserver { Future<void> beforeWrite(Set<String> moduleKeys); void afterWrite(Set<String> moduleKeys, {required bool success}); }` in `lib/repositories/database_repository.dart`. Add a `SyncWriteObserver? syncWriteObserver;` member to the `DatabaseRepository` abstraction, as specified in `specs/001-reduce-auto-sync/contracts/sync-write-observer.md`.
- [X] T009 [US1] Add constructor params `Duration snapshotMaxAge = const Duration(seconds: 5)` and `Duration ackDebounce = const Duration(milliseconds: 400)` to `SyncProvider` in `lib/providers/sync_provider.dart`, plus the state `_ackEligible` (`Set<SyncModule>`), `_foreignDirty` (`Set<SyncModule>`), and `_ackTimer` (`Timer?`) per `specs/001-reduce-auto-sync/data-model.md`.
- [X] T010 [US1] Make `SyncProvider implements SyncWriteObserver` in `lib/providers/sync_provider.dart`:
  - **`beforeWrite`**:
    - Map the keys with `SyncModule.fromKey`.
    - Refresh `_remoteSnapshot` through `_readRemoteLogs` only if it is null or older than `snapshotMaxAge`.
    - For each module: if `remote(m)` is equal to or older than `_localTimestamps[m]` (or both are null), add it to `_ackEligible`; otherwise add it to `_foreignDirty` and remove it from `_ackEligible`.
    - Catch and log every error, never rethrow, and leave the module neither eligible nor dirty on error.
    - Skip everything when `!isAuthenticated()` or `!_hasBaseline`.
  - **`afterWrite`**:
    - On `success: false`, remove the modules from `_ackEligible`.
    - On success, (re)start `_ackTimer` with `ackDebounce`, which calls `_runAck()`.
  - **`_runAck()`**:
    - Read the logs once.
    - For modules that are in `_ackEligible`, not in `_foreignDirty`, and whose remote is newer than local, set `_localTimestamps[m] = remote` with no reload.
    - Then call `_refreshChanged` for everything else, which picks up side effects and foreign changes.
    - Clear the acknowledged modules from `_ackEligible`, and clear the reloaded modules from `_foreignDirty`.
    - Log with `SyncTrigger.localWriteAck`, and catch and log errors without rethrowing.
    - Join with `_activeCheck` or `_activeInitialization` so it never runs in parallel with them.
  - Add a short comment explaining the pre-write snapshot (research R1).
- [X] T011 [US1] Extend `reset()` in `lib/providers/sync_provider.dart` to cancel `_ackTimer` and clear `_ackEligible` and `_foreignDirty` (FR-014). In `_refreshChanged`, remove reloaded modules from `_foreignDirty`.
- [X] T012 [US1] Add `Future<T> _trackWrite<T>(Set<String> modules, Future<T> Function() write)` to `lib/repositories/supabase_repository.dart`, following `contracts/sync-write-observer.md`:
  - If `syncWriteObserver` is null, pass through.
  - Otherwise await `beforeWrite`, run `write`, call `afterWrite(success: true)`, and on error call `afterWrite(success: false)` and rethrow.
  - Implement the `syncWriteObserver` field.
- [X] T013 [US1] Wrap the account, category, and transaction write delegates in `lib/repositories/supabase_repository.dart` with `_trackWrite`:
  - `{'accounts'}`: `insertAccount`, `updateAccount`, `updateAccountCashBalance`, `updateAccountExchangeRate`, `updateAccountSortOrder`, `updateAccountSortOrders`, `deleteAccount`
  - `{'categories'}`: `insertCategory`, `updateCategory`, `updateCategorySortOrder`, `updateCategorySortOrders`, `deleteCategory`
  - `{'transactions'}`: `insertTransaction`, `updateTransaction`, `deleteTransaction`

  Include only the directly written table's module. Server side effects are not listed.
- [X] T014 [US1] Wrap the portfolio write delegates in `lib/repositories/supabase_repository.dart` with `_trackWrite({'portfolio'}, ...)`: `insertHolding`, `updateHolding`, `updateHoldingMarketData`, `updateHoldingSortOrder`, `deleteHolding`, `deleteHoldingsByPortfolio`, `insertStockTrade`, `updateStockTrade`, `deleteStockTrade`, `insertStockPurchase`, `updateStockPurchase`, `deleteStockPurchase`, `insertPortfolioAnnualReport`, `updatePortfolioAnnualReport`, `deletePortfolioAnnualReport`, `upsertInvestmentPlanMonthStatus`, `upsertPortfolioAllocationTarget`.
- [X] T015 [US1] Wrap the remaining write delegates in `lib/repositories/supabase_repository.dart`:
  - `{'budgets'}`: `insertBudget`, `updateBudget`, `updateBudgets`, `updateBudgetSortOrder`, `deleteBudget`
  - `{'recurring'}`: `insertRecurringTransaction`, `updateRecurringTransaction`, `deleteRecurringTransaction`, `updateRecurringSortOrder`, `updateRecurringSortOrders`, `insertRecurringOccurrence`, `deleteOccurrence`, `deleteOccurrencesByRecurring`
  - `{'cash_flow'}`: `insertFixedCashFlowItem`, `updateFixedCashFlowItem`, `deleteFixedCashFlowItem`, `insertPlannedPurchase`, `updatePlannedPurchase`, `deletePlannedPurchase`, `upsertBudgetForecastSetting`, `deleteBudgetForecastSetting`
  - Bulk and maintenance operations: `bulkInsert*` with the matching module (`bulkInsertHoldings` and `bulkInsertStockTrades` use `portfolio`; `bulkInsertOccurrences` uses `recurring`), `batchInsert(table, …)` with the module mapped from the table name per data-model.md, and `clearAllData()` with all seven module keys.
- [X] T016 [US1] Audit `lib/repositories/supabase_repository.dart` and `lib/repositories/supabase_adapters/*.dart` for any other method that inserts, updates, upserts, deletes, or calls an RPC that writes a trigger-backed table (for example, reorder helpers in `cash_flow_adapter.dart`), and wrap it too. Check the table→module mapping against the trigger list in `specs/001-reduce-auto-sync/data-model.md`, and confirm that `getSyncLogs()` and every read method stay unwrapped.
- [X] T017 [US1] Wire the observer in `lib/main.dart`. After `syncProvider` is constructed, set `dbManager.repositoryOrNull?.syncWriteObserver = syncProvider`. Also re-apply it wherever `DatabaseManager` creates or replaces the repository (`lib/services/database_manager.dart` around the `SupabaseRepository(` construction), for example through a `DatabaseManager.syncWriteObserver` field that is copied onto each new repository, so that setup and reconfiguration flows keep the observer.
- [X] T018 [US1] Run `flutter test test/sync_provider_test.dart` and make T007 (a)–(g) pass

**Checkpoint**: Own writes no longer trigger reloads (verify with quickstart scenarios 2, 3, and 6).

---

## Phase 4: User Story 2 - Fewer background checks while navigating (Priority: P1)

**Goal**: No automatic checks on route changes or tab switches; the resume check stays with the 30 s cooldown (FR-004, FR-005).

**Independent Test**: Quickstart scenarios 1 and 4. Navigating for 1 minute produces no `trigger=` lines. Resuming after an edit on device B produces `trigger=resume reloaded=[budgets]`.

### Tests for User Story 2

- [X] T019 [P] [US2] Add a test to `test/sync_provider_test.dart`: two `checkAndSync()` calls within the 30 s `cooldown` (injected `now`) read the logs only once, and a call after the cooldown reads them again. This locks in the resume-only cooldown behavior. — covered by the existing test `cooldown suppresses repeated eligible triggers`, so no duplicate test was added

### Implementation for User Story 2

- [X] T020 [P] [US2] In `lib/main.dart`, change the `_routeInformationListener` (around lines 296–302) to call only `setState(() {})` when mounted, removing the `_checkAndSync()` call. Keep `didChangeAppLifecycleState` (resume) and `_checkAndSync()` unchanged.
- [X] T021 [P] [US2] In `lib/screens/main_tab_screen.dart` `_selectTab` (around lines 38–46), remove the `SyncProvider` read and the `checkAndSync()` call, keeping only the tab state change. Remove the `SyncProvider` import if it becomes unused.

**Checkpoint**: Navigation is silent; resume still syncs.

---

## Phase 5: User Story 3 - Pull down to refresh on main lists (Priority: P2)

**Goal**: Accounts, Transactions, and Budgets lists support pull-to-refresh. A pull bypasses the cooldown, force-reloads the screen's module, and shows an error SnackBar on failure while keeping the current data (FR-006 – FR-010, FR-012).

**Independent Test**: Quickstart scenarios 5, 7, 8, and 9.

### Tests for User Story 3

- [X] T022 [P] [US3] Add tests to `test/sync_provider_test.dart` for `refresh(forceModules:)`:
  - (a) Runs even within the cooldown right after `checkAndSync()`.
  - (b) Force-reloads `transactions` when the logs show no change.
  - (c) Calls the `accounts` refresher only once when `forceModules: {SyncModule.accounts}` and the logs also show `portfolio` changed (refreshTarget).
  - (d) Rethrows when `getSyncLogs` throws.
  - (e) Rethrows when a refresher throws.
  - (f) Concurrent `refresh()` calls share one execution (the refresher is called once).

### Implementation for User Story 3

- [X] T023 [US3] Implement `Future<void> refresh({Set<SyncModule> forceModules = const {}})` in `lib/providers/sync_provider.dart` per `contracts/sync-provider.md`:
  - Return the shared in-flight `_activeRefresh` if there is one.
  - Await any `_activeInitialization` or `_activeCheck`.
  - Read the logs (ignoring the cooldown), then `final reloaded = await _refreshChanged(logs)`.
  - For each `forceModules` target (`m.refreshTarget`) not in `reloaded`, call its refresher and set `_localTimestamps[m] = logs[m]` where present.
  - Set `_lastCheckTime = _now()` and log `SyncTrigger.pull`.
  - **Rethrow** errors.
  - Clear `_activeRefresh` in `finally`, and clear it in `reset()` as well.
- [X] T024 [P] [US3] Create `lib/widgets/app_refresh_indicator.dart` with `AppRefreshIndicator({required Future<void> Function() onRefresh, required Widget child})` per `contracts/app-refresh-indicator.md`:
  - Wrap `RefreshIndicator.adaptive`.
  - Use color `AppColors.accentFor(isDarkMode, themeColor)` and background `AppColors.surfaceFor(isDarkMode)`, read from `SettingsProvider`.
  - Await `onRefresh` inside try/catch. On error, show `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('รีเฟรชข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง')))` (only if mounted) and complete normally.
- [X] T025 [US3] In `lib/screens/account/account_list_screen.dart`, wrap the main `CustomScrollView` (around line 161) with `AppRefreshIndicator(onRefresh: () => context.read<SyncProvider>().refresh(forceModules: {SyncModule.accounts}), ...)`. Give the scroll view `AlwaysScrollableScrollPhysics` (parented to its existing physics if any). The file MUST stay ≤800 lines.
- [X] T026 [US3] In `lib/screens/transaction/transaction_list_screen.dart`, wrap the body `CustomScrollView` (around line 182) with `AppRefreshIndicator(onRefresh: () => context.read<SyncProvider>().refresh(forceModules: {SyncModule.transactions}), ...)` and ensure `AlwaysScrollableScrollPhysics`. If the screen is also used as a filtered secondary screen, the pull must work there too. The file MUST stay ≤800 lines.
- [X] T027 [US3] In `lib/screens/budget/budget_list_screen.dart`, wrap the widget that returns the list variants (flat, grouped, and empty-state `ReorderableListView`/`ListView`, around lines 378–561) with `AppRefreshIndicator(onRefresh: () => context.read<SyncProvider>().refresh(forceModules: {SyncModule.budgets}), ...)`. Make every variant (including the empty state in `budget_empty_state.dart` if it is not scrollable) use `AlwaysScrollableScrollPhysics`, so that an empty list can still be pulled. If pulling conflicts with reorder mode, disable the indicator while reordering. The file MUST stay ≤800 lines.
- [X] T028 [P] [US3] Add an `AppRefreshIndicator` row to the "Shared widgets และ tokens" table in `docs/design.md`, covering `RefreshIndicator` / `RefreshIndicator.adaptive` and file `lib/widgets/app_refresh_indicator.dart`. Add one sentence to "หน้าจอและการนำทาง" stating that main lists (Accounts, Transactions, Budgets) support pull-to-refresh, which bypasses the cooldown and shows a SnackBar on failure.
- [X] T029 [P] [US3] Add a rule to `tool/check_design.sh`: `check 'Use AppRefreshIndicator instead of RefreshIndicator' '(^|[^A-Za-z0-9_])RefreshIndicator(\.adaptive)?\(' $(files_except 'lib/widgets/app_refresh_indicator\.dart')`
- [X] T030 [US3] Run `flutter test test/sync_provider_test.dart` and make T022 (a)–(f) pass

**Checkpoint**: All three stories work independently.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T031 Run `dart format .` at the repository root
- [X] T032 Run `flutter analyze` and fix any new errors or warnings in touched files
- [X] T033 Run `flutter test` (full suite) and fix tests broken by the change, for example `test/transaction_form_calculator_test.dart` if it constructs providers or repositories
- [X] T034 Run `bash tool/check_design.sh` (Git Bash on Windows) and make it pass, including the new rule from T029
- [X] T035 Verify the line counts of `lib/screens/account/account_list_screen.dart`, `lib/screens/transaction/transaction_list_screen.dart`, and `lib/screens/budget/budget_list_screen.dart` are each ≤800 (Constitution V)
- [ ] T036 Execute the manual scenarios 1–12 in `specs/001-reduce-auto-sync/quickstart.md` on two devices. Record "after" counts next to the T002 baseline for SC-001 and SC-002, and confirm SC-006 (balances and totals are unchanged) — **NOT DONE**: manual two-device verification is still pending
- [X] T037 Stop any `flutter run` or emulator processes started for verification (user global rule) — no app or emulator was started (only `flutter test`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none
- **Foundational (Phase 2)**: after Setup. Blocks US1 and US3, which both edit `sync_provider.dart` on top of the refactor
- **US1 (Phase 3)**: after Foundational
- **US2 (Phase 4)**: independent of Foundational in code (it only touches `main.dart` and `main_tab_screen.dart`), so it can start after Setup. T019 is appended to the shared test file
- **US3 (Phase 5)**: after Foundational. Independent of US1, although T023 and the US1 tasks edit the same file (`sync_provider.dart`), so do them sequentially
- **Polish (Phase 6)**: after all desired stories

### User Story Dependencies

- **US1 (P1)**: no dependency on other stories
- **US2 (P1)**: no dependency. On its own, without US1, it still reduces checks but leaves the self-write reload
- **US3 (P2)**: no functional dependency. It is recommended together with US2, because pull replaces the freshness that navigation triggers used to provide

### Within Each User Story

- Tests are written first (T007, T019, T022) and fail until implemented
- `database_repository.dart` (T008) comes before `sync_provider.dart` observer work (T010) and before `supabase_repository.dart` wrapping (T012–T016)
- T012 comes before T013–T016, which all edit the same file and must run sequentially
- T017 wiring comes after T010 and T012

### Parallel Opportunities

- T007, T019, and T022 are test additions in the same file, so they are not truly parallel with each other. Each is marked [P] relative to the implementation files of its own story
- T020 and T021 (US2) touch different files and can run in parallel
- T024, T028, and T029 (US3: widget, design doc, design check) touch different files and can run in parallel, before T025–T027
- US2 as a whole can proceed in parallel with US1 or US3 (different files, except `main.dart`: T017 and T020 touch different regions, so do them sequentially)

---

## Parallel Example: User Story 3

```text
# After T023 (SyncProvider.refresh) is done, launch together:
Task: "T024 Create AppRefreshIndicator in lib/widgets/app_refresh_indicator.dart"
Task: "T028 Document AppRefreshIndicator in docs/design.md"
Task: "T029 Add RefreshIndicator rule to tool/check_design.sh"
# Then wire screens (different files, can also run in parallel):
Task: "T025 account_list_screen.dart"  |  "T026 transaction_list_screen.dart"  |  "T027 budget_list_screen.dart"
```

## Parallel Example: User Story 2

```text
Task: "T020 Remove route-change sync call in lib/main.dart"
Task: "T021 Remove tab-switch sync call in lib/screens/main_tab_screen.dart"
```

---

## Implementation Strategy

### MVP First

1. Complete Phases 1–2 (Setup, Foundational).
2. Complete Phase 3 (US1), which is the biggest request saving and has no UI change.
3. **Stop and validate** with quickstart scenarios 2, 3, and 6.

### Incremental Delivery

1. US1 removes self-write reloads.
2. **US2 and US3 should ship together**. Removing the navigation triggers without pull-to-refresh leaves resume as the only way to get fresh data while the app is open, so release US2 in the same build as US3.
3. Polish (Phase 6) runs the quality gates and a two-device verification.

---

## Notes

- Portfolio Detail pull-to-refresh is intentionally **not** included (research R5: the file is at the 800-line limit).
- No migration, and no `sync_logs` schema change.
- Commit after each phase. Commit messages are in English (user global rule).
