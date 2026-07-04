# Thai Stock Portfolio Ship Checklist

## Scope

Ship the Thai stock portfolio account type with THB-denominated portfolio values, Yahoo `.BK` price lookup, and shared portfolio screens.

Out of scope for this launch:

- Renaming existing `*_usd` columns or Dart fields.
- Thai tax calculation/reporting.
- Thai broker statement import.
- New unit tests or browser tests unless requested separately.

## Pre-Launch Checklist

- [ ] Confirm migration `20260704120000_add_thai_portfolio_account_type.sql` is included in the deployment.
- [ ] Confirm `supabase/init_schema.sql` references the Thai portfolio migration for fresh setup.
- [ ] Run `dart format .`.
- [ ] Run `flutter analyze`.
- [ ] Confirm no remaining general portfolio flow uses `AccountType.portfolio` where `account.isPortfolio` is required.
- [ ] Confirm remaining `AccountType.portfolio` references are US-only reporting/tax surfaces.
- [ ] Confirm no user-facing Thai portfolio core screen labels THB values as USD.

## Smoke Test

1. Create a new account with type `พอร์ตหุ้นไทย`.
2. Confirm currency displays as THB and no USD/THB exchange-rate controls are shown.
3. Add a Thai holding such as `PTT`.
4. Refresh prices and confirm lookup works through Yahoo-compatible `PTT.BK`.
5. Confirm portfolio summary, holding row, and cash row show THB values.
6. Sell part of the holding and confirm cash balance increases in THB.
7. Confirm annual broker report action is not available from the Thai portfolio menu.
8. Confirm an existing US portfolio still shows USD labels and USD/THB exchange-rate controls.

## Rollback

If the release needs rollback before users create Thai portfolios:

1. Revert the app changes.
2. Revert or replace the account type constraint migration before deployment.

If users may already have created `thaiPortfolio` accounts:

1. Do not remove `thaiPortfolio` from the database constraint until data is migrated.
2. Hide Thai portfolio creation in the app if needed.
3. Keep read support for existing Thai portfolio accounts, or migrate them to a supported type with an explicit data migration.

## Known Technical Debt

- Existing model and database names still use `Usd` / `_usd` for portfolio monetary values.
- CSV headers remain backward-compatible and may still expose `*_usd` column names.
- US broker reports and trade tracker tax summaries remain intentionally US-only.
