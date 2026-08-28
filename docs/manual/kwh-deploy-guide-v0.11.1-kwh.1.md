# Production Deployment Guide - `v0.11.1-kwh.1`

## 1. Release Identity

| Item                 | Value                                                                     |
| -------------------- | ------------------------------------------------------------------------- |
| Final tag            | `v0.11.1-kwh.1`                                                           |
| Main SHA             | `75311d2ac64d670b7cceaad5ecd05c5cf5a034bd`                                |
| Image                | `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.1`                         |
| OCI index digest     | `sha256:8cce5ff469e71f86fb029d69ddfff5951e3b61b04385419bb788171a606631c0` |
| Linux AMD64 digest   | `sha256:5cf1a764a605bf5ee415e77c301a6543bae9d186524fc15b6e8732100798697b` |
| Short-SHA parity tag | `ghcr.io/kwh8121/openwebui-service:git-75311d2`                           |
| Build run            | https://github.com/kwh8121/openwebui-service/actions/runs/33162328125     |
| Upstream release     | Open WebUI `v0.11.1`, commit `d3e8bf3405e848cfba377814d0aa7ba7290e414d`   |
| Rollback tag         | `v0.11.0-kwh.1`                                                           |
| Rollback digest      | `sha256:1b1173f32c96667782360e1c986d5c5406ee3d00cf1afc314cd73b9c1b0c1b76` |

Only the final immutable kwh tag is a valid production target. Do not deploy the RC,
`main`, `latest`, or the upstream-style `v0.11.1` tag.

## 2. Scope

This release upgrades the fork from Open WebUI `v0.11.0` to `v0.11.1` and preserves:

- Koreatimes favicon, logo, and light/dark splash assets.
- `WEBUI_NAME=Koreatimes` without an appended `(Open WebUI)` suffix.
- `insertSuggestionPrompt=true` as the default for suggestion-card insertion.
- Existing production OAuth and Google Drive Picker environment configuration.
- The existing Pipelines service and data mount; Pipelines must not be recreated.

Release-path hardening included in this tag:

- Deployment tag lineage accepts only a tag identical to or behind current `main`.
- Generated `data/state_store.db` artifacts are removed and ignored.
- Inherited upstream GitHub Release and PyPI workflows are disabled in this fork.

## 3. Confirmed Production Baseline

The production agent must stop if any of these values differ:

| Item             | Expected value                                      |
| ---------------- | --------------------------------------------------- |
| Compose project  | `openwebui`                                         |
| Compose file     | `/home/ubuntu/openwebui/docker-compose.deploy.yaml` |
| Environment file | `/home/ubuntu/openwebui/.env.openwebui.oauth`       |
| Open WebUI data  | `/home/ubuntu/openwebui/openwebui`                  |
| Pipelines data   | `/app/pipelines`                                    |
| Current image    | `ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1`   |
| Current state    | healthy                                             |

The environment file was confirmed mode `600`. `WEBUI_SECRET_KEY` was persisted from
the currently running container without rotating it, so the next recreate should retain
existing OAuth session encryption.

## 4. Migration Expectation

The production database currently reports revision `f0bd01a18a3d`. The new image applies
three revisions automatically during startup:

1. `1ce6ade7d93b` - add the `group_member(user_id, group_id)` index.
2. `6d09d1bf1f23` - repair double-encoded user OAuth JSON where present.
3. `d4c1a8e37b62` - add `chat.timer_at` and chat list, unread, and timer indexes.

Expected final revision: `d4c1a8e37b62`.

The upstream release also modifies the older `b10670c03dd5` migration, but that revision
is already behind the production head and is not rerun during this upgrade.

Migration validation was performed with both RC and final images against a disposable
copy of a production SQLite backup. The upgrade reached the expected head, SQLite
integrity remained `ok`, and user/OAuth records remained present.

Image rollback does not reverse these migrations. Any failure after the new container
starts requires an explicit incident decision before changing the image or restoring data.

## 5. Validation Evidence

Passed:

