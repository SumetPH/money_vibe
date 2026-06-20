-- Harden Supabase security linter warnings without changing app-facing flows.

-- Make function name resolution deterministic.
ALTER FUNCTION public.handle_updated_at()
SET search_path = '';

ALTER FUNCTION public.delete_user()
SET search_path = '';

ALTER FUNCTION public.get_user_stats()
SET search_path = '';

-- These RPCs only operate on the current user's rows via RLS-safe predicates,
-- so they do not need SECURITY DEFINER privileges.
ALTER FUNCTION public.delete_user()
SECURITY INVOKER;

ALTER FUNCTION public.get_user_stats()
SECURITY INVOKER;

REVOKE EXECUTE ON FUNCTION public.delete_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.delete_user() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_stats() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_user_stats() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_stats() TO authenticated;

-- Public buckets can serve public object URLs without a broad SELECT policy.
-- Dropping this policy prevents clients from listing every object in the bucket.
DROP POLICY IF EXISTS "Anyone can view account icons" ON storage.objects;

-- Keep uploads scoped to the authenticated user's own folder.
DROP POLICY IF EXISTS "Users can upload their own account icons" ON storage.objects;

CREATE POLICY "Users can upload their own account icons"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'account-icons'
  AND (storage.foldername(name))[1] = (select auth.uid()::text)
  AND storage."filename"(name) LIKE '%.%'
);
