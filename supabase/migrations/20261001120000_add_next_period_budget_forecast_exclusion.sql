-- Cash-flow forecast: separate budget selections for the current and next
-- windows. Existing column stays the current-window selection; the next-window
-- selection starts from the same value to keep current behaviour.
ALTER TABLE public.budgets
    ADD COLUMN IF NOT EXISTS is_excluded_from_next_cash_forecast boolean
        NOT NULL DEFAULT false;

UPDATE public.budgets
SET is_excluded_from_next_cash_forecast = is_excluded_from_cash_forecast;
