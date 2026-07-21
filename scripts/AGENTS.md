<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# scripts

## Purpose
Build- and packaging-time helper scripts invoked by `npm` targets. `prepare-pyodide.js` runs before every `dev`, `build`, and `check` (via `npm run pyodide:fetch`) to fetch Pyodide runtime assets into `../static/pyodide`. `generate-sbom.sh` produces a Software Bill of Materials for release artifacts.

## Key Files

| File | Description |
|------|-------------|
| `prepare-pyodide.js` | Downloads Pyodide wheels and lockfile into `../static/pyodide/`; invoked by every `dev`/`build`/`check` |
| `generate-sbom.sh` | Generates SBOM for the built distribution (used by release automation) |

## For AI Agents

### Working In This Directory
- `prepare-pyodide.js` is on the hot path for every frontend command. Keep it idempotent — it should be a no-op on re-runs when the target assets already exist.
- Do not commit anything under `../static/pyodide/` — the fetch script populates it locally and CI runs it fresh.
- If you change what `prepare-pyodide.js` downloads, verify the Pyodide version matches the `pyodide` dependency pin in `../package.json`.

### Testing Requirements
- Run `npm run pyodide:fetch` to verify the fetch script still succeeds against the pinned Pyodide version.
- SBOM script is exercised by release workflows in `.github/workflows/`.

### Common Patterns
- Shell scripts use `set -euo pipefail`; Node scripts are ES modules (project `"type": "module"`).

## Dependencies

### Internal
- Called from `../package.json` scripts (`pyodide:fetch`, `dev`, `build`, `build:watch`).
- Output consumed by `../src/lib/pyodide/` and served from `../static/pyodide/`.

### External
- Node.js `>=18.13.0 <=22.x.x` (matches the `engines` field in `../package.json`).
- Pyodide CDN for asset downloads.

<!-- MANUAL: -->
