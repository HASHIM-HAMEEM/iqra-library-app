-- Ensure bucket exists (id and name set to 'profile-images')
insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do nothing;

-- Allow public read of files in 'profile-images'
drop policy if exists "allow public read for profile-images" on storage.objects;
create policy "allow public read for profile-images"
on storage.objects for select
to public
using (bucket_id = 'profile-images');

-- Allow authenticated users to upload to 'profile-images'
drop policy if exists "allow authenticated uploads to profile-images" on storage.objects;
create policy "allow authenticated uploads to profile-images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'profile-images');

-- Allow authenticated users to update their objects in 'profile-images'
drop policy if exists "allow authenticated updates to profile-images" on storage.objects;
create policy "allow authenticated updates to profile-images"
on storage.objects for update
to authenticated
using (bucket_id = 'profile-images')
with check (bucket_id = 'profile-images');

-- Optional: allow authenticated delete (uncomment if you want deletes via app)
-- drop policy if exists "allow authenticated deletes for profile-images" on storage.objects;
-- create policy "allow authenticated deletes for profile-images"
-- on storage.objects for delete
-- to authenticated
-- using (bucket_id = 'profile-images');


