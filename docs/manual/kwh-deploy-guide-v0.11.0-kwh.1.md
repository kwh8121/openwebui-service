# Production Deployment Guide — `v0.11.0-kwh.1`

This guide is written for the production deployment agent. It supersedes
`docs/manual/kwh-release-routine.md §7` **for this release only**. All
paths and variable values are the confirmed production state on
2026-07-30. If any path has changed since, stop and re-verify.

Reading order: §1 → §2 → §3 → §4 → §5 → §6 → §7. If anything in §3
diverges from reality, halt and escalate before touching §4.

---

## 1. Release identifiers

| Item | Value |
|---|---|
| Version | **v0.11.0-kwh.1** |
| Git tag object | annotated tag on `main` tip after PR #8 merge |
| Main tip SHA | `0e2bd547c` |
| GHCR image tag (deploy this) | `ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1` |
| GHCR short-SHA tag (parity check) | `ghcr.io/kwh8121/openwebui-service:git-0e2bd54` |
| Image digest (`sha256:...`) | **Agent fetches — see §3.4** |
| GH Actions build Run | `30522437399` |
| Run URL | https://github.com/kwh8121/openwebui-service/actions/runs/30522437399 |
| Build duration | 6m47s |
| Base upstream | Open WebUI `v0.11.0` (2026-07-27) |
| Fork carryovers | Koreatimes brand assets, `WEBUI_NAME` suffix removal, `insertSuggestionPrompt=true` default, local-test tooling |
| Rollback target | `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.2` (currently running) |

> **Do NOT deploy `latest` or `main`.** Only the immutable version tag or
> the git-SHA tag. The compose file will refuse to start without
> `OPENWEBUI_IMAGE_TAG` set — this is intentional.

---

## 2. Deployment overview

**What changes:** `v0.10.2-kwh.2` → `v0.11.0-kwh.1`.

- Upstream `v0.11.0` ground-up UI redesign (narrower conversation column, tidier menus, consistent dropdowns, admin panel rearranged).
- New backend features: notifications, chat variables, user variables, subagents, chat_fork utilities, terminals, timers, openserp retrieval, JSON codec/response helpers.
- **7 new Alembic migrations run automatically on first boot** to bring the schema from v0.10.2 to v0.11.0:
  1. `55f1302ac17c_add_memory_id_user_id_covering_index`
  2. `856c5b02fb54_add_chat_message_meta`
  3. `959eaac8f909_add_automation_folder_id`
  4. `9a1b2c3d4e5f_add_current_message_id_to_chat`
  5. `b0018471bbbe_add_user_variables`
  6. `c49178636c78_add_chat_variables`
  7. `f0bd01a18a3d_add_unique_normalized_user_email_index`

**Fork carryovers preserved** (do not need re-application):
- `backend/open_webui/env.py`: no forced `' (Open WebUI)'` suffix on `WEBUI_NAME`.
- Chat.svelte / Settings/Interface.svelte: `insertSuggestionPrompt ?? true` default (suggestion cards populate input; do not auto-submit).
- Static assets (`static/static/*` and `backend/open_webui/static/*`): Koreatimes favicon / logo / splash (light + dark) / manifest.

**Not changing:** pipelines image (`ghcr.io/open-webui/pipelines:main`), pipelines container port, `.env.openwebui.oauth` structure.

**Deployment strategy:** rolling replace of `openwebui` service only (`--no-deps`). `pipelines` container stays up.

---

## 3. Prerequisites verification (perform BEFORE §4)

Verify the exact production state matches what this guide assumes. Any
mismatch → stop, escalate.

### 3.1 Working directory and paths

```bash
cd /home/ubuntu/openwebui
test -f docker-compose.deploy.yaml || { echo "MISSING compose file"; exit 1; }
test -f .env.openwebui.oauth      || { echo "MISSING env file"; exit 1; }
test -d openwebui                 || { echo "MISSING data dir"; exit 1; }
test -f openwebui/webui.db        || { echo "MISSING sqlite DB"; exit 1; }
ls -la openwebui/webui.db openwebui/webui.db-wal openwebui/webui.db-shm 2>&1
```

