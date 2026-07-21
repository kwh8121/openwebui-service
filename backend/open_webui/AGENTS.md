<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# open_webui

## Purpose
The FastAPI application package. `main.py` creates the app, registers routers under `/api/v1`, `/ollama`, and `/openai`, then mounts the built frontend as the SPA fallback. Configuration is centralized in `config.py` (persisted, DB-backed settings) and `env.py` (environment variables). Alembic migrations live in `migrations/`, SQLAlchemy models in `models/`, HTTP routers in `routers/`, and cross-cutting helpers in `utils/`. This package is what `open-webui serve` boots, and it is also packaged as the wheel entry point (`open_webui:app`).

## Key Files

| File | Description |
|------|-------------|
| `main.py` | FastAPI app factory, middleware wiring, router registration, SPA mount, lifespan hooks |
| `config.py` | Persistent (DB-backed) settings — feature flags, tunables, provider configs |
| `env.py` | Environment-variable-only config — read at boot, not persisted |
| `constants.py` | Enum-style constants and error codes shared across routers |
| `events.py` | Socket.IO / SSE event definitions and dispatchers |
| `functions.py` | Function-calling runtime for chat pipelines |
| `tasks.py` | APScheduler background tasks (title generation, cleanup, etc.) |
| `__init__.py` | Exposes `app` for `open-webui serve` and the wheel entry point |
| `alembic.ini` | Alembic configuration; points at `migrations/` |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `routers/` | HTTP routers mounted under `/api/v1` (chats, auths, files, knowledge, ollama, openai, retrieval, …). One file per feature area. |
| `models/` | SQLAlchemy ORM models and repository-style `*Table` helpers |
| `migrations/` | Alembic environment + `versions/` scripts. Generate via `DATABASE_URL=<url> alembic revision --autogenerate -m "…"` |
| `utils/` | Cross-cutting helpers: `auth.py`, `middleware.py`, `oauth.py`, `tools.py`, `redis.py`, `telemetry/`, `mcp/`, `access_control/`, `images/` |
| `retrieval/` | RAG stack — `loaders/`, `models/` (embedders/rerankers), `vector/` (DB backends), `web/` (search), plus `utils.py` and `external.py` |
| `socket/` | Socket.IO server integration for real-time channels |
| `tools/` | Built-in tool implementations exposed to chat pipelines |
| `storage/` | Storage abstraction (local / S3 / GCS / Azure Blob) |
| `internal/` | Internal-only helpers not part of the public router surface |
| `static/` | Static assets served by FastAPI (Swagger UI, fonts, images) — do not confuse with the frontend `../../static/` |
| `data/` | Runtime data written by the server (SQLite DB, uploads). Do **not** commit. |

## For AI Agents

### Working In This Directory
- `main.py` is very large (~100K). Prefer editing the target router or util module rather than growing `main.py` further.
- When adding a router, register it in `main.py` under the correct URL prefix (`/api/v1/<feature>`) and follow the auth-decorator patterns used by peer routers (`Depends(get_verified_user)` / `get_admin_user`).
- New settings: prefer `env.py` for boot-time env vars, `config.py` for anything the admin should toggle at runtime.
- Any schema change requires an Alembic migration under `migrations/versions/`. Autogenerate, then hand-edit for correctness — autogen misses server defaults and enum changes.
- Do not commit `data/` or `.webui_secret_key`; both are runtime state.

### Testing Requirements
- Format check: `ruff format --check . --exclude .venv --exclude venv` (from `../../`).
- Apply formatting: `npm run format:backend` from repo root.
- Lint: `npm run lint:backend` (Pylint).
- Integration tests require the `all` extras group from `../../pyproject.toml`.

### Common Patterns
- Router files pair a Pydantic request/response model with a `*Form` schema and delegate persistence to `models/<feature>.py::<Feature>Table`.
- Long-running work is scheduled via `tasks.py` / APScheduler, not spawned ad-hoc.
- Provider integrations (Ollama, OpenAI, Anthropic, Google) each have a dedicated router + a util module (e.g. `utils/anthropic.py`) that owns request shaping.

## Dependencies

### Internal
- `../pyproject.toml` (dependency source of truth), `../requirements.txt` (derived pinned view).
- `../dev.sh` / `../start.sh` boot this package.
- Wheel packaging: `pyproject.toml` sets `sources = ["backend"]` and force-includes `build/` at `open_webui/frontend`.

### External
- FastAPI, Uvicorn, SQLAlchemy 2.x, Alembic, Pydantic 2.x, python-socketio, redis, APScheduler, LangChain, ChromaDB, tiktoken, MCP SDK — full pins in `../../pyproject.toml`.

<!-- MANUAL: -->
