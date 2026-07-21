<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# backend

## Purpose

Python FastAPI backend for Open WebUI. This directory is a thin wrapper: entry scripts, pinned Python requirements, and Docker-ignore rules live here, while the actual application package is `open_webui/`. `dev.sh` and `start.sh` are the supported entry points; the packaged distribution invokes `open-webui serve` instead.

## Key Files

| File                   | Description                                                                      |
| ---------------------- | -------------------------------------------------------------------------------- |
| `dev.sh`               | Local reload server on port 8080; allows the Vite dev origin for full-stack work |
| `start.sh`             | Production entry script used by the container image                              |
| `start_windows.bat`    | Windows equivalent of `start.sh`                                                 |
| `requirements.txt`     | Frozen full runtime dependencies (mirrors `pyproject.toml`)                      |
| `requirements-min.txt` | Minimal dependency set for lean installs                                         |
| `.dockerignore`        | Paths excluded when building the backend image                                   |
| `.gitignore`           | Backend-specific ignores (e.g. `data/`, `.webui_secret_key`)                     |

## Subdirectories

| Directory     | Purpose                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------- |
| `open_webui/` | FastAPI application package — routers, models, migrations, utilities (see `open_webui/AGENTS.md`) |
| `data/`       | Runtime state written by the server (SQLite DB, uploaded files, cache). Do **not** commit.        |

## For AI Agents

### Working In This Directory

- Never commit `data/`, `.webui_secret_key`, `chroma.sqlite3`, `webui.db`, or anything the running server generates.
- Modify Python dependencies in the root `pyproject.toml`. If you must edit `requirements.txt` directly, keep it in sync with `pyproject.toml`.
- `dev.sh` expects to be executed from this `backend/` directory, not from the repo root.

### Testing Requirements

- Backend format check: `ruff format --check . --exclude .venv --exclude venv`.
- Apply fixes with `npm run format:backend` from the repo root.
- Lint: `npm run lint:backend` (Pylint across `backend/`).

### Common Patterns

- Run alongside `npm run dev` (Vite on 5173) to develop the full stack. The reload server on 8080 whitelists the Vite origin.
- Alembic migrations live in `open_webui/migrations/`; generate with `DATABASE_URL=<url> alembic revision --autogenerate -m "description"`.

## Dependencies

### Internal

- `../pyproject.toml` — canonical dependency manifest; `requirements*.txt` are derived views.
- `../Dockerfile` — consumes `start.sh` and packaged wheel.

### External

- FastAPI, Uvicorn, SQLAlchemy, Alembic, Pydantic — full pins in `pyproject.toml`.

<!-- MANUAL: -->
