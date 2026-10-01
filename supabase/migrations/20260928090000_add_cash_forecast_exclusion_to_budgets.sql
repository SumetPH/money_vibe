-- Cash-flow forecast: let the user leave individual budgets (expense or
-- savings) out of the next-period forecast, like liquid accounts.
ALTER TABLE public.budgets
    ADD COLUMN IF NOT EXISTS is_excluded_from_cash_forecast boolean
        NOT NULL DEFAULT false;
