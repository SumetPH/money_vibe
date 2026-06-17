CREATE TABLE public.portfolio_annual_reports (
    id TEXT PRIMARY KEY,
    portfolio_id TEXT NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    inflow_usd NUMERIC NOT NULL DEFAULT 0.0 CHECK (inflow_usd >= 0),
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Ensure only one report per portfolio per year
    UNIQUE(portfolio_id, year)
);

-- Enable RLS
ALTER TABLE public.portfolio_annual_reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own portfolio_annual_reports"
    ON public.portfolio_annual_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.accounts a
            WHERE a.id = portfolio_annual_reports.portfolio_id
            AND a.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert their own portfolio_annual_reports"
    ON public.portfolio_annual_reports FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.accounts a
            WHERE a.id = portfolio_annual_reports.portfolio_id
            AND a.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own portfolio_annual_reports"
    ON public.portfolio_annual_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.accounts a
            WHERE a.id = portfolio_annual_reports.portfolio_id
            AND a.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.accounts a
            WHERE a.id = portfolio_annual_reports.portfolio_id
            AND a.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their own portfolio_annual_reports"
    ON public.portfolio_annual_reports FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.accounts a
            WHERE a.id = portfolio_annual_reports.portfolio_id
            AND a.user_id = auth.uid()
        )
    );
