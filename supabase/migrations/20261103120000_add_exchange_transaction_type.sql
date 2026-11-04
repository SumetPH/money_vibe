-- เพิ่มประเภทรายการ 'exchange' (แลกเงินระหว่างบัญชีคนละสกุล)
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check
CHECK (type IN ('expense', 'income', 'transfer', 'exchange', 'debtRepay', 'debtTransfer', 'increaseBalance', 'decreaseBalance'));
