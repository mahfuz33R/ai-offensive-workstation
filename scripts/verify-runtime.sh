#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RUNTIME_AUDIT_IMAGE:-ai-offensive-workstation:latest}"
RECREATE=0
REUSE_ROUNDTRIP=0
AUDIT_ID="runtime-audit-$(date -u +%Y%m%dT%H%M%SZ)-$$"
ROOT_SENTINEL="$PROJECT_DIR/workspace/container-root/.${AUDIT_ID}"
DATA_SENTINEL="$PROJECT_DIR/workspace/container-opt/data/.${AUDIT_ID}"
WORKSPACE_SENTINEL="$PROJECT_DIR/workspace/.${AUDIT_ID}"
TMUX_SOCKET="audit-${AUDIT_ID}"
TEMP_DIR=

usage() {
  cat <<'EOF'
Usage:
  bash scripts/verify-runtime.sh [--recreate] [--reuse-roundtrip]

--recreate
  Write temporary persistence sentinels, force-recreate the Compose services,
  verify all sentinels survived, and remove only those sentinels.

--reuse-roundtrip
  Create a real encrypted reuse bundle and restore it into an isolated
  temporary project. This requires substantial free disk space.
EOF
}

pass() {
  printf '[PASS] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  rm -f -- "$ROOT_SENTINEL" "$DATA_SENTINEL" "$WORKSPACE_SENTINEL"
  if [[ -n "${DOCKER+x}" ]]; then
    "${DOCKER[@]}" exec --user root ai-offensive-workstation \
      tmux -L "$TMUX_SOCKET" kill-server >/dev/null 2>&1 || true
  fi
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    case "$TEMP_DIR" in
      /tmp/ai-offensive-runtime-audit.*) rm -rf -- "$TEMP_DIR" ;;
      "$PROJECT_DIR"/.runtime-audit.*) rm -rf -- "$TEMP_DIR" ;;
      *) printf '[WARN] Refusing to remove unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
    esac
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

while (($#)); do
  case "$1" in
    --recreate) RECREATE=1 ;;
    --reuse-roundtrip) REUSE_ROUNDTRIP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown argument: $1" ;;
  esac
  shift
done

cd "$PROJECT_DIR"

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi
"${DOCKER[@]}" info >/dev/null
"${DOCKER[@]}" image inspect "$IMAGE" >/dev/null

compose() {
  "${DOCKER[@]}" compose "$@"
}

container_id() {
  compose ps -a -q "$1"
}

wait_for_workstation() {
  local id status attempt
  id="$(container_id workstation)"
  [[ -n "$id" ]] || fail 'workstation container does not exist'
  for attempt in {1..72}; do
    status="$("${DOCKER[@]}" inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id")"
    case "$status" in
      healthy)
        pass 'workstation health check is healthy'
        return 0
        ;;
      unhealthy|exited|dead)
        compose logs --tail=160 workstation >&2 || true
        fail "workstation entered terminal state: $status"
        ;;
    esac
    sleep 5
  done
  compose logs --tail=160 workstation >&2 || true
  fail 'workstation did not become healthy within six minutes'
}

wait_for_dashboard() {
  local configured_port port attempt
  configured_port="$(sed -n 's/^HERMES_DASHBOARD_PORT=//p' "$PROJECT_DIR/.env" | tail -n1)"
  port="${HERMES_DASHBOARD_PORT:-${configured_port:-9119}}"
  for _ in {1..60}; do
    if curl -fsS --max-time 3 "http://127.0.0.1:${port}/" >/dev/null; then
      pass "dashboard responds on 127.0.0.1:${port}"
      return 0
    fi
    sleep 2
  done
  compose logs --tail=160 dashboard >&2 || true
  fail "dashboard did not respond on 127.0.0.1:${port}"
}

