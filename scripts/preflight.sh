#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

REQUIRE_DOCKER=0
if [[ "${1:-}" == --require-docker ]]; then
  REQUIRE_DOCKER=1
  shift
fi
if (( $# > 0 )); then
  printf 'usage: %s [--require-docker]\n' "$0" >&2
  exit 64
fi

FAILURES=0
CHECKS=0

pass() {
  CHECKS=$((CHECKS + 1))
  printf '[PASS] %s\n' "$*"
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  printf '[FAIL] %s\n' "$*" >&2
}

check_file_ignored() {
  local ignore_file="$1" ignored_name="$2"
  if grep -Fxq "$ignored_name" "$ignore_file"; then
    pass "$ignored_name is excluded by $ignore_file"
  else
    fail "$ignored_name is not excluded by $ignore_file"
  fi
}

printf 'Running source, safety, and architecture checks...\n'

if [[ -f .env ]]; then
  mode="$(stat -c '%a' .env)"
  if [[ "$mode" == 600 ]]; then
    pass 'Single private .env exists with permissions 600'
  else
    fail ".env permissions are $mode; run: chmod 600 .env"
  fi
else
  fail 'Run: bash scripts/configure-host.sh'
fi

if [[ ! -e secrets.env && ! -e secrets.env.example && ! -e versions.env ]]; then
  pass 'Legacy split configuration files are absent'
else
  fail 'Remove legacy secrets.env, secrets.env.example, and versions.env after migrating to .env'
fi

check_file_ignored .dockerignore .env
check_file_ignored .gitignore .env

if bash scripts/unit-test.sh; then
  pass 'All offline unit and syntax tests pass'
else
  fail 'Offline unit or syntax tests failed'
fi

inventory_result="$(awk -F '\t' '
  BEGIN { errors=0; count=0 }
  /^#/ || NF == 0 { next }
  NF != 3 {
    printf "line %d has %d fields (expected 3)\n", NR, NF
    errors++
    next
  }
  $1 !~ /^(command|path|asset|capability)$/ {
    printf "line %d has unknown kind: %s\n", NR, $1
    errors++
  }
  {
    key=$1 SUBSEP $2
    if (seen[key]++) {
      printf "line %d duplicates kind/name: %s/%s\n", NR, $1, $2
      errors++
    }
    count++
  }
  END { printf "COUNT=%d ERRORS=%d\n", count, errors }
' scripts/manifests/tool-inventory.tsv)"
if grep -q 'ERRORS=0$' <<<"$inventory_result"; then
  inventory_count="$(sed -n 's/^COUNT=\([0-9][0-9]*\) ERRORS=0$/\1/p' <<<"$inventory_result")"
  pass "Tool inventory is valid ($inventory_count required checks)"
else
  printf '%s\n' "$inventory_result" >&2
  fail 'Tool inventory is malformed'
fi

if [[ -s knowledge/payloads/PayloadsAllTheThings/README.md ]] \
  && [[ -d knowledge/payloads/payload-box ]] \
  && find knowledge/payloads/payload-box \
    -mindepth 2 -maxdepth 2 -name README.md -print -quit \
    | grep -q .; then
  pass 'Vendored payload repositories are present for the Docker build'
else
  fail 'Vendored payload repositories are missing from knowledge/payloads'
fi

legacy_missing=0
legacy_count=0
while IFS= read -r command_name; do
  [[ -n "$command_name" && "${command_name:0:1}" != '#' ]] || continue
  legacy_count=$((legacy_count + 1))
  if ! awk -F '\t' -v wanted="$command_name" \
    '$1 == "command" && $3 == wanted { found=1 } END { exit !found }' \
    scripts/manifests/tool-inventory.tsv; then
    printf '[FAIL] Original command is not inventoried: %s\n' \
      "$command_name" >&2
    legacy_missing=1
  fi
done < scripts/manifests/original-check-tools.txt
if (( legacy_missing == 0 )); then
  pass "All $legacy_count original tool names remain inventoried"
else
  fail 'One or more original tool names is not checked by the image'
fi

required_installers=(
  install-kali-base.sh
  install-system-tools.sh
  install-zsh.sh
  install-network-tools.sh
  install-go.sh
  install-python.sh
  install-cyberstrike-kb.sh
  install-node.sh
  install-rust.sh
  install-ruby.sh
  install-binary-tools.sh
  install-source-tools.sh
  install-compatibility.sh
  install-assets.sh
  install-browser-automation.sh
  install-cyberstrike.sh
  install-hermes.sh
  install-runtime-permissions.sh
)
missing_installer=0
for installer in "${required_installers[@]}"; do
  if [[ ! -f "scripts/$installer" ]] \
    || ! grep -Fq "/tmp/install/$installer" Dockerfile; then
    printf '[FAIL] Dockerfile is not linked to scripts/%s\n' "$installer" >&2
    missing_installer=1
  fi
done
if (( missing_installer == 0 )); then
  pass 'Dockerfile invokes every required installation stage'
else
  fail 'Dockerfile installer chain is incomplete'
fi

if grep -Fq 'FROM ${KALI_IMAGE}:${KALI_TAG}${KALI_DIGEST}' Dockerfile \
  && grep -Fq 'kali-linux-headless' scripts/install-kali-base.sh \
  && ! grep -Fq 'nousresearch/hermes-agent' Dockerfile; then
  pass 'Image uses official Kali directly with the standard headless metapackage'
else
  fail 'Kali direct-base or standard metapackage linkage is missing'
fi

if grep -Fq 'releases/latest' scripts/install-hermes.sh \
  && grep -Fq '/usr/local/lib/hermes-agent' scripts/install-hermes.sh \
  && grep -Fq 'install-hermes.sh' Dockerfile; then
  pass 'Hermes resolves the latest stable release and installs with the standard FHS layout'
else
  fail 'Hermes direct stable-release installation is incomplete'
fi

if grep -Fq 'CYBERSTRIKE_VERSION' scripts/install-cyberstrike.sh \
  && grep -Fq '"${CYBERSTRIKE_PACKAGE}@${version_selector}"' \
    scripts/install-cyberstrike.sh \
  && grep -Fq 'CYBERSTRIKE_CACHE_BUST' scripts/build-and-verify.sh; then
  pass 'CyberStrike resolves the configured stable npm release on managed builds'
else
  fail 'CyberStrike release resolution or cache invalidation is missing'
fi

if grep -Fq 'verify-installation.sh' Dockerfile \
  && grep -Fq 'tool-inventory.tsv' Dockerfile; then
  pass 'Strict installation verification remains a Docker build gate'
else
  fail 'Dockerfile does not run the strict tool verifier'
fi

if python3 scripts/verify-knowledge-base.py; then
  pass 'Hermes pentesting knowledge base covers the authoritative inventory'
else
  fail 'Hermes pentesting knowledge base is incomplete or malformed'
fi

if [[ -s knowledge/skills/offensive-workstation-pentesting/SKILL.md ]] \
  && [[ -s knowledge/skills/offensive-workstation-pentesting/references/cyberstrike/AGENTS.md ]] \
  && [[ -s knowledge/skills/offensive-workstation-pentesting/references/cyberstrike/MEMORY-SEED.md ]] \
  && [[ -s knowledge/skills/offensive-workstation-pentesting/references/WORKSTATION-MEMORY-SEED.md ]] \
  && [[ -s knowledge/skills/offensive-workstation-pentesting/references/LOCAL-RAG.md ]] \
  && [[ -d knowledge/skills/offensive-workstation-pentesting/references/cyberstrike/source-library ]] \
  && grep -Fq 'cyberstrike-kb search "$USER_INTENT"' \
    knowledge/skills/offensive-workstation-pentesting/SKILL.md \
  && grep -Fq 'workstation-kb search "$USER_INTENT"' \
    knowledge/skills/offensive-workstation-pentesting/SKILL.md \
  && grep -Fq 'HERMES_BUNDLED_CYBERSTRIKE_KB' scripts/workstation-entrypoint.sh \
  && grep -Fq 'HERMES_BUNDLED_WORKSTATION_KB' scripts/workstation-entrypoint.sh \
  && grep -Fq 'CYBERSTRIKE_MEMORY_MARKER' scripts/workstation-entrypoint.sh \
  && grep -Fq 'WORKSTATION_MEMORY_MARKER' scripts/workstation-entrypoint.sh \
  && grep -Fq 'flock 9' scripts/workstation-entrypoint.sh; then
  pass 'Skill, vector RAG, memory pointer, and serialized runtime synchronization are connected'
else
  fail 'Hermes skill/vector RAG/memory runtime connection is incomplete'
fi

if grep -Fq 'NODE_VERSION="${NODE_VERSION:-latest}"' scripts/install-node.sh \
  && grep -Fq 'NPM_VERSION="${NPM_VERSION:-latest}"' scripts/install-node.sh \
  && grep -Fq 'playwright install chromium firefox' \
    scripts/install-browser-automation.sh \
  && grep -Fq $'asset\thermes-firefox\t/opt/browser-tools/firefox' \
    scripts/manifests/tool-inventory.tsv; then
  pass 'Latest Node/npm and Chromium/Firefox headless contracts are build-gated'
else
  fail 'Node/npm or dual-browser installation contract is incomplete'
fi

if grep -Eq '^[[:space:]]*privileged:[[:space:]]*true([[:space:]]|$)' \
  docker-compose.yml; then
  fail 'Compose must not use privileged mode'
else
  pass 'Compose does not use privileged mode'
fi

if grep -Eq '^[[:space:]]*network_mode:[[:space:]]*host([[:space:]]|$)' \
  docker-compose.yml; then
  fail 'Compose must not share the host network namespace'
else
  pass 'Compose does not use host networking'
fi

if grep -Fq 'driver: bridge' docker-compose.yml \
  && grep -Fq '127.0.0.1:8642:8642' docker-compose.yml \
  && grep -Fq '127.0.0.1:${HERMES_DASHBOARD_PORT:-9119}:9119' \
    docker-compose.yml; then
  pass 'Workstation traffic uses bridge/NAT with host-local published ports'
else
  fail 'Bridge/NAT network or localhost port bindings are incomplete'
fi

if grep -Fq '/opt/data' docker-compose.yml \
  && grep -Fq '/root' docker-compose.yml \
  && grep -Fq './workspace:/workspace' docker-compose.yml; then
  pass 'Hermes data, root home, and workspace bind mounts are preserved'
else
  fail 'Compose persistence mounts are incomplete'
fi

if grep -Fq 'network_mode: none' docker-compose.yml \
  && grep -Fq 'read_only: true' docker-compose.yml \
  && grep -Fq 'no-new-privileges:true' docker-compose.yml \
  && grep -Fq 'malware-analysis:/analysis' docker-compose.yml; then
  pass 'Malware profile has no network, a read-only root, and Docker-managed storage'
else
  fail 'Malware-analysis isolation profile is incomplete'
fi

public_files=(Dockerfile docker-compose.yml .env.example .zshrc)
while IFS= read -r -d '' file; do public_files+=("$file"); done \
  < <(find scripts tests -type f -print0)
while IFS= read -r -d '' file; do public_files+=("$file"); done \
  < <(find knowledge/skills -type f -print0)
secret_scan="$(mktemp)"
if grep -nHE \
  '^(SHODAN_API_KEY|CENSYS_API_ID|CENSYS_API_SECRET|VIRUSTOTAL_API_KEY|INTERACTSH_AUTH_TOKEN|ANTHROPIC_API_KEY|OPENAI_API_KEY|GOOGLE_API_KEY|OPENROUTER_API_KEY|GROQ_API_KEY)=.+$' \
  "${public_files[@]}" >"$secret_scan"; then
  cat "$secret_scan" >&2
  fail 'A credential variable has a non-empty value in a public/build file'
else
  pass 'No configured credential values occur in public/build files'
fi
rm -f "$secret_scan"

if (( REQUIRE_DOCKER )); then
  if ! command -v docker >/dev/null 2>&1; then
    fail 'Docker command is required for a managed build'
  elif ! docker compose version >/dev/null 2>&1; then
    fail 'Docker Compose plugin is required for a managed build'
  elif ! docker compose config --quiet; then
    fail 'docker-compose.yml does not resolve'
  elif ! docker info >/dev/null 2>&1; then
    fail 'Current user cannot access the Docker engine'
  else
    pass 'Docker, Compose, configuration, and engine access are ready'
  fi
fi

if (( FAILURES > 0 )); then
  printf 'Preflight failed: %d of %d checks failed.\n' \
    "$FAILURES" "$CHECKS" >&2
  exit 1
fi

printf 'Preflight passed: all %d checks succeeded.\n' "$CHECKS"
