-- ============================================
-- Migration: Add icon_url column to accounts table
-- ============================================

ALTER TABLE public.accounts
ADD COLUMN IF NOT EXISTS icon_url text not null default '';