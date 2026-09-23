# Background refresh sync hardening

Status: ready-for-agent

## Problem Statement

ผู้ใช้ Money Vibe บนหลายอุปกรณ์อาจเห็นข้อมูลเก่า เนื่องจาก background refresh sync ปัจจุบันอาศัย timestamp จากเครื่องผู้ใช้ ยืนยัน checkpoint แม้ refresh ล้มเหลว มี mutation บางเส้นทางที่ไม่อัปเดต sync log และมี module key ที่ฝั่งเขียนกับฝั่ง refresh รองรับไม่ตรงกัน จึงอาจพลาดการเปลี่ยนแปลงข้ามอุปกรณ์ได้ถาวร

ระบบยังขยายจำนวน request โดยไม่จำเป็น: cold start โหลด provider แล้วโหลดซ้ำเมื่อ local checkpoint ยังว่าง, `accounts` กับ `portfolio` สั่ง refresh AccountProvider ตัวเดียวกันซ้ำกัน, mutation ปกติใช้ request เพิ่มเพื่อเขียน sync log และ reorder บางชุดอัปเดตทีละแถวพร้อม sync log ทีละครั้ง นอกจากนี้ account reload ยังดึงและเขียนอัตราแลกเปลี่ยนอัตโนมัติ ซึ่งสามารถกระตุ้น sync กลับไปมาระหว่างอุปกรณ์

## Solution

ทำให้ background refresh sync เป็น action-triggered sync ที่เชื่อถือได้และมี request เท่าที่จำเป็น โดยให้ Supabase เป็นผู้บันทึก sync log ด้วย server time ภายใน transaction เดียวกับ data mutation, ใช้ canonical module keys ชุดเดียวตลอดระบบ และให้ sync coordinator refresh provider แต่ละตัวสูงสุดเพียงหนึ่งครั้งต่อ sync pass

ระบบจะเก็บ checkpoint เมื่อ refresh สำเร็จเท่านั้น และจะคง single-flight กับ cooldown 30 วินาทีไว้เพื่อป้องกัน request storm การเข้าแอป เข้าระบบ กลับจาก background และเปลี่ยน user-visible navigation จะวิ่งผ่าน coordinator เดียว รวมถึงการสลับ Main Tab แบบ local state

## User Stories

1. As a Money Vibe user, I want data changed on another device to appear after I return to the app, so that I do not need to restart it.
2. As a Money Vibe user, I want data changed on another device to appear when I navigate to another user-visible area, so that each area reflects current server data.
3. As a Money Vibe user, I want switching a Main Tab to trigger an eligible sync check, so that local tab navigation does not bypass refresh.
4. As a Money Vibe user, I want concurrent navigation and resume events to share one sync check, so that the app does not send duplicate requests.
5. As a Money Vibe user, I want rapid navigation within 30 seconds to reuse the existing cooldown, so that ordinary app use does not create a request storm.
6. As a multi-device user, I want account changes to refresh once per sync pass, so that `accounts` and `portfolio` changes do not reload the same provider twice.
7. As a portfolio user, I want holdings, stock trades, stock purchases, investment plans, allocation targets, and annual reports to refresh through the same portfolio module, so that none of those records remain stale.
8. As a transaction user, I want remote transaction inserts, updates, and deletes to refresh the transaction list, so that balances and reports use current data.
9. As a budget user, I want remote budget changes to refresh the budget list, so that category assignments and limits remain current.
10. As a recurring-transaction user, I want changes to Recurring transactions and Occurrences to refresh together, so that schedules, statuses, and notifications stay consistent.
11. As a user importing CSV data, I want every successfully imported module to advance its sync log, so that my other devices discover the imported records.
12. As a user clearing all data, I want every affected module to advance its sync log, so that other devices remove their stale in-memory records.
13. As a user reordering accounts, categories, budgets, or Recurring transactions, I want the new order saved with a bounded number of requests, so that larger lists do not become progressively slower.
14. As a user whose device clock is inaccurate, I want sync ordering to use server time, so that clock or timezone drift cannot hide remote updates.
15. As a user on an unreliable network, I want a failed refresh to remain retryable, so that a temporary failure does not permanently acknowledge unseen data.
16. As a user on an unreliable network, I want a failed sync-log read to be distinguishable from an account with no sync logs, so that the app retries instead of treating an error as an empty result.
17. As a user reopening the app, I want initial provider loading to establish a safe checkpoint without immediately loading every provider again, so that startup remains responsive.
18. As a user whose data changes during initial loading, I want the coordinator to detect that race, so that establishing the initial checkpoint cannot acknowledge data that providers did not load.
19. As a user with USD accounts, I want background data refresh to avoid fetching and writing exchange rates, so that sync does not create cross-device update loops.
20. As a user with many transactions, I want existing paginated transaction loading to remain correct, so that synchronization does not truncate history.
21. As a signed-in user switching to another account, I want sync checkpoints and cooldown state reset for the new user, so that one user's timestamps cannot affect another user's refresh.
22. As a signed-out user, I want sync checks to do no network work, so that unauthenticated screens remain quiet.
23. As a user, I want a local mutation to remain visible while the next sync establishes the authoritative server checkpoint, so that background refresh does not overwrite my recent action with an older snapshot.
24. As a user, I want recurring notification rescheduling to remain correct after a remote recurring-data refresh, so that synchronization does not regress reminders.
25. As a user on mobile or web, I want the same sync semantics, so that cross-device behavior does not depend on platform.
26. As a developer, I want unknown module keys rejected or surfaced clearly, so that adding a new persisted entity cannot silently produce a sync log with no refresh consumer.
27. As a developer, I want request counts observable in focused tests, so that future changes do not reintroduce duplicate startup or per-row sync requests.

