ALTER TABLE public.portfolio_annual_reports
ADD COLUMN IF NOT EXISTS dividend_gross_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_gross_usd >= 0),
ADD COLUMN IF NOT EXISTS dividend_tax_withheld_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_tax_withheld_usd >= 0),
ADD COLUMN IF NOT EXISTS dividend_net_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_net_usd >= 0),
ADD COLUMN IF NOT EXISTS remitted_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (remitted_usd >= 0),
ADD COLUMN IF NOT EXISTS remitted_thb NUMERIC NOT NULL DEFAULT 0.0 CHECK (remitted_thb >= 0),
ADD COLUMN IF NOT EXISTS inflow_thb NUMERIC NOT NULL DEFAULT 0.0 CHECK (inflow_thb >= 0);
