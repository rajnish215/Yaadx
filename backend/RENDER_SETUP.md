# Render deployment handoff

Status: configuration prepared locally; no Render service created. The accessible
Render browser session currently shows the login screen. This is not a deployed
or verified public API.

## Prepared configuration

The root `render.yaml` selects one Free Docker web service, Singapore region,
`/ready` health check, and manual deployments. It creates no additional database,
disk, storage bucket or paid service. The existing Docker image runs as a
non-root user. Secrets are requested separately rather than committed.

Render Free sleeps when idle; initial requests may fail or take longer while it
wakes. The app preserves its pending operations for retry. This tier is for
evaluation, not an assurance of production availability.

## Account and secret setup

1. Sign in at https://dashboard.render.com/ using your own account. If signing up,
   review its terms yourself. Authorize access only to the Yaadx repository.
2. Review and push the backend changes and root `render.yaml` to that repository.
   Local uncommitted files cannot be deployed from GitHub.
3. Create a Blueprint from that repository. Confirm the displayed service uses
   **Free** before creating it. No payment-plan upgrade is required by this file.
4. Set `DB_SCHEMA` to the schema you have migrated. `yaadx_dev` is the existing
   development schema; do not label it as an isolated production branch.
5. Set `DATABASE_URL` privately in Render to a pooled Neon connection using a
   dedicated runtime LOGIN role with membership only in the corresponding
   `<schema>_api` role. Keep migration/admin credentials off the hosted service.
   Provision that login through your database administrator before deployment.
6. In Firebase project `yaadx-8e018`, obtain server-side Admin credentials with
   the required Firebase Authentication permissions. Prefer workload identity
   where supported. For a key-based deployment, store the downloaded JSON only
   as Render Secret File named `firebase-admin.json`. The configured path is
   `/etc/secrets/firebase-admin.json`. Never commit it or paste it in chat.
7. Run the versioned migrations separately from a trusted machine using direct
   database/admin credentials. Do not run migrations on every API startup and do
   not add admin credentials to the runtime service.
8. Deploy manually after those prerequisites are ready.

## Media is a separate prerequisite

The current storage adapter requires a private S3-compatible bucket. Render's
local filesystem is not persistent media storage. Configure `S3_BUCKET`,
`AWS_REGION`, optional `S3_ENDPOINT`, and scoped server-side credentials only
after selecting/provisioning a bucket. No bucket is created by the Blueprint.
Without storage, text-only events can sync; events with new local media remain
queued safely. Do not claim full media backup until real transfers are tested.

## Verification before distributing an APK

- Check the actual Render URL's `/health` and `/ready` return success.
- Confirm unauthenticated `/v1/reminders` returns 401.
- Test a real Firebase account and a second account for isolation, then CRUD,
  restart, offline retry and cross-device synchronization.
- Test private photo/audio upload and download with the configured bucket.
- Build using the actual HTTPS API URL as `YAADX_API_URL`.
- Configure release signing before distributing a release build.
- Run the deferred Android integration test.

The existing development APK targets a laptop backend and will not automatically
switch to Render. A new build is required after the URL is known.

References:
- https://render.com/docs/blueprint-spec
- https://render.com/docs/configure-environment-variables
- https://render.com/docs/free
- https://firebase.google.com/docs/admin/setup
