begin;

alter table public.messages enable row level security;
revoke update on public.messages from public, anon, authenticated;
grant update (read_at) on public.messages to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'messages'
      and policyname = 'rivo_messages_update_read_at_receiver'
  ) then
    create policy rivo_messages_update_read_at_receiver
    on public.messages
    for update
    to authenticated
    using (receiver_id = (select auth.uid()))
    with check (
      receiver_id = (select auth.uid())
      and read_at is not null
    );
  end if;
end;
$$;

alter table public.notifications enable row level security;
revoke update on public.notifications from public, anon, authenticated;
grant update (is_read) on public.notifications to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'rivo_notifications_update_read_own'
  ) then
    create policy rivo_notifications_update_read_own
    on public.notifications
    for update
    to authenticated
    using (user_id = (select auth.uid()))
    with check (
      user_id = (select auth.uid())
      and is_read is true
    );
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'notifications'
    ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

commit;