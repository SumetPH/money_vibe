ALTER TABLE public.portfolio_annual_reports
ADD COLUMN IF NOT EXISTS dividend_gross_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_gross_usd >= 0),
ADD COLUMN IF NOT EXISTS dividend_tax_withheld_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_tax_withheld_usd >= 0),
ADD COLUMN IF NOT EXISTS dividend_net_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (dividend_net_usd >= 0);
