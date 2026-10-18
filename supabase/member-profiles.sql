-- FollowUp test build: member display names and unique four-digit member codes.
-- Run in the TEST Supabase project's SQL Editor. This does not touch the original CRM.

create table if not exists public.member_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 100),
  member_code text not null unique check (member_code ~ '^[0-9]{4}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.member_profiles enable row level security;
revoke all on public.member_profiles from anon, authenticated;
grant select, insert, update on public.member_profiles to authenticated;

-- Create a globally unique four-digit code, retrying if a random code is already used.
create or replace function public.generate_member_code()
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  candidate text;
begin
  loop
    candidate := (1000 + floor(random() * 9000)::int)::text;
    if not exists (select 1 from public.member_profiles p where p.member_code = candidate) then
      return candidate;
    end if;
  end loop;
end;
$function$;
revoke all on function public.generate_member_code() from public, anon, authenticated;

create or replace function public.handle_new_followup_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requested_name text;
begin
  requested_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if char_length(requested_name) < 2 then
    requested_name := split_part(coalesce(new.email, 'FollowUp member'), '@', 1);
  end if;
  if char_length(requested_name) > 100 then
    requested_name := left(requested_name, 100);
  end if;

  insert into public.member_profiles(user_id, display_name, member_code)
  values (new.id, requested_name, public.generate_member_code())
  on conflict (user_id) do nothing;
  return new;
end;
$function$;
revoke all on function public.handle_new_followup_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_followup_profile on auth.users;
create trigger on_auth_user_created_followup_profile
after insert on auth.users
for each row execute function public.handle_new_followup_user();

-- Backfill existing test users. They can edit the fallback name in their profile section.
do $function$
declare
  u record;
  candidate text;
begin
  for u in
    select au.id, au.email, au.raw_user_meta_data
    from auth.users au
    left join public.member_profiles mp on mp.user_id = au.id
    where mp.user_id is null
  loop
    candidate := trim(coalesce(u.raw_user_meta_data ->> 'display_name', split_part(coalesce(u.email, 'FollowUp member'), '@', 1)));
    if char_length(candidate) < 2 then candidate := 'FollowUp member'; end if;
    candidate := left(candidate, 100);
    insert into public.member_profiles(user_id, display_name, member_code)
    values (u.id, candidate, public.generate_member_code())
    on conflict (user_id) do nothing;
  end loop;
end;
$function$;

drop policy if exists member_profiles_select_self on public.member_profiles;
create policy member_profiles_select_self on public.member_profiles
for select to authenticated using (user_id = auth.uid());

drop policy if exists member_profiles_insert_self on public.member_profiles;
create policy member_profiles_insert_self on public.member_profiles
for insert to authenticated with check (user_id = auth.uid());

drop policy if exists member_profiles_update_self on public.member_profiles;
create policy member_profiles_update_self on public.member_profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.update_my_member_profile(new_display_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  cleaned_name text := trim(coalesce(new_display_name, ''));
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if char_length(cleaned_name) < 2 or char_length(cleaned_name) > 100 then
    raise exception 'Name must be between 2 and 100 characters';
  end if;
  update public.member_profiles
  set display_name = cleaned_name, updated_at = now()
  where user_id = auth.uid();
  if not found then raise exception 'Member profile not found'; end if;
end;
$function$;
revoke all on function public.update_my_member_profile(text) from public, anon;
grant execute on function public.update_my_member_profile(text) to authenticated;

create or replace function public.list_workspace_members(target_team_id uuid)
returns table(user_id uuid, role text, joined_at timestamptz, display_name text, member_code text)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if not public.is_team_member(target_team_id) then raise exception 'You are not a member of this workspace'; end if;

  return query
  select tm.user_id, tm.role, tm.joined_at, mp.display_name, mp.member_code
  from public.team_members tm
  join public.member_profiles mp on mp.user_id = tm.user_id
  where tm.team_id = target_team_id
  order by tm.joined_at asc;
end;
$function$;
revoke all on function public.list_workspace_members(uuid) from public, anon;
grant execute on function public.list_workspace_members(uuid) to authenticated;
