#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="python"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

setup_python() {
  python3 -m venv "$SECURITY_VENV"
  # setuptools 81 removed pkg_resources, which is still imported by the
  # current Shodan CLI and python-Wappalyzer. Keep the last compatible series
  # inside this isolated environment only; Hermes' own environment is untouched.
  "$SECURITY_VENV/bin/pip" install --upgrade pip 'setuptools<81' wheel
  "$SECURITY_VENV/bin/pip" install arjun censys fissix jsbeautifier lxml requests shodan uro
  for command_name in arjun censys shodan uro; do
    link_command "$SECURITY_VENV/bin/$command_name" "$command_name"
  done
  printf 'python-security-venv\tpython\tPyPI\t%s\t%s\n' "$("$SECURITY_VENV/bin/python" --version 2>&1)" "$SECURITY_VENV" >> "$RESOLVED_FILE"
}

install_python_project() {
  local name="$1" url="$2"
  shift 2
  python_repo "$name" "$url" "$@"
}

install_xsstrike() {
  local destination="$SECURITY_TOOLS_DIR/XSStrike"
  clone_repo XSStrike https://github.com/s0md3v/XSStrike.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  python_command "$destination/xsstrike.py" xsstrike
}

install_xss_vibes() {
  local destination="$SECURITY_TOOLS_DIR/xss_vibes"
  clone_repo xss_vibes https://github.com/faiyazahmad07/xss_vibes.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements"
  python_first xss-vibes "$destination/xss_vibes.py" "$destination/main.py"
}

install_oralyzer() {
  local destination="$SECURITY_TOOLS_DIR/Oralyzer"
  clone_repo Oralyzer https://github.com/r0075h3ll/Oralyzer.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  python_command "$destination/oralyzer.py" oralyzer
  cp "$destination/payloads.txt" "$SECURITY_ASSETS_DIR/payloads/open_redirect.txt"
}

install_poc_bomber() {
  local destination="$SECURITY_TOOLS_DIR/POC-bomber"
  clone_repo POC-bomber https://github.com/tr0uble-mAker/POC-bomber.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  python_first poc-bomber "$destination/pocbomber.py" "$destination/POC-bomber.py" "$destination/main.py"
}

install_injectus() {
  local destination="$SECURITY_TOOLS_DIR/Injectus"
  clone_repo Injectus https://github.com/dubs3c/Injectus.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  python_first Injectus "$destination/injectus.py" "$destination/Injectus.py" "$destination/main.py"
}

install_openredirex() {
  local destination="$SECURITY_TOOLS_DIR/OpenRedireX"
  clone_repo OpenRedireX https://github.com/devanshbatham/OpenRedireX.git "$destination"
  if [[ -f "$destination/requirements.txt" ]]; then "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"; fi
  python_first OpenRedireX "$destination/openredirex.py" "$destination/OpenRedireX.py"
}

install_wappalyzer_cli() {
  local destination="$SECURITY_TOOLS_DIR/wappalyzer-cli"
  clone_repo wappalyzer-cli https://github.com/gokulapap/wappalyzer-cli.git "$destination"
  "$SECURITY_VENV/bin/pip" install -r "$destination/requirements.txt"
  python_command "$destination/src/wappy" wappy
}

install_nosqlmap() {
  local destination="$SECURITY_TOOLS_DIR/NoSQLMap"
  clone_repo NoSQLMap https://github.com/codingo/NoSQLMap.git "$destination"
  # Upstream pins Python-2-era versions (including pymongo 2.7.2) and lists
  # itself as a dependency. Install compatible current libraries and keep the
  # source checkout intact instead of allowing that metadata to poison the
  # shared security virtualenv.
  "$SECURITY_VENV/bin/pip" install CouchDB httplib2 ipcalc pbkdf2 pymongo requests
  # NoSQLMap's default branch still contains Python 2 syntax. Convert the
  # checkout deterministically with fissix, then require every converted module
  # to compile before exposing the command.
  "$SECURITY_VENV/bin/python" - "$destination" <<'PY'
import compileall
import sys
from fissix.refactor import RefactoringTool, get_fixers_from_package

destination = sys.argv[1]
tool = RefactoringTool(get_fixers_from_package("fissix.fixes"))
tool.refactor_dir(destination, write=True)
if not compileall.compile_dir(destination, quiet=1):
    raise SystemExit("NoSQLMap Python 3 conversion did not compile")
PY
  printf 'NoSQLMap\tpython3-conversion\tfissix\tlatest\t%s\n' "$destination" >> "$RESOLVED_FILE"
  python_command "$destination/nosqlmap.py" nosqlmap
}

