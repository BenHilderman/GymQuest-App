-- Storage policies for post-media bucket
create policy "post_media_read" on storage.objects for select using (bucket_id = 'post-media' and auth.role() = 'authenticated');
create policy "post_media_insert" on storage.objects for insert with check (bucket_id = 'post-media' and auth.role() = 'authenticated');
create policy "post_media_delete" on storage.objects for delete using (bucket_id = 'post-media' and auth.uid()::text = (storage.foldername(name))[1]);

-- Storage policies for profile-photos bucket
create policy "profile_photos_read" on storage.objects for select using (bucket_id = 'profile-photos' and auth.role() = 'authenticated');
create policy "profile_photos_insert" on storage.objects for insert with check (bucket_id = 'profile-photos' and auth.role() = 'authenticated');
create policy "profile_photos_delete" on storage.objects for delete using (bucket_id = 'profile-photos' and auth.uid()::text = (storage.foldername(name))[1]);
