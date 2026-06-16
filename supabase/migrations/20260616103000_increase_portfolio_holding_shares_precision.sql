ALTER TABLE public.portfolio_holdings
  ALTER COLUMN shares TYPE numeric(18,7),
  ALTER COLUMN cost_basis_usd TYPE numeric(15,4);
