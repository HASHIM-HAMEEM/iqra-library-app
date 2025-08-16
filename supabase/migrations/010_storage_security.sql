-- STORAGE SECURITY HARDENING
-- Tighten storage policies for 'profile-images' bucket

-- Ensure bucket exists but not public
update storage.buckets set public = false where id = 'profile-images';

-- Drop all existing overly-permissive policies
drop policy if exists "allow public read for profile-images" on storage.objects;
drop policy if exists "allow authenticated uploads to profile-images" on storage.objects; 
drop policy if exists "allow authenticated updates to profile-images" on storage.objects;
drop policy if exists "allow authenticated deletes for profile-images" on storage.objects;

-- Use path-based ownership: files must be in path format 'user_id/...'
-- This requires client apps to organize files by user ID

-- Read: only owner can read their files (using path convention user_id/...)
create policy "profile-images owner can read"
on storage.objects for select to authenticated
using (
  bucket_id = 'profile-images'
  and (auth.role() = 'service_role' or name ~ ('^' || auth.uid()::text || '/'))
);

-- Insert: only owner can upload files to their path
create policy "profile-images owner can insert"  
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-images'
  and name ~ ('^' || auth.uid()::text || '/')
);

-- Update: only owner can update their files
create policy "profile-images owner can update"
on storage.objects for update to authenticated
using (
  bucket_id = 'profile-images' and name ~ ('^' || auth.uid()::text || '/')
)
with check (
  bucket_id = 'profile-images' and name ~ ('^' || auth.uid()::text || '/')
);

-- Delete: only owner can delete their files  
create policy "profile-images owner can delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'profile-images' and name ~ ('^' || auth.uid()::text || '/')
);

COMMIT;