-- Keep existing next-period selections; current-period selection starts off.
ALTER TABLE public.planned_purchases
    ADD COLUMN IF NOT EXISTS is_included_current boolean NOT NULL DEFAULT false;
