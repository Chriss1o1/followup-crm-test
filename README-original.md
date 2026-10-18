# FollowUp

A free follow-up and lead manager for small teams. One HTML file. No account, no server, no subscription.

> **Status: early MVP.** The date/task/merge logic has unit tests. The UI smoke test requires the development dependency installed with `npm install`. Team sync has not yet been tested with real shared drives. Please use fake data first and keep backups.

**Try it:** open `index.html`, or host it free on GitHub Pages.

## What it does
- **Next steps on every lead.** Overdue, today and next-7-days views, for you or the whole team. Leads with no next step are flagged.
- **Notes become tasks.** Type “send quote next Tuesday and call on 3 Nov” and tap to add the suggested tasks (runs in your browser, no AI service).
- **Basic team sharing, free.** Everyone connects to the same shared folder (Google Drive, OneDrive, Dropbox, network drive). Each person writes a separate JSON file, reducing write collisions; this does not make the folder a transactional database. If two people edit the same lead at the same moment, FollowUp flags it for review instead of silently picking a winner.
- **Lead criteria.** Edit your own checklist (budget, decision-maker, need, timeline). Each lead shows a score.
- **Deals.** Stage, value and expected close, with open-deal totals.
- **Forward a lead.** One click builds a hand-off summary (details, criteria, open steps, starred conversations) to copy or email.
- **Drafts in your style.** Paste a few of your own messages; drafts copy your greeting, sign-off, length and tone. Or copy a ready-made prompt for any free AI chat.
- **Import your spreadsheet.** CSV from HubSpot, Zoho, Pipedrive, Google Contacts or a plain sheet. Full CSV and JSON export any time.

## Run it with your team (free)
1. Put `index.html` on GitHub Pages (Settings → Pages → deploy from `main`) or share the file.
2. Make a locally synced folder in your shared drive. For Google Drive, install Google Drive for desktop first; the browser folder picker selects a folder on your computer, not the Google Drive website. Everyone opens FollowUp in Chrome or Edge → Team → Connect shared folder.
3. Reconnect after a browser restart if prompted. Sync checks about every 30 seconds while the page is open; cloud-drive propagation can take longer. Test with fake data and two browser profiles before relying on it.

## Honest limits
- Folder sync needs Chrome or Edge on desktop and a locally available synced folder. Other browsers can still swap team files (Team → Export / Import).
- Anyone with access to the folder can see the leads. Access control is your drive’s sharing settings.
- Sync is not a transactional database. Concurrent edits to one record are detected and shown for you to resolve, but a drive that syncs slowly can delay when teammates see changes. See [`docs/sync-limitations.md`](docs/sync-limitations.md).
- Deleted leads can be restored from the Team tab; imports and restores can be undone once.
- Message drafts are rule-based, not AI. They are a good first line, not a finished email.

MIT license. See [`PRIVACY.md`](PRIVACY.md), [`SECURITY.md`](SECURITY.md), and [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Local tests

Install the test dependency and run the suite:

```bash
npm install
npm test
```

The UI smoke test uses jsdom; it does not replace testing shared-folder sync in two real browser profiles.
