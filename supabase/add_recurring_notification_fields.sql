ALTER TABLE public.recurring_transactions
ADD COLUMN IF NOT EXISTS notification_enabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.recurring_transactions
ADD COLUMN IF NOT EXISTS notification_hour integer NOT NULL DEFAULT 9;

ALTER TABLE public.recurring_transactions
ADD COLUMN IF NOT EXISTS notification_minute integer NOT NULL DEFAULT 0;
