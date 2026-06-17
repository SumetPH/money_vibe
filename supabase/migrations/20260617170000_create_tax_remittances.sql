CREATE TABLE IF NOT EXISTS public.tax_remittances (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    portfolio_id text not null references public.accounts (id) on delete cascade,
    remitted_at timestamp without time zone not null,
    amount_usd numeric(15, 4) not null,
    fx_rate numeric(15, 6) not null,
    thb_amount numeric(15, 2) not null,
    note text not null default '',
    created_at timestamp without time zone default now()
);

CREATE TABLE IF NOT EXISTS public.tax_remittance_allocations (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    remittance_id text not null references public.tax_remittances (id) on delete cascade,
    bucket_type text not null,
    tax_year integer,
    amount_usd numeric(15, 4) not null,
    note text not null default ''
);

CREATE INDEX IF NOT EXISTS idx_tax_remittances_user_id
ON public.tax_remittances (user_id);

CREATE INDEX IF NOT EXISTS idx_tax_remittances_portfolio_id
ON public.tax_remittances (portfolio_id);

CREATE INDEX IF NOT EXISTS idx_tax_remittances_remitted_at
ON public.tax_remittances (remitted_at desc);

CREATE INDEX IF NOT EXISTS idx_tax_remittance_allocations_remittance_id
ON public.tax_remittance_allocations (remittance_id);

ALTER TABLE public.tax_remittances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_remittance_allocations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own tax remittances"
ON public.tax_remittances
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only access their own tax remittance allocations"
ON public.tax_remittance_allocations
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