## Implementation Decisions

- Keep action-triggered synchronization. Eligible triggers are initial authenticated loading, successful sign-in, app resume, top-level navigation, and Main Tab selection. Continuous polling and operating-system background jobs are not introduced.
- Keep the existing 30-second cooldown and single-flight behavior. Concurrent callers receive the same in-flight result; a failed pass becomes eligible for retry after the cooldown.
- Make the sync coordinator the single public behavior seam. It receives the authenticated sync-log reader and one canonical module-to-refresh callback registry. Production callbacks invoke the existing providers; tests use controlled callbacks without constructing application screens.
- Define exactly six canonical module keys: `accounts`, `portfolio`, `categories`, `transactions`, `budgets`, and `recurring`. The database, repository, coordinator, diagnostics, and tests use this shared vocabulary.
- Treat portfolio annual reports as part of `portfolio`. Existing `portfolio_annual_reports` sync-log state is merged into `portfolio` using the later server timestamp, then the obsolete key is removed.
- Add a database constraint that rejects module keys outside the canonical set, while retaining uniqueness per user and module and the existing user isolation policy.
- Make Supabase the authority for sync-log writes. Database triggers update the appropriate sync-log row with server time in the same database transaction as each successful insert, update, or delete.
- Use one generic trigger function for tables that carry `user_id`. The annual-report trigger derives the user through its portfolio account. Every persisted table owned by the six modules must be mapped exactly once.
- Remove client-authored sync timestamps and explicit per-mutation sync-log requests. The client retains only the ability to read sync logs.
- Preserve the existing full-module refresh model. A changed module reloads its provider snapshot; incremental row sync, tombstones, merge resolution, and Supabase Realtime are deferred.
- Group changed module keys by refresh callback before loading. `accounts` and `portfolio` may share AccountProvider data, but the callback runs only once in a sync pass and acknowledges every covered key only after success.
- Advance a module checkpoint only after its refresh callback completes successfully. Unknown modules, thrown errors, canceled work, and unsuccessful provider loads leave the checkpoint unchanged.
- Make provider refresh failures observable to the coordinator. A provider may report loading state to the UI, but its refresh Future must fail when authoritative data could not be loaded.
- Distinguish a successful empty sync-log response from a failed request. Repository failures propagate to the coordinator and are logged without replacing checkpoints.
- Establish the initial checkpoint with a before-and-after protocol: read sync logs, load providers, then read sync logs again. Modules whose server timestamp changed during loading are refreshed once; unchanged modules adopt the post-load checkpoint without a second full reload.
- Reset checkpoints, initial-baseline state, and cooldown when the authenticated user identity changes or signs out.
- Keep background account/portfolio refresh pure: it loads persisted account and portfolio data but does not fetch market-derived exchange rates or write account rows. Exchange-rate refresh remains an explicit, independently guarded operation.
- Ensure a refresh snapshot cannot replace a local mutation that started after the refresh began. Use the existing provider boundary to serialize or reject stale snapshot application rather than adding guards in individual screens.
- Route user-visible navigation triggers through the application navigation host. Remove duplicated screen-level initial callbacks once the host covers their entry paths.
- Submit reorder changes as one batch request per affected collection, reusing the existing batch-upsert approach already used by budgets. Database triggers create the module sync signal inside that request.
- Preserve transaction pagination at 1,000 rows per page and all existing Provider notifications, repository data shapes, local-time rules for financial data, validation, recurring notification behavior, and UI flows.
- Add the trigger and canonical-key changes through a new migration and include that migration in the consolidated initialization schema.
- Preserve RLS isolation: users can read only their own sync logs, and trigger-written rows always use the owner of the mutated data.

