# Open WebUI Service — Claude Code Session Startup

Claude Code auto-loads this file at session start. It re-exports the shared project agent guide via `@`-import so that `AGENTS.md` remains the single source of truth for both Claude Code and other agent tools (Codex, etc.) that follow the `AGENTS.md` convention.

Content-heavy edits belong in `AGENTS.md` or the linked docs. The routine summary below is duplicated here **on purpose** so it stays in every Claude Code session's context without a lookup.

## Production Release Routine (at-a-glance)

For any code/asset change destined for production. Full details in `docs/manual/kwh-release-routine.md`; authoritative rules in `docs/manual/github-actions-ghcr-release-deployment.md`.

1. **Recovery guard**: if a customization was mistakenly committed to `main`, branch `feature/<slug>` at that SHA → `git reset --hard origin/main` → `--no-ff` merge into `integration/vX.Y.Z`. (Verified 2026-07-22 with commit `c68c745d2`.)
2. **Feature branch**: `git checkout integration/vX.Y.Z && git pull && git checkout -b feature/<slug>`; commit; then `git checkout integration/vX.Y.Z && git merge --no-ff feature/<slug>`.
3. **Push**: both feature and integration branches to `origin`.
4. **RC tag** on integration tip: `git tag -a vX.Y.Z-kwh.N-rc.M <sha> -m "..."` → push → GH Actions builds `ghcr.io/kwh8121/openwebui-service:vX.Y.Z-kwh.N-rc.M` (note the required `v` prefix).
5. **Staging verify**: SSH to staging → set `OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N-rc.M` in env; `docker compose -f docker-compose.staging.yaml pull && up -d`; run smoke checklist (health, OAuth, model, RAG, pipelines, brand, suggestion-prompt UX).
6. **PR** `integration/vX.Y.Z` → `main`; merge `--merge` style; sync local `main` (`git fetch && git checkout main && git pull --ff-only`).
7. **Final tag** on merged main tip: `git tag -a vX.Y.Z-kwh.N <sha> -m "..."` → push → GH Actions builds the production image.
8. **Production deploy**: SSH to prod → SQLite WAL-safe backup (`docker compose stop openwebui` then `tar`, OR online `sqlite3 <db> ".backup ..."`) → set `OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N` (with `v`), `OPENWEBUI_LOCAL_DATA`, `OPENWEBUI_DEPLOY_ENV_FILE` explicitly → `docker compose -f docker-compose.deploy.yaml pull openwebui && up -d --no-deps openwebui`; re-run full smoke.
9. **Post-release fixes** discovered during rollout: doc-only shortcut — `feature/docs-*` branched from `main` → PR directly to `main`, no new git tag or image rebuild.

**Every session, always** log the day's work in `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (append same-day, new file when the date rolls over). Consult prior days' logs before starting to avoid repeating work.

@AGENTS.md
