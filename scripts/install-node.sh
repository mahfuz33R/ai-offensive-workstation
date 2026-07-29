#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="node"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

NODE_VERSION="${NODE_VERSION:-latest}"
NPM_VERSION="${NPM_VERSION:-latest}"
NODE_INSTALL_DIR="${NODE_INSTALL_DIR:-/opt/toolchains/node}"

resolve_node_version() {
  local node_arch="$1" requested="$NODE_VERSION"
  if [[ "$requested" != latest ]]; then
    [[ "$requested" == v* ]] || requested="v${requested}"
    printf '%s\n' "$requested"
    return
  fi

  retry curl -fsSL https://nodejs.org/dist/index.json \
    | jq -er --arg artifact "linux-${node_arch}" '
        map(select(.files | index($artifact)))[0].version
      '
}

install_official_node() {
  local arch node_arch resolved archive base checksum_file temporary
  arch="$(detect_arch)"
  case "$arch" in
    amd64) node_arch=x64 ;;
    arm64) node_arch=arm64 ;;
  esac

  resolved="$(resolve_node_version "$node_arch")"
  [[ "$resolved" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
  archive="node-${resolved}-linux-${node_arch}.tar.xz"
  base="https://nodejs.org/dist/${resolved}"
  temporary="$(mktemp -d)"
  checksum_file="$temporary/SHASUMS256.txt"

  retry curl -fsSL -o "$checksum_file" "$base/SHASUMS256.txt"
  retry curl -fsSL -o "$temporary/$archive" "$base/$archive"
  (
    cd "$temporary"
    grep -E "  ${archive}$" SHASUMS256.txt | sha256sum --check -
  )

  rm -rf "$NODE_INSTALL_DIR"
  install -d -m 0755 "$NODE_INSTALL_DIR"
  tar -xJf "$temporary/$archive" \
    --strip-components=1 \
    -C "$NODE_INSTALL_DIR"
  rm -rf "$temporary"

  ln -sfn "$NODE_INSTALL_DIR/bin/node" /usr/local/bin/node
  ln -sfn "$NODE_INSTALL_DIR/bin/npm" /usr/local/bin/npm
  ln -sfn "$NODE_INSTALL_DIR/bin/npx" /usr/local/bin/npx
  if [[ -x "$NODE_INSTALL_DIR/bin/corepack" ]]; then
    ln -sfn "$NODE_INSTALL_DIR/bin/corepack" /usr/local/bin/corepack
  fi

  PATH="/usr/local/bin:${NODE_INSTALL_DIR}/bin:${PATH}" \
    npm install --global --no-audit --no-fund "npm@${NPM_VERSION}"
}

verify_node() {
  local major installed_node installed_npm registry_npm
  command -v node npm npx >/dev/null
  installed_node="$(node --version)"
  installed_npm="$(npm --version)"
  major="${installed_node#v}"
  major="${major%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]]
  # Current agent-browser requires Node 24 or newer.
  (( major >= 24 ))
  [[ "$installed_npm" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]

  if [[ "$NPM_VERSION" == latest ]]; then
    registry_npm="$(npm view npm@latest version)"
    [[ "$installed_npm" == "$registry_npm" ]]
  fi

  printf 'node\tofficial-release\thttps://nodejs.org/dist\t%s\t%s\n' \
    "$installed_node" "$(command -v node)" >> "$RESOLVED_FILE"
  printf 'npm\tnpm-registry\tnpm@%s\t%s\t%s\n' \
    "$NPM_VERSION" "$installed_npm" "$(command -v npm)" >> "$RESOLVED_FILE"
}

install_step "latest official Node.js and npm" \
  "nodejs.org checksummed binary and npm stable dist-tag" install_official_node
install_step "Node.js and npm runtime contract" \
  "global command and supported-major verification" verify_node
finish_installer
