#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSISTENT_ROOT_DIR="$PROJECT_DIR/workspace/container-root"
cd "$PROJECT_DIR"

DOCKER=(docker)
DOCKER_USES_SUDO=0
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
  DOCKER_USES_SUDO=1
fi

container_id="$("${DOCKER[@]}" compose ps -a -q workstation)"
if [[ -z "$container_id" ]]; then
  printf 'No existing workstation container was found.\n' >&2
  printf 'Created an empty persistent root at %s\n' "$PERSISTENT_ROOT_DIR"
  mkdir -p "$PERSISTENT_ROOT_DIR"
  chmod 0700 "$PERSISTENT_ROOT_DIR"
  exit 0
fi

mkdir -p "$PERSISTENT_ROOT_DIR"
printf 'Copying the existing container /root into %s ...\n' \
  "$PERSISTENT_ROOT_DIR"
"${DOCKER[@]}" cp "$container_id:/root/." "$PERSISTENT_ROOT_DIR/"

# docker cp can create root-owned host files when Docker is invoked via sudo.
if (( DOCKER_USES_SUDO == 1 )) || [[ ! -w "$PERSISTENT_ROOT_DIR" ]]; then
  sudo chown -R "$(id -u):$(id -g)" "$PERSISTENT_ROOT_DIR"
fi
chmod 0700 "$PERSISTENT_ROOT_DIR"
printf 'Persistent /root migration completed.\n'
