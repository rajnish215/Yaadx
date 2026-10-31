# YaadX private API and Neon sync

Flutter keeps Firebase Authentication. Only this server receives DATABASE_URL. The app sends a Firebase ID token; the server derives the UID from the verified token. The API never accepts a client-supplied owner UID. Mobile scheduling, yearly recurrence, advance alerts and day-before spoken notifications remain on-device.

## Current configuration and honest launch status

- Existing Neon URL is loaded from `/Users/ankitkumar/.config/yaadx/backend.env` by setting `YAADX_ENV_FILE` to that path. It is parsed with dotenv, never executed as shell code or printed.
- Development migration was applied to a separate **schema** `yaadx_dev` in the supplied database. A schema is NOT a Neon branch. No Neon management API credential was provided. Before production use, create a development branch in Neon Console → project → Branches → New branch and set its pooled URL and direct URL in the external environment file. No paid branch/hosting/storage was provisioned.
- No public service was deployed. The Flutter API URL is build-time configuration. Without it, the app explicitly shows device-only storage; it does not pretend cloud sync occurred.
- Private object storage is not configured in the supplied environment. Media API/Flutter upload/download integration is implemented, but real bucket transfer remains unverified until an existing private S3-compatible bucket and credentials are supplied. Reminders containing unuploaded media remain locally queued, with an explicit message; unrelated reminders can sync.
- Production Firebase revocation checks require Firebase Admin Application Default Credentials (workload identity preferred). No service-account private key is embedded. The production server uses `verifyIdToken(token, true)`; development uses standard signature/issuer/audience/expiry verification. Auth emulator mode is explicitly forbidden in production.

## Local backend

Requires Node 22+ (Node 24 tested).

```sh
cd backend
npm ci
YAADX_ENV_FILE=/Users/ankitkumar/.config/yaadx/backend.env npm run db:check
YAADX_ENV_FILE=/Users/ankitkumar/.config/yaadx/backend.env npm run migrate
YAADX_ENV_FILE=/Users/ankitkumar/.config/yaadx/backend.env npm start
```

Defaults: loopback `127.0.0.1:8080`, Firebase project `yaadx-8e018`, schema `yaadx_dev`. `/health` checks the process; `/ready` checks a database connection. Both omit credentials/details. Do not expose development HTTP to the public Internet.

The connection URL must be a postgres/postgresql URL, not a command. TLS certificates are always verified (`rejectUnauthorized: true`). Node verifies the client-to-Neon TLS socket; `pg_stat_ssl` behind a pooler can describe the pooler's downstream connection rather than this socket. Application connections use a pool (maximum 5, idle timeout 30s, connect timeout 10s, statement timeout 10s). Migrations use a direct connection; a direct Neon hostname is derived from `-pooler` only when DIRECT_DATABASE_URL is absent.

## Database and migrations

`migrations/001_initial.sql` creates:

| Table | Purpose |
| --- | --- |
| profiles | Firebase UID, token-derived display name/email, timestamps |
| preferences | Account notification preference and optimistic version |
| reminders | Composite UID/event ID, validated event JSON, optimistic version, deletion tombstone, timestamps |
| media | Owner-scoped private object key, kind, MIME type, size, verified upload state |
| mutations | Per-account operation UUID, request hash and response for safe retries |
| schema_migrations | Applied version/checksum; not accessible to API role |

Event JSON stores date/time, recurrence, advance interval, day-before voice flag, completion/checklist and private media IDs. Local paths never enter Neon. Dates/times are floating local wall-clock values, preserving existing notification behavior when timezone changes.

The migration runner uses a transaction and advisory lock, checks checksums, and refuses changed applied migrations. Re-running is safe. Migrations never drop existing application data. The API transaction switches to a dedicated `yaadx_dev_api` NOLOGIN, NOSUPERUSER, NOBYPASSRLS role. All user tables have FORCE ROW LEVEL SECURITY based on transaction-local `app.uid`, plus explicit API ownership filters. Advisory locks serialize writes for one account. Versions reject stale updates with HTTP 409. Mutations are idempotent; reusing an operation UUID with a different body fails.

