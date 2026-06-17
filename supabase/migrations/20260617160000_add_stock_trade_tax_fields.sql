ALTER TABLE public.stock_trades
ADD COLUMN IF NOT EXISTS gross_proceeds_usd numeric(15, 4),
ADD COLUMN IF NOT EXISTS broker_fee_usd numeric(15, 4),
ADD COLUMN IF NOT EXISTS exchange_fee_usd numeric(15, 4),
ADD COLUMN IF NOT EXISTS tax_fee_usd numeric(15, 4),
ADD COLUMN IF NOT EXISTS cost_method text NOT NULL DEFAULT 'average',
ADD COLUMN IF NOT EXISTS pnl_source text NOT NULL DEFAULT 'estimated',
ADD COLUMN IF NOT EXISTS settled_at timestamp without time zone,
ADD COLUMN IF NOT EXISTS broker_order_ref text;
