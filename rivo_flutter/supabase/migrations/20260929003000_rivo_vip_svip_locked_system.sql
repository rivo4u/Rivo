create extension if not exists pg_cron;
create schema if not exists private;

create table if not exists public.vip_reward_config (
  vip_level integer primary key check (vip_level between 1 and 10),
  daily_reward_coins bigint not null check (daily_reward_coins > 0),
  reward_time text not null default '21:00 Asia/Karachi',
  active boolean not null default true
);

insert into public.vip_reward_config(vip_level,daily_reward_coins,reward_time,active) values
(1,3000,'21:00 Asia/Karachi',true),(2,15000,'21:00 Asia/Karachi',true),
(3,75000,'21:00 Asia/Karachi',true),(4,150000,'21:00 Asia/Karachi',true),
(5,300000,'21:00 Asia/Karachi',true),(6,600000,'21:00 Asia/Karachi',true),
(7,1200000,'21:00 Asia/Karachi',true),(8,2400000,'21:00 Asia/Karachi',true),
(9,4800000,'21:00 Asia/Karachi',true),(10,9600000,'21:00 Asia/Karachi',true)
on conflict (vip_level) do update set daily_reward_coins=excluded.daily_reward_coins,
reward_time=excluded.reward_time,active=true;

create table if not exists public.svip_reward_config (
  svip_level integer primary key check (svip_level between 1 and 8),
  required_recharge_usd numeric(14,2) not null check (required_recharge_usd > 0),
  weekly_friday_reward_coins bigint not null default 0 check (weekly_friday_reward_coins >= 0),
  anti_kick boolean not null default false,
  active boolean not null default true
);

insert into public.svip_reward_config values
(1,50,0,false,true),(2,500,0,false,true),(3,2000,0,false,true),(4,4500,0,false,true),
(5,10000,50000000,true,true),(6,20000,100000000,true,true),
(7,50000,300000000,true,true),(8,100000,600000000,true,true)
on conflict (svip_level) do update set required_recharge_usd=excluded.required_recharge_usd,
weekly_friday_reward_coins=excluded.weekly_friday_reward_coins,
anti_kick=excluded.anti_kick,active=true;

create table if not exists public.vip_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  cycle_started_at timestamptz,
  cycle_ends_at timestamptz,
  cycle_recharge_usd numeric(14,2) not null default 0,
  last_vip_reward_date date,
  last_svip_friday_reward_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.vip_recharge_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount_usd numeric(14,2) not null check (amount_usd > 0),
  source text not null,
  reference_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.vip_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_kind text not null check (reward_kind in ('vip_daily','svip_friday')),
  reward_level integer not null,
  reward_coins bigint not null check (reward_coins > 0),
  reward_date date not null,
  created_at timestamptz not null default now(),
  unique(user_id,reward_kind,reward_date)
);

alter table public.vip_reward_config enable row level security;
alter table public.svip_reward_config enable row level security;
alter table public.vip_accounts enable row level security;
alter table public.vip_recharge_events enable row level security;
alter table public.vip_reward_claims enable row level security;

drop policy if exists "vip reward config read" on public.vip_reward_config;
create policy "vip reward config read" on public.vip_reward_config for select to authenticated using (true);
drop policy if exists "svip reward config read" on public.svip_reward_config;
create policy "svip reward config read" on public.svip_reward_config for select to authenticated using (true);
drop policy if exists "vip accounts own read" on public.vip_accounts;
create policy "vip accounts own read" on public.vip_accounts for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "vip recharge events own read" on public.vip_recharge_events;
create policy "vip recharge events own read" on public.vip_recharge_events for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "vip reward claims own read" on public.vip_reward_claims;
create policy "vip reward claims own read" on public.vip_reward_claims for select to authenticated using ((select auth.uid()) = user_id);

revoke all on public.vip_recharge_events from anon, authenticated;
revoke insert, update, delete on public.vip_accounts from anon, authenticated;
revoke insert, update, delete on public.vip_reward_claims from anon, authenticated;

