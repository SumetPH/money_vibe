# Concept: Fewer background refreshes, plus refresh on demand

- **Slug**: pull-to-refresh
- **Created**: 2026-10-30
- **Recommended option**: Option B (Hybrid: trim automatic refresh and add pull-to-refresh)

## Options

### Option A: Trim automatic refresh only (smallest thing that could work)

- **Sketch**:
  - The app stops re-fetching data the user just changed on the same device. A write made here counts as already-known data.
  - Automatic checks on route changes and tab switches are removed, so only the check on app resume remains.
  - Nothing new appears in the UI.
- **Appetite**: small (days)
- **Trade-offs**:
  - Wins:
    - Targets what the research identified as the likely waste, the self-write reload.
    - Cuts most of the trigger frequency.
    - No new UI and no `docs/design.md` change.
  - Sacrifices:
    - Users still cannot force a refresh.
    - Data edited on another device only shows up after backgrounding and resuming the app.
  - Risk: the self-write fix has to be correct for every module, including portfolio, which refreshes through accounts. A mistake would hide genuine remote changes.
- **Rabbit holes**:
  - Server-side triggers that change other modules as a side effect, such as transfers touching portfolio cash or recurring occurrences. These make it unclear what "my own write" covers.
  - Updating `test/sync_provider_test.dart` accordingly.

### Option B: Hybrid (Option A plus pull-to-refresh on the main list screens)

- **Sketch**:
  - Includes everything in Option A.
  - The main list screens get pull-to-refresh: accounts, transactions, and budgets, plus portfolio detail if it fits.
  - Pulling down asks the server for the latest data, bypassing the cooldown. It reuses the existing "reload only what changed" behavior, with a forced full reload of the screen's module as a possible variant to decide in spec.
  - The automatic check on app resume stays, so users returning from another device still see fresh balances.
  - The gesture becomes a documented pattern in `docs/design.md`.
- **Appetite**: small to medium (about 1–2 weeks)
- **Trade-offs**:
  - Wins:
    - Meets all three goals: fewer requests, kept freshness on resume, and user control.
    - Matches common mobile convention.
  - Sacrifices:
    - More UI surface across several screens.
    - Needs a shared widget or pattern and a design-doc entry.
  - Risks:
    - Inconsistent coverage: screens without a top-level scroll list, such as forms and statistics, will not support the gesture.
    - Users may not discover the gesture.
- **Rabbit holes**:
  - Screens with nested scroll views or custom headers (glass bottom nav, sliver layouts) where pull-to-refresh conflicts with existing scrolling.
  - Deciding the refresh scope per screen: this module only, or everything.
  - Defining loading and error feedback when the refresh fails offline.

### Option C: Pure pull-to-refresh (the original request)

- **Sketch**:
  - All automatic background refresh is removed: on resume, on route change, and on tab switch.
  - Data updates only at startup or login, after the user's own writes, or when the user pulls to refresh.
- **Appetite**: small to medium (about 1–2 weeks, similar to B)
- **Trade-offs**:
  - Wins:
    - The largest request reduction.
    - The simplest mental model: nothing happens unless the user asks.
  - Sacrifices:
    - Freshness. A user who edits on another device or lets the app sit in the background sees stale balances until they pull.
    - Screens without pull-to-refresh can only be refreshed by restarting.
  - Risks:
    - Silent staleness in a finance app.
    - Discards most of the sync-log infrastructure investment, which would make the DB triggers on `sync_logs` partially redundant.
- **Rabbit holes**:
  - Whether to remove or keep the `sync_logs` table and its triggers. Removing them is a schema migration, which brings scope creep.
  - Stale-data indicators would be needed to make up for the lost automatic refresh.

### Option D: Do nothing / measure first

- **Sketch**:
  - Keep the current behavior.
  - Optionally gather Supabase usage numbers first to confirm whether background refresh is a meaningful cost.
- **Appetite**: small (hours, to check Supabase dashboard usage)
- **Trade-offs**:
  - Wins: zero risk, and it avoids optimizing a cost that may be negligible for a single-user app.
  - Sacrifices: the known redundant reload stays, and users still lack an explicit refresh.

## Recommendation

**Option B (Hybrid)** is recommended.

- It fixes the likely real source of waste, the self-write reload, and removes the high-frequency triggers on route and tab changes. That serves the "fewer requests" goal and the self-write reload metric.
- Keeping the resume check protects the "users stay confident data is current" goal, which matters for balances when the app is used on more than one device.
- Pull-to-refresh adds the on-demand control the owner originally asked for.

Option C would cut more requests than B, but at the cost of freshness. The research suggests the remaining resume-only check is cheap: one small query of at most 7 rows, at most once per resume.

If the owner confirms they use only one device and want zero automatic traffic, Option C becomes reasonable. If Supabase usage turns out to be negligible, start with Option A alone, or Option D.

## Out of Scope (for the recommended option)

- The full data load at app start or login, and the reload after import or reset in Data Management.
- Offline support, a local cache, or SQLite (forbidden by AGENTS.md).
- Realtime push or live subscriptions.
- Dropping or reshaping the `sync_logs` table and its DB triggers.
- Pull-to-refresh on forms, the Statistics screen, settings, and other non-list screens.
- Stale-data indicators or "last updated" timestamps in the UI. These can be revisited separately.
- Any change to financial calculations, validation, or schema.

## Assumptions to Validate

- Redundant self-write reloads account for a meaningful share of background requests. This is inferred from code and not measured.
- Route-change and tab-switch triggers make up most of the `checkAndSync` calls in a normal session.
- Keeping the resume check is acceptable to the owner, given the original goal of moving to pull-to-refresh.
- The owner, or users, sometimes use more than one device. If not, Option C's freshness downside shrinks.
- The main list screens have a top-level scrollable that can host pull-to-refresh without conflicting with existing scroll behavior.
- Each refresh can be attributed to the device's own writes, including server-side side effects such as portfolio cash on transfers, so that real remote changes are not suppressed.
