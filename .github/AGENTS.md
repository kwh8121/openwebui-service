<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# .github

## Purpose
GitHub-specific repo configuration: CI/CD workflows, issue and PR templates, Dependabot config, and funding metadata. The active CI covers backend format checks, frontend build/format/i18n checks, Docker image builds, and PyPI + GHCR release publishing. Files with a `.disabled` suffix under `workflows/` are intentionally inert — do not rename them to `.yml`/`.yaml` without an explicit decision.

## Key Files

| File | Description |
|------|-------------|
| `FUNDING.yml` | GitHub Sponsors / funding link metadata |
| `dependabot.yml` | Automated dependency update schedule and scopes |
| `pull_request_template.md` | PR template — includes the required CLA section referenced by the root `AGENTS.md` |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `ISSUE_TEMPLATE/` | Structured issue forms for bug reports, feature requests, etc. |
| `workflows/` | GitHub Actions workflows — `backend.yaml`, `frontend.yaml`, `docker.yaml`, `release.yml`, `release-pypi.yml`, plus disabled variants |

## For AI Agents

### Working In This Directory
- CI runs `npm run format`, `npm run i18n:parse`, then requires a clean tree before building. Any workflow change should preserve that gate.
- `.disabled` workflow files are kept for reference. Enabling one requires an explicit user decision — do not rename them silently.
- The GHCR release workflow has an operator playbook at `../docs/manual/github-actions-ghcr-release-deployment.md`; keep them in sync when the workflow changes.
- PR template edits are visible to every contributor — keep the CLA section intact.

### Testing Requirements
- Actions can be validated locally with `actionlint` if available. Otherwise, push to a branch and observe workflow runs.
- Test workflow changes on a branch, never directly on `main`.

### Common Patterns
- Workflows use `pinned` action versions (SHA or tag) — do not switch to floating `@main`.

## Dependencies

### Internal
- Consumes `../package.json` scripts (`format`, `i18n:parse`, `check`, `build`, `lint:*`).
- Consumes `../pyproject.toml` for backend format/lint checks.
- Docker workflow builds `../Dockerfile`.

### External
- GitHub Actions runners, GHCR, PyPI.

<!-- MANUAL: -->
