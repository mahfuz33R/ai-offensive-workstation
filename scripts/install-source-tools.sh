#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="source"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

install_lilly() {
  clone_repo Lilly https://github.com/Dheerajmadhukar/Lilly.git "$SECURITY_TOOLS_DIR/Lilly"
  bash -n "$SECURITY_TOOLS_DIR/Lilly/lilly.sh"
  link_command "$SECURITY_TOOLS_DIR/Lilly/lilly.sh" lilly
}

install_findom_xss() {
  clone_repo findom-xss https://github.com/dwisiswant0/findom-xss.git "$SECURITY_TOOLS_DIR/findom-xss"
  bash -n "$SECURITY_TOOLS_DIR/findom-xss/findom-xss.sh"
  link_command "$SECURITY_TOOLS_DIR/findom-xss/findom-xss.sh" findom-xss
}

install_js_scanner() {
  clone_repo JSScanner https://github.com/dark-warlord14/JSScanner.git "$SECURITY_TOOLS_DIR/JSScanner"
  bash -n "$SECURITY_TOOLS_DIR/JSScanner/script.sh"
  link_command "$SECURITY_TOOLS_DIR/JSScanner/script.sh" JSScanner
}

install_git_tools() {
  local destination="$SECURITY_TOOLS_DIR/GitTools"
  clone_repo GitTools https://github.com/internetwache/GitTools.git "$destination"
  bash -n "$destination/Dumper/gitdumper.sh"
  bash -n "$destination/Extractor/extractor.sh"
  "$SECURITY_VENV/bin/python" -m py_compile "$destination/Finder/gitfinder.py"
  link_command "$destination/Dumper/gitdumper.sh" gitdumper
  link_command "$destination/Extractor/extractor.sh" extractor
  python_command "$destination/Finder/gitfinder.py" gitfinder
}

install_gau_expose() {
  clone_repo Gau-Expose https://github.com/tamimhasan404/Gau-Expose.git "$SECURITY_TOOLS_DIR/Gau-Expose"
  bash -n "$SECURITY_TOOLS_DIR/Gau-Expose/gau-expose.sh"
  link_command "$SECURITY_TOOLS_DIR/Gau-Expose/gau-expose.sh" gau-expose
}

install_kiterunner() {
  local destination="$SECURITY_TOOLS_DIR/kiterunner"
  clone_repo kiterunner https://github.com/assetnote/kiterunner.git "$destination"
  make -C "$destination" build
  link_command "$destination/dist/kr" kr
}

install_sploitscan() {
  local destination="$SECURITY_TOOLS_DIR/SploitScan"
  local sploitscan_venv="$TOOLCHAINS_DIR/python-apps/sploitscan"
  clone_repo SploitScan https://github.com/xaitax/SploitScan.git "$destination"
  # SploitScan pins tqdm 4.68.4 while Interlace pins tqdm 4.62.3. They cannot
  # coexist in one pip environment, so keep SploitScan as an isolated app.
  python3 -m venv "$sploitscan_venv"
  "$sploitscan_venv/bin/pip" install --upgrade pip wheel
  "$sploitscan_venv/bin/pip" install "$destination"
  "$sploitscan_venv/bin/pip" check
  link_command "$sploitscan_venv/bin/sploitscan" sploitscan
  printf 'sploitscan\tpython-app-venv\t%s\t%s\t%s\n' \
    "$destination" "$("$sploitscan_venv/bin/python" --version 2>&1)" "$sploitscan_venv" \
    >> "$RESOLVED_FILE"
}

verify_python_environment() {
  "$SECURITY_VENV/bin/pip" check
  "$TOOLCHAINS_DIR/python-apps/sploitscan/bin/pip" check
  smoke_help_commands interlace sploitscan aem_hacker.py gitfinder
}

install_earlybird() {
  local destination="$SECURITY_TOOLS_DIR/earlybird"
  clone_repo earlybird https://github.com/americanexpress/earlybird.git "$destination"
  (cd "$destination" && ./build.sh)
  link_command "$destination/binaries/go-earlybird-linux" go-earlybird
}

