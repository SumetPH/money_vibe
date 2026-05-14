-- เพิ่มคอลัมน์ portfolio_group ในตาราง portfolio_holdings
ALTER TABLE portfolio_holdings 
ADD COLUMN IF NOT EXISTS portfolio_group TEXT DEFAULT '' NOT NULL;