- PR #22 Frontend Format & Build and Unit Tests.
- PR #22 Ruff format checks on Python 3.11 and 3.12.
- RC image build run `33159720495`.
- RC fresh-container health, build SHA, startup log scan, and Koreatimes manifest checks.
- RC migration from `f0bd01a18a3d` to `d4c1a8e37b62` on copied production SQLite data.
- Final image build run `33162328125`.
- Final tag and `git-75311d2` parity tags resolve to the same OCI index digest.
- Final fresh-container health, exact build SHA, clean startup log scan, and Koreatimes
  manifest checks.
- Final migration and SQLite integrity recheck on a fresh copy of the source backup.

Explicitly skipped by maintainer decision:

- OAuth browser login, logout, and session persistence.
- Google Drive Picker OAuth popup and file attachment.
- Real model chat and long delta-streaming response.
- File upload, RAG retrieval, and citation rendering.
- Pipelines and custom-tool end-to-end calls.

These skipped checks are known release risks, not passed validations. They must be run as
post-deployment browser acceptance before the deployment Issue is closed.

## 6. Deployment Control Plane

Deployment is permitted only through the GitHub workflow named
`Deploy approved production release` after a complete deployment Issue is approved.

Required workflow inputs:

- `tag`: `v0.11.1-kwh.1`
- `issue_number`: the production deployment request Issue created for this release
- `guide_commit`: the full commit SHA containing this guide

The local release agent stops after submitting the Issue. It must not dispatch the
production workflow.

## 7. Automated Deployment Sequence

The approved workflow must:

1. Validate the final tag, main lineage, guide commit, production paths, and database.
2. Capture `v0.11.0-kwh.1` as the rollback anchor.
3. Pull and record the final image digest before downtime.
4. Stop only the `openwebui` service.
5. Create and fully verify a WAL-safe archive containing Open WebUI and Pipelines data.
6. Recreate only `openwebui` with `--no-deps`.
7. Wait for health and verify version, manifest, Pipelines API, container state, and logs.
8. Record the backup path, digest, and technical result on the deployment Issue.

The expected service interruption is approximately 3 to 6 minutes. Reserve a 10 to 15
minute maintenance window. Do not restart Pipelines.

## 8. Startup Checkpoints

Expected migration log order:

```text
f0bd01a18a3d -> 1ce6ade7d93b
1ce6ade7d93b -> 6d09d1bf1f23
6d09d1bf1f23 -> d4c1a8e37b62
```

Required technical results:

- Container reaches healthy within five minutes.
- `/health` returns HTTP 200 with `status: true`.
- `/_app/version.json` reports `75311d2ac64d670b7cceaad5ecd05c5cf5a034bd`.
- `/manifest.json` reports `Koreatimes` for `name` and `short_name`.
- Pipelines OpenAPI remains reachable on port 9099.
- Startup logs contain no migration exception, startup failure, or unhandled traceback.

The known optional `fastapi-tools-v2` DNS error is not caused by this release. Record it,
but do not treat it as an automatic rollback trigger when required health checks pass.

## 9. Failure Policy

- Failure before the new container starts: restart the captured previous final image.
- Failure after the new container starts: halt and preserve the container, logs, database,
  and verified backup. Do not roll back automatically.
- Migration or data-integrity failure: require explicit approval before image rollback or
  full backup restore.
- Browser-only failure: keep the deployment Issue open and choose between restricted
  operation, a new immutable hotfix release, or approved rollback.

## 10. Browser Acceptance

After technical deployment succeeds, verify in a fresh browser session:

- Google OAuth login, logout, refresh, and session persistence.
- Google Drive Picker account selection, file listing, and one successful attachment.
- Existing chats, settings, Knowledge files, and user data remain available.
- A real model response completes, including a long streamed response.
- A document upload can be retrieved with citations.
- Pipelines and configured custom tools complete a request.
- Koreatimes title, logo, favicon, and light/dark splash are present.
- Suggestion cards populate the composer without automatically sending.

Do not close the deployment Issue until these browser checks are recorded.
