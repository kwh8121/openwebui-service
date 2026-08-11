# Open WebUI Agent Guide

## Layout

- `src/` is the SvelteKit frontend. `src/routes` contains routes and `src/lib` contains shared UI, stores, and client utilities.
- `backend/open_webui/main.py` creates the FastAPI app, registers routers under `/api/v1`, `/ollama`, and `/openai`, then mounts the built frontend as the SPA fallback. Backend configuration is centralized in `backend/open_webui/config.py` and `env.py`.
- `npm run build` creates `build/`; it is packaged into the Python wheel as `open_webui/frontend`. Do not edit built assets.
- Database migrations live in `backend/open_webui/migrations`. Generate one with `DATABASE_URL=<url> alembic revision --autogenerate -m "description"`.

## Local Development

- Node is engine-strict and must be `>=18.13.0` through Node 22; Python support is 3.11-3.12.
- Frontend: `npm run dev` fetches Pyodide assets before starting Vite. Use `npm run dev:5050` only when port 5050 is required.
- Backend: from `backend/`, run `./dev.sh`. It starts the reload server on port 8080 and allows the Vite origin. Run it alongside Vite for full-stack work.
- The supported packaged server command is `open-webui serve`; it creates or loads `.webui_secret_key` when `WEBUI_SECRET_KEY` is absent. Do not commit that key or `backend/data`.

## Verification And Formatting

- Frontend type check: `npm run check`. Production build: `npm run build`; both fetch Pyodide first.
- Frontend tests: `npm run test:frontend -- <path-or-vitest-args>`.
- `npm run lint:frontend`, `npm run format`, and `npm run i18n:parse` modify files. The last regenerates `src/lib/i18n`; run it after changing translatable strings and include its output.
- CI runs `npm run format`, `npm run i18n:parse`, then requires a clean tree before building. Use `npx prettier --check <files>` when a non-mutating frontend format check is needed.
- Backend CI is `ruff format --check . --exclude .venv --exclude venv`; format backend edits with `npm run format:backend`. `npm run lint:backend` runs Pylint across `backend/`.

## Delivery Constraints

- Develop custom changes in `feature/*`, merge official releases and features into `integration/vX.Y.Z`, then open verified integration PRs against `main`. Use typed PR titles and keep the required CLA section in the PR description.
- The root Compose configuration is deployment-specific: it loads `.env.openwebui.oauth`, exposes port 80, and joins `shared_bridge_network`. Do not assume it is a generic local development stack.

## Development And Release Workflow (5 Stages)

Full lifecycle for any change destined for production. Stages 1–4 use Linear (`koreatimes` workspace, project `openwebui vX.Y.Z`); stage 5 stays on GitHub Issue per the existing opencode production agent contract.

1. **계획 (Planning)** — Planner agent creates Linear Project + Parent issue + Sub-issues. Label: `plan-draft`. Uses parent/child hierarchy, `blockedBy` for dependencies, `gitBranchName` auto-generated for future branch naming.
2. **계획 검증 (Plan verification)** — Planner transitions parent label `plan-draft` → `needs-review`. Verifier agent picks up via `list_issues --label needs-review`, posts findings as issue comments (PASS/CRITICAL/MEDIUM/MINOR + verdict), transitions label to `plan-approved` (approved) or back to `plan-draft` (revision requested). Comment thread is the audit surface.
3. **개발 (Development)** — Dev agent picks up a `plan-approved` sub-issue, creates feature branch using the issue's `gitBranchName` field. Standard `feature/* → integration/vX.Y.Z → main` flow (see §"Release Routine And Session Continuity" below). Linear issue tracks status ("In Progress") as a progress pointer; git holds the truth.
4. **개발 검증 (Dev review)** — Dev agent transitions issue label to `verify-request`. Verifier agent picks up, reviews diff (via GitHub PR linked to the Linear issue as `create_attachment`), posts findings, transitions to `verify-passed`. Same comment-thread audit pattern as stage 2.
5. **배포 (Deployment)** — **Unchanged, stays on GitHub Issue.** Local dev agent submits `Production deployment request` Issue per handoff §"배포 요청 계약" (Protocol v1.2). Opencode production agent executes via `deploy-approved-production-release.yaml` workflow. Linear issue references the GitHub deployment Issue URL via `create_attachment` for audit trail.

