#!/usr/bin/env bash
#
# local-test.sh — Pre-deploy local verification for GHCR openwebui-service images.
#
# Purpose:
#   Pull a final GHCR image, boot it in an isolated local container, and confirm
#   image integrity (container running, no startup errors, /health 200) before
#   an SSH production deploy. This is an *additional* defense line — it never
#   replaces the RC → staging gate.
#
# Usage:
#   ./scripts/local-test.sh <image-tag> [--reuse-data] [--allow-rc]
#   ./scripts/local-test.sh <image-tag> --down
#
# Flags:
#   --down         Stop and remove the local-test container (bind-mount data dir kept)
#   --reuse-data   Skip the empty-data-directory guard (empty DB migration check is skipped)
#   --allow-rc     Also accept RC tags (v...-kwh.N-rc.M) — pull-only sanity, not a staging replacement
#
# Env overrides (optional):
#   OPENWEBUI_LOCAL_TEST_DATA   Bind-mount data dir (default: $HOME/openwebui-local-test-data)
#   OPENWEBUI_LOCAL_TEST_PORT   Host port (default: 8082)
#   OPENWEBUI_LOCAL_TEST_ENV_FILE   Env file (default: ./.env.local-test)

set -euo pipefail

# Resolve repo root from script location so it works from any cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.local-test.yaml"
ENV_TEMPLATE="${REPO_ROOT}/.env.local-test.template"
ENV_FILE_DEFAULT="${REPO_ROOT}/.env.local-test"

DEFAULT_DATA_DIR="${HOME}/openwebui-local-test-data"
DEFAULT_PORT=8082
IMAGE_REPO="ghcr.io/kwh8121/openwebui-service"

# --- Arg parsing ----------------------------------------------------------
IMAGE_TAG=""
DOWN=0
REUSE_DATA=0
ALLOW_RC=0

usage() {
  # Print the leading comment block (skip shebang), stopping at the first non-comment line.
  awk 'NR>1 { if ($0 ~ /^#/) { sub(/^# ?/, ""); print } else { exit } }' "${BASH_SOURCE[0]}"
  exit 2
}

if [[ $# -eq 0 ]]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --down) DOWN=1 ;;
    --reuse-data) REUSE_DATA=1 ;;
    --allow-rc) ALLOW_RC=1 ;;
    -h|--help) usage ;;
    -*)
      echo "ERROR: unknown flag: $arg" >&2
      usage
      ;;
    *)
      if [[ -n "$IMAGE_TAG" ]]; then
        echo "ERROR: multiple image tags given: '$IMAGE_TAG' and '$arg'" >&2
        exit 2
      fi
      IMAGE_TAG="$arg"
      ;;
  esac
done

if [[ -z "$IMAGE_TAG" ]]; then
  echo "ERROR: image tag argument is required" >&2
  usage
fi

# --- Tag format validation (v3 strict) ------------------------------------
FINAL_TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+-kwh\.[0-9]+$'
RC_TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+-kwh\.[0-9]+-rc\.[0-9]+$'

IS_RC=0
if [[ "$IMAGE_TAG" =~ $FINAL_TAG_RE ]]; then
  :
elif [[ "$IMAGE_TAG" =~ $RC_TAG_RE ]]; then
  IS_RC=1
  if [[ $ALLOW_RC -ne 1 ]]; then
    cat >&2 <<EOF
ERROR: '${IMAGE_TAG}' is an RC tag.

This script is for final-tag verification (v0.10.2-kwh.N).
RC tags must be verified through the staging gate (docker-compose.staging.yaml).
To run this script as a pull-only sanity check on an RC tag, add: --allow-rc
EOF
    exit 2
  fi
else
  cat >&2 <<EOF
ERROR: '${IMAGE_TAG}' does not match required tag format.

Expected: v<MAJOR>.<MINOR>.<PATCH>-kwh.<N>            (e.g., v0.10.2-kwh.2)
   or with --allow-rc: v<MAJOR>.<MINOR>.<PATCH>-kwh.<N>-rc.<M>

Tags without the leading 'v' are not published to GHCR and will fail to pull.
EOF
  exit 2
fi

# --- --down short-circuit -------------------------------------------------
if [[ $DOWN -eq 1 ]]; then
  export OPENWEBUI_LOCAL_TEST_TAG="$IMAGE_TAG"
  export OPENWEBUI_LOCAL_TEST_DATA="${OPENWEBUI_LOCAL_TEST_DATA:-$DEFAULT_DATA_DIR}"
  echo "Stopping local-test container (compose down)..."
  docker compose -f "$COMPOSE_FILE" down
  echo "Done. Bind-mount data dir left intact at: $OPENWEBUI_LOCAL_TEST_DATA"
  exit 0
fi

# --- Prereq: ghcr.io auth -------------------------------------------------
DOCKER_CONFIG_FILE="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
if [[ ! -f "$DOCKER_CONFIG_FILE" ]] || ! grep -q 'ghcr.io' "$DOCKER_CONFIG_FILE" 2>/dev/null; then
  cat >&2 <<EOF
ERROR: ghcr.io login not detected in ${DOCKER_CONFIG_FILE}.
Run once (PAT needs read:packages scope):
  docker login ghcr.io -u kwh8121
EOF
  exit 3
fi

# --- Prereq: data directory state check (v3) -----------------------------
DATA_DIR="${OPENWEBUI_LOCAL_TEST_DATA:-$DEFAULT_DATA_DIR}"

