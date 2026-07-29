#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${REUSE_IMAGE:-ai-offensive-workstation:latest}"
TEMP_DIR=
RUNNING_SERVICES=()
GPG_PASSPHRASE_ARGS=()

usage() {
  cat <<'EOF'
Create or restore an encrypted AI Offensive Workstation migration bundle.

Usage:
  ./scripts/reuse.sh export [BUNDLE.tar.gpg]
  ./scripts/reuse.sh import BUNDLE.tar.gpg [--force]
  ./scripts/reuse.sh verify BUNDLE.tar.gpg

export
  Saves the Docker image and private persistent state into one GPG-encrypted
  bundle. GPG asks for a passphrase; it is never accepted as a command argument.

import
  Decrypts and verifies the bundle, loads the image, restores private state,
  and creates a machine-specific .env. Existing state causes an abort.

import --force
  Moves existing workspace and .env to timestamped backup paths before
  restoring the bundle. Nothing is deleted.

verify
  Decrypts the bundle and verifies its manifest and checksums without loading
  the image or restoring files.
EOF
}

die() {
  printf 'reuse: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

prepare_gpg_passphrase() {
  local passphrase_file="${REUSE_GPG_PASSPHRASE_FILE:-}"
  GPG_PASSPHRASE_ARGS=()
  [[ -n "$passphrase_file" ]] || return 0
  [[ -f "$passphrase_file" ]] \
    || die "REUSE_GPG_PASSPHRASE_FILE does not exist: $passphrase_file"
  [[ "$(stat -c '%a' "$passphrase_file")" == 600 ]] \
    || die 'REUSE_GPG_PASSPHRASE_FILE must have permissions 600'
  GPG_PASSPHRASE_ARGS=(
    --batch
    --pinentry-mode loopback
    --passphrase-file "$passphrase_file"
  )
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if (( ${#RUNNING_SERVICES[@]} > 0 )); then
    restart_services || true
  fi
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    case "$TEMP_DIR" in
      /tmp/ai-offensive-reuse.*) rm -rf -- "$TEMP_DIR" ;;
      "$PROJECT_DIR"/.reuse-tmp.*) rm -rf -- "$TEMP_DIR" ;;
      *) printf 'reuse: refusing to remove unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
    esac
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

prepare_temp_dir() {
  TEMP_DIR="$(mktemp -d "$PROJECT_DIR/.reuse-tmp.XXXXXXXX")"
  chmod 0700 "$TEMP_DIR"
}

docker_command() {
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  else
    DOCKER=(sudo docker)
  fi
  "${DOCKER[@]}" info >/dev/null
}

validate_persistent_mounts() {
  local container_id expected_root expected_data expected_workspace
  local actual_root actual_data actual_workspace
  [[ -f "$PROJECT_DIR/docker-compose.yml" ]] || return 0
  container_id="$(
    cd "$PROJECT_DIR"
    "${DOCKER[@]}" compose ps -a -q workstation
  )"
  [[ -n "$container_id" ]] || return 0

  expected_root="$(realpath -m "$PROJECT_DIR/workspace/container-root")"
  expected_data="$(realpath -m "$PROJECT_DIR/workspace/container-opt/data")"
  expected_workspace="$(realpath -m "$PROJECT_DIR/workspace")"
  actual_root="$("${DOCKER[@]}" inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/root"}}{{.Source}}{{end}}{{end}}' \
    "$container_id")"
  actual_data="$("${DOCKER[@]}" inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/opt/data"}}{{.Source}}{{end}}{{end}}' \
    "$container_id")"
  actual_workspace="$("${DOCKER[@]}" inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$container_id")"

  [[ "$actual_root" == "$expected_root" ]] || die \
    "container /root is not mounted from $expected_root; run scripts/migrate-container-root.sh and recreate the container before export"
  [[ "$actual_data" == "$expected_data" ]] || die \
    "container /opt/data is not mounted from $expected_data; recreate the container with the current Compose configuration before export"
  [[ "$actual_workspace" == "$expected_workspace" ]] || die \
    "container /workspace is not mounted from $expected_workspace; recreate the container with the current Compose configuration before export"
}