**Label vocabulary** (workspace-level, created 2026-08-11):

| Label | Color | Meaning |
| ----- | ----- | ------- |
| `plan-draft` | gray | Planner is still writing the plan |
| `needs-review` | yellow | Plan complete, awaits plan verifier |
| `plan-approved` | teal | Plan verified, ready for dev pickup |
| `verify-request` | orange | Dev complete, awaits dev verifier |
| `verify-passed` | green | Dev verified, ready for deployment handoff to GitHub |

**Rationale**: Stages 1–2 (planning + plan verification) gain the most from Linear's hierarchical issue model and comment-based review — text-only planning misses design gaps that comment threads catch. Deployment stays on GitHub because the opencode production agent contract is stable and changing it would risk regression. Validated in the 2026-08-11 scenario-B walkthrough (see `docs/jobs/2026-08-11-openwebui-jobs.md`), where the verifier caught a Bootstrap paradox in the runner health monitoring plan that the planner had missed.

**Note on jobs log coexistence**: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` remains the session-level truth (append-only, cross-session context). Linear comments are per-issue conversation. Use both, don't duplicate.

## Release Routine And Session Continuity

Reference these before touching the release or deploy path:

- **Practical routine (start here)**: `docs/manual/kwh-release-routine.md` — end-to-end feature → integration → RC → staging → PR → main → final tag → prod flow, with copy-paste SSH blocks, environment variables inventory, SQLite WAL-safe backup, smoke checklist, and recovery patterns.
- **Top authority (coordination protocol)**: `docs/manual/github-control-plane-local-agent-handoff.ko.md` — **Protocol v1.2. In any conflict on release/deploy coordination, this wins.** Covers: local↔production agent handoff, GitHub as control plane, required release flow (all changes including docs through `feature/* → integration/vX.Y.Z → main`), deploy request Issue schema, production agent reply contract, incident matrix, state awareness.
- **Authoritative rules (CI/CD mechanics)**: `docs/manual/github-actions-ghcr-release-deployment.md` — tag rules, GHCR conventions, image build policy. Wins when conflict is CI/CD-specific and not covered by the coordination protocol above. Covers:
  - Repository roles (`origin` push target; `upstream` fetch-only with push URL `DISABLED`).
  - Branch and release flow (`feature/*` → `integration/vX.Y.Z` via `--no-ff` → PR → `main` → tag).
  - Image build policy (immutable tags, `linux/amd64`, buildx registry cache, `v*-kwh.*` workflow trigger, RC vs final tag semantics).
  - Deployment policy (compose files: `docker-compose.deploy.yaml` for prod, `docker-compose.staging.yaml` for isolated staging, `docker-compose-build.yaml` for dev only; pre-deploy backup; rollback via prior image tag).
  - Model cache considerations for slim vs non-slim builds.
- **Session/work history**: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` under `~/projects/openwebui-service/docs/jobs/`. Each file records that day's decisions, commits, PRs, and learnings for cross-session context. Same-day work: **append** as a new `## HH:MM` section. Date change: **new file**. Consult prior days' logs before repeating work.
- **GHCR image tag format**: `vX.Y.Z-kwh.N` (with the `v` prefix, verbatim from the git tag) and `git-<7-char-short-sha>`. Bare `X.Y.Z-kwh.N` or a full 40-char SHA are not published and will fail to `docker pull`.
- **Never commit directly to `main`.** If it happens locally, preserve the commit by creating `feature/<slug>` at that SHA, `git reset --hard origin/main`, then merge the feature into `integration/vX.Y.Z` with `--no-ff`. Verified recovery: 2026-07-22 with commit `c68c745d2`.
- **All changes (including docs)** follow the same flow: `feature/*` → `integration/vX.Y.Z` → PR → `main`. Direct `feature/docs-*` → `main` shortcut is **abolished** (2026-07-31).
