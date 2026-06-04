ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS stop_loss_pct numeric(15, 4) NOT NULL DEFAULT 0;
