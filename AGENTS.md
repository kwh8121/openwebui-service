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

## Release Routine And Session Continuity

Reference these before touching the release or deploy path:

- **Practical routine (start here)**: `docs/manual/kwh-release-routine.md` — end-to-end feature → integration → RC → staging → PR → main → final tag → prod flow, with copy-paste SSH blocks and recovery patterns.
- **Authoritative rules**: `docs/manual/github-actions-ghcr-release-deployment.md` — if any doc conflicts with this one, this wins.
- **Session/work logs**: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` — append same-day work; new file only when the date rolls over.
- **GHCR image tag format**: `vX.Y.Z-kwh.N` (with the `v` prefix, verbatim from the git tag) and `git-<7-char-short-sha>`. Bare `X.Y.Z-kwh.N` or a full 40-char SHA are not published and will fail to `docker pull`.
- **Never commit directly to `main`.** If it happens locally, preserve the commit by creating `feature/<slug>` at that SHA, `git reset --hard origin/main`, then merge the feature into `integration/vX.Y.Z` with `--no-ff`. Verified recovery: 2026-07-22 with commit `c68c745d2`.
- **Doc-only changes** skip the integration cycle: branch from `main`, PR directly to `main`, no new tag.
