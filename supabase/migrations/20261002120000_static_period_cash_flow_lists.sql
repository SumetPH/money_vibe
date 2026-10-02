-- Cash-flow forecast: fixed cash-flow items and planned purchases become two
-- static what-if lists, one for the current window and one for the next.
-- Lists do not move when the clear day passes; the user adds and removes rows.
-- is_done (ticked) means the item already happened / was bought, so it is no
-- longer counted. Monthly/one-time schedules and monthly paid marks go away.

-- ── Fixed cash-flow items ───────────────────────────────────────────────────

ALTER TABLE public.fixed_cash_flow_items
    ADD COLUMN IF NOT EXISTS period text NOT NULL DEFAULT 'current',
    ADD COLUMN IF NOT EXISTS is_done boolean NOT NULL DEFAULT false;

-- The current list keeps this month's tick (clear days are monthly).
UPDATE public.fixed_cash_flow_items AS i
SET is_done = EXISTS (
    SELECT 1
    FROM public.fixed_cash_flow_paid_marks AS m
    WHERE m.item_id = i.id
      AND m.month = to_char(current_date, 'YYYY-MM')
);

-- Monthly items occurred in both windows, so they are copied to the next list.
INSERT INTO public.fixed_cash_flow_items (
    id, user_id, name, amount, day_of_month, direction, sort_order, period,
    is_done
)
SELECT id || '-next', user_id, name, amount, day_of_month, direction,
       sort_order, 'next', false
FROM public.fixed_cash_flow_items
WHERE day_of_month IS NOT NULL
  AND period = 'current'
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.fixed_cash_flow_items
    DROP CONSTRAINT IF EXISTS fixed_cash_flow_items_schedule_check,
    DROP CONSTRAINT IF EXISTS fixed_cash_flow_items_day_check,
    DROP COLUMN IF EXISTS day_of_month,
    DROP COLUMN IF EXISTS one_time_on,
    DROP CONSTRAINT IF EXISTS fixed_cash_flow_items_period_check;

ALTER TABLE public.fixed_cash_flow_items
    ADD CONSTRAINT fixed_cash_flow_items_period_check
        CHECK (period IN ('current', 'next'));

DROP TABLE IF EXISTS public.fixed_cash_flow_paid_marks;

-- ── Planned purchases ───────────────────────────────────────────────────────

ALTER TABLE public.planned_purchases
    ADD COLUMN IF NOT EXISTS period text NOT NULL DEFAULT 'current',
    ADD COLUMN IF NOT EXISTS is_done boolean NOT NULL DEFAULT false;

-- Selected for both windows: one row per list.
INSERT INTO public.planned_purchases (
    id, user_id, name, amount, sort_order, period, is_done, is_included,
    is_included_current
)
SELECT id || '-next', user_id, name, amount, sort_order, 'next', false,
       false, false
FROM public.planned_purchases
WHERE is_included AND is_included_current
ON CONFLICT (id) DO NOTHING;

-- Selected only for the next window moves there. Rows selected for neither
-- go to the next list ticked, so they stay visible without being counted.
UPDATE public.planned_purchases
SET period = 'next',
    is_done = NOT is_included
WHERE NOT is_included_current
  AND id NOT LIKE '%-next';

ALTER TABLE public.planned_purchases
    DROP COLUMN IF EXISTS is_included,
    DROP COLUMN IF EXISTS is_included_current,
    DROP CONSTRAINT IF EXISTS planned_purchases_period_check;

ALTER TABLE public.planned_purchases
    ADD CONSTRAINT planned_purchases_period_check
        CHECK (period IN ('current', 'next'));
