#!/usr/bin/env bash
#
# local-test.sh — Local production-mirror verification for GHCR openwebui-service (v4).
#
# Purpose:
#   Pull a GHCR image and boot it locally in an isolated compose that mirrors
#   the production stack (openwebui + pipelines). Verifies image integrity,
#   upgrade migration on accumulated data, brand assets, and /health.
#   Replaces the co-located "staging on prod host" gate.
#
# Usage:
#   ./scripts/local-test.sh <image-tag> [--fresh] [--no-backup] [--allow-rc] [--reseed-cache]
#   ./scripts/local-test.sh --down
#   ./scripts/local-test.sh --list-backups
#   ./scripts/local-test.sh --restore <timestamp>
#   ./scripts/local-test.sh --prune-backups [--keep N] [--yes]
#
# Flags:
#   --fresh          Require an empty data directory (verify fresh-install migration)
#   --no-backup      Skip the automatic pre-upgrade backup (data loss risk)
#   --allow-rc       Accept RC tags (v...-kwh.N-rc.M) — required for local RC verification
#   --reseed-cache   Force re-copy of baked-in model cache from the image (use when
#                    a new release ships new bundled models; otherwise seeds once
#                    on first run and reuses thereafter).
#   --down           Stop and remove containers (bind-mount data dirs are kept)
#   --list-backups   Print backup history and exit
#   --restore <ts>   Restore data + pipelines dirs from a backup timestamp
#   --prune-backups  Delete older backups; keeps latest N (default 5)
#   --keep N         Number of backups to keep with --prune-backups
#   --yes            Skip interactive confirmation for --prune-backups
#
# Env overrides (optional):
#   OPENWEBUI_LOCAL_TEST_DATA       openwebui bind-mount dir (default: $HOME/openwebui-local-test-data)
#   PIPELINES_LOCAL_TEST_DATA       pipelines bind-mount dir (default: $HOME/openwebui-local-test-pipelines)
#   OPENWEBUI_LOCAL_TEST_PORT       host port (default: 8082)
#   PIPELINES_LOCAL_TEST_PORT       pipelines host port (default: 9099)
#   OPENWEBUI_LOCAL_TEST_ENV_FILE   env file (default: ./.env.local-test)

set -euo pipefail

# --- Paths ---------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.local-test.yaml"
ENV_TEMPLATE="${REPO_ROOT}/.env.local-test.template"
ENV_FRESH_TEMPLATE="${REPO_ROOT}/.env.local-test.fresh.template"
ENV_FILE_DEFAULT="${REPO_ROOT}/.env.local-test"

DEFAULT_DATA_DIR="${HOME}/openwebui-local-test-data"
DEFAULT_PIPELINES_DIR="${HOME}/openwebui-local-test-pipelines"
DEFAULT_PORT=8082
DEFAULT_PIPELINES_PORT=9099
IMAGE_REPO="ghcr.io/kwh8121/openwebui-service"

# --- Arg state -----------------------------------------------------------
IMAGE_TAG=""
MODE="verify"          # verify | down | list_backups | restore | prune_backups
FRESH=0
NO_BACKUP=0
ALLOW_RC=0
RESEED_CACHE=0
RESTORE_TS=""
KEEP=5
YES=0

usage() {
  awk 'NR>1 { if ($0 ~ /^#/) { sub(/^# ?/, ""); print } else { exit } }' "${BASH_SOURCE[0]}"
  exit 2
}