if [[ ! -e "$DATA_DIR" ]]; then
  echo "Creating fresh data directory: $DATA_DIR"
  mkdir -p "$DATA_DIR"
elif [[ ! -d "$DATA_DIR" ]]; then
  echo "ERROR: $DATA_DIR exists but is not a directory" >&2
  exit 4
else
  # Directory exists — check emptiness.
  if [[ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]]; then
    if [[ $REUSE_DATA -ne 1 ]]; then
      cat >&2 <<EOF
ERROR: data directory '${DATA_DIR}' is not empty.

The default verification target is a fresh install migration on an empty DB.
Options:
  (a) wipe and re-run:      rm -rf "${DATA_DIR}"/*
  (b) reuse existing state: rerun with --reuse-data (fresh-migration check is skipped)
EOF
      exit 4
    else
      echo "WARN: --reuse-data set — reusing existing data at ${DATA_DIR}."
      echo "WARN: fresh-migration verification is SKIPPED."
    fi
  fi
fi

# --- Prereq: env file -----------------------------------------------------
ENV_FILE="${OPENWEBUI_LOCAL_TEST_ENV_FILE:-$ENV_FILE_DEFAULT}"
if [[ ! -f "$ENV_FILE" ]]; then
  cat >&2 <<EOF
ERROR: env file not found: ${ENV_FILE}
Create it from the tracked template:
  cp "${ENV_TEMPLATE}" "${ENV_FILE_DEFAULT}"
Then re-run.
EOF
  exit 5
fi

# --- Pull image -----------------------------------------------------------
FULL_IMAGE="${IMAGE_REPO}:${IMAGE_TAG}"
echo "Pulling ${FULL_IMAGE}..."
if ! docker pull "$FULL_IMAGE"; then
  echo "ERROR: docker pull failed for ${FULL_IMAGE}" >&2
  echo "Verify the tag exists on GHCR and that your PAT can read the package." >&2
  exit 6
fi

# --- Start container ------------------------------------------------------
export OPENWEBUI_LOCAL_TEST_TAG="$IMAGE_TAG"
export OPENWEBUI_LOCAL_TEST_DATA="$DATA_DIR"
export OPENWEBUI_LOCAL_TEST_ENV_FILE="$ENV_FILE"
PORT="${OPENWEBUI_LOCAL_TEST_PORT:-$DEFAULT_PORT}"
export OPENWEBUI_LOCAL_TEST_PORT="$PORT"

echo "Starting compose (port 127.0.0.1:${PORT})..."
docker compose -f "$COMPOSE_FILE" up -d

# --- Triple success check -------------------------------------------------
FAIL=0

# 1) ps state must be 'running'
STATE="$(docker compose -f "$COMPOSE_FILE" ps openwebui --format '{{.State}}' 2>/dev/null || true)"
echo "compose ps state: ${STATE:-<empty>}"
if [[ "$STATE" != "running" ]]; then
  echo "ERROR: container state is not 'running'" >&2
  FAIL=1
fi

# 2) logs scan for startup error keywords
echo "--- last 100 log lines ---"
LOG_OUT="$(docker compose -f "$COMPOSE_FILE" logs --tail 100 openwebui 2>&1 || true)"
echo "$LOG_OUT"
echo "--- end logs ---"
if grep -Eiq 'Traceback|ERROR|Failed to start' <<<"$LOG_OUT"; then
  echo "ERROR: startup error keywords detected in logs (Traceback|ERROR|Failed to start)" >&2
  FAIL=1
fi

# 3) health poll up to 60s (5s interval)
HEALTH_URL="http://127.0.0.1:${PORT}/health"
HEALTHY=0
echo "Polling ${HEALTH_URL} (up to 60s)..."
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if curl -sf --max-time 3 "$HEALTH_URL" >/dev/null 2>&1; then
    HEALTHY=1
    break
  fi
  sleep 5
done
if [[ $HEALTHY -eq 1 ]]; then
  echo "OK: /health returned 200"
else
  echo "ERROR: /health did not return 200 within 60s" >&2
  FAIL=1
fi

# --- Report ---------------------------------------------------------------
if [[ $FAIL -eq 0 ]]; then
  cat <<EOF

===============================================================
[PASS] automated checks OK for ${FULL_IMAGE}
Open:  http://127.0.0.1:${PORT}
Now run the browser manual checklist (see docs/plan/local-test-workflow.md).
Teardown: ./scripts/local-test.sh ${IMAGE_TAG} --down
===============================================================
EOF
  exit 0
else
  cat >&2 <<EOF

===============================================================
[FAIL] one or more automated checks failed for ${FULL_IMAGE}
Inspect logs:
  docker compose -f docker-compose.local-test.yaml logs openwebui
Teardown:
  ./scripts/local-test.sh ${IMAGE_TAG} --down
EOF
  if [[ $IS_RC -ne 1 ]]; then
    cat >&2 <<EOF
--- immutable final-tag rule (docs/manual/kwh-release-routine.md §3.9-b) ---
Final tags are immutable. Do NOT rebuild or overwrite ${IMAGE_TAG}.
Fix the underlying issue, then cut the next release number (e.g., kwh.N+1)
and re-run the pipeline from staging (§3.5) onward.
===============================================================
EOF
  else
    echo "===============================================================" >&2
  fi
  exit 1
fi
