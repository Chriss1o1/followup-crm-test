# FollowUp CRM integration plan

## Goal
Bring the existing FollowUp CRM features into the Supabase-backed multi-workspace build, validate in `followup-crm-test`, and only then deploy the integrated build to the main `Followup-CRM` repository.

## Do not overwrite the production app prematurely
The production `Followup-CRM/index.html` is currently the localStorage-based app. The test `followup-crm-test/shared-crm.html` is Supabase-backed but currently only implements a subset of the full CRM. Keep the production app untouched until feature parity, permissions, and isolation tests pass.

## Target behavior
- Users sign up with display name and unique four-digit member code.
- Users can create independent workspaces or accept invitations to join one.
- Each workspace has isolated leads, tasks, notes, and team records.
- Owner/admin can view and manage all workspace records, invitations, and member roles, subject to protected owner rules.
- Members can view and edit only records assigned to them, plus related notes/tasks allowed by policy.
- Record ownership, creator, last editor, and timestamps are recorded so the activity trail is attributable.
- Changing the active workspace changes every list and operation to that workspace.
- No automatic import of localStorage data into cloud storage. Provide an explicit import path later if requested.

## Integration sequence
1. Inventory the original app's record schema, tabs, actions, import/export and local backup/undo behavior.
2. Extend the test schema for leads, notes, tasks, activity metadata, and assignment rules. Keep RLS enforced for every table/record.
3. Port the original app's user-facing features to Supabase-backed reads/writes, starting with lead create/view/edit/delete and assignment.
4. Port notes, tasks, follow-up suggestions, search/filter, and the other original CRM screens.
5. Port CSV/JSON import/export and backup/restore with workspace-aware validation and explicit confirmation.
6. Test with two accounts and two workspaces: cross-workspace isolation, member assignment restrictions, admin role changes, and audit fields.
7. Only after the test build passes, deploy the integrated code to the main repository.

## Safety requirements
- Never place a Supabase service-role key in browser code.
- Use the publishable key only with appropriate table grants and RLS.
- Do not trust frontend role checks alone; enforce access in database policies/functions.
- Do not copy localStorage data into Supabase automatically.
- Preserve the original production build until the test build is verified.
