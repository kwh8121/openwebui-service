# Production Deployment Guide - `v0.11.1-kwh.2`

## Release Identity

| Item                   | Value                                                                     |
| ---------------------- | ------------------------------------------------------------------------- |
| Final tag              | `v0.11.1-kwh.2`                                                           |
| Main SHA               | `3540e976cf2bcbbf2c806573287628edf8bf486f`                                |
| Image                  | `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.2`                         |
| OCI index digest       | `sha256:cbd58005ffd70c874826c60530cb56df57bac515b5dcdbb389838e4b828a8447` |
| Linux AMD64 digest     | `sha256:88753e4dcc4f6cea6e4bb3840ec71ff2c45d7404f9807404107c77c86e2fcdf2` |
| Short-SHA parity tag   | `ghcr.io/kwh8121/openwebui-service:git-3540e97`                           |
| Build run              | https://github.com/kwh8121/openwebui-service/actions/runs/33165866491     |
| Current rollback image | `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.1`                         |

Only the final immutable `v0.11.1-kwh.2` tag is a valid deployment target.

## Incident And Fix

The `v0.11.1-kwh.1` upgrade completed its migrations and Open WebUI became healthy, but
Google OAuth login failed after successful token exchange with:

```text
Python int too large to convert to SQLite INTEGER
```

Google subject identifiers can contain 21 decimal digits. The SQLite compatibility query
unconditionally converted every decimal subject to an integer for legacy numeric JSON
matching. Values above signed 64-bit range failed before the query executed.

The hotfix preserves string matching for all subjects and adds the legacy numeric fallback
only when the value is at most `2^63 - 1`.

The deployment workflow also adds a required `check_pipelines` boolean input. Pipelines has
been stopped since before the original release and the maintainer chose to leave it stopped.
This hotfix must be dispatched with `check_pipelines=false`, which records the check as
skipped instead of reporting an unrelated Open WebUI health failure.

## Validation Evidence

- PR #26 Frontend Format & Build and Unit Tests passed.
- PR #26 Ruff checks passed on Python 3.11 and 3.12.
- RC `v0.11.1-kwh.2-rc.1` build run `33165103202` passed.
- The unmodified RC image handled an oversized synthetic OAuth subject without overflow.
- The RC image resolved an existing production-derived OAuth subject to its user.
- Final image build run `33165866491` passed.
- Final and `git-3540e97` tags resolve to the same OCI index digest.
- The unmodified final image passed both oversized and existing OAuth subject lookups.

## Database State

No new migration is included. Production is already at Alembic revision
`d4c1a8e37b62` with SQLite integrity `ok` after the `v0.11.1-kwh.1` deployment.

The workflow must still create and verify a new WAL-safe backup before replacing the
container. Do not restore the earlier pre-upgrade backup for this hotfix.

## Deployment Inputs

Use the GitHub workflow `Deploy approved production release` with:

- `tag`: `v0.11.1-kwh.2`
- `issue_number`: the hotfix production deployment request Issue
- `guide_commit`: the full commit containing this guide
- `check_pipelines`: `false`

The `check_pipelines=false` choice is authorized only because the maintainer explicitly
decided to keep the pre-existing Pipelines container stopped.

## Expected Automated Sequence

1. Verify tag, lineage, guide, paths, and current database.
2. Capture `v0.11.1-kwh.1` as the immediate rollback image.
3. Pull and pin the `v0.11.1-kwh.2` digest before downtime.
4. Stop only Open WebUI and create a new verified backup.
5. Recreate only Open WebUI with `--no-deps`.
6. Verify health, version, manifest, container state, and startup logs.
7. Record Pipelines as intentionally skipped.

## Required Technical Results

- Running image is `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.2`.
- Running digest is `sha256:cbd58005ffd70c874826c60530cb56df57bac515b5dcdbb389838e4b828a8447`.
- Container is healthy.
- `/health` returns HTTP 200.
- `/_app/version.json` reports `3540e976cf2bcbbf2c806573287628edf8bf486f`.
- `/manifest.json` reports `Koreatimes` for `name` and `short_name`.
- Alembic remains at `d4c1a8e37b62` and SQLite integrity remains `ok`.
- Logs contain no migration or startup failure.
- `WEBUI_SECRET_KEY` is loaded from the persistent env and is not regenerated.

## Browser Acceptance

Immediately after technical success:

1. Complete a Google OAuth login using an existing account.
2. Refresh and confirm that the session persists.
3. Open Google Drive Picker and attach one file.
4. Confirm existing chats and settings remain available.

Keep the deployment Issue open if OAuth still fails. Do not automatically restore data or
rewrite the immutable tag.

## Failure Policy

- Failure before the new container starts: restart `v0.11.1-kwh.1`.
- Failure after the new container starts: preserve the container, logs, current database,
  and new backup while awaiting an explicit incident decision.
- This hotfix has no schema change, but automatic rollback remains disabled by policy.
