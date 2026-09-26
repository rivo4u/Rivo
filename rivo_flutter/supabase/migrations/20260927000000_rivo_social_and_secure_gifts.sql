create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.moments enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments' and policyname = 'rivo_moments_read_authenticated'
  ) then
    create policy rivo_moments_read_authenticated on public.moments
      for select to authenticated using (true);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments' and policyname = 'rivo_moments_insert_own'
  ) then
    create policy rivo_moments_insert_own on public.moments
      for insert to authenticated with check (user_id = (select auth.uid()));
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments' and policyname = 'rivo_moments_update_own'
  ) then
    create policy rivo_moments_update_own on public.moments
      for update to authenticated using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid()));
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments' and policyname = 'rivo_moments_delete_own'
  ) then
    create policy rivo_moments_delete_own on public.moments
      for delete to authenticated using (user_id = (select auth.uid()));
  end if;
end;
$$;

create index if not exists moments_created_at_idx on public.moments (created_at desc);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if to_regclass('public.messages') is not null and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;
    if to_regclass('public.gift_transactions') is not null and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'gift_transactions'
    ) then
      alter publication supabase_realtime add table public.gift_transactions;
    end if;
  end if;
end;
$$;

create or replace function public.send_gift(
  p_receiver_id uuid,
  p_gift_id uuid,
  p_room_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender_id uuid := auth.uid();
  v_coin_cost bigint;
  v_balance bigint;
  v_balance_column text;
  v_transaction_id uuid;
  v_gift_row jsonb;
  v_updated_rows bigint;
begin
  if v_sender_id is null then
    raise exception 'Authentication required';
  end if;
  if p_receiver_id is null or p_receiver_id = v_sender_id then
    raise exception 'Choose another signed-in user as the gift receiver';
  end if;

  select to_jsonb(gift_row)
    into v_gift_row
    from public.gifts as gift_row
    where to_jsonb(gift_row)->>'id' = p_gift_id::text;
  if v_gift_row is null then
    raise exception 'Gift does not exist';
  end if;
  if coalesce((v_gift_row->>'is_active')::boolean, true) is false then
    raise exception 'Gift is not available';
  end if;
  v_coin_cost := coalesce(
    nullif(v_gift_row->>'price', '')::bigint,
    nullif(v_gift_row->>'coin_price', '')::bigint,
    nullif(v_gift_row->>'coins', '')::bigint
  );
  if v_coin_cost is null or v_coin_cost <= 0 then
    raise exception 'Gift has no valid coin price';
  end if;

  select column_name
    into v_balance_column
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'wallets'
      and column_name in ('coins', 'coin_balance', 'balance')
    order by case column_name when 'coins' then 1 when 'coin_balance' then 2 else 3 end
    limit 1;
  if v_balance_column is null then
    raise exception 'Wallet balance column not found';
  end if;

  execute format(
    'select %I::bigint from public.wallets where user_id = $1 for update',
    v_balance_column
  ) into v_balance using v_sender_id;
  if not found or v_balance is null or v_balance < v_coin_cost then
    raise exception 'Insufficient coin balance';
  end if;

  execute format(
    'update public.wallets set %I = %I - $1 where user_id = $2 and %I >= $1',
    v_balance_column, v_balance_column, v_balance_column
  ) using v_coin_cost, v_sender_id;
  get diagnostics v_updated_rows = row_count;
  if v_updated_rows <> 1 then
    raise exception 'Insufficient coin balance';
  end if;

  insert into public.gift_transactions (sender_id, receiver_id, gift_id, room_id, coin_amount)
  values (v_sender_id, p_receiver_id, p_gift_id, p_room_id, v_coin_cost)
  returning id into v_transaction_id;

  insert into public.coin_transactions (user_id, amount, transaction_type, reference_id)
  values (v_sender_id, -v_coin_cost, 'gift_sent', v_transaction_id);

  return v_transaction_id;
end;
$$;

revoke all on function public.send_gift(uuid, uuid, uuid) from public;
grant execute on function public.send_gift(uuid, uuid, uuid) to authenticated;

revoke insert, update, delete on public.wallets from anon, authenticated;
revoke insert, update, delete on public.coin_transactions from anon, authenticated;
revoke insert, update, delete on public.gift_transactions from anon, authenticated;
revoke insert, update, delete on public.gifts from anon, authenticated;

-- Add least-privilege policies only when the pre-existing table has the expected owner columns.
do $$
begin
  if to_regclass('public.wallets') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'wallets' and column_name = 'user_id'
  ) then
    alter table public.wallets enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'wallets' and policyname = 'rivo_wallet_read_own') then
      create policy rivo_wallet_read_own on public.wallets for select to authenticated using (user_id = (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.coin_transactions') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'coin_transactions' and column_name = 'user_id'
  ) then
    alter table public.coin_transactions enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'coin_transactions' and policyname = 'rivo_coin_transactions_read_own') then
      create policy rivo_coin_transactions_read_own on public.coin_transactions for select to authenticated using (user_id = (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.gifts') is not null then
    alter table public.gifts enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'gifts' and policyname = 'rivo_gifts_read_authenticated') then
      create policy rivo_gifts_read_authenticated on public.gifts for select to authenticated using (true);
    end if;
  end if;

  if to_regclass('public.gift_transactions') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'gift_transactions' and column_name = 'sender_id'
  ) and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'gift_transactions' and column_name = 'receiver_id'
  ) and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'gift_transactions' and column_name = 'room_id'
  ) then
    alter table public.gift_transactions enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'gift_transactions' and policyname = 'rivo_gift_transactions_read_related') then
      create policy rivo_gift_transactions_read_related on public.gift_transactions for select to authenticated
        using (
          sender_id = (select auth.uid())
          or receiver_id = (select auth.uid())
          or exists (
            select 1 from public.rooms as room
            where room.id = gift_transactions.room_id and room.owner_id = (select auth.uid())
          )
          or exists (
            select 1 from public.mic_seats as seat
            where seat.room_id = gift_transactions.room_id and seat.user_id = (select auth.uid())
          )
        );
    end if;
  end if;

  if to_regclass('public.messages') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'sender_id'
  ) and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'receiver_id'
  ) then
    alter table public.messages enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'messages' and policyname = 'rivo_messages_read_related') then
      create policy rivo_messages_read_related on public.messages for select to authenticated
        using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'messages' and policyname = 'rivo_messages_insert_sender') then
      create policy rivo_messages_insert_sender on public.messages for insert to authenticated
        with check (sender_id = (select auth.uid()) and receiver_id <> (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.notifications') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'notifications' and column_name = 'user_id'
  ) then
    alter table public.notifications enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'notifications' and policyname = 'rivo_notifications_read_own') then
      create policy rivo_notifications_read_own on public.notifications for select to authenticated using (user_id = (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.user_settings') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'user_settings' and column_name = 'user_id'
  ) then
    alter table public.user_settings enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'user_settings' and policyname = 'rivo_settings_read_own') then
      create policy rivo_settings_read_own on public.user_settings for select to authenticated using (user_id = (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'user_settings' and policyname = 'rivo_settings_insert_own') then
      create policy rivo_settings_insert_own on public.user_settings for insert to authenticated with check (user_id = (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'user_settings' and policyname = 'rivo_settings_update_own') then
      create policy rivo_settings_update_own on public.user_settings for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.follows') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'follows' and column_name = 'follower_id'
  ) and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'follows' and column_name = 'followed_id'
  ) then
    alter table public.follows enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follows' and policyname = 'rivo_follows_read_related') then
      create policy rivo_follows_read_related on public.follows for select to authenticated using (follower_id = (select auth.uid()) or followed_id = (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follows' and policyname = 'rivo_follows_insert_own') then
      create policy rivo_follows_insert_own on public.follows for insert to authenticated with check (follower_id = (select auth.uid()) and followed_id <> (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.blocks') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'blocks' and column_name = 'blocker_id'
  ) and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'blocks' and column_name = 'blocked_id'
  ) then
    alter table public.blocks enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'blocks' and policyname = 'rivo_blocks_read_own') then
      create policy rivo_blocks_read_own on public.blocks for select to authenticated using (blocker_id = (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'blocks' and policyname = 'rivo_blocks_insert_own') then
      create policy rivo_blocks_insert_own on public.blocks for insert to authenticated with check (blocker_id = (select auth.uid()) and blocked_id <> (select auth.uid()));
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'blocks' and policyname = 'rivo_blocks_delete_own') then
      create policy rivo_blocks_delete_own on public.blocks for delete to authenticated using (blocker_id = (select auth.uid()));
    end if;
  end if;

  if to_regclass('public.reports') is not null and exists (
    select 1 from information_schema.columns where table_schema = 'public' and table_name = 'reports' and column_name = 'reporter_id'
  ) then
    alter table public.reports enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'reports' and policyname = 'rivo_reports_insert_own') then
      create policy rivo_reports_insert_own on public.reports for insert to authenticated with check (reporter_id = (select auth.uid()));
    end if;
  end if;
end;
$$;
