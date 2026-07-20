<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# pipelines

## Purpose
Open WebUI **Pipelines** — external Python modules loaded by the Pipelines runtime (separate service) to expose filters, manifolds, and pass-through model providers to the chat backend. Each file here is a self-contained pipeline plugin; there is no package structure. The router that talks to the Pipelines service lives at `../backend/open_webui/routers/pipelines.py`.

## Key Files

| File | Description |
|------|-------------|
| `n8n_pipeline.py` | Bridges chat completions into an n8n workflow endpoint |
| `wikipedia_pipeline.py` | Wikipedia lookup pipeline for retrieval-augmented responses |
| `perplexity_manifold_pipeline.py` | Manifold pipeline exposing Perplexity models |
| `dify_pipeline_local_org.py` | Dify bridge — local organization deployment |
| `dify_pipeline_outer_dify.py` | Dify bridge — external Dify instance |
| `dify_pipeline_outer_dify_stylebook.py` | Dify bridge variant with stylebook-specific prompting |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `failed/` | Quarantine directory for pipelines that failed to load. The Pipelines runtime moves broken files here at startup — inspect, fix, and move back into `../` when repaired. |

## For AI Agents

### Working In This Directory
- Each pipeline is a standalone module. Follow the Open WebUI Pipelines contract: define a `Pipeline` class with a `Valves` Pydantic model plus `on_startup`/`on_shutdown`/`pipe` (or `inlet`/`outlet` for filters).
- These files run inside the Pipelines container, not the main backend. Do not import from `open_webui.*`. Only stdlib + packages available in the Pipelines runtime image.
- Secrets go through `Valves`, not environment variables baked into the file.

### Testing Requirements
- No unit tests in-tree. Validate by loading the pipeline in a running Pipelines instance and issuing a chat request through the connected Open WebUI.
- Broken pipelines land in `failed/` — check the Pipelines container logs for the load error.

### Common Patterns
- `pipe()` returns a string or an iterator of strings (for streaming); use SSE-shaped payloads only when the pipeline sits behind a manifold that expects them.
- The `dify_pipeline_*` variants share a lot of code — when editing one, check if the change applies to the siblings.

## Dependencies

### Internal
- Loaded by the external Open WebUI Pipelines service (not this repo). The backend talks to that service via `../backend/open_webui/routers/pipelines.py`.

### External
- `httpx`/`requests` for outbound calls, `pydantic` for `Valves`. No shared repo dependencies.

<!-- MANUAL: -->
