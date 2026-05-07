-- ============================================
-- Create account-icons bucket for user-uploaded account icons
-- ============================================

-- Insert bucket into storage.buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'account-icons',
  'account-icons',
  true,
  2097152, -- 2MB limit
  ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- RLS Policies for account-icons bucket
-- ============================================

-- Policy: Allow authenticated users to view any account icon (public)
CREATE POLICY "Anyone can view account icons" ON storage.objects FOR
SELECT USING (bucket_id = 'account-icons');

-- Policy: Allow users to upload their own account icons
CREATE POLICY "Users can upload their own account icons"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'account-icons'
  AND auth.role() = 'authenticated'
  -- File path format: {userId}/{accountId}_{timestamp}.{ext}
  AND storage."filename"(name) LIKE '%.%'
);

-- Policy: Allow users to update their own account icons
CREATE POLICY "Users can update their own account icons"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'account-icons'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'account-icons'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own account icons
CREATE POLICY "Users can delete their own account icons"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'account-icons'
  AND (storage.foldername(name))[1] = auth.uid()::text
);