-- Account list net-worth filter: accounts the user unticked in the
-- "ยอดเงินสุทธิ" filter sheet. Previously stored locally (SharedPreferences);
-- the app moves an existing local selection here on first load.
-- Separate from exclude_from_net_worth, which also affects statistics/export.

ALTER TABLE public.accounts
    ADD COLUMN IF NOT EXISTS is_excluded_from_net_worth_filter boolean
        NOT NULL DEFAULT false;
