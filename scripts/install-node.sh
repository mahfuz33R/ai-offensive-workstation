#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="node"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

verify_node() {
  command -v node >/dev/null
  command -v npm >/dev/null
  printf 'node\truntime\tHermes base image\t%s\t%s\n' "$(node --version)" "$(command -v node)" >> "$RESOLVED_FILE"
}

# hunt_tools.sh's npm installs are inside the commented-out Sudomy block.
# Node is still verified because Hermes and browser tooling depend on it.
install_step "Hermes Node.js runtime" "base-image" verify_node
finish_installer
