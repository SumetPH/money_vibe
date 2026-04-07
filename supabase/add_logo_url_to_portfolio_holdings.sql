ALTER TABLE public.portfolio_holdings
ADD COLUMN IF NOT EXISTS logo_url text NOT NULL DEFAULT '';
