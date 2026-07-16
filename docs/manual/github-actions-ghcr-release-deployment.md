# GitHub Actions And GHCR Release Deployment

## Purpose

Build Open WebUI images outside the production server, publish immutable images to GitHub Container Registry (GHCR), and deploy only verified image tags. This prevents source builds from consuming production CPU, memory, disk I/O, and network capacity.

## Repository Roles

| Remote     | Role                                                                                          |
| ---------- | --------------------------------------------------------------------------------------------- |
| `origin`   | `https://github.com/kwh8121/openwebui-service.git`; the operational fork and only push target |
| `upstream` | `https://github.com/open-webui/open-webui.git`; the official Open WebUI fetch-only source     |

The `upstream` push URL is set to `DISABLED` to prevent accidental pushes to the official repository.

## Branch And Release Flow

1. Fetch official release tags with `git fetch upstream --tags`.
2. Create or update `integration/vX.Y.Z` from the current `main` branch.
3. Merge the selected official release into the integration branch.
4. Develop custom changes in `feature/*` branches and merge them into the integration branch with `--no-ff`.
5. Run CI and staging validation.
6. Open a pull request from `integration/vX.Y.Z` to `main`.
7. Merge only after review and required staging checks pass.
8. Create a release tag such as `v0.10.2-kwh.1` from the approved `main` commit.

`main` is the operational source of truth. Do not deploy directly from an integration or feature branch.

## Image Build Policy

GitHub Actions builds and pushes images to:

```text
ghcr.io/kwh8121/openwebui-service
```

Use immutable release and commit tags:

```text
0.10.2-kwh.1
git-<commit-sha>
```

Do not use mutable tags such as `main` or `latest` for production deployment. Buildx registry cache is stored in GHCR and shared across CI runs with `cache-from` and `cache-to`. This reuses unchanged frontend and Python dependency layers.

The workflow requires `contents: read` and `packages: write` permissions. A production server pulling a private GHCR image must use a separate read-only package token; never copy the GitHub Actions `GITHUB_TOKEN` to the server.

## Deployment Policy

`docker-compose-build.yaml` is for development builds and retains its `build:` section. It must not be the production deployment definition.

Create and maintain a separate `docker-compose.deploy.yaml` that:

- Has no `build:` section.
- References `ghcr.io/kwh8121/openwebui-service:${OPENWEBUI_IMAGE_TAG}`.
- Preserves existing ports, networks, environment files, and bind mounts.
- Keeps `/app/backend/data` and `/app/pipelines` persistent across container replacement.

Deployment uses a fixed image tag and recreates only Open WebUI:

```bash
docker compose -f docker-compose.deploy.yaml pull openwebui
docker compose -f docker-compose.deploy.yaml up -d --no-deps openwebui
```

Before deployment, back up `/app/backend/data` and `/app/pipelines`. After deployment, verify the health endpoint, authentication, a model request, RAG retrieval, file upload, and pipeline connectivity. Roll back by restoring the prior image tag. Image rollback does not necessarily reverse a database migration.

## Model Cache Consideration

The Dockerfile downloads embedding and Whisper assets during a non-slim image build. The production bind mount at `/app/backend/data` can hide those image-layer caches at runtime. This can increase image size and CI build time without improving production startup.

Before changing this behavior, validate a slim build or a separately persisted model cache in staging. Confirm the first RAG and audio requests, download behavior, and cold-start time.

## Current Integration Status

As of 2026-07-16:

- Official Open WebUI `v0.10.2` is integrated in `integration/v0.10.2`.
- Pull request: `https://github.com/kwh8121/openwebui-service/pull/1`.
- The integration branch includes formatting fixes required by CI and a frontend CI Node heap limit of 6144 MB.
- GitHub Actions checks pass: frontend format and build, frontend unit tests, and Ruff formatting on Python 3.11 and 3.12.
- `main` has not been merged and no production deployment has been performed.

## Remaining Release Steps

1. Create a staging copy of production data; do not test migrations against the only production copy.
2. Start the `v0.10.2` integration image in staging.
3. Verify database migrations, OAuth, RAG, uploads, pipelines, and health checks.
4. Review and merge pull request #1 after staging validation succeeds.
5. Tag the merged commit as `v0.10.2-kwh.1`.
6. Build and push the GHCR image from that tag.
7. Update `OPENWEBUI_IMAGE_TAG` on the production server and deploy with `docker-compose.deploy.yaml`.
8. Run smoke tests and retain the prior release tag for rollback.
