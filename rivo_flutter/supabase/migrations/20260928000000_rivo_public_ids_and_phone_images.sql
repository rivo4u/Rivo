create sequence if not exists public.profile_public_id_seq
  start with 100000
  increment by 1;

alter table public.profiles
  add column if not exists public_id bigint,
  add column if not exists display_name text,
  add column if not exists bio text,
  add column if not exists avatar_path text;

alter table public.profiles
  alter column public_id set default nextval('public.profile_public_id_seq'::regclass);

update public.profiles
set public_id = nextval('public.profile_public_id_seq'::regclass)
where public_id is null or public_id < 100000;

select setval(
  'public.profile_public_id_seq'::regclass,
  greatest(coalesce(max(public_id), 99999), 99999),
  max(public_id) is not null
)
from public.profiles;

alter table public.profiles
  alter column public_id set not null;

create unique index if not exists profiles_public_id_uidx
  on public.profiles (public_id);

alter table public.profiles enable row level security;
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, bio, avatar_path) on public.profiles to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'rivo_profiles_read_authenticated'
  ) then
    create policy rivo_profiles_read_authenticated on public.profiles
      for select to authenticated using (true);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'rivo_profiles_update_own'
  ) then
    create policy rivo_profiles_update_own on public.profiles
      for update to authenticated
      using (id = (select auth.uid()))
      with check (id = (select auth.uid()));
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'rivo_profiles_update_owner_guard'
  ) then
    create policy rivo_profiles_update_owner_guard on public.profiles
      as restrictive for update to authenticated
      using (id = (select auth.uid()))
      with check (id = (select auth.uid()));
  end if;
end;
$$;

create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.rooms
  add column if not exists image_path text;

alter table public.moments
  add column if not exists body text,
  add column if not exists content text,
  add column if not exists image_path text,
  add column if not exists author_name text,
  add column if not exists author_avatar_path text,
  add column if not exists updated_at timestamptz not null default now();

update public.moments
set body = coalesce(nullif(body, ''), nullif(content, '')),
    content = coalesce(nullif(content, ''), nullif(body, ''))
where body is null or content is null or body = '' or content = '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.moments'::regclass
      and conname = 'rivo_moments_body_valid'
  ) then
    alter table public.moments
      add constraint rivo_moments_body_valid
      check (body is not null and char_length(body) between 1 and 1000)
      not valid;
  end if;
end;
$$;

alter table public.moments enable row level security;

revoke all on public.moments from anon;
grant select, insert, update, delete on public.moments to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments'
      and policyname = 'rivo_moments_read_authenticated'
  ) then
    create policy rivo_moments_read_authenticated on public.moments
      for select to authenticated using (true);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments'
      and policyname = 'rivo_moments_insert_own'
  ) then
    create policy rivo_moments_insert_own on public.moments
      for insert to authenticated
      with check (user_id = (select auth.uid()));
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments'
      and policyname = 'rivo_moments_update_own'
  ) then
    create policy rivo_moments_update_own on public.moments
      for update to authenticated
      using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid()));
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments'
      and policyname = 'rivo_moments_delete_own'
  ) then
    create policy rivo_moments_delete_own on public.moments
      for delete to authenticated using (user_id = (select auth.uid()));
  end if;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rivo-media',
  'rivo-media',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

alter table storage.objects enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'rivo_media_read_own_uploads'
  ) then
    create policy rivo_media_read_own_uploads on storage.objects
      for select to authenticated
      using (
        bucket_id = 'rivo-media'
        and (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'moments'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'rooms'
          and exists (
            select 1 from public.rooms as room
            where room.id::text = (storage.foldername(name))[2]
              and room.owner_id = (select auth.uid())
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'rivo_media_insert_own_uploads'
  ) then
    create policy rivo_media_insert_own_uploads on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'rivo-media'
        and (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'moments'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'rooms'
          and exists (
            select 1 from public.rooms as room
            where room.id::text = (storage.foldername(name))[2]
              and room.owner_id = (select auth.uid())
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'rivo_media_update_own_uploads'
  ) then
    create policy rivo_media_update_own_uploads on storage.objects
      for update to authenticated
      using (
        bucket_id = 'rivo-media'
        and (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'moments'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'rooms'
          and exists (
            select 1 from public.rooms as room
            where room.id::text = (storage.foldername(name))[2]
              and room.owner_id = (select auth.uid())
          )
        )
      )
      with check (
        bucket_id = 'rivo-media'
        and (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'moments'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'rooms'
          and exists (
            select 1 from public.rooms as room
            where room.id::text = (storage.foldername(name))[2]
              and room.owner_id = (select auth.uid())
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'rivo_media_delete_own_uploads'
  ) then
    create policy rivo_media_delete_own_uploads on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'rivo-media'
        and (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'moments'
          and (storage.foldername(name))[2] = (select auth.uid())::text
          or (storage.foldername(name))[1] = 'rooms'
          and exists (
            select 1 from public.rooms as room
            where room.id::text = (storage.foldername(name))[2]
              and room.owner_id = (select auth.uid())
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rooms'
      and policyname = 'rivo_rooms_insert_owner'
  ) then
    create policy rivo_rooms_insert_owner on public.rooms
      for insert to authenticated
      with check (owner_id = (select auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rooms'
      and policyname = 'rivo_rooms_update_owner'
  ) then
    create policy rivo_rooms_update_owner on public.rooms
      for update to authenticated
      using (owner_id = (select auth.uid()))
      with check (owner_id = (select auth.uid()));
  end if;
end;
$$;