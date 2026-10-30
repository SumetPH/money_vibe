# Idea Intake: Replace auto data reload with pull-to-refresh

- **Slug**: pull-to-refresh
- **Created**: 2026-10-30
- **Source**: pasted text (via `/speckit-assess-intake`); related code in `lib/main.dart`, `lib/providers/sync_provider.dart`
- **Type**: improvement

## Idea (as captured)

> อยากจะเปลี่ยน auto reload data เป็นการใช้ pull refresh คิดว่ายังไง

(Translation: "I'd like to change the auto reload of data to using pull-to-refresh — what do you think?")

## Restated

Replace the app's automatic data reload with a user-initiated pull-to-refresh gesture, so data is re-fetched from Supabase when the user pulls down on a screen rather than automatically.

## Origin & Context

- **Raised by**: project owner (SumetPH)
- **Trigger**: wish to reduce request volume / load on the Supabase backend caused by automatic syncing.

### Current behavior (observed in repo, not evaluated)

- `lib/main.dart` (`didChangeAppLifecycleState`): on `AppLifecycleState.resumed`, if logged in and `SyncProvider.hasBaseline`, calls `syncProvider.checkAndSync()` in the background.
- `lib/providers/sync_provider.dart`: `_checkAndSync()` respects a `cooldown`, reads remote sync logs (`getSyncLogs()`), and calls per-module `refreshers` only for modules whose remote timestamp changed. Initial load (`_initialize`) also establishes a baseline from sync logs.
- No `RefreshIndicator` usage was found in `lib/` at intake time.

## First-Glance Unknowns

- [NEEDS CLARIFICATION: Which "auto reload" is meant — only the on-resume `checkAndSync`, initial load after login, provider reloads after save/delete, or all of them?]
- [NEEDS CLARIFICATION: Should auto sync on resume be removed entirely, or kept alongside pull-to-refresh (e.g. with a longer cooldown)?]
- [NEEDS CLARIFICATION: How many requests does the current auto sync actually generate (sync-log check vs. full module refresh), and is it a measurable backend cost?]
- [NEEDS CLARIFICATION: Which screens should support pull-to-refresh, and should a pull refresh only that screen's module or run the global sync check?]
- [NEEDS CLARIFICATION: Is multi-device use (data changed on another device) a primary scenario that depends on auto sync for freshness?]
- [NEEDS CLARIFICATION: Should pull-to-refresh force a full reload or reuse the sync-log "only changed modules" logic?]
