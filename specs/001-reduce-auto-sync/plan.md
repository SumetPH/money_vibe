# Implementation Plan: Reduce Automatic Sync and Add Pull-to-Refresh

**Branch**: `001-reduce-auto-sync` (work currently on `speckit`) | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-reduce-auto-sync/spec.md`

## Summary

The change has five parts:

1. Stop automatic sync checks on route changes and tab switches, and keep the check on app resume.
2. Stop re-downloading data this device wrote itself. `SupabaseRepository` brackets every trigger-backed write and notifies `SyncProvider` (`SyncWriteObserver`). The provider takes a pre-write `sync_logs` snapshot to detect foreign changes, then acknowledges its own writes with one debounced post-write read, and reloads only side-effect or foreign-changed modules.
3. Add pull-to-refresh to the Account, Transaction, and Budget lists through a new shared `AppRefreshIndicator`. A pull calls `SyncProvider.refresh(forceModules: …)`, which bypasses the cooldown, force-reloads the screen's module, and reports errors.
4. Add trigger-tagged debug logs for measurement.
5. No schema change.

## Technical Context

**Language/Version**: Dart / Flutter (project SDK as in `pubspec.yaml`)

**Primary Dependencies**: `provider`, `go_router`, `supabase_flutter` (all existing; nothing new)

**Storage**: Supabase Postgres. The existing `public.sync_logs` table is read-only from the client and its trigger-maintained timestamps are used as-is. No migration.

**Testing**: `flutter_test` (`test/sync_provider_test.dart` extended), plus manual multi-device checks in [quickstart.md](quickstart.md)

**Target Platform**: iOS 15+ and Android (mobile first); wide-screen layout ≥800px unchanged

**Project Type**: mobile-app (Flutter) with a BaaS backend

**Performance Goals**:
- Zero automatic checks during navigation (SC-001).
- At most 2 small `sync_logs` reads per write burst, replacing a full module reload (SC-002).
- A pull completes in ≤3 s on a normal connection (SC-004).

**Constraints**:
- Supabase only; no local cache (Constitution I).
- No timezone conversion. `sync_logs` timestamps are compared server-to-server only (Constitution II).
- Screen files must not exceed 800 lines (Constitution V).

**Scale/Scope**:
- Single user, multiple devices.
- 7 sync modules.
- About 55 repository write delegates to wrap.
- 3 screens get pull-to-refresh.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Supabase-Only Data Layer | ✅ Pass | No local store and no schema change. `sync_logs` is used as-is |
| II. Local-Time Date Handling | ✅ Pass | No `.toUtc()`/`.toLocal()` added. `sync_logs` (timestamptz, server clock) values are only compared with each other, never with device time or user-facing dates |
| III. Repository-First & Provider | ✅ Pass | `SyncWriteObserver` and the `syncWriteObserver` property are declared on `DatabaseRepository` first, then implemented in `SupabaseRepository`. Sync state lives in `SyncProvider`, and the UI only calls the provider |
| IV. Design System & Zero Logic Regression | ✅ Pass | New shared `AppRefreshIndicator` in `lib/widgets/`, documented in `docs/design.md`, and guarded by a `check_design.sh` rule. No calculation, validation, or debounce-timer changes in business code |
| V. Modular Screen Structure | ✅ Pass (with deferral) | Account list (713), Transaction list (751), and Budget list (664) stay under 800 after adding a wrapper of a few lines. Portfolio Detail is at 800 lines, so it is **deferred** (research R5) instead of breaking the limit |
| Quality gates | ✅ Planned | `dart format .`, `flutter analyze`, `flutter test`, and `bash tool/check_design.sh` in [quickstart.md](quickstart.md) |

**Post-design re-check (after Phase 1)**: all gates still pass, and no violations need justification.

## Project Structure

### Documentation (this feature)

```text
specs/001-reduce-auto-sync/
├── plan.md                    # This file
├── research.md                # Phase 0: decisions R1–R8
├── data-model.md              # Phase 1: in-memory sync state, trigger→module mapping
├── quickstart.md              # Phase 1: validation guide
├── contracts/
│   ├── sync-provider.md       # SyncProvider public API (refresh, observer impl)
│   ├── sync-write-observer.md # Repository → sync write bracketing contract
│   └── app-refresh-indicator.md # Shared pull-to-refresh widget contract
├── checklists/requirements.md
└── tasks.md                   # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/
├── main.dart                               # remove route-change sync call; wire repository.syncWriteObserver = syncProvider
├── providers/
│   └── sync_provider.dart                  # refresh(), SyncWriteObserver impl, snapshot/ack state, SyncTrigger logs, reset()
├── repositories/
│   ├── database_repository.dart            # declare SyncWriteObserver + syncWriteObserver
│   └── supabase_repository.dart            # _trackWrite wrapper around trigger-backed write delegates
├── screens/
│   ├── main_tab_screen.dart                # remove tab-switch sync call
│   ├── account/account_list_screen.dart    # wrap CustomScrollView with AppRefreshIndicator
│   ├── transaction/transaction_list_screen.dart  # wrap body CustomScrollView
│   └── budget/budget_list_screen.dart      # wrap list area
└── widgets/
    └── app_refresh_indicator.dart          # NEW shared widget

docs/design.md                              # add AppRefreshIndicator row
tool/check_design.sh                        # add raw RefreshIndicator rule
test/sync_provider_test.dart                # extend
```

**Structure Decision**: This is a single Flutter app that uses the existing `lib/` layering (providers / repositories / screens / widgets). No new module folders are needed. Only `lib/widgets/app_refresh_indicator.dart` is a new file.

## Key Design Decisions

See [research.md](research.md) for full rationale and alternatives.

- **R1, own-write detection**: pre-write snapshot plus a debounced post-write acknowledgement, driven by repository write bracketing. A server-side writer id was rejected because it needs a schema change. The residual masking window is a few seconds and is recoverable by pull or restart.
- **R2, triggers**: remove the route and tab triggers; keep resume with the 30 s cooldown.
- **R3, UI**: `AppRefreshIndicator` wraps `RefreshIndicator.adaptive`, with `AlwaysScrollableScrollPhysics`.
- **R4, pull scope**: changed-only for all modules, plus a forced reload of the screen's primary module. Errors surface as a SnackBar.
- **R5**: Portfolio Detail is deferred because of the 800-line limit.
- **R6**: `SyncTrigger`-tagged `debugPrint` diagnostics.

## Risks

| Risk | Mitigation |
|------|-----------|
| A missed write delegate keeps reloading after own writes, so savings are lower | Safe failure: behavior falls back to today's. The tasks phase includes a grep audit of the `SupabaseRepository` write methods against the trigger table list |
| A wrong table→module mapping causes a foreign change to be acknowledged | Mapping comes from the trigger list in `data-model.md`; plus quickstart scenario 6 |
| Large import or reset triggers many `beforeWrite` calls | The snapshot is reused within `snapshotMaxAge`, and acknowledgements are debounced. The import is followed by an explicit full reload anyway |
| `RefreshIndicator` conflicts with `ReorderableListView` in reorder mode | Verify manually. If there is a conflict, disable the indicator in reorder mode (`AppReorderBanner` state) |

## Complexity Tracking

No constitution violations to justify.
