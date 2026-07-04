# Implementation Plan: Thai Stock Portfolio Account Type

## Overview

Add a Thai stock portfolio account type while reusing the existing portfolio engine. The first release should let users create a THB-denominated Thai portfolio, add/edit/sell Thai holdings, refresh Thai stock prices through Yahoo symbols, and include the portfolio correctly in account balances and net worth. This plan intentionally keeps the existing `*_usd` database columns and Dart field names for the MVP to avoid a broad data migration; UI labels and currency behavior should become portfolio-aware.

## Scope

### In Scope

- Add a new account type for Thai stock portfolios under the existing investment group.
- Treat both US and Thai stock portfolios as portfolio accounts in shared logic.
- Default Thai stock portfolios to THB, exchange rate `1`, and no USD/THB auto-update UI.
- Reuse existing `portfolio_holdings`, `stock_trades`, and portfolio screens.
- Normalize Thai tickers for Yahoo Finance using `.BK` where appropriate.
- Show portfolio currency labels based on the account currency instead of hard-coded USD labels in the core portfolio flow.
- Update Supabase migration and `supabase/init_schema.sql`.
- Run `dart format .` and `flutter analyze` after implementation.

### Out of Scope

- Renaming `price_usd`, `cost_basis_usd`, `sell_price_usd`, and related columns.
- Thai tax-specific logic, average cost tax reports, or broker statement redesign.
- New unit tests, browser tests, CI/CD, Docker, or telemetry.
- Reworking the full portfolio analysis prompt/reporting model.

## Architecture Decisions

- Use a new `AccountType.thaiPortfolio` instead of overloading the existing `portfolio` label. This preserves existing US portfolio data and makes UI behavior explicit.
- Expand `Account.isPortfolio` and add helper methods such as portfolio currency label / Yahoo symbol normalization rather than scattering `type == AccountType.portfolio || type == AccountType.thaiPortfolio` checks.
- Keep persistence backward-compatible by adding only the new account type to the `accounts.type` check constraint. Existing portfolio child tables can continue to reference `accounts(id)`.
- Use `account.currency` as the source of truth for display and THB conversion. A Thai portfolio should have `currency == 'THB'`, so `getBalanceInThb()` should not convert it.
- For price refresh, normalize symbols at the service boundary or call site while preserving the user's display ticker where practical.

## Dependency Graph

Database constraint
  -> Account enum/model helpers
  -> Repository serialization remains compatible
  -> Account creation/edit UI
  -> Portfolio routing and balance calculations
  -> Price refresh and holding forms
  -> Sell/trade UI labels
  -> Export/analyze/statistics cleanup
  -> Verification

## Task List

### Phase 1: Foundation

- [ ] Task 1: Add Thai portfolio account type to schema and model
- [ ] Task 2: Replace core portfolio type checks with `Account.isPortfolio`

### Checkpoint: Foundation

- [ ] Existing US portfolio accounts still parse as `AccountType.portfolio`
- [ ] New Thai portfolio accounts can be represented locally and accepted by Supabase constraints

### Phase 2: Create and View Thai Portfolios

- [ ] Task 3: Make account form portfolio-aware for THB vs USD portfolios
- [ ] Task 4: Route Thai portfolios to the existing portfolio detail flow and include them in account summaries

### Checkpoint: Account Flow

- [ ] User can create a Thai stock portfolio with THB cash balance
- [ ] Account list opens the Thai portfolio detail screen
- [ ] Net worth includes Thai portfolio balance without USD conversion

### Phase 3: Holdings and Prices

- [ ] Task 5: Make holding form and portfolio detail labels currency-aware
- [ ] Task 6: Add Thai ticker normalization for Yahoo price refresh

### Checkpoint: Holding Flow

- [ ] User can add a Thai holding with THB cost/current price labels
- [ ] Refresh price requests a Yahoo-compatible Thai symbol such as `PTT.BK`
- [ ] Market-data refresh still writes only market fields, preserving the previous stale-write mitigation

### Phase 4: Selling, Reports, and Secondary Surfaces

- [ ] Task 7: Make sell holding and trade edit labels currency-aware
- [ ] Task 8: Gate or label US-only annual report/tax/reporting surfaces
- [ ] Task 9: Update CSV and AI export behavior for Thai portfolios

### Checkpoint: Secondary Surfaces

- [ ] Selling Thai holdings updates Thai portfolio cash in THB
- [ ] US-only broker report/tax UI is not misleading for Thai portfolios
- [ ] Exported data remains backward-compatible and does not mislabel Thai THB values as USD in user-facing output

### Phase 5: Final Verification

- [ ] Task 10: Format, analyze, and do a focused manual code review

### Checkpoint: Complete

- [ ] `dart format .` completes
- [ ] `flutter analyze` completes, or any environment permission issue is recorded clearly
- [ ] All planned acceptance criteria are met

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Hard-coded `AccountType.portfolio` checks miss Thai portfolios | High | Start by expanding `Account.isPortfolio`, then search and convert routing/balance/statistics checks. |
| Hard-coded USD labels mislead users | High | Add small currency label helpers and update the core holding/sell/detail screens first. |
| Existing database columns are named `*_usd` but Thai portfolios store THB values | Medium | Accept as MVP technical debt, document in comments/plan, and avoid schema rename until a dedicated migration is desired. |
| Yahoo Thai ticker behavior differs from user-entered ticker | Medium | Normalize only for price lookup and keep display ticker stable. |
| Portfolio annual report and trade tracker are US-tax oriented | Medium | Gate or explicitly label those actions as US-only for Thai portfolios in the first release. |
| Price refresh could reintroduce stale full-row writes | High | Preserve `updateHoldingMarketData()` partial update path and avoid full holding writes during refresh. |
| Flutter tooling may hit SDK cache permission errors | Low | Run required commands; if blocked by `engine.stamp` permission, report the exact failure and do not treat it as code failure. |

## Open Questions

- Should Thai portfolio ticker input store `PTT` and add `.BK` only for lookup, or store `PTT.BK` directly?
- Should the annual broker report/tax menu be hidden for Thai portfolios, or shown with a US-only label?
- Should Thai portfolio support dividends in phase 1, or leave dividend/tax reporting out entirely?

## Implementation Notes

- Prefer helpers over broad renames in the MVP.
- Keep edits scoped to existing portfolio/account/trade modules.
- Do not add tests unless explicitly requested.
- Do not make a git commit unless explicitly requested.
