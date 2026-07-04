# Thai Stock Portfolio

## Overview

Money Vibe supports a Thai stock portfolio account type alongside the existing US stock portfolio. The Thai portfolio reuses the existing portfolio engine, holdings table, trade table, and portfolio detail UI, but stores the account as THB-denominated and displays portfolio values with Thai currency labels.

## Account Type

- Dart enum: `AccountType.thaiPortfolio`
- Stored database value: `thaiPortfolio`
- Group: `AccountGroup.investment`
- Default currency: `THB`
- Exchange rate: `1`
- Auto exchange-rate update: off for Thai portfolios

Use `account.isPortfolio` for shared portfolio behavior. Use `account.isUsPortfolio` only for US-specific flows such as USD broker reports and tax summaries.

## Data Model Notes

The first release intentionally keeps existing field and column names such as:

- `priceUsd`
- `costBasisUsd`
- `sellPriceUsd`
- `cashReceivedUsd`
- `price_usd`
- `cost_basis_usd`

For Thai portfolios, these values represent amounts in the portfolio account currency, which is THB. This avoids a broad data migration and keeps CSV/import/export compatibility. User-facing labels should use the portfolio account currency instead of assuming USD.

## Price Refresh

Thai portfolio price refresh normalizes plain Thai tickers for Yahoo Finance:

- User/display ticker: `PTT`
- Price lookup symbol: `PTT.BK`

If the ticker already contains a dot, the app sends it unchanged. US portfolios keep existing ticker behavior.

Price refresh must keep using the market-data-only update path so it does not overwrite manually edited holding fields. The important persistence path is `updateHoldingMarketData()`.

## UI Behavior

Thai portfolios:

- Show THB cash balance, holdings value, total cost, and P/L.
- Hide USD/THB exchange-rate controls in the portfolio detail summary.
- Use THB labels in holding add/edit, sell holding, and trade edit forms.
- Open the same `PortfolioDetailScreen` as US portfolios.

US portfolios:

- Keep USD value labels and THB converted summary values.
- Keep USD/THB exchange-rate controls.
- Keep broker report and tax-oriented portfolio surfaces.

## US-Only Surfaces

The annual broker report and trade tax/reporting surfaces are USD-oriented and remain US-only for this release. Thai portfolios should not enter those flows unless those screens are redesigned for Thai tax/reporting rules.

## Migration

The migration `supabase/migrations/20260704120000_add_thai_portfolio_account_type.sql` updates the `accounts_type_check` constraint to allow `thaiPortfolio`.

`supabase/init_schema.sql` includes the same migration so fresh environments get the latest schema.

## Verification

After implementation, run:

```bash
dart format .
flutter analyze
```

If Flutter tooling fails with `engine.stamp: Operation not permitted`, rerun the command outside the sandbox with approval. This is an SDK cache permission issue, not automatically a code failure.