assert_mount() {
  local service="$1" destination="$2" expected="$3" id actual
  id="$(container_id "$service")"
  [[ -n "$id" ]] || fail "$service container does not exist"
  actual="$("${DOCKER[@]}" inspect --format \
    "{{range .Mounts}}{{if eq .Destination \"$destination\"}}{{.Source}}{{end}}{{end}}" \
    "$id")"
  [[ "$actual" == "$(realpath -m "$expected")" ]] \
    || fail "$service $destination mount is $actual, expected $(realpath -m "$expected")"
  pass "$service $destination uses the expected host bind"
}

check_sentinels_in_container() {
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/root/.${AUDIT_ID}"
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/opt/data/.${AUDIT_ID}"
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/workspace/.${AUDIT_ID}"
  pass 'persistence sentinels are visible in /root, /opt/data, and /workspace'
}

run_core_runtime_checks() {
  "${DOCKER[@]}" exec --user root ai-offensive-workstation zsh -ic '
    [[ "$ZSH" == /opt/oh-my-zsh ]]
    [[ "$SHELL" == /usr/bin/zsh ]]
    [[ -n "$PROMPT" ]]
    (( $+functions[configure_prompt] ))
    (( $+functions[toggle_prompt] ))
    (( $+functions[mkcd] ))
    (( ${plugins[(Ie)git]} ))
    alias ll >/dev/null
    command -v hermes zsh tmux go python3 node cargo nmap nuclei >/dev/null
  '
  pass 'root interactive Zsh and Oh My Zsh configuration loads'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation zsh -ic '
    [[ "$(id -un)" == hermes ]]
    [[ "$ZSH" == /opt/oh-my-zsh ]]
    [[ "$SHELL" == /usr/bin/zsh ]]
    (( $+functions[configure_prompt] ))
    alias ll >/dev/null
    test ! -w /opt/hermes
    command -v hermes check-tools check-knowledge agent-browser cyberstrike >/dev/null
  '
  pass 'Hermes-user Zsh loads and immutable Hermes files remain protected'

  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" new-session -d -s workstation-audit
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" has-session -t workstation-audit
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" kill-server
  pass 'Tmux creates, finds, and removes an isolated session'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    check-tools /opt/security-manifest/tool-inventory.tsv \
    /tmp/runtime-audit-tool-manifest.tsv
  pass 'all required tool, asset, path, and capability checks pass'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    check-knowledge --require-help
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    env COLUMNS=240 hermes skills list \
    | grep -F offensive-workstation-pentesting >/dev/null
  pass 'Hermes knowledge and bundled skill discovery pass'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    agent-browser --help >/dev/null
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
    cyberstrike_version="$(cyberstrike --version)"
    package_version="$(jq -r .version /opt/security-tools/cyberstrike/node_modules/@cyberstrike-io/cyberstrike/package.json)"
    test "$cyberstrike_version" = "$package_version"
    [[ "$cyberstrike_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
    CYBERSTRIKE_DISABLE_MODELS_FETCH=1 timeout 30 cyberstrike --help >/dev/null
    test -L "${XDG_DATA_HOME:-$HOME/.local/share}/cyberstrike/bin/hackbrowser-worker.js"
    test -L "${XDG_DATA_HOME:-$HOME/.local/share}/cyberstrike/node_modules/playwright"
  '
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
    chromium="$(find /opt/hermes/.playwright -maxdepth 6 -type f \
      \( -name chrome -o -name chromium -o -name chrome-headless-shell \
         -o -name headless_shell -o -name chromium-browser \) \
      -perm /111 -print -quit)"
    test -x "$chromium"
    timeout 30 "$chromium" --headless --no-sandbox --disable-gpu \
      --disable-dev-shm-usage \
      --dump-dom "data:text/html,<title>RuntimeAuditOK</title>" \
      2>/dev/null | grep -q RuntimeAuditOK
  '
  pass 'agent-browser and offline Chromium launch pass'
}

run_reuse_roundtrip() {
  local passphrase_file bundle import_dir dependency_bin dependency_log
  local protection_dir protection_log
  command -v gpg >/dev/null || fail 'gpg is required for reuse round-trip'
  command -v openssl >/dev/null || fail 'openssl is required for reuse round-trip'
  TEMP_DIR="$(mktemp -d "$PROJECT_DIR/.runtime-audit.XXXXXXXX")"
  chmod 0700 "$TEMP_DIR"
  passphrase_file="$TEMP_DIR/passphrase"
  bundle="$TEMP_DIR/workstation.tar.gpg"
  import_dir="$TEMP_DIR/import"
  openssl rand -hex 48 > "$passphrase_file"
  chmod 0600 "$passphrase_file"

  dependency_bin="$TEMP_DIR/dependency-bin"
  dependency_log="$TEMP_DIR/dependency-check.log"
  mkdir -p "$dependency_bin"
  ln -s "$(command -v dirname)" "$dependency_bin/dirname"
  if PATH="$dependency_bin" /bin/bash "$PROJECT_DIR/reuse/reuse.sh" export \
      "$TEMP_DIR/dependency-test.tar.gpg" >"$dependency_log" 2>&1; then
    fail 'reuse export accepted a host without its required Docker command'
  fi
  grep -F 'required command not found: docker' "$dependency_log" >/dev/null \
    || fail 'reuse dependency failure did not identify the missing command'
  pass 'reuse dependency checks reject a missing required command'

  protection_dir="$TEMP_DIR/mount-protection"
  protection_log="$TEMP_DIR/mount-protection.log"
  mkdir -p \
    "$protection_dir/wrong-root" \
    "$protection_dir/workspace/container-root" \
    "$protection_dir/workspace/container-opt/data"
  mkdir -p "$protection_dir/reuse"
  cp "$PROJECT_DIR/reuse/reuse.sh" "$protection_dir/reuse/reuse.sh"
  chmod 0755 "$protection_dir/reuse/reuse.sh"
  {
    printf 'services:\n'
    printf '  workstation:\n'
    printf '    image: %s\n' "$IMAGE"
    printf '    entrypoint: /bin/sleep\n'
    printf '    command: ["300"]\n'
    printf '    volumes:\n'
    printf '      - ./wrong-root:/root\n'
    printf '      - ./workspace/container-opt/data:/opt/data\n'
    printf '      - ./workspace:/workspace\n'
  } > "$protection_dir/docker-compose.yml"
  (
    cd "$protection_dir"
    "${DOCKER[@]}" compose up -d --no-build
    trap '"${DOCKER[@]}" compose down --remove-orphans >/dev/null 2>&1 || true' \
      EXIT INT TERM
    if REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
        ./reuse/reuse.sh export "$TEMP_DIR/mount-protection.tar.gpg" \
        >"$protection_log" 2>&1; then
      fail 'reuse export accepted an incorrect /root bind source'
    fi
    grep -F 'container /root is not mounted from' "$protection_log" >/dev/null \
      || fail 'reuse mount-protection failure did not identify the bad /root bind'
  )
  pass 'reuse mount protection rejects an incorrect bind source'

  REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
    "$PROJECT_DIR/reuse/reuse.sh" export "$bundle"
  REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
    "$PROJECT_DIR/reuse/reuse.sh" verify "$bundle"

  mkdir -p "$import_dir"
  mkdir -p "$import_dir/reuse"
  cp "$PROJECT_DIR/reuse/reuse.sh" "$import_dir/reuse/reuse.sh"
  chmod 0755 "$import_dir/reuse/reuse.sh"
  (
    cd "$import_dir"
    REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
      ./reuse/reuse.sh import "$bundle"
    "${DOCKER[@]}" compose config -q
  )

  [[ -s "$import_dir/workspace/container-opt/data/config.yaml" ]] \
    || fail 'reuse import did not restore Docker Hermes config.yaml'
  cmp -s \
    "$PROJECT_DIR/workspace/container-opt/data/config.yaml" \
    "$import_dir/workspace/container-opt/data/config.yaml" \
    || fail 'restored Docker Hermes config.yaml differs from the source'
  if [[ -f "$PROJECT_DIR/secrets.env" ]]; then
    cmp -s "$PROJECT_DIR/secrets.env" "$import_dir/secrets.env" \
      || fail 'restored secrets.env differs from the source'
  fi
  [[ -s "$import_dir/docker-compose.yml" ]] \
    || fail 'reuse import did not restore docker-compose.yml'
  pass 'encrypted reuse export, verify, and isolated import round-trip pass'
}

printf 'Starting the existing image without rebuilding...\n'
compose up -d --no-build
wait_for_workstation
wait_for_dashboard

assert_mount workstation /root "$PROJECT_DIR/workspace/container-root"
assert_mount workstation /opt/data "$PROJECT_DIR/workspace/container-opt/data"
assert_mount workstation /workspace "$PROJECT_DIR/workspace"
assert_mount dashboard /root "$PROJECT_DIR/workspace/container-root"
assert_mount dashboard /opt/data "$PROJECT_DIR/workspace/container-opt/data"
assert_mount dashboard /workspace "$PROJECT_DIR/workspace"
pass 'Docker Hermes uses only the project data directory, independently of host Hermes'

run_core_runtime_checks

if (( RECREATE == 1 )); then
  printf '%s\n' "$AUDIT_ID" > "$ROOT_SENTINEL"
  printf '%s\n' "$AUDIT_ID" > "$DATA_SENTINEL"
  printf '%s\n' "$AUDIT_ID" > "$WORKSPACE_SENTINEL"
  check_sentinels_in_container
  compose up -d --no-build --force-recreate
  wait_for_workstation
  wait_for_dashboard
  assert_mount workstation /root "$PROJECT_DIR/workspace/container-root"
  assert_mount workstation /opt/data "$PROJECT_DIR/workspace/container-opt/data"
  assert_mount workstation /workspace "$PROJECT_DIR/workspace"
  [[ -f "$ROOT_SENTINEL" && -f "$DATA_SENTINEL" && -f "$WORKSPACE_SENTINEL" ]] \
    || fail 'one or more host persistence sentinels disappeared after recreation'
  check_sentinels_in_container
  pass 'all persistent data survived forced container recreation'
  run_core_runtime_checks
fi

if (( REUSE_ROUNDTRIP == 1 )); then
  run_reuse_roundtrip
fi

printf '\nRuntime audit passed.\n'
