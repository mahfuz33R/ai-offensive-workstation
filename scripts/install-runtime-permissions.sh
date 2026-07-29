#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="runtime-permissions"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

grant_network_caps() {
  local command_name="$1" capabilities="$2" executable current
  executable="$(command -v "$command_name")"
  executable="$(readlink -f "$executable")"
  [[ -x "$executable" ]]
  setcap "$capabilities" "$executable"
  current="$(getcap "$executable")"
  [[ -n "$current" ]]
  printf '%s\tfile-capabilities\t%s\t%s\t%s\n' \
    "$command_name" "$capabilities" "$current" "$executable" >> "$RESOLVED_FILE"
}

install_step "nmap raw sockets" "Linux capabilities" \
  grant_network_caps nmap cap_net_admin,cap_net_raw,cap_net_bind_service+eip
install_step "masscan raw sockets" "Linux capabilities" \
  grant_network_caps masscan cap_net_admin,cap_net_raw+eip
install_step "tcpdump packet capture" "Linux capabilities" \
  grant_network_caps tcpdump cap_net_admin,cap_net_raw+eip
install_step "naabu raw sockets" "Linux capabilities" \
  grant_network_caps naabu cap_net_admin,cap_net_raw+eip

finish_installer
