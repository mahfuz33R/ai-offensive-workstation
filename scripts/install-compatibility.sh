#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="compatibility"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

compat_alias() {
  local legacy="$1" canonical="$2" target
  target="$(command -v "$canonical")"
  [[ -n "$target" ]]
  ln -sfn "$target" "${COMMANDS_DIR}/$legacy"
  printf '%s\tcompatibility-alias\t%s\tlatest\t%s\n' "$legacy" "$canonical" "${COMMANDS_DIR}/$legacy" >> "$RESOLVED_FILE"
}

ALIASES=(
  "lilly.sh|lilly"
  "certcrunchy.py|certcrunchy"
  "ctfr.py|ctfr"
  "censys-subdomain-finder.py|censys-subdomain-finder"
  "httpx-toolkit|httpx"
  "oralyzer.py|oralyzer"
  "cmake.sh|cmake"
  "xsstrike.py|xsstrike"
  "xss_vibes|xss-vibes"
  "findom-xss.sh|findom-xss"
  "linkfinder.py|linkfinder"
  "nosqlmap.py|nosqlmap"
  "SecretFinder.py|secretfinder"
  "GitDorker.py|GitDorker"
  "gitGraber.py|gitGraber"
  "gitdumper.sh|gitdumper"
  "extractor.sh|extractor"
  "gitfinder.py|gitfinder"
  "gau-expose.sh|gau-expose"
  "tplmap.py|tplmap"
  "sstimap.py|sstimap"
  "pocbomber.py|poc-bomber"
  "Injectus.py|Injectus"
  "openredirex|OpenRedireX"
  "ssrfmap.py|ssrfmap"
)

for spec in "${ALIASES[@]}"; do
  IFS='|' read -r legacy canonical <<<"$spec"
  install_step "$legacy" "alias for $canonical" compat_alias "$legacy" "$canonical"
done

finish_installer