# --- Arg parsing ---------------------------------------------------------
if [[ $# -eq 0 ]]; then usage; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh)         FRESH=1 ;;
    --no-backup)     NO_BACKUP=1 ;;
    --allow-rc)      ALLOW_RC=1 ;;
    --reseed-cache)  RESEED_CACHE=1 ;;
    --down)          MODE="down" ;;
    --list-backups)  MODE="list_backups" ;;
    --restore)
      MODE="restore"
      shift
      [[ $# -eq 0 ]] && { echo "ERROR: --restore requires a timestamp" >&2; exit 2; }
      RESTORE_TS="$1"
      ;;
    --prune-backups) MODE="prune_backups" ;;
    --keep)
      shift
      [[ $# -eq 0 ]] && { echo "ERROR: --keep requires a number" >&2; exit 2; }
      KEEP="$1"
      ;;
    --yes)           YES=1 ;;
    -h|--help)       usage ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      usage
      ;;
    *)
      if [[ -n "$IMAGE_TAG" ]]; then
        echo "ERROR: multiple image tags given: '$IMAGE_TAG' and '$1'" >&2
        exit 2
      fi
      IMAGE_TAG="$1"
      ;;
  esac
  shift
done

# --- Resolve paths (default env fallbacks) ------------------------------
DATA_DIR="${OPENWEBUI_LOCAL_TEST_DATA:-$DEFAULT_DATA_DIR}"
PIPELINES_DIR="${PIPELINES_LOCAL_TEST_DATA:-$DEFAULT_PIPELINES_DIR}"
DATA_BACKUPS_DIR="${DATA_DIR%/}.backups"
PIPELINES_BACKUPS_DIR="${PIPELINES_DIR%/}.backups"
ENV_FILE="${OPENWEBUI_LOCAL_TEST_ENV_FILE:-$ENV_FILE_DEFAULT}"
PORT="${OPENWEBUI_LOCAL_TEST_PORT:-$DEFAULT_PORT}"
PIPELINES_PORT="${PIPELINES_LOCAL_TEST_PORT:-$DEFAULT_PIPELINES_PORT}"

# --- Helper: export compose vars (for down/up/config) -------------------
export_compose_vars() {
  export OPENWEBUI_LOCAL_TEST_TAG="${IMAGE_TAG:-placeholder}"
  export OPENWEBUI_LOCAL_TEST_DATA="$DATA_DIR"
  export OPENWEBUI_LOCAL_TEST_ENV_FILE="$ENV_FILE"
  export OPENWEBUI_LOCAL_TEST_PORT="$PORT"
  export PIPELINES_LOCAL_TEST_DATA="$PIPELINES_DIR"
  export PIPELINES_LOCAL_TEST_PORT="$PIPELINES_PORT"
}

# --- Subcommand: --down -------------------------------------------------
if [[ "$MODE" == "down" ]]; then
  # Env file may not exist for down; touch a placeholder if missing so compose parses.
  if [[ ! -f "$ENV_FILE" ]]; then
    tmp_env="$(mktemp)"; trap 'rm -f "$tmp_env"' EXIT
    ENV_FILE="$tmp_env"
  fi
  # Ensure bind-mount dirs exist (compose validates paths in some versions).
  mkdir -p "$DATA_DIR" "$PIPELINES_DIR"
  export_compose_vars
  echo "Stopping local-test containers (compose down)..."
  docker compose -f "$COMPOSE_FILE" down
  echo "Done. Data dirs preserved:"
  echo "  openwebui:  $DATA_DIR"
  echo "  pipelines:  $PIPELINES_DIR"
  exit 0
fi

# --- Subcommand: --list-backups -----------------------------------------
list_dir_backups() {
  local dir="$1" label="$2"
  echo "백업 (${dir}) — ${label}:"
  if [[ ! -d "$dir" ]]; then
    echo "  (없음)"
    return
  fi
  local found=0
  # shellcheck disable=SC2010
  while IFS= read -r f; do
    found=1
    local size
    size="$(du -h "$dir/$f" 2>/dev/null | cut -f1)"
    printf "  %-40s  %s\n" "$f" "$size"
  done < <(ls -1 "$dir" 2>/dev/null | grep -E '\.tar\.gz$' | sort)
  [[ $found -eq 0 ]] && echo "  (없음)"
}

if [[ "$MODE" == "list_backups" ]]; then
  list_dir_backups "$DATA_BACKUPS_DIR" "openwebui"
  echo
  list_dir_backups "$PIPELINES_BACKUPS_DIR" "pipelines"
  exit 0
