-- รายการข้ามสกุลทั้งหมดเป็น 'exchange'; 'transfer' ใช้ได้เฉพาะบัญชีสกุลเดียวกัน
-- 1. แปลง transfer เดิมที่บัญชีต้นทาง/ปลายทางคนละสกุลเป็น exchange
--    ปิด trigger ระหว่างแปลง เพื่อไม่ให้ cash_balance ของพอร์ตถูกหักแล้วบวกซ้ำ
--    (เปลี่ยนแค่ type; portfolio_cash_applied และยอดเงินคงเดิม)
ALTER TABLE public.transactions DISABLE TRIGGER sync_transfer_portfolio_cash;

UPDATE public.transactions AS t
SET type = 'exchange'
FROM public.accounts AS source, public.accounts AS destination
WHERE t.type = 'transfer'
  AND source.id = t.account_id
  AND source.user_id = t.user_id
  AND destination.id = t.to_account_id
  AND destination.user_id = t.user_id
  AND source.currency <> destination.currency;

ALTER TABLE public.transactions ENABLE TRIGGER sync_transfer_portfolio_cash;

-- 2. trigger เติมเงินพอร์ต US ใช้เฉพาะ exchange
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
        AND OLD.type = 'exchange' AND EXISTS (
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
          AND NEW.type = 'exchange'
    ) INTO is_portfolio_deposit;

    NEW.portfolio_cash_applied := false;
    IF is_portfolio_deposit THEN
        IF NEW.to_amount IS NULL OR NEW.to_amount <= 0
            OR NEW.to_amount = 'NaN'::numeric THEN
            -- Older backups may not contain a received USD amount.
            IF restored_cash_snapshot THEN
                RETURN NEW;
            END IF;
            RAISE EXCEPTION 'A THB to US portfolio deposit requires a positive USD amount';
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
