-- Cash-flow forecast: per-card payment due day, liquid-account exclusion,
-- fixed cash-flow items and their monthly paid marks.

ALTER TABLE public.accounts
    ADD COLUMN IF NOT EXISTS payment_due_day integer,
    ADD COLUMN IF NOT EXISTS is_excluded_from_cash_forecast boolean
        NOT NULL DEFAULT false;

ALTER TABLE public.accounts
    DROP CONSTRAINT IF EXISTS accounts_payment_due_day_check;

ALTER TABLE public.accounts
    ADD CONSTRAINT accounts_payment_due_day_check
        CHECK (payment_due_day IS NULL OR payment_due_day BETWEEN 1 AND 31);

CREATE TABLE IF NOT EXISTS public.fixed_cash_flow_items (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    amount numeric(15, 2) not null,
    day_of_month integer not null,
    direction text not null,
    is_payday boolean not null default false,
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now(),
    CONSTRAINT fixed_cash_flow_items_amount_check CHECK (amount > 0),
    CONSTRAINT fixed_cash_flow_items_day_check
        CHECK (day_of_month BETWEEN 1 AND 31),
    CONSTRAINT fixed_cash_flow_items_direction_check
        CHECK (direction IN ('incoming', 'outgoing')),
    CONSTRAINT fixed_cash_flow_items_payday_incoming_check
        CHECK (NOT is_payday OR direction = 'incoming')
);

CREATE INDEX IF NOT EXISTS idx_fixed_cash_flow_items_user_id
    ON public.fixed_cash_flow_items (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fixed_cash_flow_items_one_payday
    ON public.fixed_cash_flow_items (user_id)
    WHERE is_payday;

ALTER TABLE public.fixed_cash_flow_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own fixed cash-flow items"
    ON public.fixed_cash_flow_items;

CREATE POLICY "Users can only access their own fixed cash-flow items"
    ON public.fixed_cash_flow_items
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS handle_fixed_cash_flow_items_updated_at
    ON public.fixed_cash_flow_items;

CREATE TRIGGER handle_fixed_cash_flow_items_updated_at
    BEFORE UPDATE ON public.fixed_cash_flow_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.fixed_cash_flow_paid_marks (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    item_id text not null
        references public.fixed_cash_flow_items (id) on delete cascade,
    month text not null,
    created_at timestamp without time zone default now(),
    CONSTRAINT fixed_cash_flow_paid_marks_month_check
        CHECK (month ~ '^[0-9]{4}-[0-9]{2}$'),
    CONSTRAINT fixed_cash_flow_paid_marks_unique_month
        UNIQUE (item_id, month)
);

CREATE INDEX IF NOT EXISTS idx_fixed_cash_flow_paid_marks_user_id
    ON public.fixed_cash_flow_paid_marks (user_id);

ALTER TABLE public.fixed_cash_flow_paid_marks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own fixed cash-flow paid marks"
    ON public.fixed_cash_flow_paid_marks;

CREATE POLICY "Users can only access their own fixed cash-flow paid marks"
    ON public.fixed_cash_flow_paid_marks
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Background sync: register the cash_flow module.
ALTER TABLE public.sync_logs
    DROP CONSTRAINT IF EXISTS sync_logs_module_name_check;

ALTER TABLE public.sync_logs
    ADD CONSTRAINT sync_logs_module_name_check CHECK (
        module_name IN (
            'accounts',
            'portfolio',
            'categories',
            'transactions',
            'budgets',
            'recurring',
            'cash_flow'
        )
    );

DROP TRIGGER IF EXISTS sync_fixed_cash_flow_items
    ON public.fixed_cash_flow_items;
CREATE TRIGGER sync_fixed_cash_flow_items
AFTER INSERT OR UPDATE OR DELETE ON public.fixed_cash_flow_items
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('cash_flow');

DROP TRIGGER IF EXISTS sync_fixed_cash_flow_paid_marks
    ON public.fixed_cash_flow_paid_marks;
CREATE TRIGGER sync_fixed_cash_flow_paid_marks
AFTER INSERT OR UPDATE OR DELETE ON public.fixed_cash_flow_paid_marks
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('cash_flow');