Expected: all four checks succeed. `webui.db-wal` size hints at recent traffic.

### 3.2 Compose project name

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui ps
```

Expected: `openwebui-openwebui-1` (running healthy) and `openwebui-pipelines-1` (running).
If the container names use a different prefix, the compose project name is not `openwebui` — halt and re-check.

### 3.3 Current running image (rollback anchor)

```bash
CURRENT_IMAGE=$(docker inspect $(docker compose -f docker-compose.deploy.yaml -p openwebui ps -q openwebui) --format '{{.Config.Image}}')
echo "Currently running: $CURRENT_IMAGE"
```

Expected exactly: `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.2`.
If different, record actual value — that becomes your rollback target.

### 3.4 GHCR authentication and image existence

```bash
# If not already logged in on this host:
# docker login ghcr.io -u <deploy-account>

docker pull ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1
NEW_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1)
echo "New image digest: $NEW_DIGEST"
```

Expected: `docker pull` completes, `NEW_DIGEST` is `ghcr.io/kwh8121/openwebui-service@sha256:<64-hex>`.
Record `$NEW_DIGEST` — this is your immutable pin. Cross-reference with the GHCR web UI (https://github.com/kwh8121/openwebui-service/pkgs/container/openwebui-service) if paranoia demands.

Also confirm the parity tag resolves to the same digest:

```bash
docker pull ghcr.io/kwh8121/openwebui-service:git-0e2bd54
PARITY_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/kwh8121/openwebui-service:git-0e2bd54)
[[ "$NEW_DIGEST" == "$PARITY_DIGEST" ]] && echo "digest match OK" || { echo "DIGEST MISMATCH — halt"; exit 1; }
```

### 3.5 Environment file sanity

```bash
grep -E '^(WEBUI_NAME|ENABLE_OAUTH_SIGNUP|ENABLE_LOGIN_FORM|ENABLE_OAUTH_PERSISTENT_CONFIG|GOOGLE_CLIENT_ID)=' \
  .env.openwebui.oauth
```

Expected findings (based on 2026-07-30 confirmed state):
- `WEBUI_NAME=Koreatimes`
- `ENABLE_OAUTH_SIGNUP=true`
- `ENABLE_OAUTH_PERSISTENT_CONFIG=true`
- `GOOGLE_CLIENT_ID=...` (present)
- `ENABLE_LOGIN_FORM` is **not set** — backend default is `True`, but note §7.1 caveat about DB-persisted config overriding env values.

If `WEBUI_NAME` is missing or not `Koreatimes`, add/fix before proceeding:

```bash
grep -q '^WEBUI_NAME=' .env.openwebui.oauth \
  && sed -i 's|^WEBUI_NAME=.*|WEBUI_NAME=Koreatimes|' .env.openwebui.oauth \
  || echo 'WEBUI_NAME=Koreatimes' >> .env.openwebui.oauth
```

### 3.6 Disk space check (backup + new image both need room)

```bash
df -h /home/ubuntu /var/lib/docker
```

Expected: at least a few GB free on both. The pre-deploy tar of `openwebui/` may be ~1 GB depending on cache size; the new image adds a few hundred MB.

---

## 4. Pre-deployment backup — **MANDATORY**

WAL-safe backup. The `v0.10.2 → v0.11.0` migration is not trivially reversible; a bad migration + no backup = data loss.

```bash
export TS=$(date +%Y%m%d-%H%M%S)
export OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.2   # keep current tag for compose commands during stop
export OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
export OPENWEBUI_DEPLOY_ENV_FILE=/home/ubuntu/openwebui/.env.openwebui.oauth
export PIPELINES_LOCAL_DATA=/app/pipelines

