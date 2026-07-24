#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="ruby"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

install_wpscan() {
  gem install --no-document wpscan
  command -v wpscan >/dev/null
  printf 'wpscan\tgem\thttps://rubygems.org/gems/wpscan\t%s\t%s\n' "$(gem list -e wpscan)" "$(command -v wpscan)" >> "$RESOLVED_FILE"
}

install_whatweb() {
  local destination="$SECURITY_TOOLS_DIR/WhatWeb"
  clone_repo WhatWeb https://github.com/urbanadventurer/WhatWeb.git "$destination"
  link_command "$destination/whatweb" whatweb
}

install_step "WPScan" "gem" install_wpscan
install_step "WhatWeb" "ruby-git" install_whatweb
install_step "Ruby command smoke tests" "offline --help" \
  smoke_help_commands wpscan whatweb
finish_installer
