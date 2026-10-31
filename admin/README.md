# YaadX Admin website

Separate React website for the YaadX Flutter app. It uses the existing Node API, Neon database, and Firebase Authentication. No deployment is needed for local development.

## Run locally

Terminal 1 (backend):

```sh
cd /Users/ankitkumar/Documents/projects/YAADX/Yaadx/backend
YAADX_ENV_FILE=/Users/ankitkumar/.config/yaadx/backend.env npm start
```

Terminal 2 (website):

```sh
cd /Users/ankitkumar/Documents/projects/YAADX/Yaadx/admin
npm install
npm run dev
```

Open http://127.0.0.1:5174. Port 5174 proxies authenticated `/v1` requests to the backend on port 8080. Both servers bind to this laptop only. The production bundle can be checked with `npm run build` and `npm run preview` (the API still needs to run). Do not expose a Vite development/preview server publicly.

Sign in with the fixed admin account `ankitkr7488.01@gmail.com` and its existing Firebase password. There is no email editor, signup or email-verification step in the admin website. The backend checks the signed Firebase ID token and exact `ADMIN_EMAILS` allowlist match. Email-verification gating was removed at the owner's explicit request. Passwords remain managed by Firebase and are never hardcoded in browser code. Password changes to this Firebase account also affect mobile app login.

The admin session lasts for the browser tab/session. Logout clears displayed state. No admin password or server key is stored in this repository.

## Connected features

- Dashboard: real cloud-synced users, reminders, monthly registrations, plan counts, support status, AI usage and recent app activity and admin actions; refreshes every 30 seconds while visible.
- User Management: search, status filters, profile details, paginated reminders, media counts and cloud access suspension/reactivation with a reason. Suspension does not delete local app data or revoke Firebase authentication.
- Subscription Management: versioned **manual plan records**, expiry, active/expired/expiring filters and notes. No payment collection or premium feature gating is implied.
- Notification Management / Send Announcement: editable drafts, search, pagination, explicit publication, withdrawal, and recorded reads. This is an **in-app inbox**, not remote push notification delivery.
- Support & Feedback: searchable user tickets, conversation history, follow-up replies and status. Replies appear in the mobile app inbox.
- Analytics & Reports: actual counts/charts and CSV download. No invented revenue or delivery statistics.
- Settings & Security: support contact, inbox notice, integration configuration and access status. Admin allowlist stays server-managed.
- View App Logs: actual registration/reminder/support activity and admin audit actions, excluding secret credentials and raw server logs.
- Backup Data: JSON **application export**, not a disaster-recovery database backup. Excludes media binaries, Firebase credentials and database roles; rejects tables exceeding 10,000 records. Version 2 exports include a SHA-256 checksum, export history and a local integrity checker. The checker does not upload or restore files.

Upcoming events are calculated across synced reminders, including yearly recurrence. Admin lists are paginated; app inbox/tickets show the latest 50. Test accounts with reserved `@example.test` addresses are excluded by default; the explicit Include test accounts switch allows inspection without deleting data. AI usage starts at this update. The dashboard's last sync date is a profile sync timestamp, not a live presence indicator.

## Mobile connection

Run Flutter with the existing API define:

```sh
flutter run -d emulator-5554 --dart-define=YAADX_API_URL=http://10.0.2.2:8080
```

Open Notifications → announcements icon for Updates, Support and Plan tabs, or Profile → Help & Support → Support inbox. Inbox refreshes when opened/resumed, every 30 seconds while active, and via pull-to-refresh. Account changes discard in-flight responses. Failed support sends preserve text and retry the same operation ID.

## Database and verification

`002_admin.sql`, `003_admin_workflows.sql` and `004_review_fixes.sql` are additive migrations with separate restricted admin/API database roles and forced row-level security. They have been applied to the configured development schema. For a new environment:

```sh
YAADX_ENV_FILE=/path/to/backend.env npm --prefix backend run migrate
```

Run from the repository root:

```sh
npm --prefix admin test
npm --prefix admin run build
flutter test test/community_test.dart
```

Admin integration tests only run with an explicitly isolated schema whose name begins `yaadx_admin_check_`. Apply all migrations to that schema before running the backend tests; never point fixture tests at production. The tests use injected identities for route/database checks; Firebase's real verifier has a separate forged-token check and an optional Auth emulator suite.

No app uninstall, emulator data reset, paid service activation, or public deployment is part of these checks.

Migration 004 preserves pre-thread support replies and corrects yearly event start dates. Status-only support updates preserve the existing reply. Apply all migrations before starting the updated backend.