# Stop only openwebui (pipelines keeps running; not affected by the release)
docker compose -f docker-compose.deploy.yaml -p openwebui stop openwebui

# Full data tar (SQLite is now quiesced; WAL is safely rolled up)
tar -czf ~/prod-backup-preupgrade-${TS}-v0.10.2-kwh.2.tar.gz \
  -C /home/ubuntu/openwebui openwebui

# Verify archive integrity + note size
ls -lh ~/prod-backup-preupgrade-${TS}-v0.10.2-kwh.2.tar.gz
tar -tzf ~/prod-backup-preupgrade-${TS}-v0.10.2-kwh.2.tar.gz | head -5
tar -tzf ~/prod-backup-preupgrade-${TS}-v0.10.2-kwh.2.tar.gz | wc -l
```

**Record** `~/prod-backup-preupgrade-${TS}-v0.10.2-kwh.2.tar.gz` — you need this path exactly for §7 rollback.

Optional online alternative (only if you cannot stop the container even momentarily):

```bash
sqlite3 /home/ubuntu/openwebui/openwebui/webui.db \
  ".backup /home/ubuntu/prod-backup-preupgrade-${TS}-webui.db"
```

Note: online backup captures the DB only; uploaded files, vector_db, caches under `openwebui/` are not included. The stop-then-tar path is strongly preferred.

---

## 5. Deployment execution

All compose commands **require** `OPENWEBUI_IMAGE_TAG` because the compose interpolation uses `${OPENWEBUI_IMAGE_TAG:?...}`. Export once at the start of the deploy shell and keep it set through §6.

```bash
export OPENWEBUI_IMAGE_TAG=v0.11.0-kwh.1
export OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
export OPENWEBUI_DEPLOY_ENV_FILE=/home/ubuntu/openwebui/.env.openwebui.oauth
export PIPELINES_LOCAL_DATA=/app/pipelines
```

Sanity-render the resolved compose (no side effects):

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui config \
  | grep -E 'image:|source:|env_file:' | head -20
```

Expected: `image: ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1`, correct bind-mount sources, correct env file path.

Then deploy (openwebui only; leave pipelines running):

```bash
# Pull was already done in §3.4; this line is a no-op but confirms cache
docker compose -f docker-compose.deploy.yaml -p openwebui pull openwebui

# Rolling replace: brings container down, recreates on new image, brings up
docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
```

Do **not** run `up` without `--no-deps` — that would attempt to recreate pipelines, which is unnecessary and briefly interrupts pipeline traffic.

Immediate post-up sanity:

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui ps
```

Expected: `openwebui` state `running` (health check may still be `starting`); `pipelines` state `running (healthy)` (untouched).

---

## 6. Migration monitoring

The new container runs Alembic on first boot. Watch until you see the final "Application startup complete" line (or equivalent), or a fatal error.

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 200 -f openwebui
```

Watch for (in this rough order):

1. `Generating new WEBUI_SECRET_KEY` line **should NOT appear** — the key file already exists in the persisted data dir. If it appears, the bind mount is broken or pointing at the wrong path. Halt and rollback (§7).
2. Alembic lines like:
   ```
   INFO  [alembic.runtime.migration] Context impl SQLiteImpl.
   INFO  [alembic.runtime.migration] Will assume non-transactional DDL.
   INFO  [alembic.runtime.migration] Running upgrade <old> -> 55f1302ac17c, add_memory_id_user_id_covering_index
   INFO  [alembic.runtime.migration] Running upgrade 55f1302ac17c -> 856c5b02fb54, add_chat_message_meta
   ... (7 upgrade lines total)
   ```
3. `Uvicorn running on http://0.0.0.0:8080` or similar.
4. No `Traceback`, no `ERROR`, no `Failed to start`, no `sqlalchemy` migration exceptions.