fi

# --- Subcommand: --restore ----------------------------------------------
if [[ "$MODE" == "restore" ]]; then
  data_bk="${DATA_BACKUPS_DIR}/${RESTORE_TS}.tar.gz"
  pipe_bk="${PIPELINES_BACKUPS_DIR}/${RESTORE_TS}.tar.gz"
  missing=0
  [[ ! -f "$data_bk" ]] && { echo "ERROR: backup not found: $data_bk" >&2; missing=1; }
  [[ ! -f "$pipe_bk" ]] && { echo "ERROR: backup not found: $pipe_bk" >&2; missing=1; }
  [[ $missing -eq 1 ]] && exit 2

  echo "Restoring from timestamp: $RESTORE_TS"
  # Stop containers if running.
  mkdir -p "$DATA_DIR" "$PIPELINES_DIR"
  if [[ ! -f "$ENV_FILE" ]]; then
    tmp_env="$(mktemp)"; trap 'rm -f "$tmp_env"' EXIT
    ENV_FILE="$tmp_env"
  fi
  export_compose_vars
  docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true

  now="$(date +%Y%m%d-%H%M%S)"
  echo "Moving current dirs aside for safety..."
  [[ -d "$DATA_DIR" ]] && mv "$DATA_DIR" "${DATA_DIR%/}.rolled-back-${now}"
  [[ -d "$PIPELINES_DIR" ]] && mv "$PIPELINES_DIR" "${PIPELINES_DIR%/}.rolled-back-${now}"
  mkdir -p "$DATA_DIR" "$PIPELINES_DIR"

  echo "Extracting openwebui backup..."
  tar -xzf "$data_bk" -C "$DATA_DIR"
  echo "Extracting pipelines backup..."
  tar -xzf "$pipe_bk" -C "$PIPELINES_DIR"

  cat <<EOF

[RESTORED] $RESTORE_TS
  openwebui data:  $DATA_DIR
  pipelines data:  $PIPELINES_DIR
Previous state moved to:
  ${DATA_DIR%/}.rolled-back-${now}
  ${PIPELINES_DIR%/}.rolled-back-${now}
Re-run verification with:
  ./scripts/local-test.sh <tag> [--allow-rc]
EOF
  exit 0
fi