Production: use a dedicated LOGIN role with only membership in the schema's API role, no schema CREATE, no table ownership, no SUPERUSER/BYPASSRLS. Keep migration credentials in a separate secret/job; set DIRECT_DATABASE_URL only there. A database administrator must provision the LOGIN password securely. The supplied development URL was not replaced and its privileges were not broadened except granting membership in the new restricted role.

## HTTP API

Every `/v1` route requires `Authorization: Bearer <Firebase ID token>`.

- `GET /v1/profile`: token-derived profile, creates/refreshes profile on access.
- `GET /v1/preferences`; `PUT /v1/preferences` with `{alertsEnabled, baseVersion}`.
- `GET /v1/reminders`: full owner snapshot including tombstones (maximum 5,000 records; explicit account_limit beyond this).
- `GET /v1/reminders/:id`: owner-only active reminder or 404.
- `PUT /v1/reminders/:id`: `{operationId, baseVersion, data}`. Version 0 creates; null data deletes with a tombstone. A tombstone cannot be resurrected; restore as a new ID.
- `POST /v1/media`: `{id,kind,contentType,byteSize}` returns a short-lived upload URL (or ready=true).
- `POST /v1/media/:id/complete`: verifies object size/type before marking ready.
- `GET /v1/media/:id`: owner-only, short-lived private download URL.

Unknown fields are rejected. JSON request limit 96 KiB; text limits and date/time validation are explicit. Maximum media item 20 MiB, 10 photos per event; no binary media in Postgres. Responses are no-store. Logs never contain tokens/URLs/bodies. The in-process per-IP limiter is 180 requests/minute; add a shared gateway limiter before horizontal scaling. Configure trusted proxy addresses explicitly at deployment; do not blindly trust client `X-Forwarded-For`.

## Flutter development / production

```sh
# Start Pixel_8 from Android Studio or your normal terminal first.
flutter run -d emulator-5554 --dart-define=YAADX_API_URL=http://10.0.2.2:8080
flutter build apk --debug --dart-define=YAADX_API_URL=http://10.0.2.2:8080
# After approved deployment to your actual HTTPS hostname:
flutter build apk --release --dart-define=YAADX_API_URL=https://YOUR_API_HOST
```

Only a public API URL is a Flutter define. HTTP is allowed only in debug builds for loopback / Android emulator's host alias. Release manifest has INTERNET permission but no cleartext exception. Use proper release signing before store/public launch; this repository's existing release signing currently uses the debug key.

`CloudApi` refreshes a token once on 401, checks the current account before and after requests, prevents authenticated redirects, uses timeouts and avoids displaying raw server errors. New cloud photos/audio are cached privately on-device for the existing File-based UI/sharing controls. Name/email changes remain in Firebase; name edits refresh the token and request profile sync.

## Existing data, offline and conflict safety

- Original `yaadx_reminders` and existing per-UID keys are retained. Pre-cloud account snapshots are retained under `*_pre_cloud_backup`. No old backup is removed by this change.
- A single versioned SharedPreferences envelope stores the device copy, server versions, outbox, media transfer mappings, preference state, and conflicts. Each edit/delete records an operation UUID before sending. If a response is lost, the same body/UUID is retried.
- Loading starts from the local copy; background sync runs on initial load, after CRUD, on resume, or explicit Retry. Existing Android alarms are rebuilt after a pull; deleted-event alarms are cancelled.
- Local data is isolated by Firebase UID. Sign-out resets the active storage scope. A request cannot reuse another user's token when the account changes.
- Concurrent changes stop with a reviewable conflict, rather than overwriting. Sync screen offers Keep this device / Use cloud version; a conflict backup remains. Keeping a locally edited remotely-deleted event creates a new ID.
- Notification preferences are account-scoped and versioned. A stale preference requires an explicit choice on the sync screen. OS notification permission is device-local.
- Sync requires the app to run/resume; it is not a background server push service. No FCM/public push deployment is included.

## Private object storage setup (required for media backup)

Use an existing private bucket. Supply S3_BUCKET, AWS_REGION, optional S3_ENDPOINT, and workload-identity or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY only to the backend. Disable public access, require HTTPS, enable encryption and versioning, and grant only object read/write/head under `yaadx/` for the app's bucket. Configure lifecycle cleanup for abandoned incomplete uploads with a retention window; never delete referenced media automatically. Signed URLs expire after 5 minutes and are not persisted in the mobile database or Postgres.

