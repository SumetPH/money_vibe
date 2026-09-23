-- Keep sync metadata canonical and update it in the same transaction as data.

INSERT INTO public.sync_logs (user_id, module_name, last_updated_at)
SELECT user_id, 'portfolio', max(last_updated_at)
FROM public.sync_logs
WHERE module_name IN ('portfolio', 'portfolio_annual_reports')
GROUP BY user_id
ON CONFLICT (user_id, module_name) DO UPDATE
SET last_updated_at = greatest(
    public.sync_logs.last_updated_at,
    excluded.last_updated_at
);

DELETE FROM public.sync_logs
WHERE module_name NOT IN (
    'accounts',
    'portfolio',
    'categories',
    'transactions',
    'budgets',
    'recurring'
);

ALTER TABLE public.sync_logs
    DROP CONSTRAINT IF EXISTS sync_logs_module_name_check;

ALTER TABLE public.sync_logs
    ADD CONSTRAINT sync_logs_module_name_check CHECK (
        module_name IN (
            'accounts',
            'portfolio',
            'categories',
            'transactions',
            'budgets',
            'recurring'
        )
    );

DROP POLICY IF EXISTS "Users can manage their own sync logs"
    ON public.sync_logs;
DROP POLICY IF EXISTS "Users can read their own sync logs"
    ON public.sync_logs;
CREATE POLICY "Users can read their own sync logs"
    ON public.sync_logs
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.touch_sync_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    affected_user_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.user_id;
    ELSE
        affected_user_id := NEW.user_id;
    END IF;

    INSERT INTO public.sync_logs (user_id, module_name, last_updated_at)
    VALUES (affected_user_id, TG_ARGV[0], clock_timestamp())
    ON CONFLICT (user_id, module_name) DO UPDATE
    SET last_updated_at = greatest(
        public.sync_logs.last_updated_at,
        excluded.last_updated_at
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_portfolio_report_sync_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    affected_portfolio_id text;
    affected_user_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_portfolio_id := OLD.portfolio_id;
    ELSE
        affected_portfolio_id := NEW.portfolio_id;
    END IF;

    SELECT user_id INTO affected_user_id
    FROM public.accounts
    WHERE id = affected_portfolio_id;

    IF affected_user_id IS NULL THEN
        affected_user_id := auth.uid();
    END IF;

    IF affected_user_id IS NOT NULL THEN
        INSERT INTO public.sync_logs (user_id, module_name, last_updated_at)
        VALUES (affected_user_id, 'portfolio', clock_timestamp())
        ON CONFLICT (user_id, module_name) DO UPDATE
        SET last_updated_at = greatest(
            public.sync_logs.last_updated_at,
            excluded.last_updated_at
        );
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_accounts ON public.accounts;
CREATE TRIGGER sync_accounts
AFTER INSERT OR UPDATE OR DELETE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('accounts');

DROP TRIGGER IF EXISTS sync_categories ON public.categories;
CREATE TRIGGER sync_categories
AFTER INSERT OR UPDATE OR DELETE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('categories');

DROP TRIGGER IF EXISTS sync_transactions ON public.transactions;
CREATE TRIGGER sync_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('transactions');

DROP TRIGGER IF EXISTS sync_budgets ON public.budgets;
CREATE TRIGGER sync_budgets
AFTER INSERT OR UPDATE OR DELETE ON public.budgets
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('budgets');

DROP TRIGGER IF EXISTS sync_recurring_transactions
    ON public.recurring_transactions;
CREATE TRIGGER sync_recurring_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.recurring_transactions
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('recurring');

DROP TRIGGER IF EXISTS sync_recurring_occurrences
    ON public.recurring_occurrences;
CREATE TRIGGER sync_recurring_occurrences
AFTER INSERT OR UPDATE OR DELETE ON public.recurring_occurrences
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('recurring');

DROP TRIGGER IF EXISTS sync_portfolio_holdings ON public.portfolio_holdings;
CREATE TRIGGER sync_portfolio_holdings
AFTER INSERT OR UPDATE OR DELETE ON public.portfolio_holdings
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('portfolio');

DROP TRIGGER IF EXISTS sync_stock_trades ON public.stock_trades;
CREATE TRIGGER sync_stock_trades
AFTER INSERT OR UPDATE OR DELETE ON public.stock_trades
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('portfolio');

DROP TRIGGER IF EXISTS sync_stock_purchases ON public.stock_purchases;
CREATE TRIGGER sync_stock_purchases
AFTER INSERT OR UPDATE OR DELETE ON public.stock_purchases
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('portfolio');

DROP TRIGGER IF EXISTS sync_portfolio_investment_plans
    ON public.portfolio_investment_plans;
CREATE TRIGGER sync_portfolio_investment_plans
AFTER INSERT OR UPDATE OR DELETE ON public.portfolio_investment_plans
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('portfolio');

DROP TRIGGER IF EXISTS sync_portfolio_allocation_targets
    ON public.portfolio_allocation_targets;
CREATE TRIGGER sync_portfolio_allocation_targets
AFTER INSERT OR UPDATE OR DELETE ON public.portfolio_allocation_targets
FOR EACH ROW EXECUTE FUNCTION public.touch_sync_log('portfolio');

DROP TRIGGER IF EXISTS sync_portfolio_annual_reports
    ON public.portfolio_annual_reports;
CREATE TRIGGER sync_portfolio_annual_reports
BEFORE INSERT OR UPDATE OR DELETE ON public.portfolio_annual_reports
FOR EACH ROW EXECUTE FUNCTION public.touch_portfolio_report_sync_log();