install_gopherus() {
  local destination="$SECURITY_TOOLS_DIR/Gopherus"
  # Upstream tarunkant/Gopherus is Python-2-only. This is the Python 3 port
  # submitted to upstream as pull request 18; its default branch compiles on
  # the modern Python runtime used by the Hermes base image.
  clone_repo Gopherus https://github.com/Antabuse-123/Gopherus.git "$destination"
  [[ ! -f "$destination/requirements.txt" ]] || \
    (cd "$destination" && "$SECURITY_VENV/bin/pip" install -r requirements.txt)
  "$SECURITY_VENV/bin/python" -m compileall -q "$destination"
  python_command "$destination/gopherus3.py" gopherus
}

install_droopescan() {
  local destination="$SECURITY_TOOLS_DIR/droopescan"
  clone_repo droopescan https://github.com/droope/droopescan.git "$destination"
  # droopescan pins Cement below 2.7. That release imports Python's removed
  # `imp` module and crashes on Python 3.13. Cement 2.10 retains the compatible
  # 2.x API and passes droopescan's help smoke test, so widen only this stale
  # packaging constraint before building the wheel.
  "$SECURITY_VENV/bin/python" - "$destination/setup.py" <<'PY'
import pathlib
import sys

setup_file = pathlib.Path(sys.argv[1])
source = setup_file.read_text()
old = "cement>=2.6,<2.6.99"
if old not in source:
    raise SystemExit("droopescan's expected Cement constraint changed upstream")
setup_file.write_text(source.replace(old, "cement>=2.10,<3"))
PY
  "$SECURITY_VENV/bin/pip" install "$destination"
  link_command "$SECURITY_VENV/bin/droopescan" droopescan
  printf 'droopescan\tpython3.13-compatibility\tcement>=2.10,<3\tlatest\t%s\n' \
    "$destination" >> "$RESOLVED_FILE"
}

install_whatwaf() {
  local destination="$SECURITY_TOOLS_DIR/WhatWaf"
  clone_repo WhatWaf https://github.com/Ekultek/WhatWaf.git "$destination"
  [[ ! -f "$destination/requirements.txt" ]] || \
    (cd "$destination" && "$SECURITY_VENV/bin/pip" install -r requirements.txt)
  # WhatWaf's setup.py imports runtime dependencies while pip is still in an
  # isolated build environment and also prompts when run as root. The command
  # is a source script, so installing its dependencies plus a wrapper is both
  # non-interactive and sufficient.
  cat > "$COMMANDS_DIR/whatwaf" <<'WRAPPER'
#!/bin/sh
set -eu
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
config_dir="${user_home}/.whatwaf"
mkdir -p "$config_dir/files" "$config_dir/plugins" "$config_dir/tampers"
cp -rn /opt/security-tools/WhatWaf/content/files/. "$config_dir/files/" 2>/dev/null || true
cp -rn /opt/security-tools/WhatWaf/content/plugins/. "$config_dir/plugins/" 2>/dev/null || true
cp -rn /opt/security-tools/WhatWaf/content/tampers/. "$config_dir/tampers/" 2>/dev/null || true
touch "$config_dir/whatwaf.sqlite"
cd /opt/security-tools/WhatWaf
exec /opt/toolchains/python/bin/python whatwaf "$@"
WRAPPER
  chmod 0755 "$COMMANDS_DIR/whatwaf"
}

install_tplmap() {
  local destination="$SECURITY_TOOLS_DIR/tplmap"
  clone_repo tplmap https://github.com/epinna/tplmap.git "$destination"
  # Upstream still pins wsgiref 0.1.2, a Python-2-only backport. Python 3 ships
  # wsgiref in its standard library. Use maintained dependency releases rather
  # than downgrading the shared environment to 2018-era packages.
  "$SECURITY_VENV/bin/pip" install PyYAML certifi chardet idna requests urllib3
  python_command "$destination/tplmap.py" tplmap
}

finalize_python_environment() {
  # SSRFmap pins dnspython 2.6.1, while current knockpy requires >=2.8. Restore
  # the compatible version after all source requirements have been processed.
  "$SECURITY_VENV/bin/pip" install --upgrade \
    'setuptools<81' 'dnspython>=2.8.0' 'requests>=2.32.3,<3' \
    'urllib3>=2,<3' 'charset-normalizer>=3,<4' 'chardet<6'
  "$SECURITY_VENV/bin/pip" check
}

