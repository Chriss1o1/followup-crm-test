-- FollowUp test build: secure team-role management
-- Run this in the Supabase SQL Editor for the TEST project only.
create or replace function public.change_team_member_role(
  target_team_id uuid,
  target_user_id uuid,
  new_role text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role text;
  target_role text;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  if new_role not in ('admin', 'member') then
    raise exception 'Role must be admin or member';
  end if;

  select tm.role into actor_role
  from public.team_members tm
  where tm.team_id = target_team_id and tm.user_id = auth.uid();

  if actor_role is null or actor_role not in ('owner', 'admin') then
    raise exception 'Only the workspace owner or an admin can change member roles';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot change your own role';
  end if;

  select tm.role into target_role
  from public.team_members tm
  where tm.team_id = target_team_id and tm.user_id = target_user_id
  for update;

  if target_role is null then
    raise exception 'Team member not found';
  end if;

  if target_role = 'owner' then
    raise exception 'The workspace owner role cannot be changed here';
  end if;

  if actor_role = 'admin' and target_role <> 'member' then
    raise exception 'Admins can change member roles, but only the owner can change admin roles';
  end if;

  update public.team_members
  set role = new_role
  where team_id = target_team_id and user_id = target_user_id;
end;
$function$;

revoke all on function public.change_team_member_role(uuid, uuid, text) from public, anon;
grant execute on function public.change_team_member_role(uuid, uuid, text) to authenticated;
