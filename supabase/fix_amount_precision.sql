-- แก้ไขปัญหา precision ของ amount columns
-- เปลี่ยนจาก real เป็น numeric(15,2) เพื่อเก็บทศนิยมครบถ้วน

-- 1. Transactions table
ALTER TABLE transactions 
  ALTER COLUMN amount TYPE numeric(15,2);

-- 2. Accounts table  
ALTER TABLE accounts
  ALTER COLUMN initial_balance TYPE numeric(15,2),
  ALTER COLUMN cash_balance TYPE numeric(15,2),
  ALTER COLUMN exchange_rate TYPE numeric(15,4); -- อาจต้องการทศนิยม 4 ตำแหน่ง

-- 3. Budgets table
ALTER TABLE budgets
  ALTER COLUMN amount TYPE numeric(15,2);

-- 4. Portfolio holdings
ALTER TABLE portfolio_holdings
  ALTER COLUMN shares TYPE numeric(15,4),
  ALTER COLUMN price_usd TYPE numeric(15,4),
  ALTER COLUMN cost_basis_usd TYPE numeric(15,4);

-- 5. Recurring transactions
ALTER TABLE recurring_transactions
  ALTER COLUMN amount TYPE numeric(15,2);
