-- Cash-flow forecast: per-window budget settings keyed by the window's clear
-- day, so a selection follows its window when the forecast rolls over.
-- is_excluded null follows the budget's default (hidden budgets are left out,
-- visible ones counted). amount is a what-if amount used only by the forecast
-- (null = the budget's real amount). Replaces the relative current/next
-- exclusion flags on budgets.
-- period_end_on is deliberately not named *_date: the app's row normalizer
-- replaces null *_date values with the current time.

CREATE TABLE IF NOT EXISTS public.budget_forecast_settings (
    id text primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    budget_id text not null references public.budgets (id) on delete cascade,
    period_end_on date not null,
    is_excluded boolean,
    amount numeric(15, 2),
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now(),
    CONSTRAINT budget_forecast_settings_amount_check
        CHECK (amount IS NULL OR amount >= 0),
    CONSTRAINT budget_forecast_settings_unique_period
        UNIQUE (budget_id, period_end_on)
);

-- Keep re-runs consistent with the nullable is_excluded above.
ALTER TABLE public.budget_forecast_settings
    ALTER COLUMN is_excluded DROP NOT NULL,
    ALTER COLUMN is_excluded DROP DEFAULT;

CREATE INDEX IF NOT EXISTS idx_budget_forecast_settings_user_id
    ON public.budget_forecast_settings (user_id);

ALTER TABLE public.budget_forecast_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own budget forecast settings"
    ON public.budget_forecast_settings;

CREATE POLICY "Users can only access their own budget forecast settings"
    ON public.budget_forecast_settings
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS handle_budget_forecast_settings_updated_at
    ON public.budget_forecast_settings;

CREATE TRIGGER handle_budget_forecast_settings_updated_at
    BEFORE UPDATE ON public.budget_forecast_settings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Background sync: forecast settings are loaded by the cash_flow module.
DROP TRIGGER IF EXISTS sync_budget_forecast_settings
    ON public.budget_forecast_settings;
CREATE TRIGGER sync_budget_forecast_settings
AFTER INSERT OR UPDATE OR DELETE ON public.budget_forecast_settings
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('cash_flow');

-- The relative flags cannot be mapped to a clear day in SQL (the clear day is
-- a local app setting), so selections start fresh in the new table.
ALTER TABLE public.budgets
    DROP COLUMN IF EXISTS is_excluded_from_cash_forecast,
    DROP COLUMN IF EXISTS is_excluded_from_next_cash_forecast;
