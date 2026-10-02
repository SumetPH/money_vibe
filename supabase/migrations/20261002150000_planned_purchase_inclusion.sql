-- Cash-flow forecast: planned purchases are what-if rows. An unticked row is
-- only listed; ticking it (is_included) counts it in its window. Replaces the
-- "bought" tick (is_done) and keeps current totals: rows that were counted
-- (not done) become included.

ALTER TABLE public.planned_purchases
    ADD COLUMN IF NOT EXISTS is_included boolean NOT NULL DEFAULT false;

UPDATE public.planned_purchases
SET is_included = NOT is_done;

ALTER TABLE public.planned_purchases
    DROP COLUMN IF EXISTS is_done;
