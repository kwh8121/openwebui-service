# kwh Release Routine — Production-Oriented Operational Guide

> **Scope**: Practical, session-to-session reference for the day-to-day release routine of this fork. Codifies the workflow that stabilized after the 2026-07-22 `main`-direct-commit incident and the `v0.10.2-kwh.2` (Koreatimes brand) rollout.
>
> **Authority**: `docs/manual/github-actions-ghcr-release-deployment.md` remains the highest-authority reference. This document supplements it with the operational how-to, real invocations, and recovery patterns. If they conflict, the authoritative doc wins and this one should be updated to match.

## 1. Repository & Remote Setup

| Item | Value |
|---|---|
| Local working directory | `~/projects/openwebui-service` |
| `origin` (push target) | `https://github.com/kwh8121/openwebui-service.git` |
| `upstream` (fetch only) | `https://github.com/open-webui/open-webui.git` (push URL: `DISABLED`) |
| Container registry | `ghcr.io/kwh8121/openwebui-service` |
| Authoritative release doc | `docs/manual/github-actions-ghcr-release-deployment.md` |
| Session/work logs | `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (date-based, append same-day) |

## 2. Branch And Tag Conventions

### Branches

| Pattern | Purpose | Rules |
|---|---|---|
| `main` | Deploy source of truth | **Never commit directly.** PR from `integration/*` only. |
| `integration/vX.Y.Z` | Accumulates custom changes for a specific upstream version | Feature merges via `--no-ff`. Long-lived per upstream version. |
| `feature/<slug>` | One logical customization unit | Branch from current `integration/*` (or `main` for docs-only). Merge to `integration/*` with `--no-ff`. |

Feature branches remain on `origin` after merge for traceability. Delete only after next release cycle proves stable.

### Tags

| Pattern | Example | Meaning |
|---|---|---|
| `vX.Y.Z-kwh.N` | `v0.10.2-kwh.2` | Final release. Cut from the merge commit on `main`. Triggers production image build. |
| `vX.Y.Z-kwh.N-rc.M` | `v0.10.2-kwh.2-rc.1` | Release candidate. Cut from `integration/vX.Y.Z` tip. Triggers staging image build. |

The workflow (`.github/workflows/docker.yaml`) fires on tag pattern `v*-kwh.*`.

### GHCR Image Tag Format (verified 2026-07-22)

`docker/metadata-action@v5` in `docker.yaml` produces:

- `type=ref,event=tag` — **preserves the git tag verbatim, including the `v` prefix**.
- `type=sha,prefix=git-` — **7-character short SHA** (e.g., `git-42681f0`), not the full 40-char SHA.

**Correct** deployment variable:
```bash
export OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.2       # 'v' prefix required
```
Bare `0.10.2-kwh.2` or a full 40-char SHA **will not exist on GHCR** and `docker pull` will fail.

## 3. End-to-End Routine (per custom change)

### 3.1 Start work

```bash
cd ~/projects/openwebui-service
git fetch origin
git checkout integration/vX.Y.Z
git pull --ff-only
git checkout -b feature/<slug>
```

### 3.2 Commit changes

Small, focused commits. If a change has an asset step and a code step, keep them as separate commits within the feature branch for reviewability.

### 3.3 Merge to integration

```bash
git checkout integration/vX.Y.Z
git merge --no-ff feature/<slug> \
  -m "merge: feature/<slug> into integration/vX.Y.Z"
```

### 3.4 Push

```bash
git push -u origin feature/<slug>
git push origin integration/vX.Y.Z
```

### 3.5 Cut RC tag → staging build

Find the next RC number:
```bash
git fetch --tags
git tag -l 'vX.Y.Z-kwh.*' | sort -V
```

Cut and push:
```bash
git tag -a vX.Y.Z-kwh.N-rc.M <integration-tip-sha> -m "vX.Y.Z-kwh.N-rc.M ..."
git push origin vX.Y.Z-kwh.N-rc.M
```

Monitor:
```bash
gh run list --repo kwh8121/openwebui-service --workflow=docker.yaml --limit 3
gh run watch <run-id> --repo kwh8121/openwebui-service --interval 45 --exit-status
```

Result image: `ghcr.io/kwh8121/openwebui-service:vX.Y.Z-kwh.N-rc.M`

### 3.6 Staging deploy (SSH to staging host)

```bash
cd /path/to/staging-deploy   # location of docker-compose.staging.yaml
# ensure env file contains: WEBUI_NAME=Koreatimes  (see §5)
export OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N-rc.M
export OPENWEBUI_LOCAL_DATA=<staging-data-path>
export OPENWEBUI_DEPLOY_ENV_FILE=<staging-env-file>
docker compose -f docker-compose.staging.yaml pull
docker compose -f docker-compose.staging.yaml up -d
```

Run the smoke checklist (§6). Localhost-only port per compose file.

### 3.7 Open PR integration → main

```bash
gh pr create --repo kwh8121/openwebui-service \
  --base main \
  --head integration/vX.Y.Z \
  --title "Merge integration/vX.Y.Z (kwh.N): <summary>" \
  --body-file <path-to-body.md>
```

PR body should include the staging verification checklist as completed items.

### 3.8 Merge PR (`--merge` style)

```bash
gh pr merge <N> --merge --repo kwh8121/openwebui-service
git fetch origin && git checkout main && git pull --ff-only
```

`--merge` (not `--squash`, not `--rebase`) preserves the merge commit structure aligned with prior kwh releases.

### 3.9 Cut final tag → production build

```bash
git tag -a vX.Y.Z-kwh.N <main-tip-sha> -m "..."
git push origin vX.Y.Z-kwh.N
```

Monitor the build; verify success before touching production.

### 3.10 Production deploy (SSH to prod host)

See §7 (full command block).

## 4. Docker Compose Files

| File | Purpose | build: section | Data mount |
|---|---|---|---|
| `docker-compose-build.yaml` | Dev builds only | ✅ present | dev data |
| `docker-compose.staging.yaml` | Isolated staging validation | ❌ absent | Separate staging data dir, localhost-only port |
| `docker-compose.deploy.yaml` | Production | ❌ absent | Preserves `/app/backend/data` and `/app/pipelines` |

Staging compose **must never** mount the production data directory.

## 5. Deployment Environment Variables

All read by `docker-compose.deploy.yaml` (and staging variant). Set explicitly to avoid silent default fallback.

| Variable | Default in compose | Purpose |
|---|---|---|
| `OPENWEBUI_IMAGE_TAG` | required (compose fails without) | GHCR image tag, e.g., `v0.10.2-kwh.2` (with `v`) |
| `OPENWEBUI_LOCAL_DATA` | `/app/backend/data` | Bind-mount source for user data / DB |
| `OPENWEBUI_DEPLOY_ENV_FILE` | `./.env.openwebui.oauth` | Path to the env_file with OAuth + brand config |
| `PIPELINES_LOCAL_DATA` | `/app/pipelines` | Bind-mount for pipelines container |

Env file contents required for Koreatimes brand:
```env
WEBUI_NAME=Koreatimes
# ... existing OAuth vars ...
```

Add via:
```bash
grep -q '^WEBUI_NAME=' <env-file> \
  && sed -i 's|^WEBUI_NAME=.*|WEBUI_NAME=Koreatimes|' <env-file> \
  || echo 'WEBUI_NAME=Koreatimes' >> <env-file>
```

**Note**: This fork removed the upstream `WEBUI_NAME != "Open WebUI"` suffix enforcement in `backend/open_webui/env.py:842` (commit `4cbd9a061`). Setting `WEBUI_NAME=Koreatimes` yields the string `Koreatimes` verbatim, not `Koreatimes (Open WebUI)`.

## 6. Verification Checklist

After each staging or production deploy:

**Container health**
- [ ] `docker compose ... ps openwebui` shows `running (healthy)` or equivalent
- [ ] `docker compose ... logs --tail 100 openwebui` shows no startup errors
- [ ] `curl -sf http://<host>/health` returns 200

**Authentication**
- [ ] Login page loads
- [ ] OAuth provider flow completes end-to-end
- [ ] User session persists on refresh

**Functional smoke**
- [ ] Model request: send a message, get a response
- [ ] File upload / RAG: upload a document, ask about it, verify citations
- [ ] Pipelines: pipeline service listed and connectable in workspace UI

**Brand (post Koreatimes swap)**
- [ ] Top-left sidebar logo = Koreatimes
- [ ] Sidebar footer instance name = `Koreatimes` (no ` (Open WebUI)` suffix)
- [ ] Login page + onboarding logo = Koreatimes
- [ ] Browser tab favicon + title = Koreatimes
- [ ] `/manifest.json` `name` / `short_name` = `Koreatimes`
- [ ] `/opensearch.xml` ShortName / Description = `Koreatimes`
- [ ] Dark mode logo renders correctly

**Suggestion prompt behavior (post kwh.2)**
- [ ] Clicking a suggestion card populates the input instead of auto-sending (for users with no explicit setting)

## 7. Production Deployment (SSH block, copy-paste)

```bash
ssh <prod-server>
cd /path/to/prod-deploy-dir      # location of docker-compose.deploy.yaml

# --- 0) sanity ---
docker login ghcr.io -u <username>   # skip if already authenticated
grep -E "OPENWEBUI_LOCAL_DATA|OPENWEBUI_DEPLOY_ENV_FILE" .env* 2>/dev/null

# --- 1) backup (SQLite WAL-safe) ---
# Option A (recommended): stop container -> tar -> deploy will restart
docker compose -f docker-compose.deploy.yaml stop openwebui
sudo tar czf ~/backup-openwebui-$(date +%Y%m%d-%H%M%S).tar.gz \
  <actual-data-path> <actual-pipelines-path>

# Option B (online, no downtime, requires sqlite3):
# sqlite3 <data-path>/webui.db ".backup /tmp/webui.db.backup"
# sudo tar czf ~/backup-openwebui-$(date +%Y%m%d-%H%M%S).tar.gz \
#   /tmp/webui.db.backup <data-path>/uploads <pipelines-path>

# --- 2) env file (WEBUI_NAME) ---
grep -q '^WEBUI_NAME=' <env-file> \
  && sed -i 's|^WEBUI_NAME=.*|WEBUI_NAME=Koreatimes|' <env-file> \
  || echo 'WEBUI_NAME=Koreatimes' >> <env-file>

# --- 3) deploy ---
export OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N               # 'v' prefix required
export OPENWEBUI_LOCAL_DATA=<actual-data-path>
export OPENWEBUI_DEPLOY_ENV_FILE=<actual-env-file-path>
docker compose -f docker-compose.deploy.yaml pull openwebui
docker compose -f docker-compose.deploy.yaml up -d --no-deps openwebui

# --- 4) smoke ---
docker compose -f docker-compose.deploy.yaml ps openwebui
docker compose -f docker-compose.deploy.yaml logs --tail 100 openwebui
curl -sf http://localhost/health && echo OK
# then browser checks per §6
```

### Rollback

```bash
export OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.<N-1>   # e.g., v0.10.2-kwh.1
docker compose -f docker-compose.deploy.yaml pull openwebui
docker compose -f docker-compose.deploy.yaml up -d --no-deps openwebui
```

⚠ Image rollback does not automatically reverse database migrations. Between `v0.10.2-kwh.1` and `v0.10.2-kwh.2` there are no migrations, but verify per release.

## 8. SQLite WAL Backup Notes

Open WebUI defaults to SQLite in WAL mode when no external DB is configured. Plain `tar` while the container is running may miss uncommitted WAL data. Use either:

- **stop → tar → start** (short downtime; simplest)
- **`sqlite3 <db> ".backup <copy>"`** for consistent online snapshot, then tar auxiliary dirs (`uploads/`, `cache/`, etc.)

If a Postgres/other backend is later adopted, use its native dump tool.

## 9. Documentation-Only Changes

Doc-only changes (Markdown under `docs/`, comments, this file) do not require the full integration cycle:

- Branch from `main`: `git checkout -b feature/docs-<slug>`
- Commit
- PR directly to `main`
- No new git tag or image needed

Rationale: no artifact rebuild, no staging validation applicable.

## 10. Recovery Patterns

### 10.1 Accidental commit on `main`

If a custom change was committed directly on the local `main` branch by mistake (as happened 2026-07-22 with the `insertSuggestionPrompt` fix), before it is pushed:

```bash
git branch feature/<slug> <bad-commit-sha>      # preserve the commit
git reset --hard origin/main                    # restore main
git checkout integration/vX.Y.Z
git merge --no-ff feature/<slug> \
  -m "merge: feature/<slug> into integration/vX.Y.Z"
```

The commit SHA survives (`git branch` at that SHA), `main` returns to pristine, and the change reaches integration through the correct path. Verified with commit `c68c745d2` on 2026-07-22.

### 10.2 Doc example mismatch discovered post-release

Follow §9 (docs-only shortcut). Correct the doc, PR to `main`. No new release tag.

## 11. Session Continuity

- Work logs: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (append same-day)
- This file: reference during any session touching the release routine
- Persistent memory (mem0/openviking): pointer to this file lives under `kwh8121-openwebui-service` project scope

Between sessions, start by:
```bash
git status --short --branch
git log --oneline -5
git tag -l 'v*-kwh.*' | sort -V | tail -5
```
to reorient without reading full history.

## 12. Divergence From Upstream (running inventory)

Kept here so operators know what will conflict on future upstream merges.

| File | Line(s) | Change | Introduced |
|---|---|---|---|
| `src/lib/components/chat/Chat.svelte` | 323 | `?? false` → `?? true` (default for `insertSuggestionPrompt`) | `c68c745d2` (v0.10.2-kwh.2) |
| `src/lib/components/chat/Settings/Interface.svelte` | 57, 227 | `= false` / `?? false` → `= true` / `?? true` (matches Chat.svelte default) | `c68c745d2` (v0.10.2-kwh.2) |
| `backend/open_webui/env.py` | 842-844 | Removed `if WEBUI_NAME != 'Open WebUI': WEBUI_NAME += ' (Open WebUI)'` | `4cbd9a061` (v0.10.2-kwh.2) |
| `static/static/*` + `backend/open_webui/static/*` | — | Koreatimes brand assets (12 files × 2 dirs) | `171e0f742` (v0.10.2-kwh.2) |