Once the log settles (no new lines for ~30s and startup complete has appeared), exit the follow with `Ctrl+C` and run:

```bash
curl -sf http://localhost/health && echo "health OK" || { echo "HEALTH FAILED"; }
```

Expected: `{"status":true}` or similar 200 body → `health OK`.

If `/health` does not return 200 within ~3 minutes, go to §7 rollback.

---

## 7. Post-deployment smoke checklist

Perform via **a fresh browser session (incognito) or hard-refresh** — v0.11.0 changes CSS and static assets substantially, and PWA + splash images are aggressively cached. Include Ctrl+Shift+R and `Application → Storage → Clear site data` in DevTools if anything looks stale.

### 7.1 Authentication (VERIFY LOGIN SCREEN ACTUAL STATE)

Production `.env.openwebui.oauth` does **not** set `ENABLE_LOGIN_FORM`.
Backend default is `True`, so the password/email form should be visible
alongside the OAuth button. **However**, `ENABLE_OAUTH_PERSISTENT_CONFIG=true`
means a previously-saved DB config may override this. **Confirm from the
actual login screen**:

- [ ] Landing page shows **both** password/email fields **and** the "Sign in with Google" (Koreatimes) button — matches OAuth-hybrid expectation.
- [ ] If only the OAuth button is shown, note this. Existing password-only users cannot log in. Escalate before treating deploy as complete; the fix is to set `ENABLE_LOGIN_FORM=true` in `.env.openwebui.oauth` and restart openwebui, or to update the persisted DB config through the admin UI (only reachable once an admin OAuth login succeeds).
- [ ] Existing OAuth (Google) user sign-in completes end-to-end without error.
- [ ] After sign-in, refresh: session persists, no re-login required.

### 7.2 Data integrity (upgrade migration verification)

- [ ] Chat history from before the upgrade is present and openable.
- [ ] User settings (theme, interface preferences) preserved.
- [ ] Uploaded files / knowledge bases still listed under Workspace → Knowledge.

### 7.3 Fork carryovers

- [ ] Top-left sidebar logo = Koreatimes.
- [ ] Browser tab title = `Koreatimes`.
- [ ] Sidebar footer / instance name = `Koreatimes` with **no** `(Open WebUI)` suffix.
- [ ] Loading splash (light) = Koreatimes splash. Trigger by reloading `/`.
- [ ] Loading splash (dark) = Koreatimes splash-dark. Switch OS or app theme to dark → reload → observe.
- [ ] `/manifest.json` returns `name: Koreatimes`, `short_name: Koreatimes` (curl or DevTools → Application → Manifest).
- [ ] Suggestion cards: click a suggestion → the text populates the input field. It does **not** auto-submit.

### 7.4 Functional smoke

- [ ] Send a message to the default model → response is returned.
- [ ] Workspace → Pipelines lists the pipelines container (port 9099) and shows connected status.
- [ ] Upload a small text document, ask a question about it → response includes citations.

### 7.5 v0.11.0 UI redesign spot check

- [ ] Conversation column is visibly narrower than pre-upgrade.
- [ ] Menus and dropdowns render without visual glitches.
- [ ] Admin panel (`/admin/settings`) loads for the admin user; sections are reachable.

---

## 8. Rollback procedure

**Trigger any of the following:**
- `/health` returns non-200 for >3 minutes after §5.
- Alembic emits an `ERROR` or `Traceback` in §6.
- §7.1 shows regression that blocks all users (not just the LOGIN_FORM caveat).
- Data-integrity check in §7.2 fails (chats, users, uploads missing/corrupted).

### 8.1 Image-only rollback (data intact)

Fastest recovery when the failure is purely at the container/runtime level.

```bash
export OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.2
docker compose -f docker-compose.deploy.yaml -p openwebui pull openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 50 openwebui
curl -sf http://localhost/health && echo OK
```

