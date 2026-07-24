#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="network-apt"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

install_apt_network() {
  apt-get update
  apt-get install -y --no-install-recommends \
    dirsearch masscan netcat-openbsd nmap python3-pkg-resources sqlmap \
    tcpdump traceroute wfuzz
  rm -rf /var/lib/apt/lists/*
}

install_step "network and security packages" "apt" install_apt_network
finish_installer