create or replace function private.apply_vip_recharge(
  p_user_id uuid,p_amount_usd numeric,p_source text,p_reference_id uuid default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_total numeric(14,2); v_started timestamptz; v_ends timestamptz; v_svip integer:=0;
begin
  if p_amount_usd <= 0 then raise exception 'Recharge amount must be positive'; end if;
  insert into public.vip_recharge_events(user_id,amount_usd,source,reference_id)
  values(p_user_id,p_amount_usd,p_source,p_reference_id);
  select cycle_started_at,cycle_ends_at,cycle_recharge_usd into v_started,v_ends,v_total
  from public.vip_accounts where user_id=p_user_id for update;
  if v_started is null or v_ends is null or v_ends <= now() then
    v_started:=now(); v_ends:=now()+interval '90 days'; v_total:=p_amount_usd;
    insert into public.vip_accounts(user_id,cycle_started_at,cycle_ends_at,cycle_recharge_usd,updated_at)
    values(p_user_id,v_started,v_ends,v_total,now())
    on conflict(user_id) do update set cycle_started_at=excluded.cycle_started_at,
    cycle_ends_at=excluded.cycle_ends_at,cycle_recharge_usd=excluded.cycle_recharge_usd,
    last_vip_reward_date=null,last_svip_friday_reward_date=null,updated_at=now();
  else
    v_total:=v_total+p_amount_usd;
    update public.vip_accounts set cycle_recharge_usd=v_total,updated_at=now() where user_id=p_user_id;
  end if;
  select coalesce(max(svip_level),0) into v_svip from public.svip_reward_config
  where active=true and required_recharge_usd <= v_total;
  update public.profiles set svip_level=v_svip,updated_at=now() where id=p_user_id;
  return jsonb_build_object('svip_level',v_svip,'cycle_recharge_usd',v_total,
    'cycle_started_at',v_started,'cycle_ends_at',v_ends);
end $$;

create or replace function private.grant_vip_scheduled_rewards()
returns void language plpgsql security definer set search_path='' as $$
declare
  r record; v_reward bigint;
  v_today date := (now() at time zone 'Asia/Karachi')::date;
  v_dow integer := extract(dow from (now() at time zone 'Asia/Karachi'));
begin
  for r in
    select a.user_id,p.vip_level,p.svip_level
    from public.vip_accounts a join public.profiles p on p.id=a.user_id
    where a.cycle_ends_at>now() and (p.vip_level>0 or p.svip_level>0)
  loop
    if r.vip_level>0 then
      select daily_reward_coins into v_reward from public.vip_reward_config
      where vip_level=r.vip_level and active=true;
      if v_reward is not null then
        insert into public.vip_reward_claims(user_id,reward_kind,reward_level,reward_coins,reward_date)
        values(r.user_id,'vip_daily',r.vip_level,v_reward,v_today)
        on conflict(user_id,reward_kind,reward_date) do nothing;
        if found then
          update public.profiles set coins=coins+v_reward,updated_at=now() where id=r.user_id;
          insert into public.coin_transactions(user_id,amount,type,description)
          values(r.user_id,v_reward,'vip_daily_reward','VIP '||r.vip_level||' daily reward');
        end if;
      end if;
    end if;
    if v_dow=5 and r.svip_level>=5 then
      select weekly_friday_reward_coins into v_reward from public.svip_reward_config
      where svip_level=r.svip_level and active=true;
      if coalesce(v_reward,0)>0 then
        insert into public.vip_reward_claims(user_id,reward_kind,reward_level,reward_coins,reward_date)
        values(r.user_id,'svip_friday',r.svip_level,v_reward,v_today)
        on conflict(user_id,reward_kind,reward_date) do nothing;
        if found then
          update public.profiles set coins=coins+v_reward,updated_at=now() where id=r.user_id;
          insert into public.coin_transactions(user_id,amount,type,description)
          values(r.user_id,v_reward,'svip_friday_reward','SVIP '||r.svip_level||' Friday reward');
        end if;
      end if;
    end if;
  end loop;
end $$;

revoke all on function private.apply_vip_recharge(uuid,numeric,text,uuid) from public,anon,authenticated;
revoke all on function private.grant_vip_scheduled_rewards() from public,anon,authenticated;

create or replace function private.kick_room_member(p_room_id uuid,p_user_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.require_room_owner(p_room_id);
  if p_user_id=(select owner_id from public.rooms where id=p_room_id) then raise exception 'cannot_kick_owner'; end if;
  if coalesce((select svip_level from public.profiles where id=p_user_id),0)>=5 then
    raise exception 'svip_protected_cannot_kick';
  end if;
  delete from public.mic_seats where room_id=p_room_id and user_id=p_user_id;
  delete from public.room_members where room_id=p_room_id and user_id=p_user_id;
  return jsonb_build_object('success',true,'user_id',p_user_id);
end $$;

do $$ begin perform cron.unschedule('rivo-vip-daily-rewards'); exception when others then null; end $$;
select cron.schedule('rivo-vip-daily-rewards','0 16 * * *','select private.grant_vip_scheduled_rewards()');
