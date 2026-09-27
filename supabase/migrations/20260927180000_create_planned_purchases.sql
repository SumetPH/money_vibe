-- Cash-flow forecast: planned purchases the user can toggle on/off to see
-- how buying them would affect the next forecast window.

CREATE TABLE IF NOT EXISTS public.planned_purchases (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    amount numeric(15, 2) not null,
    is_included boolean not null default true,
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now(),
    CONSTRAINT planned_purchases_amount_check CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_planned_purchases_user_id
    ON public.planned_purchases (user_id);

ALTER TABLE public.planned_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own planned purchases"
    ON public.planned_purchases;

CREATE POLICY "Users can only access their own planned purchases"
    ON public.planned_purchases
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS handle_planned_purchases_updated_at
    ON public.planned_purchases;

CREATE TRIGGER handle_planned_purchases_updated_at
    BEFORE UPDATE ON public.planned_purchases
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Background sync: planned purchases belong to the cash_flow module.
DROP TRIGGER IF EXISTS sync_planned_purchases ON public.planned_purchases;
CREATE TRIGGER sync_planned_purchases
AFTER INSERT OR UPDATE OR DELETE ON public.planned_purchases
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('cash_flow');
