create policy "Users can upload their own stock logos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'stock-logos' and
  (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Users can update their own stock logos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'stock-logos' and
  (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'stock-logos' and
  (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Users can delete their own stock logos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'stock-logos' and
  (storage.foldername(name))[1] = (select auth.uid()::text)
);
