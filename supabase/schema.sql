-- FollowUp Supabase test schema
-- Run only in a NEW, empty Supabase test project. Do not run against a production database.
-- This schema is a security foundation; the existing HTML app is not yet connected to it.

create extension if not exists pgcrypto;

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- Invitations are created by a trusted admin workflow (e.g. Supabase dashboard initially).
-- Never expose service-role credentials in the browser to create invitations.
create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  email text not null check (char_length(trim(email)) between 3 and 320),
  role text not null default 'member' check (role in ('admin', 'member')),
  invited_by uuid not null references auth.users(id) on delete restrict,
  accepted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  unique (team_id, email)
);

-- One row per FollowUp record. JSONB preserves the existing record shape during migration.
-- owner_user_id is the authenticated user's UUID for lead assignment; records without an
-- assignee (e.g. team config) may use NULL and are visible to elevated roles only.
create table if not exists public.crm_records (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  record_key text not null,
  record_type text not null check (record_type in ('lead', 'note', 'task', 'member', 'cfg')),
  owner_user_id uuid references auth.users(id) on delete set null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  updated_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (team_id, record_key)
);

create index if not exists crm_records_team_type_idx on public.crm_records(team_id, record_type) where deleted_at is null;
create index if not exists crm_records_team_owner_idx on public.crm_records(team_id, owner_user_id) where deleted_at is null;
create index if not exists team_members_user_idx on public.team_members(user_id, team_id);

create or replace function public.is_team_member(target_team uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.team_members tm where tm.team_id = target_team and tm.user_id = auth.uid()) $$;

create or replace function public.has_team_role(target_team uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.team_members tm where tm.team_id = target_team and tm.user_id = auth.uid() and tm.role = any(allowed_roles)) $$;

create or replace function public.can_read_record(target_team uuid, target_type text, target_owner uuid, target_payload jsonb)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.is_team_member(target_team) and (
    public.has_team_role(target_team, array['owner','admin'])
    or (target_type = 'lead' and target_owner = auth.uid())
    or (target_type in ('task','note') and exists (
      select 1 from public.crm_records l
      where l.team_id = target_team
        and l.record_key = (target_payload->>'lead')
        and l.record_type = 'lead'
        and l.deleted_at is null
        and l.owner_user_id = auth.uid()
    ))
  )
$$;

create or replace function public.guard_crm_record_update()
returns trigger language plpgsql security invoker set search_path = public
as $$
begin
  if new.team_id <> old.team_id or new.record_key <> old.record_key or new.record_type <> old.record_type or new.created_by <> old.created_by then
    raise exception 'team_id, record_key, record_type and created_by are immutable';
  end if;
  if new.updated_by <> auth.uid() then
    raise exception 'updated_by must match the authenticated user';
  end if;
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

drop trigger if exists crm_records_guard_update on public.crm_records;
create trigger crm_records_guard_update before update on public.crm_records
for each row execute function public.guard_crm_record_update();

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invitations enable row level security;
alter table public.crm_records enable row level security;

-- Teams are visible only to members. Team creation is intentionally handled by a trusted
-- onboarding flow, not by unrestricted browser inserts.
drop policy if exists teams_select_member on public.teams;
create policy teams_select_member on public.teams for select to authenticated using (public.is_team_member(id));

-- Members can see their own membership row and elevated users can manage membership.
drop policy if exists members_select_self_or_admin on public.team_members;
create policy members_select_self_or_admin on public.team_members for select to authenticated
using (user_id = auth.uid() or public.has_team_role(team_id, array['owner','admin']));
drop policy if exists members_insert_admin on public.team_members;
create policy members_insert_admin on public.team_members for insert to authenticated
with check (public.has_team_role(team_id, array['owner','admin']));
drop policy if exists members_update_admin on public.team_members;
create policy members_update_admin on public.team_members for update to authenticated
using (public.has_team_role(team_id, array['owner','admin']))
with check (public.has_team_role(team_id, array['owner','admin']));
drop policy if exists members_delete_admin on public.team_members;
create policy members_delete_admin on public.team_members for delete to authenticated
using (public.has_team_role(team_id, array['owner','admin']) and user_id <> auth.uid());

-- Invitation metadata is restricted to team owners/admins.
drop policy if exists invitations_admin_all on public.team_invitations;
create policy invitations_admin_all on public.team_invitations for all to authenticated
using (public.has_team_role(team_id, array['owner','admin']))
with check (public.has_team_role(team_id, array['owner','admin']));

-- Members only read assigned leads; owners/admins read all team records.
-- Notes/tasks are scoped through their parent lead. Only elevated roles can read config/member rows.
drop policy if exists records_select_assigned_or_admin on public.crm_records;
create policy records_select_assigned_or_admin on public.crm_records for select to authenticated
using (deleted_at is null and public.can_read_record(team_id, record_type, owner_user_id, payload));

-- Members may insert leads assigned to themselves, and notes/tasks only for leads they can access.
-- Admins/owners may insert any team record. App code must set created_by/updated_by to auth.uid().
drop policy if exists records_insert_assigned_or_admin on public.crm_records;
create policy records_insert_assigned_or_admin on public.crm_records for insert to authenticated
with check (
  created_by = auth.uid() and updated_by = auth.uid() and
  public.is_team_member(team_id) and (
    public.has_team_role(team_id, array['owner','admin']) or
    (record_type = 'lead' and owner_user_id = auth.uid()) or
    (record_type in ('note','task') and exists (
      select 1 from public.crm_records l
      where l.team_id = crm_records.team_id and l.record_key = (crm_records.payload->>'lead')
        and l.record_type = 'lead' and l.deleted_at is null and l.owner_user_id = auth.uid()
    ))
  )
);

drop policy if exists records_update_assigned_or_admin on public.crm_records;
create policy records_update_assigned_or_admin on public.crm_records for update to authenticated
using (public.can_read_record(team_id, record_type, owner_user_id, payload))
with check (
  updated_by = auth.uid() and
  public.can_read_record(team_id, record_type, owner_user_id, payload)
);

drop policy if exists records_delete_admin on public.crm_records;
create policy records_delete_admin on public.crm_records for delete to authenticated
using (public.has_team_role(team_id, array['owner','admin']));

-- This first-stage policy foundation intentionally does not let regular members promote
-- themselves, invite users, create teams, or read unassigned leads. Invitation acceptance
-- and initial team creation need a trusted Edge Function or owner-run onboarding procedure.
