#!/usr/bin/env bash

# Shared installer primitives. Each ecosystem script sources this file and
# calls finish_installer before exiting.
set -uo pipefail

export DEBIAN_FRONTEND=noninteractive
export SECURITY_TOOLS_DIR="${SECURITY_TOOLS_DIR:-/opt/security-tools}"
export SECURITY_ASSETS_DIR="${SECURITY_ASSETS_DIR:-/opt/security-assets}"
export TOOLCHAINS_DIR="${TOOLCHAINS_DIR:-/opt/toolchains}"
export SECURITY_MANIFEST_DIR="${SECURITY_MANIFEST_DIR:-/opt/security-manifest}"
export COMMANDS_DIR="${COMMANDS_DIR:-/usr/local/bin}"
export SECURITY_VENV="${SECURITY_VENV:-${TOOLCHAINS_DIR}/python}"
export GOPATH="${GOPATH:-${TOOLCHAINS_DIR}/go}"
export CARGO_HOME="${CARGO_HOME:-${TOOLCHAINS_DIR}/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-${TOOLCHAINS_DIR}/rustup}"
export PATH="/usr/local/go/bin:${GOPATH}/bin:${SECURITY_VENV}/bin:${CARGO_HOME}/bin:${PATH}"

INSTALLER_NAME="${INSTALLER_NAME:-unknown}"
INSTALL_FAILURES=0
RESULTS_FILE="${SECURITY_MANIFEST_DIR}/install-results.tsv"
RESOLVED_FILE="${SECURITY_MANIFEST_DIR}/resolved-versions.txt"

mkdir -p \
  "$SECURITY_TOOLS_DIR" \
  "$SECURITY_ASSETS_DIR"/{wordlists,templates,payloads,patterns} \
  "$TOOLCHAINS_DIR" "$SECURITY_MANIFEST_DIR" "$GOPATH/bin" "$CARGO_HOME/bin" \
  "$COMMANDS_DIR"
touch "$RESULTS_FILE" "$RESOLVED_FILE"

log() { printf '[%s] %s\n' "$INSTALLER_NAME" "$*"; }

install_step() {
  local name="$1" method="$2"
  shift 2
  log "Installing ${name} (${method})"
  # Run the step in its own errexit-enabled subshell. Calling a Bash function
  # directly in an `if` condition disables `set -e` inside that function, which
  # can hide an early clone/build/pip failure when a later command succeeds.
  # This shape preserves strict failure behavior while still letting us collect
  # all failures in the current ecosystem before finish_installer returns 1.
  ( set -e; "$@" )
  local rc=$?
  if (( rc == 0 )); then
    printf '%s\t%s\t%s\t%s\n' "$INSTALLER_NAME" "$name" "$method" "installed" >> "$RESULTS_FILE"
  else
    printf '%s\t%s\t%s\t%s\n' "$INSTALLER_NAME" "$name" "$method" "failed:${rc}" >> "$RESULTS_FILE"
    log "ERROR: ${name} failed with exit code ${rc}"
    INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
  fi
}

finish_installer() {
  if (( INSTALL_FAILURES > 0 )); then
    log "${INSTALL_FAILURES} required installation step(s) failed"
    return 1
  fi
  log "All required installation steps completed"
}

retry() {
  local attempts="${RETRY_ATTEMPTS:-3}" delay="${RETRY_DELAY:-2}" n=1
  until "$@"; do
    if (( n >= attempts )); then return 1; fi
    log "Attempt ${n}/${attempts} failed; retrying in ${delay}s: $*" >&2
    sleep "$delay"
    n=$((n + 1))
  done
}

clone_repo() {
  local name="$1" url="$2" destination
  destination="${3:-${SECURITY_TOOLS_DIR}/${name}}"
  retry git clone --depth 1 "$url" "$destination"
  local revision
  revision="$(git -C "$destination" rev-parse HEAD)"
  printf '%s\tgit\t%s\t%s\t%s\n' "$name" "$url" "$revision" "$destination" >> "$RESOLVED_FILE"
}

clone_asset_repo() {
  local name="$1" url="$2" destination="$3"
  retry git clone --depth 1 "$url" "$destination"
  local revision
  revision="$(git -C "$destination" rev-parse HEAD)"
  printf '%s\tgit-asset\t%s\t%s\t%s\n' "$name" "$url" "$revision" "$destination" >> "$RESOLVED_FILE"
}

link_command() {
  local source="$1" command_name="$2"
  test -e "$source"
  chmod +x "$source"
  ln -sfn "$source" "${COMMANDS_DIR}/${command_name}"
  printf '%s\tcommand-link\t%s\tlatest\t%s\n' \
    "$command_name" "$source" "${COMMANDS_DIR}/${command_name}" >> "$RESOLVED_FILE"
}

