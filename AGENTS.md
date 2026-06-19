# Repository Guidelines

## Project Structure & Module Organization

Open WebUI combines a SvelteKit frontend with a Python FastAPI backend. Frontend routes live in `src/routes`, shared UI and client utilities in `src/lib`, and global styles in `src/app.css` and `src/tailwind.css`. Backend code is under `backend/open_webui`; key areas include `routers`, `models`, `utils`, `retrieval`, and Alembic `migrations`. Static web assets are in `static`, with packaged backend copies in `backend/open_webui/static`. Test fixtures currently live under `test/test_files`.

## Build, Test, and Development Commands

- `npm run dev`: fetches Pyodide assets and starts Vite.
- `npm run dev:5050`: starts the frontend on port 5050.
- `npm run build`: builds the SvelteKit app.
- `npm run preview`: previews the production frontend build.
- `npm run check`: runs `svelte-check`.
- `npm run lint`: runs frontend ESLint, Svelte type checks, and backend Pylint.
- `npm run test:frontend`: runs Vitest.
- `npm run cy:open`: opens Cypress.
- `make install`, `make start`, `make stop`: manage the Docker Compose stack.

## Coding Style & Naming Conventions

Use nearby files as the source of truth. Prettier formats JS, TS, Svelte, CSS, Markdown, HTML, and JSON with tabs, single quotes, no trailing commas, LF endings, and a 100-column print width. Python uses Ruff formatting with single quotes and a 120-column line length. Name Svelte components `PascalCase.svelte`, TypeScript modules with descriptive `camelCase` or domain names, and Python modules `snake_case.py`.

## Testing Guidelines

Place focused frontend unit tests near the feature using `.test.ts` or `.spec.ts` names. Use Cypress for browser flows and document required backend or fixture setup. For backend changes, add pytest coverage where practical and keep reusable fixtures under `test/`. Run the relevant subset plus `npm run check` before opening a PR.

## Commit & Pull Request Guidelines

Recent history uses short subjects such as `refac`, release labels, and merge commits; the PR template requires typed title prefixes such as `feat`, `fix`, `docs`, `refactor`, `test`, `build`, or `chore`. Keep changes atomic and target `dev`. PRs should link an issue or discussion, describe behavior changes, include a Keep a Changelog-style entry, note dependency changes, and add screenshots or recordings for UI work. Do not remove the CLA section.

## Security & Configuration Tips

Do not commit secrets, local databases, generated environment files, or private model data. Use environment variables for provider keys and service URLs, and keep runtime data in `backend/data` or Docker volumes.
