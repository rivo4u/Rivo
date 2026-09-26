create or replace function public.rivo_create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;

  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_trigger as auth_trigger
    join pg_proc as trigger_function
      on trigger_function.oid = auth_trigger.tgfoid
    join pg_namespace as function_schema
      on function_schema.oid = trigger_function.pronamespace
    where auth_trigger.tgrelid = 'auth.users'::regclass
      and not auth_trigger.tgisinternal
      and (auth_trigger.tgtype & 4) = 4
      and (
        auth_trigger.tgname = 'rivo_create_profile_after_auth_user'
        or (
          function_schema.nspname = 'public'
          and trigger_function.proname in (
            'handle_new_user',
            'rivo_create_profile_for_auth_user'
          )
        )
      )
  ) then
    create trigger rivo_create_profile_after_auth_user
      after insert on auth.users
      for each row execute function public.rivo_create_profile_for_auth_user();
  end if;
end;
$$;

insert into public.profiles (id)
select users.id
from auth.users as users
on conflict (id) do nothing;