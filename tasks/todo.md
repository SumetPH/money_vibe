# Todo: Portfolio Investment Plan

## Task 1: Add Investment Plan Schema and Supabase Contract

**Description:** Add Supabase tables for monthly DCA status and portfolio allocation targets, with RLS, updated triggers, indexes, and `init_schema.sql` wiring.

**Acceptance criteria:**
- [x] A migration creates `portfolio_investment_plans` with unique `(user_id, portfolio_id, dca_month)`.
- [x] A migration creates `portfolio_allocation_targets` with unique `(user_id, portfolio_id, ticker)`.
- [x] Both tables enable RLS and only allow users to manage their own rows.
- [x] `supabase/init_schema.sql` includes the new migration in order.

**Verification:**
- [x] Search confirms both new tables appear in migration and `supabase/init_schema.sql`.
- [x] Manual SQL review confirms no SQLite or transaction `tags` usage.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** None

**Files likely touched:**
- `supabase/migrations/<timestamp>_create_portfolio_investment_plans.sql`
- `supabase/init_schema.sql`

**Estimated scope:** S

## Task 2: Add Dart Models and Pure Allocation Calculations

**Description:** Add typed Dart models for investment plan data and pure helper functions for rebalance rows and buy recommendations.

**Acceptance criteria:**
- [x] Models can serialize/deserialize DCA status and allocation target rows without `as dynamic`.
- [x] Calculation helper returns current percent, target value, diff percent, diff amount, and buy recommendation per ticker.
- [x] Buy recommendation uses holdings-only total for MVP and never mutates holdings, account, transactions, or provider state.

**Verification:**
- [x] Manual review of calculation inputs/outputs against examples in the spec.
- [x] Search confirms helper has no repository/provider imports.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Task 1

**Files likely touched:**
- `lib/models/investment_plan.dart`
- `lib/models/stock_holding.dart` only if a tiny shared formatting/helper hook is truly needed

**Estimated scope:** S

## Task 3: Add Repository Adapter for Investment Plans

**Description:** Extend the database repository contract and Supabase delegation so investment plan data can be loaded and saved through the same architecture as existing portfolio data.

**Acceptance criteria:**
- [x] `DatabaseRepository` exposes methods to get DCA statuses, upsert current month DCA status, get allocation targets, and upsert allocation targets.
- [x] `SupabaseRepository` delegates those methods to a new investment plan adapter.
- [x] Supabase writes update the `portfolio` sync log for MVP consistency.

**Verification:**
- [x] Search confirms new repository methods are implemented by the Supabase path.
- [x] Manual review confirms no full holding update path is reused for plan writes.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Tasks 1 and 2

**Files likely touched:**
- `lib/repositories/database_repository.dart`
- `lib/repositories/supabase_repository.dart`
- `lib/repositories/supabase_adapters/investment_plan_adapter.dart`

**Estimated scope:** M

## Task 4: Load and Mutate Investment Plan Data Through AccountProvider

**Description:** Load investment plan rows during account initialization and expose small provider methods for portfolio screens to read/update current month DCA and target allocation.

**Acceptance criteria:**
- [x] `AccountProvider.init()` loads DCA statuses and allocation targets alongside accounts/holdings.
- [x] Provider exposes current month DCA status per portfolio using local `YYYY-MM`.
- [x] Provider exposes allocation targets per portfolio and can upsert target changes.
- [x] Optimistic updates restore previous state if Supabase write fails.

**Verification:**
- [x] Manual review of provider reload/init path.
- [x] Manual review of local month key generation.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Task 3

**Files likely touched:**
- `lib/providers/account_provider.dart`
- `lib/models/investment_plan.dart`

**Estimated scope:** M

## Task 5: Add the `แผนการลงทุน` Tab Shell to Portfolio Detail

**Description:** Add a third portfolio detail tab and route it to a dedicated investment plan widget while keeping the existing `พอร์ต` and `หุ้นทั้งหมด` tabs unchanged.

**Acceptance criteria:**
- [x] `DefaultTabController.length` becomes 3.
- [x] Tab labels are `พอร์ต`, `หุ้นทั้งหมด`, and `แผนการลงทุน`.
- [x] The new tab receives account, holdings, provider callbacks, and currency display context.
- [x] Existing refresh, menu, portfolio tab, and all-stocks tab behavior stays unchanged.

**Verification:**
- [x] Manual code review of `TabBar` and `TabBarView` order.
- [x] Search confirms no unrelated portfolio detail behavior was refactored.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Task 4

**Files likely touched:**
- `lib/screens/account/portfolio_detail_screen.dart`
- `lib/screens/account/portfolio_investment_plan_screen.dart`

**Estimated scope:** S

## Task 6: Build DCA Checklist and Target Allocation Editor

**Description:** Implement the upper part of the investment plan UI: current month DCA toggle and editable target allocation rows for holdings.

**Acceptance criteria:**
- [x] DCA row shows the current local month and toggles persisted state through `AccountProvider`.
- [x] Holding rows can be enabled/disabled for the plan and edit target percent.
- [x] UI shows total target percent and warns when the enabled total is outside `99.99% - 100.01%`.
- [x] UI uses portfolio currency label, `SettingsProvider` dark mode, and existing app color/radius tokens.

**Verification:**
- [x] Manual review in light/dark style paths.
- [x] Manual check that editing targets does not change holdings or transactions.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Task 5

**Files likely touched:**
- `lib/screens/account/portfolio_investment_plan_screen.dart`
- `lib/theme/app_colors.dart` only if an existing token is missing and a new token is justified

**Estimated scope:** M

## Task 7: Build Rebalance Table and Buy Amount Recommendation UI

**Description:** Implement the lower part of the investment plan UI: computed under/over allocation rows and a buy amount simulator that recommends how much to add per ticker.

**Acceptance criteria:**
- [x] Rebalance rows show ticker/name, target percent, current percent, target value, current value, diff percent, and diff amount.
- [x] Rows clearly mark `ขาด`, `เกิน`, or `พอดี` without using color as the only signal.
- [x] Buy amount input recomputes recommendation without saving transactions, cash, or holdings.
- [x] Recommendation total does not exceed the entered buy amount except for rounding tolerance.

**Verification:**
- [x] Manual calculation review with at least one overweight and one underweight holding.
- [x] Manual review of empty/zero holdings states.
- [x] Run later in final verification: `rtk flutter analyze`.

**Dependencies:** Tasks 2 and 6

**Files likely touched:**
- `lib/screens/account/portfolio_investment_plan_screen.dart`
- `lib/models/investment_plan.dart`

**Estimated scope:** M

## Task 8: Format, Analyze, and Focused Manual Review

**Description:** Run required repo verification and search for integration mistakes around schema wiring, portfolio tabs, currency labels, and stale holding writes.

**Acceptance criteria:**
- [x] `rtk dart format .` has been run.
- [x] `rtk flutter analyze` has been run, or an environment permission issue is recorded exactly.
- [x] `portfolio_detail_screen.dart` still uses partial market-data update for refresh and does not write investment plan state.
- [x] Remaining open questions are documented for review if they affect behavior.

**Verification:**
- [x] `rtk dart format .`
- [x] `rtk flutter analyze`
- [x] `rtk rg -n "portfolio_investment_plans|portfolio_allocation_targets|แผนการลงทุน|updateHoldingMarketData|updateHoldingsMarketDataBatch" lib supabase`

**Dependencies:** Tasks 1-7

**Files likely touched:**
- No planned code changes beyond cleanup from earlier tasks.

**Estimated scope:** S
