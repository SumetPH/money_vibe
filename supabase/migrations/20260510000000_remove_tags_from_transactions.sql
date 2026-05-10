-- Migration: Remove tags column from transactions table
-- Description: The tags column is no longer needed and will be removed.

ALTER TABLE public.transactions DROP COLUMN IF EXISTS tags;
