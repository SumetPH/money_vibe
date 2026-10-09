-- Harden account deletion and storage for the store release.
--
-- Account deletion now runs through the `delete-account` Edge Function, which
-- calls auth.admin.deleteUser(); every user table is removed via
-- ON DELETE CASCADE from auth.users.

-- 1. sync_logs was the only user table without ON DELETE CASCADE, which made
--    deleting an auth user fail with a foreign key violation.
DO $$
DECLARE
    constraint_record record;
BEGIN
    FOR constraint_record IN
        SELECT con.conname
        FROM pg_constraint con
        WHERE con.conrelid = 'public.sync_logs'::regclass
          AND con.contype = 'f'
          AND con.confrelid = 'auth.users'::regclass
    LOOP
        EXECUTE format(
            'ALTER TABLE public.sync_logs DROP CONSTRAINT %I',
            constraint_record.conname
        );
    END LOOP;
END;
$$;

ALTER TABLE public.sync_logs
    ADD CONSTRAINT sync_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- 2. Cascaded deletes fire the sync triggers on every user table. Skip the
--    sync_logs upsert when the auth user no longer exists, otherwise the
--    insert would violate the sync_logs foreign key mid-deletion.
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

    IF EXISTS (SELECT 1 FROM auth.users WHERE id = affected_user_id) THEN
        INSERT INTO public.sync_logs (user_id, module_name, last_updated_at)
        VALUES (affected_user_id, TG_ARGV[0], clock_timestamp())
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

    IF affected_user_id IS NOT NULL
        AND EXISTS (SELECT 1 FROM auth.users WHERE id = affected_user_id) THEN
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

-- 3. The old RPC only deleted a subset of tables and never removed the auth
--    user. It is replaced by the `delete-account` Edge Function.
DROP FUNCTION IF EXISTS public.delete_user();

-- 4. SVG can carry scripts; stock logos are only stored as raster images.
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp']
WHERE id = 'stock-logos';
