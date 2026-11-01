-- Expose only the current user's password capability, never the password hash.
create or replace function public.has_password()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users
    where id = (select auth.uid())
      and encrypted_password is not null
      and encrypted_password <> ''
  );
$$;

revoke all on function public.has_password() from public, anon;
grant execute on function public.has_password() to authenticated;
