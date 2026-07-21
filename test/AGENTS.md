<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# test

## Purpose

Fixture directory for tests. Actual test suites are colocated with source code: Vitest specs sit next to the frontend files they cover (invoked via `npm run test:frontend`), and Python tests live under `../backend/` (opt-in via the `all` extras group in `../pyproject.toml`). This directory only holds shared binary fixtures that would clutter source trees.

## Subdirectories

| Directory     | Purpose                                                               |
| ------------- | --------------------------------------------------------------------- |
| `test_files/` | Static fixtures (e.g. `image_gen/`) referenced by tests as input data |

## For AI Agents

### Working In This Directory

- Add new fixtures under `test_files/<domain>/` and reference them by path from the test that needs them; do not scatter binaries throughout the tree.
- Keep fixtures small. If a fixture must be large, consider whether it should live outside the repo (Git LFS or a fixtures registry) and be fetched on demand.
- Do not put test _code_ here. Frontend specs live next to the source; backend specs live under `../backend/`.

### Testing Requirements

- Frontend: `npm run test:frontend -- <path>` (Vitest, `--passWithNoTests` by default).
- Backend: install with the `all` extras group and use `pytest` per the fixtures in `../pyproject.toml`.

### Common Patterns

- Fixture files are read-only inputs — tests must not mutate them.

## Dependencies

### Internal

- Consumed by Vitest specs across `../src/` and by pytest suites in `../backend/`.

### External

- None (this directory ships only static data).

<!-- MANUAL: -->
