-- Existing cash balances may already include manually recorded deposits.
-- Track new deposits without changing historical transactions at migration time.
ALTER TABLE public.transactions
    ADD COLUMN portfolio_cash_applied boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.sync_transfer_portfolio_cash()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    is_portfolio_deposit boolean;
    restored_cash_snapshot boolean := false;
BEGIN
    -- Keep historical deposits manual, even when their details are edited.
    IF TG_OP = 'UPDATE' AND NOT OLD.portfolio_cash_applied
        AND OLD.type = 'transfer' AND EXISTS (
            SELECT 1 FROM public.accounts AS source
            JOIN public.accounts AS destination ON destination.id = OLD.to_account_id
            WHERE source.id = OLD.account_id
              AND source.user_id = OLD.user_id
              AND destination.user_id = OLD.user_id
              AND source.currency = 'THB'
              AND destination.type = 'portfolio'
              AND destination.currency = 'USD'
        ) THEN
        NEW.portfolio_cash_applied := false;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        restored_cash_snapshot := NEW.portfolio_cash_applied;
    ELSE
        IF OLD.portfolio_cash_applied THEN
            UPDATE public.accounts
            SET cash_balance = cash_balance - OLD.to_amount
            WHERE id = OLD.to_account_id AND user_id = OLD.user_id;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.accounts AS source
        JOIN public.accounts AS destination ON destination.id = NEW.to_account_id
        WHERE source.id = NEW.account_id
          AND source.user_id = NEW.user_id
          AND destination.user_id = NEW.user_id
          AND source.currency = 'THB'
          AND destination.type = 'portfolio'
          AND destination.currency = 'USD'
          AND NEW.type = 'transfer'
    ) INTO is_portfolio_deposit;

    NEW.portfolio_cash_applied := false;
    IF is_portfolio_deposit THEN
        IF NEW.to_amount IS NULL OR NEW.to_amount <= 0
            OR NEW.to_amount = 'NaN'::numeric THEN
            -- Older backups may not contain a received USD amount.
            IF restored_cash_snapshot THEN
                RETURN NEW;
            END IF;
            RAISE EXCEPTION 'A THB to US portfolio transfer requires a positive USD amount';
        END IF;

        IF NOT restored_cash_snapshot THEN
            UPDATE public.accounts
            SET cash_balance = cash_balance + NEW.to_amount
            WHERE id = NEW.to_account_id AND user_id = NEW.user_id;
        END IF;
        NEW.portfolio_cash_applied := true;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER sync_transfer_portfolio_cash
BEFORE INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.sync_transfer_portfolio_cash();
