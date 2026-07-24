#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
PERSISTENT_ROOT_DIR="$PROJECT_DIR/workspace/container-root"
PERSISTENT_OPT_DATA_DIR="$PROJECT_DIR/workspace/container-opt/data"

mkdir -p \
  "$PERSISTENT_ROOT_DIR" \
  "$PERSISTENT_OPT_DATA_DIR" \
  "$PROJECT_DIR/workspace/bin" \
  "$PROJECT_DIR/workspace/scripts" \
  "$PROJECT_DIR/workspace/tools" \
  "$PROJECT_DIR/workspace/config" \
  "$PROJECT_DIR/workspace/projects" \
  "$PROJECT_DIR/workspace/targets" \
  "$PROJECT_DIR/workspace/reports" \
  "$PROJECT_DIR/workspace/downloads" \
  "$PROJECT_DIR/workspace/notes"

cat > "$ENV_FILE" <<EOF
HERMES_DATA_DIR=$PERSISTENT_OPT_DATA_DIR
WORKSTATION_ROOT_DIR=$PERSISTENT_ROOT_DIR
HERMES_UID=$(id -u)
HERMES_GID=$(id -g)
HERMES_IMAGE=nousresearch/hermes-agent
HERMES_TAG=latest
# Optional: uncomment to pin an exact base image instead of following latest.
# HERMES_DIGEST=@sha256:45b67c84c5d7eef97746b576ad56ca7b21aa334396096415a6a98c5fd3a2d4a0
GO_VERSION=1.26.5
RUST_TOOLCHAIN=stable
PLAYWRIGHT_VERSION=1.58.2
EOF

chmod 600 "$ENV_FILE"
printf 'Saved permanent local Compose settings to %s\n' "$ENV_FILE"
printf 'Persistent /opt/data: %s\n' "$PERSISTENT_OPT_DATA_DIR"
printf 'Persistent /root: %s\n' "$PERSISTENT_ROOT_DIR"
printf 'UID:GID: %s:%s\n' "$(id -u)" "$(id -g)"
