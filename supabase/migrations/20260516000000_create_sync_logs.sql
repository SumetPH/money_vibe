-- Create sync_logs table for modular background sync
CREATE TABLE IF NOT EXISTS public.sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    module_name TEXT NOT NULL,
    last_updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(user_id, module_name)
);

ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own sync logs" ON public.sync_logs
    FOR ALL USING (auth.uid() = user_id);
