-- Migration: Add to_amount column for cross-currency transfers
-- Phase 0 of Multi-Currency (THB + USD) implementation
-- Date: 2026-05-11

-- to_amount stores the received amount in the destination account's currency.
-- NULL means same currency as source (no conversion needed).
-- Example: Transfer 35,000 THB → USD account → amount=35000, to_amount=1000.0
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS to_amount NUMERIC NULL;

COMMENT ON COLUMN transactions.to_amount IS
  'Amount received in destination account currency for cross-currency transfers. NULL = same currency as source account.';
