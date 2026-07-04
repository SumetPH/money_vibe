# Todo: Thai Stock Portfolio Account Type

## Task 1: Add Thai Portfolio Account Type to Schema and Model

**Description:** Add the new account type to Dart and Supabase so Thai stock portfolio accounts can exist without affecting existing US portfolio accounts.

**Acceptance criteria:**
- [x] `AccountType.thaiPortfolio` exists with Thai label and investment group ordering.
- [x] `Account.isPortfolio` returns true for both US and Thai stock portfolio types.
- [x] Supabase account type check constraint accepts the new type.
- [x] `supabase/init_schema.sql` includes the same allowed type list as the migration.

**Verification:**
- [x] Search confirms no schema constraint still omits the new account type.
- [x] Run later in final verification: `dart format .`
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** None

**Files likely touched:**
- `lib/models/account.dart`
- `supabase/migrations/<timestamp>_add_thai_portfolio_account_type.sql`
- `supabase/init_schema.sql`

**Estimated scope:** M

## Task 2: Replace Core Portfolio Type Checks with `Account.isPortfolio`

**Description:** Convert core logic that special-cases `AccountType.portfolio` so both US and Thai portfolios use portfolio balance and exclusion rules.

**Acceptance criteria:**
- [x] Balance calculation treats both portfolio types as holdings plus cash balance.
- [x] Account list, statistics, transaction account filtering, and AI export no longer miss Thai portfolios in core portfolio checks.
- [x] Existing non-portfolio accounts are unaffected.

**Verification:**
- [x] Search for `AccountType.portfolio` and classify remaining references as US-only or intentionally unchanged.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 1

**Files likely touched:**
- `lib/providers/account_provider.dart`
- `lib/screens/account/account_list_screen.dart`
- `lib/screens/statistics/statistics_screen.dart`
- `lib/screens/transaction/transaction_form_screen.dart`
- `lib/services/ai_finance_export_service.dart`

**Estimated scope:** M

## Task 3: Make Account Form Portfolio-Aware for THB vs USD Portfolios

**Description:** Let users create/edit Thai stock portfolio accounts with THB defaults and without irrelevant USD exchange-rate controls.

**Acceptance criteria:**
- [x] Choosing Thai stock portfolio defaults currency to THB, exchange rate to `1`, and auto update rate to false or irrelevant.
- [x] Choosing US stock portfolio preserves the existing USD broker cash flow.
- [x] The initial balance field label remains portfolio cash-oriented, but suffix follows selected currency.
- [x] Switching account type does not leave stale USD settings on Thai portfolios.

**Verification:**
- [x] Manual code review of account form state transitions.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 1

**Files likely touched:**
- `lib/screens/account/account_form_screen.dart`
- `lib/models/account.dart`

**Estimated scope:** M

## Task 4: Route Thai Portfolios to Existing Portfolio Detail and Summaries

**Description:** Ensure Thai portfolios open the existing portfolio detail screen and appear correctly in account group totals and account rows.

**Acceptance criteria:**
- [x] Tapping a Thai portfolio account opens `PortfolioDetailScreen`.
- [x] Account list balance row shows THB value without a USD conversion sublabel.
- [x] Group totals include Thai portfolio value once, in THB.

**Verification:**
- [x] Search account list route and total calculation for hard-coded portfolio checks.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Tasks 2 and 3

**Files likely touched:**
- `lib/screens/account/account_list_screen.dart`
- `lib/providers/account_provider.dart`

**Estimated scope:** S

## Task 5: Make Holding Form and Portfolio Detail Labels Currency-Aware

**Description:** Replace user-facing hard-coded USD labels in the core holding and portfolio detail flow with the portfolio account currency.

**Acceptance criteria:**
- [x] Holding form price and cost labels show THB for Thai portfolios and USD for US portfolios.
- [x] Portfolio detail cash, holdings value, total cost, P/L, and group labels use the correct currency text.
- [x] Internal field names may remain `priceUsd` / `costBasisUsd` for MVP compatibility.

**Verification:**
- [x] Search affected screens for remaining hard-coded `USD` labels and classify them as updated, US-only, or deferred.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 4

