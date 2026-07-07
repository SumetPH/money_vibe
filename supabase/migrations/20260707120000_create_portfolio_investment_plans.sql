-- Investment plan state for portfolio accounts.
-- IDs match the app's existing text-based model IDs.

CREATE TABLE IF NOT EXISTS public.portfolio_investment_plans (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    portfolio_id text not null references public.accounts (id) on delete cascade,
    dca_month text not null,
    dca_completed boolean not null default false,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now(),
    CONSTRAINT portfolio_investment_plans_dca_month_check
        CHECK (dca_month ~ '^[0-9]{4}-[0-9]{2}$'),
    CONSTRAINT portfolio_investment_plans_unique_month
        UNIQUE (user_id, portfolio_id, dca_month)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_investment_plans_user_id
    ON public.portfolio_investment_plans (user_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_investment_plans_portfolio_id
    ON public.portfolio_investment_plans (portfolio_id);

ALTER TABLE public.portfolio_investment_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own investment plans"
    ON public.portfolio_investment_plans;

CREATE POLICY "Users can only access their own investment plans"
    ON public.portfolio_investment_plans
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS handle_portfolio_investment_plans_updated_at
    ON public.portfolio_investment_plans;

CREATE TRIGGER handle_portfolio_investment_plans_updated_at
    BEFORE UPDATE ON public.portfolio_investment_plans
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.portfolio_allocation_targets (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    portfolio_id text not null references public.accounts (id) on delete cascade,
    holding_id text references public.portfolio_holdings (id) on delete set null,
    ticker text not null,
    target_percent numeric(15, 4) not null default 0,
    is_enabled boolean not null default true,
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now(),
    CONSTRAINT portfolio_allocation_targets_percent_check
        CHECK (target_percent >= 0),
    CONSTRAINT portfolio_allocation_targets_unique_ticker
        UNIQUE (user_id, portfolio_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_allocation_targets_user_id
    ON public.portfolio_allocation_targets (user_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_allocation_targets_portfolio_id
    ON public.portfolio_allocation_targets (portfolio_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_allocation_targets_holding_id
    ON public.portfolio_allocation_targets (holding_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_allocation_targets_sort_order
    ON public.portfolio_allocation_targets (sort_order);

ALTER TABLE public.portfolio_allocation_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their allocation targets"
    ON public.portfolio_allocation_targets;

CREATE POLICY "Users can only access their allocation targets"
    ON public.portfolio_allocation_targets
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS handle_portfolio_allocation_targets_updated_at
    ON public.portfolio_allocation_targets;

CREATE TRIGGER handle_portfolio_allocation_targets_updated_at
    BEFORE UPDATE ON public.portfolio_allocation_targets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
