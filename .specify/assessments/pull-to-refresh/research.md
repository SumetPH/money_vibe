# Idea Research: Replace auto data reload with pull-to-refresh

- **Slug**: pull-to-refresh
- **Created**: 2026-10-30
- **Evidence confidence (overall)**: medium. The code evidence is strong, but there are no runtime metrics or usage data.

## Users & Demand

- The only requester is the project owner, and their stated reason is to reduce request volume and load on the Supabase backend. No other users, tickets, or feedback ask for this. — [source: intake.md, user answer during intake] (confidence: high that this is the stated want; low as evidence of broader demand)
- No observed data shows that users are unhappy with stale data or with background reloads. — [ASSUMPTION: no analytics or feedback sources exist in the repo] (confidence: low)
- The app looks like a single-user personal finance tool, and each user's data is scoped by `user_id`. Data usually goes stale only when the same user edits on another device or when a server-side trigger writes data. — [source: `supabase/migrations/20260516000000_create_sync_logs.sql` RLS policy; `SupabaseRepository.getSyncLogs` filters by `currentUserId`] (confidence: medium)

## Prior Art

### Internal

- **The current "auto reload" is a modular background sync, not a polling timer.** `SyncProvider.checkAndSync()` reads `sync_logs`, which has at most about 7 rows per user (one per module). It then calls a provider `reload` only for modules whose remote `last_updated_at` is newer than the local baseline. — [source: `lib/providers/sync_provider.dart:110-157`, `lib/repositories/supabase_repository.dart:497-513`] (confidence: high)
- **A 30-second cooldown limits how often the check runs.** — [source: `lib/providers/sync_provider.dart:48` (`cooldown = Duration(seconds: 30)`), `:113-116`] (confidence: high)
- **There are three triggers for `checkAndSync`:**
  1. App resume. — [source: `lib/main.dart:322-328`]
  2. Every route change through the GoRouter `routeInformationProvider` listener. — [source: `lib/main.dart:296-302`]
  3. Switching bottom tabs. — [source: `lib/screens/main_tab_screen.dart:38-46`]

  (confidence: high)
- **Full data loads happen outside the background sync.** They run at startup and login (`SyncProvider.initialize`) and after manual import or reset in Data Management. These are separate from the "auto reload" and are not affected by the idea unless it is scoped wider. — [source: `lib/main.dart:107-118`, `lib/screens/auth/auth_screen.dart:67-97`, `lib/screens/settings/data_management_screen.dart:85-90, 185-190`] (confidence: high)
- **The sync design has been revised several times:**
  - It was first introduced in `f52f57b` ("implement modular background sync system…").
  - It was moved from a NavigatorObserver to screen `initState` in `4de0765`.
  - It was later hardened in migration `20260923000000_harden_background_sync.sql`, where DB triggers `touch_sync_log(...)` on accounts, categories, transactions, budgets, recurring, and portfolio tables bump `sync_logs`.

  The owner has already invested in making background sync cheap and targeted. — [source: `git log`; `supabase/migrations/20260923000000_harden_background_sync.sql:48-170`] (confidence: high)
- **The app already refreshes the user's own changes twice.** Every write bumps `sync_logs` through DB triggers, but `SyncProvider` never updates `_localTimestamps` when a write comes from this device. After the cooldown, the next check sees the module as "changed" and reloads it, even though the provider already holds the latest state. This redundant reload, not the `sync_logs` check itself, may be the main source of extra requests. — [source: `lib/providers/sync_provider.dart:137-157` (timestamps update only inside `_refreshChanged`); triggers in `20260923000000_harden_background_sync.sql`] (confidence: medium, inferred from code and not measured at runtime)
- **No pull-to-refresh exists today.** There is no `RefreshIndicator` in `lib/`, and `docs/design.md` has no pull-to-refresh pattern or shared widget, so one would need to be added there under AGENTS.md rules. — [source: repo grep of `lib/`, `docs/design.md`] (confidence: high)
- **Existing tests cover the sync logic.** `test/sync_provider_test.dart` exists, so changing sync behavior means updating it under the AGENTS.md test rule. — [source: `test/sync_provider_test.dart`, AGENTS.md] (confidence: high)

### External

- Pull-to-refresh is a standard mobile pattern that Flutter supports with `RefreshIndicator` (Material) and `CupertinoSliverRefreshControl`. — [ASSUMPTION: general platform knowledge, not fetched] (confidence: high)
- Many apps combine automatic freshness on resume or foreground with pull-to-refresh as a manual override, instead of choosing only one. — [ASSUMPTION: general industry practice, no specific source fetched] (confidence: medium)

## Market & Context

