# Implementation plan and review notes

## What the current app does

- Stores its primary state in one `localStorage` JSON object (`S`, `recs`, `conf`).
- Stores writing-style preferences and backup snapshots in separate localStorage keys.
- Persists a record immediately in `put()` and schedules shared-folder sync after 1.5 seconds.
- Uses a File System Access API directory handle stored in IndexedDB to synchronize `followup-<member>.json` files.
- Models leads, notes, tasks, member display records, config, and deleted records as typed JSON records.
- Supports CSV and JSON import/export, restore/undo, and conflict resolution for folder sync.

## Recommended architecture

- Keep GitHub Pages for the static frontend.
- Supabase Auth for invited users only.
- PostgreSQL tables for teams, memberships, invitations, and records.
- RLS for team isolation and assigned-lead visibility.
- Keep the JSON `payload` initially to minimize migration churn, then normalize later only if justified.
- Use a `version` field and conditional updates for concurrent-edit detection.
- Keep JSON/CSV export and local backup support.

## Important design issue

The current app uses a locally generated `S.me` ID and a `member` record to represent people. Supabase uses `auth.users.id` UUIDs. The integration must map local owners to authenticated users, and it must not trust an arbitrary `owner` value supplied by the browser. This requires a deliberate data-access layer; replacing only `localStorage.setItem()` would not be safe or sufficient.

## Role model

- `owner`: can manage team, memberships, invitations, and all team records.
- `admin`: can manage memberships/invitations and all team records.
- `member`: can read/update only leads assigned to their auth user ID, plus notes/tasks attached to those leads.

## Not yet complete

- No Supabase client integration in the HTML.
- No invitation acceptance Edge Function.
- No initial-team bootstrap flow.
- No live cross-account tests or RLS penetration tests.
- No migration utility, by design: first cloud workspace starts empty.