# --- Subcommand: --prune-backups ----------------------------------------
prune_one() {
  local dir="$1" label="$2"
  [[ ! -d "$dir" ]] && return
  mapfile -t all < <(ls -1 "$dir" 2>/dev/null | grep -E '\.tar\.gz$' | sort)
  local total=${#all[@]}
  if (( total <= KEEP )); then
    echo "[$label] ${total} backups (keep=${KEEP}); nothing to prune."
    return
  fi
  local prune_count=$((total - KEEP))
  echo "[$label] Will delete ${prune_count} of ${total} backups (keep newest ${KEEP}):"
  local to_delete=("${all[@]:0:prune_count}")
  printf '  %s\n' "${to_delete[@]}"
  if [[ $YES -ne 1 ]]; then
    read -r -p "Proceed? [y/N] " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Aborted."; return; }
  fi
  for f in "${to_delete[@]}"; do rm -f -- "$dir/$f"; done
  echo "[$label] Pruned."
}

if [[ "$MODE" == "prune_backups" ]]; then
  prune_one "$DATA_BACKUPS_DIR" "openwebui"
  prune_one "$PIPELINES_BACKUPS_DIR" "pipelines"
  exit 0
fi

# ========================================================================
# Verify mode from here on. Requires image tag.
# ========================================================================

if [[ -z "$IMAGE_TAG" ]]; then
  echo "ERROR: image tag argument is required for verify mode" >&2
  usage
fi

# --- Tag format validation ----------------------------------------------
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

Local RC verification is the v4 default, but the tool still requires an
explicit opt-in for RC tags to avoid accidental release-gate confusion.
Add: --allow-rc
EOF
    exit 2
  fi
else
  cat >&2 <<EOF
ERROR: '${IMAGE_TAG}' does not match required tag format.

Expected: v<MAJOR>.<MINOR>.<PATCH>-kwh.<N>            (e.g., v0.10.2-kwh.3)
   or with --allow-rc: v<MAJOR>.<MINOR>.<PATCH>-kwh.<N>-rc.<M>

Tags without the leading 'v' are not published to GHCR and will fail to pull.
EOF
  exit 2
fi

# --- Prereq: ghcr.io auth -----------------------------------------------
DOCKER_CONFIG_FILE="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
if [[ ! -f "$DOCKER_CONFIG_FILE" ]] || ! grep -q 'ghcr.io' "$DOCKER_CONFIG_FILE" 2>/dev/null; then
  cat >&2 <<EOF
ERROR: ghcr.io login not detected in ${DOCKER_CONFIG_FILE}.
Run once (PAT needs read:packages scope):
  docker login ghcr.io -u kwh8121
EOF
  exit 3
fi

# --- Prereq: env file ---------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ $FRESH -eq 1 ]]; then
    cat >&2 <<EOF
ERROR: env file not found: ${ENV_FILE}
Fresh-mode template:
  cp "${ENV_FRESH_TEMPLATE}" "${ENV_FILE_DEFAULT}"
EOF
  else
    cat >&2 <<EOF
ERROR: env file not found: ${ENV_FILE}
Production-mirror template:
  cp "${ENV_TEMPLATE}" "${ENV_FILE_DEFAULT}"
Then edit to fill in GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET, and register
the local redirect URI in Google Cloud Console:
  http://127.0.0.1:${PORT}/oauth/google/callback
EOF
  fi
  exit 5
fi

# --- Prereq: env file sanity (prod-mirror mode) -------------------------
if [[ $FRESH -ne 1 ]]; then
  if ! grep -q '^GOOGLE_CLIENT_ID=' "$ENV_FILE" 2>/dev/null; then
    echo "WARN: GOOGLE_CLIENT_ID not set in $ENV_FILE — prod-mirror OAuth check will not work." >&2
    echo "WARN: If a fresh-install migration test is intended, use --fresh." >&2
  fi
fi

# --- Data directory state check (v4: preserve by default) ---------------
ensure_dir() {
  local dir="$1"
  if [[ ! -e "$dir" ]]; then
    echo "Creating new data directory: $dir"
    mkdir -p "$dir"
    return 1   # created empty
  elif [[ ! -d "$dir" ]]; then
    echo "ERROR: $dir exists but is not a directory" >&2
    exit 4
  fi
  return 0     # existed
}

dir_empty() {
  [[ -z "$(ls -A "$1" 2>/dev/null)" ]]
}

ensure_dir "$DATA_DIR" || :
ensure_dir "$PIPELINES_DIR" || :

if [[ $FRESH -eq 1 ]]; then
  if ! dir_empty "$DATA_DIR" || ! dir_empty "$PIPELINES_DIR"; then
    cat >&2 <<EOF
ERROR: --fresh mode requires empty data directories.
  openwebui:  ${DATA_DIR}  ($(dir_empty "$DATA_DIR" && echo empty || echo NON-EMPTY))
  pipelines:  ${PIPELINES_DIR}  ($(dir_empty "$PIPELINES_DIR" && echo empty || echo NON-EMPTY))
Options:
  (a) wipe and re-run:   rm -rf "${DATA_DIR}"/* "${PIPELINES_DIR}"/*
  (b) drop --fresh and run in prod-mirror (upgrade) mode on existing data
EOF
    exit 4
  fi
  echo "MODE: --fresh (empty-DB, new-install migration check)"
else
  echo "MODE: production-mirror (preserving accumulated data)"
fi

# --- Automatic backup (v4) ----------------------------------------------
do_backup() {
  local dir="$1" bk_dir="$2" label="$3"
  mkdir -p "$bk_dir"
  local ts_tag
  ts_tag="$(date +%Y%m%d-%H%M%S)-${IMAGE_TAG}"
  local out="${bk_dir}/${ts_tag}.tar.gz"
  echo "Backup [$label] → $out"
  # -C into parent so tar entries are relative to the mount root.
  if ! tar -czf "$out" -C "$dir" . 2>/dev/null; then
    echo "ERROR: backup failed for $label ($dir → $out)" >&2
    return 1
  fi
  local size
  size="$(du -h "$out" | cut -f1)"
  echo "  size=$size"
  return 0
}

BACKUP_SKIPPED=0
if [[ $NO_BACKUP -eq 1 ]]; then
  echo "WARN: --no-backup set — skipping pre-upgrade backup (data loss risk)."
  BACKUP_SKIPPED=1
elif [[ $FRESH -eq 1 ]]; then
  echo "Fresh mode: skipping backup (nothing to preserve)."
  BACKUP_SKIPPED=1
else
  # If both dirs are empty (first ever run), nothing to back up.
  if dir_empty "$DATA_DIR" && dir_empty "$PIPELINES_DIR"; then
    echo "First run: data dirs are empty; skipping backup."
    BACKUP_SKIPPED=1
  else
    # Stop containers first to guarantee WAL-safe backup.
    export_compose_vars
    if docker compose -f "$COMPOSE_FILE" ps -q openwebui 2>/dev/null | grep -q .; then
      echo "Stopping running containers for WAL-safe backup..."
      docker compose -f "$COMPOSE_FILE" down
    fi
    if ! dir_empty "$DATA_DIR"; then
      do_backup "$DATA_DIR" "$DATA_BACKUPS_DIR" "openwebui" || {
        echo "ERROR: aborting to prevent data loss. Re-run with --no-backup to bypass (unsafe)." >&2
        exit 6
      }
    fi
    if ! dir_empty "$PIPELINES_DIR"; then
      do_backup "$PIPELINES_DIR" "$PIPELINES_BACKUPS_DIR" "pipelines" || {
        echo "ERROR: aborting to prevent data loss." >&2
        exit 6
      }
    fi
  fi
fi

# --- Pull image ---------------------------------------------------------
FULL_IMAGE="${IMAGE_REPO}:${IMAGE_TAG}"
echo "Pulling ${FULL_IMAGE}..."
if ! docker pull "$FULL_IMAGE"; then
  echo "ERROR: docker pull failed for ${FULL_IMAGE}" >&2
  echo "Verify the tag exists on GHCR and your PAT has read:packages." >&2
  exit 7
fi
echo "Pulling pipelines image..."
docker pull ghcr.io/open-webui/pipelines:main || {
  echo "ERROR: docker pull failed for pipelines" >&2
  exit 7
}

# --- Cache seed (v4.1) --------------------------------------------------
# The fork's GHCR image is built non-slim (USE_SLIM=false), so RAG embedding,
# whisper, tiktoken, etc. are baked into /app/backend/data/cache/* inside the
# image. Our bind mount at /app/backend/data hides those baked-in files, so
# the first launch would otherwise re-download ~250 MB from HuggingFace.
# On first run (or when --reseed-cache is set), copy the cache subtree from
# the freshly pulled image into the host bind-mount so subsequent starts and
# actual usage skip the network fetch.
CACHE_DIR="${DATA_DIR%/}/cache"
need_seed=0
if [[ $RESEED_CACHE -eq 1 ]]; then
  need_seed=1
elif [[ ! -d "$CACHE_DIR" ]] || [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
  need_seed=1
fi

if [[ $need_seed -eq 1 ]]; then
  echo "Seeding baked-in model cache from ${FULL_IMAGE} → ${CACHE_DIR}..."
  if [[ $RESEED_CACHE -eq 1 && -d "$CACHE_DIR" ]]; then
    echo "  --reseed-cache: removing existing cache first"
    rm -rf "$CACHE_DIR"
  fi
  tmp_cid="$(docker create "$FULL_IMAGE")"
  if ! docker cp "$tmp_cid:/app/backend/data/cache" "${DATA_DIR%/}/" 2>/dev/null; then
    echo "WARN: image has no /app/backend/data/cache (probably built with USE_SLIM=true)" >&2
    echo "WARN: models will be downloaded at runtime from HuggingFace." >&2
  else
    size="$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
    echo "  cache seeded (size=${size}) — runtime model download avoided."
  fi
  docker rm "$tmp_cid" >/dev/null
else
  echo "Cache already present at ${CACHE_DIR} — skipping seed (use --reseed-cache to force)."
fi

# --- Start compose ------------------------------------------------------
export_compose_vars
echo "Starting compose (openwebui on 127.0.0.1:${PORT}, pipelines on 127.0.0.1:${PIPELINES_PORT})..."
docker compose -f "$COMPOSE_FILE" up -d

# --- Quadruple success check --------------------------------------------
FAIL=0

check_state() {
  local svc="$1"
  local state
  state="$(docker compose -f "$COMPOSE_FILE" ps "$svc" --format '{{.State}}' 2>/dev/null || true)"
  echo "compose ps [${svc}] state: ${state:-<empty>}"
  if [[ "$state" != "running" ]]; then
    echo "ERROR: ${svc} state is not 'running'" >&2
    FAIL=1
  fi
}

check_state openwebui
check_state pipelines

echo "--- openwebui last 100 log lines ---"
LOG_OUT="$(docker compose -f "$COMPOSE_FILE" logs --tail 100 openwebui 2>&1 || true)"
echo "$LOG_OUT"
echo "--- end logs ---"
if grep -Eiq 'Traceback|ERROR|Failed to start' <<<"$LOG_OUT"; then
  echo "ERROR: startup error keywords detected in openwebui logs" >&2
  FAIL=1
fi

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
  echo "OK: openwebui /health returned 200"
else
  echo "ERROR: openwebui /health did not return 200 within 60s" >&2
  FAIL=1
fi

# Pipelines sanity: HTTP response any (its root returns 200 OK JSON).
PIPE_URL="http://127.0.0.1:${PIPELINES_PORT}/"
if curl -sf --max-time 3 "$PIPE_URL" >/dev/null 2>&1; then
  echo "OK: pipelines root reachable at ${PIPE_URL}"
else
  echo "WARN: pipelines root not reachable at ${PIPE_URL} (may be normal during boot)" >&2
fi

# --- Report -------------------------------------------------------------
if [[ $FAIL -eq 0 ]]; then
  cat <<EOF

===============================================================
[PASS] automated checks OK for ${FULL_IMAGE}
Open:      http://127.0.0.1:${PORT}
Pipelines: http://127.0.0.1:${PIPELINES_PORT}
Now walk the browser prod-mirror checklist
(see docs/plan/local-test-workflow.md § "로컬 수동 검증 체크리스트").
Teardown:  ./scripts/local-test.sh --down
===============================================================
EOF
  exit 0
else
  cat >&2 <<EOF

===============================================================
[FAIL] one or more automated checks failed for ${FULL_IMAGE}
Inspect logs:
  docker compose -f docker-compose.local-test.yaml logs openwebui
  docker compose -f docker-compose.local-test.yaml logs pipelines
Teardown:
  ./scripts/local-test.sh --down
EOF
  if [[ $BACKUP_SKIPPED -ne 1 ]]; then
    cat >&2 <<EOF
Rollback:
  ./scripts/local-test.sh --list-backups
  ./scripts/local-test.sh --restore <timestamp>
EOF
  fi
  if [[ $IS_RC -ne 1 ]]; then
    cat >&2 <<EOF
--- immutable final-tag rule (docs/manual/kwh-release-routine.md §3.6-b) ---
Final tags are immutable. Do NOT rebuild or overwrite ${IMAGE_TAG}.
Fix the underlying issue, cut the next kwh number (e.g., kwh.N+1),
and re-run the pipeline from RC.
===============================================================
EOF
  else
    echo "===============================================================" >&2
  fi
  exit 1
fi