- **Today's workaround for stale data** is to switch tabs or routes, or to background and resume the app. Each of these runs `checkAndSync` once the cooldown has passed. — [source: triggers listed above] (confidence: high)
- **Cost of doing nothing:**
  - Background requests stay at their current level: at most one small `sync_logs` select per 30 seconds of active navigation, plus a reload of changed modules.
  - The redundant reload after self-writes stays as it is.
  - No actual cost figure exists. — [NEEDS CLARIFICATION: Supabase usage numbers] (confidence: low)

## Data & Constraints

- **`sync_logs` query cost:** one `SELECT module_name, last_updated_at` filtered by `user_id`, returning at most 7 rows (module list from `SyncModule`). This is cheap compared with a full module reload. — [source: `lib/repositories/supabase_repository.dart:497-513`, `lib/providers/sync_provider.dart:6-13`] (confidence: high)
- **Module reload cost:** each module refresher, such as `transactionProvider.reload` or `accountProvider.reloadPersistedData`, re-queries that module's tables. Accounts also cover portfolio (`refreshTarget`). These reloads are likely the heavier requests. — [source: `lib/main.dart:85-92`, `lib/providers/sync_provider.dart:15`] (confidence: medium, sizes of each reload not measured)
- **Upper bound on check frequency:** with a 30-second cooldown, an active session issues at most about 120 `sync_logs` checks per hour. — [source: cooldown value; ASSUMPTION about continuous navigation] (confidence: medium)
- **Platform:** Supabase is the only backend, and AGENTS.md forbids SQLite or a local cache. There is no offline store to "refresh into", so a refresh always means a network round trip. — [source: AGENTS.md] (confidence: high)
- **Design constraint:** new UI must follow `docs/design.md`, and `tool/check_design.sh` checks it. A pull-to-refresh pattern would need to be documented there as a shared widget or rule. — [source: AGENTS.md] (confidence: high)
- No Supabase dashboard metrics, request counts, or billing data were available for this research. — [NEEDS CLARIFICATION]

## Evidence Against the Idea

- **The current auto sync is already lightweight.** A check is one small query, it is throttled by a 30-second cooldown, and it reloads only changed modules. Removing it may save little if most load comes from elsewhere. — [source: `sync_provider.dart`, `supabase_repository.dart`] (confidence: medium)
- **The likely waste may be the self-write reload, not auto sync itself.** Fixing that would cut requests without changing UX. Pull-to-refresh alone would not fix it if any automatic check remains, although removing all automatic checks would remove it too. — [source: analysis of `_refreshChanged`, inferred] (confidence: medium)
- **Removing auto sync worsens freshness across devices.** A user who edits on device A and opens device B would see stale balances until they pull. In a finance app, stale balances can mislead. — [ASSUMPTION: multi-device usage is unverified] (confidence: medium)
- **Pull-to-refresh does not fit every screen.** It needs a scrollable list at the top level. Forms, charts (Statistics), and screens with nested scroll views may not suit it, so coverage would be uneven. — [ASSUMPTION: screen layouts not fully audited] (confidence: low)
- **Large previous investment.** The owner has iterated on background sync several times (initial version, observer→initState refactor, DB trigger hardening), and replacing it partly discards that work. — [source: git history, migrations] (confidence: high)

## Gaps & Open Questions

- [NEEDS CLARIFICATION: What are the actual Supabase request counts or costs, and which endpoints dominate (`sync_logs` vs. module table reads)?]
- [NEEDS CLARIFICATION: How often does the self-write redundant reload fire in a normal session? Instrument `_refreshChanged` or use Supabase logs.]
- [NEEDS CLARIFICATION: Does the owner use the app on more than one device, or share an account?]
- [NEEDS CLARIFICATION: Should resume-triggered sync stay while route and tab triggers move to pull-to-refresh, or should all three be removed?]
- [NEEDS CLARIFICATION: Which screens are candidates for pull-to-refresh: Account list, Budget, Transaction list, Statistics, Portfolio detail?]

## Sources

- Repository code (read-only): `lib/providers/sync_provider.dart`, `lib/main.dart`, `lib/screens/main_tab_screen.dart`, `lib/repositories/supabase_repository.dart`, `lib/screens/auth/auth_screen.dart`, `lib/screens/settings/data_management_screen.dart`, `test/sync_provider_test.dart`
- Migrations: `supabase/migrations/20260516000000_create_sync_logs.sql`, `supabase/migrations/20260923000000_harden_background_sync.sql`
- Git history: commits `f52f57b`, `4de0765`, `4465773`, `8a396a8`, `9035997`, `8f4706c`
- Project rules: `AGENTS.md`, `docs/design.md`
- No external URLs were fetched.
