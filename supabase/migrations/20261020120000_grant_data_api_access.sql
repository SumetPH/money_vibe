-- Supabase stops auto-granting Data API access to new public tables (2026-10-30).
-- Grant explicitly so fresh projects and `supabase db reset` keep working.
-- New tables created after this migration must add their own GRANT.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
    TO authenticated, service_role;
