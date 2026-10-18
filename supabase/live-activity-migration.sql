-- FollowUp live collaboration and activity history migration
-- Run this in Supabase SQL Editor for the FollowUp project.
-- Safe to run once; uses IF NOT EXISTS / replaceable trigger and policies.

create table if not exists public.crm_activity (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  record_id uuid,
  record_key text not null,
  record_type text not null,
  action text not null check (action in ('created','updated','deleted')),
  actor_user_id uuid not null,
  before_payload jsonb,
  after_payload jsonb,
  before_owner_id uuid,
  after_owner_id uuid,
  created_at timestamptz not null default now()
);

alter table public.crm_activity add column if not exists before_owner_id uuid;
alter table public.crm_activity add column if not exists after_owner_id uuid;

create index if not exists crm_activity_team_created_idx
  on public.crm_activity(team_id, created_at desc);
create index if not exists crm_activity_team_record_idx
  on public.crm_activity(team_id, record_key, created_at desc);

alter table public.crm_activity enable row level security;

drop policy if exists crm_activity_select_team on public.crm_activity;
create policy crm_activity_select_team on public.crm_activity
  for select to authenticated
  using (
    public.is_team_member(team_id)
    and (
      public.has_team_role(team_id, array['owner','admin'])
      or (
        record_type = 'lead'
        and exists (
          select 1 from public.crm_records l
          where l.team_id = crm_activity.team_id
            and l.record_key = crm_activity.record_key
            and l.record_type = 'lead'
            and l.deleted_at is null
            and l.owner_user_id = auth.uid()
        )
      )
      or (
        record_type in ('note','task')
        and exists (
          select 1 from public.crm_records child
          join public.crm_records l
            on l.team_id = child.team_id
           and l.record_key = (child.payload->>'lead')
           and l.record_type = 'lead'
           and l.deleted_at is null
          where child.team_id = crm_activity.team_id
            and child.record_key = crm_activity.record_key
            and child.record_type = crm_activity.record_type
            and l.owner_user_id = auth.uid()
        )
      )
    )
  );

grant select on public.crm_activity to authenticated;

create or replace function public.log_crm_record_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_payload jsonb;
  new_payload jsonb;
  event_action text;
  actor uuid;
begin
  actor := coalesce(auth.uid(), new.updated_by, old.updated_by);
  if actor is null then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    event_action := 'created';
    new_payload := new.payload;
  elsif tg_op = 'UPDATE' then
    if new.payload is not distinct from old.payload
       and new.owner_user_id is not distinct from old.owner_user_id
       and new.deleted_at is not distinct from old.deleted_at then
      return new;
    end if;
    event_action := case when old.deleted_at is null and new.deleted_at is not null then 'deleted' else 'updated' end;
    old_payload := old.payload;
    new_payload := new.payload;
  else
    event_action := 'deleted';
    old_payload := old.payload;
  end if;

  insert into public.crm_activity
    (team_id, record_id, record_key, record_type, action, actor_user_id, before_payload, after_payload, before_owner_id, after_owner_id)
  values
    (coalesce(new.team_id, old.team_id),
     coalesce(new.id, old.id),
     coalesce(new.record_key, old.record_key),
     coalesce(new.record_type, old.record_type),
     event_action, actor, old_payload, new_payload, old.owner_user_id, new.owner_user_id);

  return coalesce(new, old);
end;
$$;

drop trigger if exists crm_records_activity_log on public.crm_records;
create trigger crm_records_activity_log
  after insert or update or delete on public.crm_records
  for each row execute function public.log_crm_record_activity();

do $$
begin
  alter publication supabase_realtime add table public.crm_records;
exception when duplicate_object then null;
when undefined_object then raise notice 'supabase_realtime publication not found; enable Realtime for crm_records in Supabase dashboard.';
end $$;

do $$
begin
  alter publication supabase_realtime add table public.crm_activity;
exception when duplicate_object then null;
when undefined_object then raise notice 'supabase_realtime publication not found; enable Realtime for crm_activity in Supabase dashboard.';
end $$;
