# FollowUp — Supabase test version

This folder is an **isolated test copy** of the current FollowUp HTML app plus a proposed Supabase schema. It does not replace the live GitHub Pages site.

## Current state (important)

- `index.html` is copied from the available project snapshot and still uses localStorage/shared-folder sync.
- `supabase/schema.sql` is a first-pass database/security foundation for team invitations and assigned-lead visibility.
- The frontend is **not connected to Supabase yet**. Do not invite real users or enter customer data at this stage.
- The schema needs review and end-to-end tests before any production use. In particular, invitation acceptance/team creation should be implemented through a trusted Edge Function or owner-controlled onboarding process. Never put a service-role key in browser code.

## Your account steps

1. Open https://supabase.com/dashboard and create a new project specifically for FollowUp testing. Do not use a project that contains other data.
2. Choose a strong database password and store it privately. It is not needed in the public repository.
3. In the new project's SQL Editor, open `supabase/schema.sql`, paste the SQL, and run it. Only do this in the empty test project.
4. In Authentication settings, configure the allowed site URL and redirect URLs for your GitHub Pages test URL. During local testing, add the local test origin you actually use.
5. For the initial invitation-only pilot, keep public sign-ups disabled. An owner can invite users through Supabase Auth dashboard; membership assignment needs the planned trusted onboarding step and must not be done by exposing the service-role key.
6. Copy the Project URL and publishable/anon key only when asked to configure the browser client. The publishable key is intended for frontend use; database security must be enforced by RLS. Never share the database password or service-role/secret key.

## Planned implementation sequence

1. Add a separate Supabase client module and an invitation-only sign-in screen.
2. Add a secure onboarding mechanism to create the first team and assign its owner role.
3. Add invitation acceptance that matches the invited email to the authenticated user and creates the correct team membership.
4. Connect read/write operations to the cloud, mapping lead owners to authenticated user UUIDs.
5. Enforce assigned-lead visibility for members and all-team visibility for owners/admins through RLS.
6. Add optimistic concurrency using `version` checks, visible sync status, and error handling.
7. Test with two accounts and two teams, including attempts to access another team's IDs.
8. Only then create a pull request or publish the tested version. Keep the current live app intact until approval.

## Data migration

The initial cloud workspace should start empty, as requested. Existing local leads remain in the old version and are not uploaded automatically. A future explicit import flow should preview the records and require confirmation.

## Test version

Open `index.html` locally to inspect the copied app. This is a baseline copy only; it does not yet offer Supabase authentication or cloud syncing.
