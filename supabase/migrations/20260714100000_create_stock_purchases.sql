CREATE TABLE IF NOT EXISTS public.stock_purchases (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    portfolio_id text NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
    holding_id text NOT NULL DEFAULT '',
    ticker text NOT NULL,
    name text NOT NULL DEFAULT '',
    logo_url text NOT NULL DEFAULT '',
    shares_bought numeric(18, 7) NOT NULL,
    buy_price_usd numeric(15, 4) NOT NULL,
    cash_paid_usd numeric(15, 4) NOT NULL,
    gross_cost_usd numeric(15, 4),
    broker_fee_usd numeric(15, 4),
    exchange_fee_usd numeric(15, 4),
    tax_fee_usd numeric(15, 4),
    bought_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_purchases_user_id ON public.stock_purchases (user_id);
CREATE INDEX IF NOT EXISTS idx_stock_purchases_bought_at ON public.stock_purchases (bought_at DESC);

ALTER TABLE public.stock_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own stock purchases"
ON public.stock_purchases FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