smoke_python_tools() {
  smoke_help_commands \
    shodan altdns certcrunchy ctfr knockpy censys-subdomain-finder censys \
    dnsvalidator oralyzer interlace paramspider waymore xnLinkFinder uro arjun \
    xsstrike xss-vibes linkfinder nosqlmap ghauri droopescan \
    secretfinder tplmap sstimap GitDorker gitGraber poc-bomber Injectus \
    OpenRedireX ssrfmap gopherus wappy

  local output rc
  log "Smoke-testing whatwaf"
  output="$(mktemp)"
  if (cd "$SECURITY_TOOLS_DIR/WhatWaf" \
    && timeout 60 "$SECURITY_VENV/bin/python" whatwaf --help </dev/null >"$output" 2>&1); then
    rc=0
  else
    rc=$?
  fi
  if (( rc == 124 || rc == 126 || rc == 127 )) \
    || grep -Eq 'Traceback \(most recent call last\)|ModuleNotFoundError:|^ImportError:|^SyntaxError:|can.t open file .*\[Errno' "$output"; then
    log "Smoke test failed for whatwaf (exit ${rc})"
    tail -n 40 "$output" >&2
    rm -f "$output"
    return 1
  fi
  rm -f "$output"
}

install_step "Python security virtualenv" "venv/pip" setup_python
install_step "altdns" "python-git" install_python_project altdns https://github.com/infosec-au/altdns.git
install_step "CertCrunchy" "python-git" install_python_project CertCrunchy https://github.com/joda32/CertCrunchy.git certcrunchy certcrunchy.py
install_step "ctfr" "python-git" install_python_project ctfr https://github.com/UnaPibaGeek/ctfr.git ctfr ctfr.py
install_step "knockpy" "python-git" install_python_project knock https://github.com/guelfoweb/knock.git
install_step "censys-subdomain-finder" "python-git" install_python_project censys-subdomain-finder https://github.com/christophetd/censys-subdomain-finder.git censys-subdomain-finder censys-subdomain-finder.py
install_step "dnsvalidator" "python-git" install_python_project dnsvalidator https://github.com/vortexau/dnsvalidator.git
install_step "Oralyzer" "python-git" install_oralyzer
install_step "Interlace" "python-git" install_python_project Interlace https://github.com/codingo/Interlace.git
install_step "ParamSpider" "python-git" install_python_project paramspider https://github.com/devanshbatham/ParamSpider.git
install_step "waymore" "python-git" install_python_project waymore https://github.com/xnl-h4ck3r/waymore.git
install_step "xnLinkFinder" "python-git" install_python_project xnLinkFinder https://github.com/xnl-h4ck3r/xnLinkFinder.git
install_step "XSStrike" "python-git" install_xsstrike
install_step "xss_vibes" "python-git" install_xss_vibes
install_step "LinkFinder" "python-git" install_python_project LinkFinder https://github.com/GerbenJavado/LinkFinder.git linkfinder linkfinder.py
install_step "NoSQLMap" "python-git" install_nosqlmap
install_step "ghauri" "python-git" install_python_project ghauri https://github.com/r0oth3x49/ghauri.git
install_step "droopescan" "python-git with Python 3.13 compatibility" install_droopescan
install_step "WhatWaf" "python-git" install_whatwaf
install_step "SecretFinder" "python-git" install_python_project SecretFinder https://github.com/m4ll0k/SecretFinder.git secretfinder SecretFinder.py
install_step "tplmap" "python-git" install_tplmap
install_step "SSTImap" "python-git" install_python_project SSTImap https://github.com/vladko312/SSTImap.git sstimap sstimap.py
install_step "GitDorker" "python-git" install_python_project GitDorker https://github.com/obheda12/GitDorker.git GitDorker GitDorker.py
install_step "gitGraber" "python-git" install_python_project gitGraber https://github.com/hisxo/gitGraber.git gitGraber gitGraber.py
install_step "POC-bomber" "python-git" install_poc_bomber
install_step "Injectus" "python-git" install_injectus
install_step "OpenRedireX" "python-git" install_openredirex
install_step "SSRFmap" "python-git" install_python_project SSRFmap https://github.com/swisskyrepo/SSRFmap.git ssrfmap ssrfmap.py
install_step "Gopherus" "Python 3 compatibility fork" install_gopherus
install_step "wappalyzer-cli" "python-git" install_wappalyzer_cli
install_step "Python dependency consistency" "pip check" finalize_python_environment
install_step "Python command smoke tests" "offline --help" smoke_python_tools
finish_installer