install_massdns() {
  local destination="$SECURITY_TOOLS_DIR/massdns"
  clone_repo massdns https://github.com/blechschmidt/massdns.git "$destination"
  make -C "$destination"
  link_command "$destination/bin/massdns" massdns
}

install_nikto() {
  local destination="$SECURITY_TOOLS_DIR/nikto" dbcheck_output rc
  # Debian Trixie does not ship Nikto in its configured repositories. Keep the
  # complete upstream tree because the Perl entry point loads its plugins,
  # databases, and configuration relative to this checkout.
  clone_repo nikto https://github.com/sullo/nikto.git "$destination"
  perl -MJSON -MXML::Writer -MIO::Socket::SSL -MXML::LibXML -e 1
  perl -c "$destination/program/nikto.pl"
  # Nikto prefers $PWD/plugins over the plugin directory beside nikto.pl.
  # Hermes also has /opt/hermes/plugins, so a plain symlink makes Nikto load
  # the unrelated Hermes directory and fail. Always enter Nikto's program
  # directory before executing it.
  printf '#!/bin/sh\ncd %q\nexec %q "$@"\n' \
    "$destination/program" "$destination/program/nikto.pl" \
    > "$COMMANDS_DIR/nikto"
  chmod 0755 "$COMMANDS_DIR/nikto"
  printf '%s\tcommand-wrapper\t%s\tlatest\t%s\n' \
    nikto "$destination/program/nikto.pl" "$COMMANDS_DIR/nikto" \
    >> "$RESOLVED_FILE"
  dbcheck_output="$(mktemp)"
  if timeout 30 "$COMMANDS_DIR/nikto" -dbcheck -nocheck \
      </dev/null >"$dbcheck_output" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  # Nikto 2.6 returns 1 after a successful database integrity report because
  # it also reports currently unused test IDs. Treat only 0/1 as expected,
  # and require the two stable integrity-report sections to be present.
  if (( rc != 0 && rc != 1 )) \
      || ! grep -q 'Syntax Check:' "$dbcheck_output" \
      || ! grep -q 'Checking plugins for duplicate test IDs' "$dbcheck_output"; then
    cat "$dbcheck_output" >&2
    rm -f "$dbcheck_output"
    return 1
  fi
  rm -f "$dbcheck_output"
  timeout 30 "$COMMANDS_DIR/nikto" -Version </dev/null
}

install_aem_hacker() {
  local destination="$SECURITY_TOOLS_DIR/aem-hacker"
  clone_repo aem-hacker https://github.com/0ang3el/aem-hacker.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  "$SECURITY_VENV/bin/python" -m py_compile "$destination/aem_hacker.py"
  python_command "$destination/aem_hacker.py" aem_hacker.py
}

install_step "Lilly" "shell-git" install_lilly
install_step "findom-xss" "shell-git" install_findom_xss
install_step "JSScanner" "shell-git" install_js_scanner
install_step "GitTools" "mixed-git" install_git_tools
install_step "Gau-Expose" "shell-git" install_gau_expose
install_step "AEM Hacker" "Python source" install_aem_hacker
install_step "EarlyBird" "source build" install_earlybird
install_step "Smuggler" "source checkout" clone_repo smuggler https://github.com/defparam/smuggler.git "$SECURITY_TOOLS_DIR/smuggler"
install_step "Kiterunner" "Go source build" install_kiterunner
install_step "SploitScan" "Python source" install_sploitscan
install_step "subjack source data" "source checkout" clone_repo subjack https://github.com/haccer/subjack.git "$SECURITY_TOOLS_DIR/subjack"
install_step "MassDNS" "C source build" install_massdns
install_step "Nikto" "Perl source checkout" install_nikto
install_step "Python dependency consistency" "pip check" verify_python_environment
finish_installer
