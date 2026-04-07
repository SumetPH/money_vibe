-- Supabase Schema for Money Flutter App
-- สร้าง tables สำหรับเก็บข้อมูลการเงิน (แยกตาม user)

-- ============================================
-- ACCOUNTS TABLE
-- เก็บข้อมูลบัญชีเงินต่างๆ
-- ============================================
create table if not exists public.accounts (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    type text not null check (type in ('cash', 'bankAccount', 'creditCard', 'debt', 'investment', 'portfolio')),
    initial_balance numeric(15,2) not null default 0,
    currency text not null default 'THB',
    start_date timestamp without time zone not null,
    icon integer not null,
    color integer not null,
    exclude_from_net_worth integer not null default 0,
    is_hidden integer not null default 0,
    sort_order integer not null default 0,
    cash_balance numeric(15,2) not null default 0,
    exchange_rate numeric(15,4) not null default 35.0,
    auto_update_rate integer not null default 1,
    statement_day integer,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_type ON public.accounts(type);
CREATE INDEX IF NOT EXISTS idx_accounts_sort_order ON public.accounts(sort_order);

-- Enable RLS
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own accounts" ON public.accounts
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- CATEGORIES TABLE
-- เก็บข้อมูลหมวดหมู่รายรับ/รายจ่าย
-- ============================================
CREATE TABLE IF NOT EXISTS public.categories (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    type text not null check (type in ('expense', 'income')),
    icon integer not null,
    color integer not null,
    parent_id text references public.categories(id) on delete set null,
    note text,
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON public.categories(type);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON public.categories(sort_order);

-- Enable RLS
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own categories" ON public.categories
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- TRANSACTIONS TABLE
-- เก็บข้อมูลธุรกรรมการเงิน
-- ============================================
CREATE TABLE IF NOT EXISTS public.transactions (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    type text not null check (type in ('expense', 'income', 'transfer', 'debtRepay')),
    amount numeric(15,2) not null,
    account_id text not null references public.accounts(id) on delete cascade,
    category_id text references public.categories(id) on delete set null,
    to_account_id text references public.accounts(id) on delete set null,
    date_time timestamp without time zone not null,
    note text,
    tags text not null default '',
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON public.transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_to_account_id ON public.transactions(to_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date_time ON public.transactions(date_time desc);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);

-- Enable RLS
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own transactions" ON public.transactions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- PORTFOLIO HOLDINGS TABLE
-- เก็บข้อมูลการถือหุ้นใน portfolio
-- ============================================
CREATE TABLE IF NOT EXISTS public.portfolio_holdings (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    portfolio_id text not null references public.accounts(id) on delete cascade,
    ticker text not null,
    name text not null default '',
    shares numeric(15,4) not null default 0,
    price_usd numeric(15,4) not null default 0,
    cost_basis_usd numeric(15,4) not null default 0,
    logo_url text not null default '',
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_holdings_user_id ON public.portfolio_holdings(user_id);
CREATE INDEX IF NOT EXISTS idx_holdings_portfolio_id ON public.portfolio_holdings(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_holdings_sort_order ON public.portfolio_holdings(sort_order);

-- Enable RLS
ALTER TABLE public.portfolio_holdings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own holdings" ON public.portfolio_holdings
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- BUDGETS TABLE
-- เก็บข้อมูลงบประมาณ
-- ============================================
CREATE TABLE IF NOT EXISTS public.budgets (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    amount numeric(15,2) not null default 0,
    category_ids text not null default '[]',
    icon integer not null,
    color integer not null,
    sort_order integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON public.budgets(user_id);
CREATE INDEX IF NOT EXISTS idx_budgets_sort_order ON public.budgets(sort_order);

-- Enable RLS
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own budgets" ON public.budgets
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- RECURRING TRANSACTIONS TABLE
-- เก็บข้อมูลธุรกรรมที่เกิดซ้ำ
-- ============================================
CREATE TABLE IF NOT EXISTS public.recurring_transactions (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    icon integer not null,
    color integer not null,
    start_date timestamp without time zone not null,
    end_date timestamp without time zone,
    day_of_month integer not null default 1,
    transaction_type text not null check (transaction_type in ('expense', 'income', 'transfer', 'debtRepay')),
    amount numeric(15,2) not null default 0,
    account_id text not null references public.accounts(id) on delete cascade,
    to_account_id text references public.accounts(id) on delete set null,
    category_id text references public.categories(id) on delete set null,
    note text,
    sort_order integer not null default 0,
    notification_enabled boolean not null default false,
    notification_hour integer not null default 9,
    notification_minute integer not null default 0,
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recurring_user_id ON public.recurring_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_account_id ON public.recurring_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_recurring_to_account_id ON public.recurring_transactions(to_account_id);
CREATE INDEX IF NOT EXISTS idx_recurring_category_id ON public.recurring_transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_recurring_sort_order ON public.recurring_transactions(sort_order);

-- Enable RLS
ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own recurring" ON public.recurring_transactions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- RECURRING OCCURRENCES TABLE
-- เก็บข้อมูลการเกิดของธุรกรรมที่ซ้ำ
-- ============================================
CREATE TABLE IF NOT EXISTS public.recurring_occurrences (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    recurring_id text not null references public.recurring_transactions(id) on delete cascade,
    due_date timestamp without time zone not null,
    transaction_id text references public.transactions(id) on delete set null,
    status text not null default 'done' check (status in ('pending', 'done', 'skipped')),
    created_at timestamp without time zone default now(),
    updated_at timestamp without time zone default now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_occurrences_user_id ON public.recurring_occurrences(user_id);
CREATE INDEX IF NOT EXISTS idx_occurrences_recurring_id ON public.recurring_occurrences(recurring_id);
CREATE INDEX IF NOT EXISTS idx_occurrences_due_date ON public.recurring_occurrences(due_date);
CREATE INDEX IF NOT EXISTS idx_occurrences_transaction_id ON public.recurring_occurrences(transaction_id);

-- Enable RLS
ALTER TABLE public.recurring_occurrences ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own data
CREATE POLICY "Users can only access their own occurrences" ON public.recurring_occurrences
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
    new.updated_at = now();
    RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all tables
DROP TRIGGER IF EXISTS handle_accounts_updated_at ON public.accounts;
CREATE TRIGGER handle_accounts_updated_at BEFORE UPDATE ON public.accounts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_categories_updated_at ON public.categories;
CREATE TRIGGER handle_categories_updated_at BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_transactions_updated_at ON public.transactions;
CREATE TRIGGER handle_transactions_updated_at BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_portfolio_holdings_updated_at ON public.portfolio_holdings;
CREATE TRIGGER handle_portfolio_holdings_updated_at BEFORE UPDATE ON public.portfolio_holdings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_budgets_updated_at ON public.budgets;
CREATE TRIGGER handle_budgets_updated_at BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_recurring_transactions_updated_at ON public.recurring_transactions;
CREATE TRIGGER handle_recurring_transactions_updated_at BEFORE UPDATE ON public.recurring_transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_recurring_occurrences_updated_at ON public.recurring_occurrences;
CREATE TRIGGER handle_recurring_occurrences_updated_at BEFORE UPDATE ON public.recurring_occurrences
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- FUNCTION: Delete User (สำหรับลบบัญชีผู้ใช้)
-- ============================================
CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void AS $$
DECLARE
    user_uuid uuid;
BEGIN
    -- ดึง user_id ของผู้ใช้ปัจจุบัน
    user_uuid := auth.uid();
    
    -- ลบข้อมูลทั้งหมดของผู้ใช้ (RLS จะตรวจสอบว่าเป็นเจ้าของ)
    DELETE FROM public.recurring_occurrences WHERE user_id = user_uuid;
    DELETE FROM public.recurring_transactions WHERE user_id = user_uuid;
    DELETE FROM public.transactions WHERE user_id = user_uuid;
    DELETE FROM public.portfolio_holdings WHERE user_id = user_uuid;
    DELETE FROM public.budgets WHERE user_id = user_uuid;
    DELETE FROM public.categories WHERE user_id = user_uuid;
    DELETE FROM public.accounts WHERE user_id = user_uuid;
    
    -- ลบ user จาก auth.users (ต้องใช้ service role หรือ admin privileges)
    -- หมายเหตุ: การลบ user จาก auth.users ต้องทำผ่าน Admin API หรือ Edge Function
    -- เนื่องจากต้องใช้ service_role key
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Get User Statistics
-- ============================================
CREATE OR REPLACE FUNCTION public.get_user_stats()
RETURNS TABLE (
    total_accounts bigint,
    total_categories bigint,
    total_transactions bigint,
    total_budgets bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM public.accounts WHERE user_id = auth.uid()),
        (SELECT count(*) FROM public.categories WHERE user_id = auth.uid()),
        (SELECT count(*) FROM public.transactions WHERE user_id = auth.uid()),
        (SELECT count(*) FROM public.budgets WHERE user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
