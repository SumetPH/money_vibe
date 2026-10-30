# Data Model: Reduce Automatic Sync and Add Pull-to-Refresh

**Feature**: [spec.md](spec.md) | **Date**: 2026-10-30

This feature needs **no database schema change**. All entities below are either in-memory state inside `SyncProvider` or the existing `public.sync_logs` table, which is read-only from the client.

## Existing (unchanged)

### `sync_logs` (server, read-only for clients)

| Field | Type | Notes |
|-------|------|-------|
| `user_id` | uuid | RLS: user reads own rows |
| `module_name` | text | One of `accounts`, `portfolio`, `categories`, `transactions`, `budgets`, `recurring`, `cash_flow` |
| `last_updated_at` | timestamptz | Set by triggers with `clock_timestamp()`, monotonic via `greatest(...)` |

Table to module mapping, as defined by the DB triggers (the repository wrapper MUST mirror it):

| Tables | Module |
|--------|--------|
| `accounts` | `accounts` |
| `categories` | `categories` |
| `transactions` | `transactions` (a transfer that involves a portfolio also bumps `accounts` through `sync_transfer_portfolio_cash`) |
| `budgets` | `budgets` |
| `recurring_transactions`, `recurring_occurrences` | `recurring` |
| `portfolio_holdings`, `stock_trades`, `stock_purchases`, `portfolio_investment_plans`, `portfolio_allocation_targets`, portfolio annual reports | `portfolio` |
| Cash-flow forecast tables (fixed items, planned purchases, budget forecast settings) | `cash_flow` |

### `SyncModule` (enum, `lib/providers/sync_provider.dart`)

The values are unchanged. `portfolio.refreshTarget == accounts`.

## New / changed in-memory state (`SyncProvider`)

| State | Type | Purpose | Cleared by |
|-------|------|---------|------------|
| `_localTimestamps` (existing) | `Map<SyncModule, DateTime>` | Known-changes baseline: the latest remote time this device reflects, per module | `reset()` |
| `_remoteSnapshot` *(new)* | `Map<SyncModule, DateTime>?` + `DateTime _snapshotAt` | Last `sync_logs` read, reused by `beforeWrite` while younger than `snapshotMaxAge` | `reset()`; refreshed by any log read |
| `_ackEligible` *(new)* | `Set<SyncModule>` | Modules written by this device whose remote equaled the baseline right before the write | Ack completes, `reset()` |
| `_foreignDirty` *(new)* | `Set<SyncModule>` | Modules found changed remotely before our write. Never acknowledged, so they reload normally | Next refresh of the module, `reset()` |
| `_ackTimer` *(new)* | `Timer?` | Debounces the post-write acknowledgement | Fired, `reset()` |
| `_lastCheckTime` (existing) | `DateTime?` | Cooldown for automatic (resume) checks only | `reset()` |

### `SyncTrigger` *(new enum)*

`initialLoad`, `resume`, `pull`, `localWriteAck`. These values are used only for diagnostics (FR-013).

## State transitions for one module *m* on this device

```text
            beforeWrite(m)
  [in sync] ───────────────► remote(m) == local(m) ? ──yes──► [ack-eligible]
      ▲                                        │no
      │                                        ▼
      │                                 [foreign-dirty]
      │                                        │ next check/pull/ack read
      │ ack read (write ok):                   ▼
      │  local(m) := remote(m)          reload target(m); local(m) := remote(m)
      └──────────────────────────────── [in sync]

  afterWrite(m, success:false) → m removed from ack-eligible (no adoption)
  ack read fails               → ack-eligible kept until next check, which reloads (safe fallback)
```

## Validation rules

- Adopting a remote timestamp without a reload is allowed **only** for modules in `_ackEligible` that are not in `_foreignDirty`.
- Any module whose remote is newer than the local baseline and that is not ack-eligible MUST be reloaded once per check (existing `_refreshChanged` semantics, grouped by `refreshTarget`).
- A pull MUST reload every module in `forceModules`, mapped through `refreshTarget`, even if the logs show no change.