**Warning:** if the failed v0.11.0 boot ran Alembic upgrades that succeeded before the container crashed, the DB now has v0.11.0 schema. `v0.10.2-kwh.2` may not run against it. If §6 showed successful migration lines before the failure, jump directly to §8.2.

### 8.2 Full rollback (image + data from backup)

Use when Alembic ran even partially, or when v0.10.2-kwh.2 fails to boot on the current DB.

```bash
export OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.2

# Stop the failing container
docker compose -f docker-compose.deploy.yaml -p openwebui stop openwebui

# Move current (possibly-migrated) data aside for forensic use
mv /home/ubuntu/openwebui/openwebui \
   /home/ubuntu/openwebui/openwebui.failed-upgrade-$(date +%Y%m%d-%H%M%S)

# Restore from the pre-upgrade backup
mkdir /home/ubuntu/openwebui/openwebui
tar -xzf ~/prod-backup-preupgrade-<TS>-v0.10.2-kwh.2.tar.gz \
  -C /home/ubuntu/openwebui \
  openwebui   # extracts as ./openwebui/

# (If your archive layout differs, adjust so /home/ubuntu/openwebui/openwebui/webui.db exists)
test -f /home/ubuntu/openwebui/openwebui/webui.db || { echo "restore failed"; exit 1; }

# Bring up on the previous image
docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 50 openwebui
curl -sf http://localhost/health && echo OK
```

After successful rollback:
- Do **not** cut a new tag pretending to fix the issue; the immutable rule applies.
- Report the failure to the release owner. The fix path is: reproduce locally, patch, cut `v0.11.0-kwh.2` (or later), re-verify locally, then re-attempt production deploy.

### 8.3 Failed-upgrade dir retention

Keep `openwebui.failed-upgrade-*` for at least 7 days for post-mortem. Delete after root cause is documented.

---

## 9. Success markers to record

At end of a successful deploy, record these values in the release ticket / operations log:

| Field | Value to capture |
|---|---|
| Deploy start UTC | (from your shell history) |
| Deploy end UTC | (health OK timestamp) |
| Old image digest | (from §3.3 + `docker inspect` of pre-upgrade container) |
| New image digest | (from §3.4 `$NEW_DIGEST`) |
| Backup path + size | `~/prod-backup-preupgrade-<TS>-v0.10.2-kwh.2.tar.gz` + `du -h` |
| Alembic upgrade lines | Copy the 7 "Running upgrade" lines from §6 logs |
| Login screen result | OAuth-only or OAuth+password (§7.1) |
| Full smoke result | pass / fail per each §7 subsection |

---

## Appendix A. Environment-variable reference for this release

`docker-compose.deploy.yaml` interpolation variables (must be exported in every compose invocation):

| Variable | Value for this deploy | Purpose |
|---|---|---|
| `OPENWEBUI_IMAGE_TAG` | `v0.11.0-kwh.1` (deploy) / `v0.10.2-kwh.2` (rollback) | Image tag, `:?` guard fails on missing |
| `OPENWEBUI_LOCAL_DATA` | `/home/ubuntu/openwebui/openwebui` | openwebui data bind mount |
| `OPENWEBUI_DEPLOY_ENV_FILE` | `/home/ubuntu/openwebui/.env.openwebui.oauth` | env_file path |
| `PIPELINES_LOCAL_DATA` | `/app/pipelines` | pipelines data bind mount |

Compose invocation always uses `-p openwebui` (project name flag).

## Appendix B. External references (source of truth on conflict)

Order of authority per project convention:

1. `docs/manual/github-actions-ghcr-release-deployment.md` — highest authority for release/deploy rules.
2. `docs/manual/kwh-release-routine.md` — generic release routine (this guide overrides §7 for this specific release only).
3. This guide (`docs/manual/kwh-deploy-guide-v0.11.0-kwh.1.md`) — release-specific overlay.

If a command in this guide contradicts (1) or (2), (1) or (2) wins; halt and re-verify.
