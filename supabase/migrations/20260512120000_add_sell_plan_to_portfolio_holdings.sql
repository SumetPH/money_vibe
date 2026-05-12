ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS sell_plan_enabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS take_profit_pct numeric(15, 4) NOT NULL DEFAULT 0;

ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS trailing_stop_pct numeric(15, 4) NOT NULL DEFAULT 0;

ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS peak_profit_pct numeric(15, 4);
