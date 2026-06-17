CREATE TABLE IF NOT EXISTS public.stock_trades (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    portfolio_id text not null references public.accounts (id) on delete cascade,
    holding_id text not null default '',
    ticker text not null,
    name text not null default '',
    logo_url text not null default '',
    shares_sold numeric(18, 7) not null,
    sell_price_usd numeric(15, 4) not null,
    cash_received_usd numeric(15, 4) not null,
    cost_basis_usd numeric(15, 4) not null,
    realized_pnl_usd numeric(15, 4) not null,
    sold_at timestamp without time zone not null,
    created_at timestamp without time zone default now()
);

ALTER TABLE public.stock_trades
ADD COLUMN IF NOT EXISTS logo_url text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_stock_trades_user_id
ON public.stock_trades (user_id);

CREATE INDEX IF NOT EXISTS idx_stock_trades_portfolio_id
ON public.stock_trades (portfolio_id);

CREATE INDEX IF NOT EXISTS idx_stock_trades_sold_at
ON public.stock_trades (sold_at desc);

ALTER TABLE public.stock_trades ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own stock trades"
ON public.stock_trades
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