## Testing

```sh
YAADX_ENV_FILE=/Users/ankitkumar/.config/yaadx/backend.env npm test
flutter test
flutter analyze
```

Backend database tests create random `test-*` users and clean up only those rows. Auth/HTTP tests additionally require a local Firebase Auth emulator at 127.0.0.1:9099 (project demo-yaadx), API on 8081 with FIREBASE_PROJECT_ID=demo-yaadx and FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099, and `RUN_AUTH_EMULATOR_TESTS=true`. These validate Admin SDK integration in emulator mode, not production revocation/IAM configuration.

`integration_test/backend_sync_test.dart` exercises the Flutter Firebase Auth emulator → API → Neon flow, restart reload, account switch, edits/deletion and local notification scheduling. Run against an Android emulator with the above QA services:

```sh
flutter test integration_test/backend_sync_test.dart -d emulator-5554
```

It uses a named Firebase app and disposable local Auth-emulator accounts. It does not sign out the app's real Firebase account. Neon QA rows use those disposable UIDs and deletion tombstones; remove only identified test rows as a separate administrative cleanup. Do not use production users or delete all rows.

Device verification on 2026-10-21 passed using ADB reverse for ports 9099 and
8081 and `--dart-define=YAADX_TEST_HOST=127.0.0.1`. Grant notification permission
when requested. The scenario verifies storage reload, not a complete process
kill/relaunch. **Use a disposable AVD:** Flutter's integration runner uninstalls
the app during cleanup and can remove local-only data. A named Firebase app
alone does not protect device storage from that uninstall. Reinstall the normal
debug APK after testing. Real Firebase production auth, media transfers and
timed audible voice delivery need separate verification.

Native Android tests cover recurrence calculations and voice channel selection. Prefer install -r + `adb shell am instrument -w com.example.yaadx.test/androidx.test.runner.AndroidJUnitRunner`; Gradle connected tests can remove the target app during cleanup.

## Production deployment gates

No public deployment or paid provisioning has been performed. Before launch:

1. Select/approve hosting and billing. Deploy the container behind HTTPS with secret injection, health checks, autoscaling limits, a shared rate limiter and restricted network access.
2. Create separate Neon dev/prod branches and set explicit DB_SCHEMA and FIREBASE_PROJECT_ID in production. Use separate runtime/migration database credentials; migrate before rolling out the API.
3. Configure Firebase Admin ADC/workload identity and verify a real Firebase user token, expiration/revocation, and IAM permissions in staging.
4. Configure and test private object storage including upload/download/retry on two devices.
5. Run emulator integration tests and real production-auth staging smoke tests, including offline recovery and account switching. Obtain a signed release build with the deployed HTTPS URL.
6. Review observability, quota/rate limits, user data export/deletion, retention, privacy policy and disaster recovery before inviting public users.

## Backup and restore

Keep local pre-cloud backups until the owner explicitly approves removal. Use Neon restore/point-in-time recovery according to the project's configured retention (verify it in Console; do not assume a plan's retention). Maintain encrypted logical PostgreSQL backups with access-controlled retention and private object-storage versions. Never print passwords in commands/logs; use a secret-mounted pgpass file or a process environment managed by the backup job. Test restoration into a separate non-production branch, apply/check migration versions, validate row counts, ownership/RLS and media references, then rehearse an application cutover. Do not run destructive rollback/drop-schema commands on the existing database. Prefer forward corrective migrations and retain tombstones/mutation history until a documented client-retention policy exists.

References: [Firebase token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [Neon connections](https://neon.com/docs/connect/connect-from-any-app).

## Personalised wishes and gift ideas

See [AI_SUGGESTIONS.md](AI_SUGGESTIONS.md) for the optional server-side Gemini
adapter, consent flow, offline fallback, account-scoped caching and local tests.
Without GEMINI_API_KEY and GEMINI_MODEL, the app still offers clearly labelled
offline inspiration. No AI credentials are bundled in the APK.
