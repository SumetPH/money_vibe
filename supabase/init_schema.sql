-- Money Vibe consolidated init schema
-- Keep this file in sync with every file under supabase/migrations.
--
-- This file is intended for local/bootstrap usage with psql:
--   psql "$DATABASE_URL" -f supabase/init_schema.sql
--
-- Do not place this file under supabase/migrations, because it is a
-- consolidated runner rather than an incremental migration.

\ir migrations/20260507101146_init_schema.sql
\ir migrations/20260510000000_remove_tags_from_transactions.sql
\ir migrations/20260511000000_add_to_amount_to_transactions.sql
\ir migrations/20260512120000_add_sell_plan_to_portfolio_holdings.sql
\ir migrations/20260514090000_add_portfolio_group_to_portfolio_holdings.sql
\ir migrations/20260516000000_create_sync_logs.sql
\ir migrations/20260604174623_add_stop_loss_to_portfolio_holdings.sql
\ir migrations/20260616103000_increase_portfolio_holding_shares_precision.sql
\ir migrations/20260617090000_create_stock_trades.sql
\ir migrations/20260617160000_add_stock_trade_tax_fields.sql
\ir migrations/20260617183610_create_portfolio_annual_reports.sql
\ir migrations/20260618120000_add_dividend_fields_to_portfolio_annual_reports.sql
\ir migrations/20260620090000_harden_security_linter_warnings.sql
\ir migrations/20260704120000_add_thai_portfolio_account_type.sql
\ir migrations/20260707120000_create_portfolio_investment_plans.sql
\ir migrations/20260714100000_create_stock_purchases.sql
