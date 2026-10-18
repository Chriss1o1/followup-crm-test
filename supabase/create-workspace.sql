-- FollowUp test: secure self-service workspace creation.
-- Run this in the SAME Supabase test project's SQL Editor after schema.sql.
-- Any authenticated user may create a workspace they own; they cannot choose another user or role.

create or replace function public.create_workspace(workspace_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_team_id uuid;
  clean_name text;
  caller_id uuid;
begin
  caller_id := auth.uid();
  if caller_id is null then
    raise exception 'You must be signed in to create a workspace';
  end if;

  clean_name := trim(workspace_name);
  if clean_name is null or char_length(clean_name) < 1 or char_length(clean_name) > 100 then
    raise exception 'Workspace name must be between 1 and 100 characters';
  end if;

  insert into public.teams (name, created_by)
  values (clean_name, caller_id)
  returning id into new_team_id;

  insert into public.team_members (team_id, user_id, role)
  values (new_team_id, caller_id, 'owner');

  return new_team_id;
end;
$$;

revoke all on function public.create_workspace(text) from public, anon;
grant execute on function public.create_workspace(text) to authenticated;
