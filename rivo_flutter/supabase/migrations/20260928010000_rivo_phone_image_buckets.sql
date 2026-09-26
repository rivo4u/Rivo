begin;

-- Public buckets are needed for direct phone/gallery image uploads.
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('moments', 'moments', true),
  ('rooms', 'rooms', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists moments_insert_own on public.moments;
create policy moments_insert_own
on public.moments
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists moments_update_own on public.moments;
create policy moments_update_own
on public.moments
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists moments_delete_own on public.moments;
create policy moments_delete_own
on public.moments
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists moments_insert_own on storage.objects;
create policy moments_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'moments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists moments_update_own on storage.objects;
create policy moments_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'moments'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'moments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists moments_delete_own on storage.objects;
create policy moments_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'moments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists rooms_insert_own on storage.objects;
create policy rooms_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'rooms'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists rooms_update_own on storage.objects;
create policy rooms_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'rooms'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'rooms'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists rooms_delete_own on storage.objects;
create policy rooms_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'rooms'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;