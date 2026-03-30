-- Phase 1: Add group_name and budget_type columns to budgets table
-- group_name: allows budgets to be visually grouped (e.g. "ใช้จ่าย", "หนี้สิน", "ออม / ลงทุน")
-- budget_type: "expense" (default) tracks via categories | "savings" shows as plan only

ALTER TABLE budgets ADD COLUMN IF NOT EXISTS group_name TEXT;

ALTER TABLE budgets
ADD COLUMN IF NOT EXISTS budget_type TEXT NOT NULL DEFAULT 'expense';