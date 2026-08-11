# Open WebUI Service — Claude Code Session Startup

Claude Code auto-loads this file at session start. It re-exports the shared project agent guide via `@`-import so that `AGENTS.md` remains the single source of truth for both Claude Code and other agent tools (Codex, etc.) that follow the `AGENTS.md` convention.

Content-heavy edits belong in `AGENTS.md` or the linked docs. The routine summary below is duplicated here **on purpose** so it stays in every Claude Code session's context without a lookup.

## Data Location Principle (요약)

**One Fact, One Home** (2026-08-11 adopted): Linear = 지금 할 일 · jobs log = 오늘 실제로 한 일 · OpenViking = 다음 에이전트가 읽을 기억 (watch 대상: `docs/jobs/`, `docs/manual/`, `docs/plan/`, `AGENTS.md`, `CLAUDE.md`) · mem0 = 프로젝트 밖 개인 선호 (auto-capture 결과는 참고 캐시, 진실 소스 아님). 전체 매트릭스는 `AGENTS.md` §"Data Location Principle — One Fact, One Home".

## Development And Release Workflow — 5 Stages

Stages 1–4 use Linear (`koreatimes` workspace, project `openwebui vX.Y.Z`); stage 5 (deployment) stays on GitHub Issue per the opencode contract. Full definition in `AGENTS.md` §"Development And Release Workflow (5 Stages)". Label progression per issue: `plan-draft` → `needs-review` → `plan-approved` → (dev) → `verify-request` → `verify-passed` → (GitHub deploy Issue).

## Production Release Routine (at-a-glance)

For stage 5 (any code/asset change destined for production). Full details in `docs/manual/kwh-release-routine.md`; coordination protocol (top authority) in `docs/manual/github-control-plane-local-agent-handoff.ko.md` (Protocol v1.2); CI/CD mechanics in `docs/manual/github-actions-ghcr-release-deployment.md`.

1. **Recovery guard**: if a customization was mistakenly committed to `main`, branch `feature/<slug>` at that SHA → `git reset --hard origin/main` → `--no-ff` merge into `integration/vX.Y.Z`. (Verified 2026-07-22 with commit `c68c745d2`.)
2. **Feature branch**: `git checkout integration/vX.Y.Z && git pull && git checkout -b feature/<slug>`; commit; then `git checkout integration/vX.Y.Z && git merge --no-ff feature/<slug>`.
3. **Push**: both feature and integration branches to `origin`.
4. **RC tag** on integration tip: `git tag -a vX.Y.Z-kwh.N-rc.M <sha> -m "..."` → push → GH Actions builds `ghcr.io/kwh8121/openwebui-service:vX.Y.Z-kwh.N-rc.M` (note the required `v` prefix).
5. **Staging verify**: SSH to staging → set `OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N-rc.M` in env; `docker compose -f docker-compose.staging.yaml pull && up -d`; run smoke checklist (health, OAuth, model, RAG, pipelines, brand, suggestion-prompt UX).
6. **PR** `integration/vX.Y.Z` → `main`; merge `--merge` style; sync local `main` (`git fetch && git checkout main && git pull --ff-only`).
7. **Final tag** on merged main tip: `git tag -a vX.Y.Z-kwh.N <sha> -m "..."` → push → GH Actions builds the production image.
8. **Production deploy**: SSH to prod → SQLite WAL-safe backup (`docker compose stop openwebui` then `tar`, OR online `sqlite3 <db> ".backup ..."`) → set `OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.N` (with `v`), `OPENWEBUI_LOCAL_DATA`, `OPENWEBUI_DEPLOY_ENV_FILE` explicitly → `docker compose -f docker-compose.deploy.yaml pull openwebui && up -d --no-deps openwebui`; re-run full smoke.
9. **All changes (including docs)** follow the same flow: `feature/*` → `integration/vX.Y.Z` → PR → `main`. Direct `feature/docs-*` → `main` shortcut is **abolished** (2026-07-31). No new tag or image rebuild for doc-only changes.

**Every session, always** log the day's work in `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (append same-day, new file when the date rolls over). Consult prior days' logs before starting to avoid repeating work.

@AGENTS.md
