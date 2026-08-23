ALTER TABLE public.budgets
ADD COLUMN IF NOT EXISTS is_hidden integer NOT NULL DEFAULT 0;
