-- budget_forecast_settings.is_excluded must allow null (null = follow the
-- budget's default). Databases that applied an earlier draft of
-- 20261002090000 still have NOT NULL, which breaks CSV import and saving
-- default settings.
ALTER TABLE public.budget_forecast_settings
    ALTER COLUMN is_excluded DROP NOT NULL,
    ALTER COLUMN is_excluded DROP DEFAULT;