stop_running_services() {
  [[ -f "$PROJECT_DIR/docker-compose.yml" ]] || return 0
  mapfile -t RUNNING_SERVICES < <(
    cd "$PROJECT_DIR"
    "${DOCKER[@]}" compose ps --services --filter status=running
  )
  if (( ${#RUNNING_SERVICES[@]} > 0 )); then
    printf 'Stopping running services for a consistent private-state snapshot...\n'
    (
      cd "$PROJECT_DIR"
      "${DOCKER[@]}" compose stop "${RUNNING_SERVICES[@]}"
    )
  fi
}

restart_services() {
  if (( ${#RUNNING_SERVICES[@]} > 0 )); then
    printf 'Restarting services that were running before export...\n'
    (
      cd "$PROJECT_DIR"
      "${DOCKER[@]}" compose start "${RUNNING_SERVICES[@]}"
    )
    RUNNING_SERVICES=()
  fi
}

decrypt_bundle() {
  local bundle="$1"
  [[ -f "$bundle" ]] || die "bundle not found: $bundle"
  prepare_temp_dir
  prepare_gpg_passphrase
  printf 'Decrypting bundle. Enter its GPG passphrase when prompted.\n'
  gpg "${GPG_PASSPHRASE_ARGS[@]}" \
    --quiet --output "$TEMP_DIR/package.tar" --decrypt "$bundle"
  mkdir -p "$TEMP_DIR/package"
  tar -xf "$TEMP_DIR/package.tar" -C "$TEMP_DIR/package"
  [[ -f "$TEMP_DIR/package/REUSE-MANIFEST.txt" ]] \
    || die 'bundle is missing REUSE-MANIFEST.txt'
  [[ -f "$TEMP_DIR/package/SHA256SUMS" ]] \
    || die 'bundle is missing SHA256SUMS'
  (
    cd "$TEMP_DIR/package"
    sha256sum -c SHA256SUMS
  )
}

write_machine_env() {
  [[ -x "$PROJECT_DIR/scripts/configure-host.sh" ]] \
    || die 'runtime bundle is missing scripts/configure-host.sh'
  bash "$PROJECT_DIR/scripts/configure-host.sh"
}

export_bundle() {
  local output="${1:-}"
  local timestamp state_entries=()

  require_command docker
  require_command gpg
  require_command gzip
  require_command sha256sum
  require_command tar
  docker_command
  "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null
  validate_persistent_mounts

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  if [[ -z "$output" ]]; then
    output="$PROJECT_DIR/ai-offensive-workstation-reuse-${timestamp}.tar.gpg"
  elif [[ "$output" != /* ]]; then
    output="$PWD/$output"
  fi
  [[ ! -e "$output" ]] || die "output already exists: $output"

  prepare_temp_dir
  stop_running_services

  printf 'Saving Docker image %s ...\n' "$IMAGE"
  "${DOCKER[@]}" image save "$IMAGE" | gzip -1 > "$TEMP_DIR/image.tar.gz"

  [[ -d "$PROJECT_DIR/workspace" ]] \
    || die "missing persistent workspace: $PROJECT_DIR/workspace"
  state_entries+=(workspace)
  [[ -f "$PROJECT_DIR/.env" ]] \
    || die 'missing private .env; run scripts/configure-host.sh first'
  state_entries+=(.env)

  printf 'Archiving private persistent state...\n'
  "${DOCKER[@]}" run --rm \
    --volume "$PROJECT_DIR:/source:ro" \
    --entrypoint /bin/tar \
    "$IMAGE" \
    -C /source -czf - \
    --exclude='workspace/container-opt/data/gateway.pid' \
    --exclude='workspace/container-opt/data/gateway.lock' \
    --exclude='workspace/container-opt/data/auth.lock' \
    "${state_entries[@]}" > "$TEMP_DIR/private-state.tar.gz"

  printf 'Archiving portable runtime files...\n'
  tar -C "$PROJECT_DIR" -czf "$TEMP_DIR/runtime-files.tar.gz" \
    Dockerfile docker-compose.yml .env.example .zshrc README.md docs \
    scripts/reuse.sh scripts/configure-host.sh

  {
    printf 'format=ai-offensive-workstation-reuse-v1\n'
    printf 'created_utc=%s\n' "$timestamp"
    printf 'image=%s\n' "$IMAGE"
    printf 'includes=image,workspace,container-opt-data,container-root'
    printf ',.env'
    printf '\n'
    printf 'warning=contains private authentication tokens, cookies, sessions, API keys, and target data\n'
  } > "$TEMP_DIR/REUSE-MANIFEST.txt"

  (
    cd "$TEMP_DIR"
    sha256sum image.tar.gz private-state.tar.gz runtime-files.tar.gz \
      REUSE-MANIFEST.txt > SHA256SUMS
    tar -cf package.tar image.tar.gz private-state.tar.gz \
      runtime-files.tar.gz REUSE-MANIFEST.txt SHA256SUMS
  )

  restart_services

  prepare_gpg_passphrase
  printf 'Encrypting migration bundle. Choose a strong, unique GPG passphrase.\n'
  gpg "${GPG_PASSPHRASE_ARGS[@]}" \
    --symmetric \
    --cipher-algo AES256 \
    --s2k-digest-algo SHA512 \
    --s2k-mode 3 \
    --s2k-count 65011712 \
    --compress-algo none \
    --output "$output" \
    "$TEMP_DIR/package.tar"
  chmod 0600 "$output"

  printf '\nEncrypted reuse bundle created:\n%s\n' "$output"
  printf 'Copy this bundle together with scripts/reuse.sh.\n'
  printf 'Keep the passphrase separate from the bundle.\n'
}

verify_bundle() {
  local bundle="${1:-}"
  [[ -n "$bundle" ]] || die 'verify requires a bundle path'
  require_command gpg
  require_command sha256sum
  require_command tar
  decrypt_bundle "$bundle"
  printf '\nBundle verified successfully:\n'
  cat "$TEMP_DIR/package/REUSE-MANIFEST.txt"
}

import_bundle() {
  local bundle="${1:-}" force="${2:-}" timestamp backup_suffix
  local package="$TEMP_DIR/package"
  [[ -n "$bundle" ]] || die 'import requires a bundle path'
  [[ -z "$force" || "$force" == --force ]] \
    || die "unknown import option: $force"

  require_command docker
  require_command gpg
  require_command gzip
  require_command sha256sum
  require_command tar
  docker_command
  decrypt_bundle "$bundle"
  package="$TEMP_DIR/package"

  if [[ -d "$PROJECT_DIR/workspace" ]] \
    && find "$PROJECT_DIR/workspace" -type f -print -quit | grep -q .; then
    [[ "$force" == --force ]] \
      || die 'destination workspace contains files; rerun with --force to preserve it as a timestamped backup'
  fi
  if [[ -f "$PROJECT_DIR/.env" ]]; then
    [[ "$force" == --force ]] \
      || die 'destination .env exists; rerun with --force to preserve it as a timestamped backup'
  fi

  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    (
      cd "$PROJECT_DIR"
      "${DOCKER[@]}" compose down
    )
  fi

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_suffix="before-reuse-${timestamp}"
  if [[ "$force" == --force ]]; then
    if [[ -d "$PROJECT_DIR/workspace" ]] \
      && find "$PROJECT_DIR/workspace" -type f -print -quit | grep -q .; then
      mv "$PROJECT_DIR/workspace" "$PROJECT_DIR/workspace.${backup_suffix}"
      printf 'Existing workspace moved to workspace.%s\n' "$backup_suffix"
    fi
    if [[ -f "$PROJECT_DIR/.env" ]]; then
      mv "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.${backup_suffix}"
      printf 'Existing .env moved to .env.%s\n' "$backup_suffix"
    fi
  fi

  printf 'Restoring portable runtime files where they are missing...\n'
  mkdir -p "$TEMP_DIR/runtime"
  tar -xzf "$package/runtime-files.tar.gz" -C "$TEMP_DIR/runtime"
  for runtime_file in \
    Dockerfile docker-compose.yml .env.example .zshrc README.md docs \
    scripts/reuse.sh scripts/configure-host.sh; do
    if [[ ! -e "$PROJECT_DIR/$runtime_file" ]]; then
      mkdir -p "$(dirname "$PROJECT_DIR/$runtime_file")"
      cp -a "$TEMP_DIR/runtime/$runtime_file" "$PROJECT_DIR/$runtime_file"
    fi
  done

  printf 'Restoring private persistent state...\n'
  tar -xzf "$package/private-state.tar.gz" \
    --no-same-owner -C "$PROJECT_DIR"
  mkdir -p \
    "$PROJECT_DIR/workspace/container-opt/data" \
    "$PROJECT_DIR/workspace/container-root"
  chmod 0700 \
    "$PROJECT_DIR/workspace/container-opt/data" \
    "$PROJECT_DIR/workspace/container-root"
  [[ ! -f "$PROJECT_DIR/.env" ]] || chmod 0600 "$PROJECT_DIR/.env"
  write_machine_env

  printf 'Loading Docker image...\n'
  gzip -dc "$package/image.tar.gz" | "${DOCKER[@]}" image load

  printf '\nReuse bundle restored successfully.\n'
  printf 'Machine-specific Compose settings: %s/.env\n' "$PROJECT_DIR"
  printf 'Next commands:\n'
  printf '  sudo docker compose up -d --no-build\n'
  printf '  sudo docker compose exec --user root --env HOME=/root workstation zsh\n'
  printf '\nSome providers can still require reauthentication if a token expired,\n'
  printf 'was revoked, or is bound to the original device.\n'
}

main() {
  local action="${1:-}"
  case "$action" in
    export)
      shift
      (( $# <= 1 )) || die 'export accepts at most one output path'
      export_bundle "${1:-}"
      ;;
    import)
      shift
      (( $# >= 1 && $# <= 2 )) || die 'import requires BUNDLE.tar.gpg and optional --force'
      import_bundle "$@"
      ;;
    verify)
      shift
      (( $# == 1 )) || die 'verify requires exactly one bundle path'
      verify_bundle "$1"
      ;;
    -h|--help|help|'')
      usage
      ;;
    *)
      usage >&2
      die "unknown action: $action"
      ;;
  esac
}

main "$@"