**Files likely touched:**
- `lib/screens/account/holding_form_screen.dart`
- `lib/screens/account/portfolio_detail_screen.dart`
- `lib/widgets/portfolio_holding_item_widget.dart`

**Estimated scope:** M

## Task 6: Add Thai Ticker Normalization for Yahoo Price Refresh

**Description:** Make price refresh work for Thai stocks by mapping user-entered Thai tickers to Yahoo-compatible symbols.

**Acceptance criteria:**
- [x] Thai portfolio price refresh uses `.BK` for plain Thai symbols such as `PTT`.
- [x] Existing US portfolio tickers are sent unchanged.
- [x] Display ticker remains predictable and does not unexpectedly duplicate `.BK`.
- [x] Refresh still persists via `updateHoldingMarketData()` or equivalent partial market-data update only.

**Verification:**
- [x] Inspect `_refreshPrices()` and single-holding refresh call sites.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 5

**Files likely touched:**
- `lib/screens/account/portfolio_detail_screen.dart`
- `lib/services/stock_price_service.dart`
- `lib/models/account.dart`

**Estimated scope:** M

## Task 7: Make Sell Holding and Trade Edit Labels Currency-Aware

**Description:** Ensure selling Thai holdings and editing trade history does not label THB values as USD.

**Acceptance criteria:**
- [x] Sell holding form labels use THB for Thai portfolios and USD for US portfolios.
- [x] Cash received, gross proceeds, fees, taxes, and P/L labels follow portfolio currency.
- [x] Selling a Thai holding increases portfolio cash balance in THB.

**Verification:**
- [x] Search sell/trade screens for hard-coded USD labels.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 6

**Files likely touched:**
- `lib/screens/account/holding_sell_form_screen.dart`
- `lib/screens/trade/stock_trade_form_screen.dart`
- `lib/providers/account_provider.dart`

**Estimated scope:** M

## Task 8: Gate or Label US-Only Annual Report and Tax Surfaces

**Description:** Prevent Thai portfolios from seeing US-specific tax/reporting surfaces as if they apply to Thai holdings.

**Acceptance criteria:**
- [x] Annual broker report action is hidden, disabled, or explicitly marked US-only for Thai portfolios.
- [x] Trade tracker/report screens do not present Thai portfolio values as USD tax summaries.
- [x] Existing US portfolio report behavior remains available.

**Verification:**
- [x] Manual code review of portfolio menu and trade tracker portfolio filtering.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 7

**Files likely touched:**
- `lib/screens/account/portfolio_detail_screen.dart`
- `lib/screens/trade/trade_tracker_screen.dart`
- `lib/screens/trade/broker_report_list_screen.dart`
- `lib/screens/trade/broker_report_form_screen.dart`

**Estimated scope:** M

## Task 9: Update CSV and AI Export Behavior for Thai Portfolios

**Description:** Keep data export/import compatible while avoiding misleading user-facing currency labels for Thai portfolios.

**Acceptance criteria:**
- [x] CSV export remains backward-compatible with existing column names.
- [x] Any user-facing export summary labels portfolio currency correctly where account context is available.
- [x] AI finance export includes Thai portfolios or intentionally separates them from US-only portfolio summaries.

**Verification:**
- [x] Search export services for hard-coded USD portfolio text.
- [x] Run later in final verification: `flutter analyze`

**Dependencies:** Task 8

**Files likely touched:**
- `lib/services/csv_service.dart`
- `lib/services/ai_finance_export_service.dart`

**Estimated scope:** M

## Task 10: Format, Analyze, and Focused Manual Review

**Description:** Run the required repo verification and do a final search-based review for missed portfolio type or USD display paths.

**Acceptance criteria:**
- [x] `dart format .` has been run.
- [x] `flutter analyze` has been run.
- [x] Remaining `AccountType.portfolio` references are intentional.
- [x] Remaining hard-coded `USD` labels in portfolio/trade surfaces are intentional, US-only, or documented as deferred.

**Verification:**
- [x] `dart format .`
- [x] `flutter analyze`
- [x] `rg -n "AccountType\\.portfolio| USD|USD\\)|usd" lib supabase`

**Dependencies:** Tasks 1-9

**Files likely touched:**
- No planned code changes beyond cleanup from earlier tasks.

**Estimated scope:** S