link_first() {
  local command_name="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      link_command "$candidate" "$command_name"
      return 0
    fi
  done
  log "No executable candidate found for ${command_name}: $*"
  return 1
}

python_command() {
  local source="$1" command_name="$2" wrapper
  wrapper="${COMMANDS_DIR}/${command_name}"
  test -f "$source"
  printf '#!/bin/sh\ncd %q\nexec %q %q "$@"\n' \
    "$(dirname "$source")" "$SECURITY_VENV/bin/python" "$source" > "$wrapper"
  chmod 0755 "$wrapper"
  printf '%s\tpython-wrapper\t%s\tlatest\t%s\n' \
    "$command_name" "$source" "$wrapper" >> "$RESOLVED_FILE"
}

smoke_help_commands() {
  local command_name executable output rc failures=0
  for command_name in "$@"; do
    log "Smoke-testing ${command_name}"
    if ! executable="$(command -v "$command_name" 2>/dev/null)" \
      || [[ ! -x "$executable" ]]; then
      log "Smoke test could not resolve executable command ${command_name}"
      failures=$((failures + 1))
      continue
    fi
    if ! output="$(mktemp)"; then
      log "Smoke test could not create output file for ${command_name}"
      failures=$((failures + 1))
      continue
    fi
    if timeout 60 "$executable" --help </dev/null >"$output" 2>&1; then
      rc=0
    else
      rc=$?
    fi
    if (( rc == 124 || rc == 126 || rc == 127 )) \
      || grep -Eq 'Traceback \(most recent call last\)|ModuleNotFoundError:|^ImportError:|^SyntaxError:|can.t open file .*\[Errno' "$output"; then
      log "Smoke test failed for ${command_name} (exit ${rc})"
      tail -n 40 "$output" >&2
      failures=$((failures + 1))
    fi
    rm -f "$output"
  done
  if (( failures > 0 )); then
    log "${failures} command smoke test(s) failed"
    return 1
  fi
  return 0
}

python_first() {
  local command_name="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      python_command "$candidate" "$command_name"
      return 0
    fi
  done
  log "No Python entry point found for ${command_name}: $*"
  return 1
}

go_tool() {
  local name module binary
  name="$1"
  module="$2"
  binary="${3:-$name}"
  retry env GOBIN="$GOPATH/bin" go install "${module}@latest"
  link_command "$GOPATH/bin/$binary" "$name"
  local module_line
  module_line="$(go version -m "$GOPATH/bin/$binary" 2>/dev/null | awk '$1 == "mod" {print $2 "@" $3; exit}')"
  printf '%s\tgo\t%s\t%s\t%s\n' "$name" "$module" "${module_line:-latest}" "${COMMANDS_DIR}/${name}" >> "$RESOLVED_FILE"
}

python_repo() {
  local name="$1" url="$2"
  shift 2
  local destination="${SECURITY_TOOLS_DIR}/${name}"
  clone_repo "$name" "$url" "$destination"
  if [[ -f "$destination/requirements.txt" ]]; then
    # Some projects use relative entries such as `-e .` or `-r other.txt`.
    # pip resolves those against its current directory, so always run from the
    # checkout instead of from whichever directory invoked this installer.
    (cd "$destination" && "$SECURITY_VENV/bin/pip" install -r requirements.txt)
  elif [[ -f "$destination/requirements" ]]; then
    (cd "$destination" && "$SECURITY_VENV/bin/pip" install -r requirements)
  fi
  if [[ -f "$destination/pyproject.toml" || -f "$destination/setup.py" ]]; then
    "$SECURITY_VENV/bin/pip" install "$destination"
  fi
  if (( $# > 0 )); then
    local command_name source_path
    while (( $# >= 2 )); do
      command_name="$1"; source_path="$2"; shift 2
      if [[ "$source_path" == *.py ]]; then
        python_command "$destination/$source_path" "$command_name"
      else
        link_command "$destination/$source_path" "$command_name"
      fi
    done
  fi
}

github_latest_asset() {
  local name="$1" repo="$2" regex="$3" destination="$4"
  local api="https://api.github.com/repos/${repo}/releases/latest" json url tag
  json="$(retry curl -fsSL "$api")"
  tag="$(jq -r '.tag_name' <<<"$json")"
  url="$(jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex; "i")) | .browser_download_url' <<<"$json" | head -n1)"
  [[ -n "$url" && "$url" != null ]]
  retry curl -fsSL -o "$destination" "$url"
  printf '%s\tgithub-release\t%s\t%s\t%s\n' "$name" "$url" "$tag" "$destination" >> "$RESOLVED_FILE"
}

detect_arch() {
  case "${TARGETARCH:-$(uname -m)}" in
    amd64|x86_64) printf 'amd64\n' ;;
    arm64|aarch64) printf 'arm64\n' ;;
    *) log "Unsupported architecture: ${TARGETARCH:-$(uname -m)}"; return 1 ;;
  esac
}