## Testing Decisions

- Test the public sync-coordinator seam and externally visible callback behavior, not private maps, switch statements, widget lifecycle methods, or exact log messages.
- Follow the existing service-test style: controlled collaborators, deterministic timestamps, and call counters without adding a mocking dependency or a new test framework.
- Verify that two simultaneous checks perform one sync-log read and share one completion result.
- Verify that repeated eligible triggers inside 30 seconds perform no additional read, while a trigger after the cooldown does.
- Verify that unauthenticated checks perform no read or refresh callback.
- Verify that unchanged server checkpoints refresh nothing.
- Verify that `accounts` and `portfolio` changes sharing one callback refresh once and acknowledge both keys only after success.
- Verify that annual-report changes arrive through the canonical `portfolio` module.
- Verify that a callback failure leaves its checkpoint unchanged and the module refreshes on the next eligible check.
- Verify that a failed sync-log request differs from an empty successful response and does not replace checkpoints.
- Verify initial loading with identical before/after logs performs no duplicate provider refresh.
- Verify a module changed between the before/after initial reads receives one compensating refresh before its checkpoint advances.
- Verify an authentication identity change clears prior checkpoints and cooldown state.
- Verify a local mutation racing with refresh remains visible and causes stale snapshot application to be rejected or retried.
- Verify account/portfolio background refresh never invokes the exchange-rate updater.
- Verify request-count behavior: cold initialization uses only the normal provider loads plus two small checkpoint reads when no concurrent change exists; each changed provider callback runs at most once per pass; reorder uses one client data request per affected collection; mutation sends no explicit client sync-log request.
- Add database integration scenarios for insert, update, and delete on every mapped table. Each successful mutation must advance exactly the correct user/module row using server time.
- Add database integration scenarios for bulk import and clear-all behavior, including transactions with more than one batch.
- Verify transaction rollback does not advance a sync log, proving data and signal remain atomic.
- Verify RLS prevents one user from reading or writing another user's sync logs.
- Retain existing recurring-notification service tests and verify a remote recurring refresh still reschedules notifications through existing behavior.
- Run repository formatting and targeted static analysis after implementation. Perform a live two-session check with one mobile or web client changing each module and the other client refreshing on navigation and resume; record this separately from automated verification.

## Out of Scope

- Supabase Realtime subscriptions or websocket-based live updates.
- Fixed-interval polling, background fetch plugins, or operating-system background execution.
- Incremental row-level synchronization, deleted-row tombstones, offline-first queues, or conflict-resolution UI.
- Changing transaction pagination size or loading only a reporting-period subset.
- Changing exchange-rate sources, market-price calculations, portfolio valuation, or automatic-rate business rules.
- UI redesign, new sync indicators, progress screens, manual refresh controls, or user-facing error banners.
- Changing financial data timezone behavior; server time applies only to sync metadata.
- Adding a dependency, code-generation layer, generic repository framework, or new state-management library.
- Refactoring unrelated repository adapters or Provider business logic.

## Further Notes

- “Background refresh” in this spec means action-triggered refresh while the app is active or resumes; it does not promise continuous synchronization while a screen remains idle.
- The current single-flight and cooldown mechanisms are retained because they already prevent concurrent and rapid duplicate checks.
- The previous implementation can issue roughly 32 Supabase reads during a cold authenticated start with fewer than 1,000 transactions and all six core sync logs present, before exchange-rate work. The target steady path removes the second full provider load.
- Full-module reload remains intentionally simple. Reconsider incremental transaction sync only after runtime measurement shows payload size or latency is a user-visible bottleneck.
- Live multi-device verification is required because static analysis cannot prove Supabase trigger deployment, RLS behavior, or cross-session refresh timing.
