-- Migration: Update check constraints for new account and transaction types
-- Run this in your Supabase SQL Editor

-- 1. Update accounts table check constraint (added 'asset')
ALTER TABLE public.accounts DROP CONSTRAINT IF EXISTS accounts_type_check;
ALTER TABLE public.accounts ADD CONSTRAINT accounts_type_check 
CHECK (type IN ('cash', 'bankAccount', 'creditCard', 'debt', 'investment', 'portfolio', 'asset'));

-- 2. Update transactions table check constraint (added 'debtTransfer')
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check 
CHECK (type IN ('expense', 'income', 'transfer', 'debtRepay', 'debtTransfer', 'increaseBalance', 'decreaseBalance'));

-- 3. Update recurring_transactions table check constraint (added 'debtTransfer')
ALTER TABLE public.recurring_transactions DROP CONSTRAINT IF EXISTS recurring_transactions_transaction_type_check;
ALTER TABLE public.recurring_transactions ADD CONSTRAINT recurring_transactions_transaction_type_check 
CHECK (transaction_type IN ('expense', 'income', 'transfer', 'debtRepay', 'debtTransfer', 'increaseBalance', 'decreaseBalance'));
