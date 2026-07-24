#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

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

printf 'Running host-side safety and linkage checks...\n'

if command -v docker >/dev/null 2>&1; then
  pass 'Docker command is installed'
else
  fail 'Docker command is not installed'
fi

if docker compose version >/dev/null 2>&1; then
  pass 'Docker Compose plugin is installed'
else
  fail 'Docker Compose plugin is not available'
fi

if [[ -f .env ]]; then
  pass 'Machine-specific .env exists'
else
  fail 'Run: bash scripts/configure-host.sh'
fi

if [[ -f secrets.env ]]; then
  mode="$(stat -c '%a' secrets.env)"
  if [[ "$mode" == 600 ]]; then
    pass 'secrets.env permissions are 600'
  else
    fail "secrets.env permissions are $mode; run: chmod 600 secrets.env"
  fi
else
  fail 'secrets.env is missing; copy secrets.env.example to secrets.env'
fi

check_file_ignored .dockerignore secrets.env
check_file_ignored .dockerignore .env
check_file_ignored .gitignore secrets.env
check_file_ignored .gitignore .env

syntax_failed=0
while IFS= read -r -d '' script; do
  if ! bash -n "$script"; then
    printf '[FAIL] Bash syntax: %s\n' "$script" >&2
    syntax_failed=1
  fi
done < <(find scripts -type f -name '*.sh' -print0)
if (( syntax_failed == 0 )); then
  pass 'Every shell script has valid Bash syntax'
else
  fail 'One or more shell scripts has invalid Bash syntax'
fi

if docker compose config -q; then
  pass 'docker-compose.yml resolves successfully'
else
  fail 'docker-compose.yml is invalid or has unresolved values'
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
' scripts/tool-inventory.tsv)"
if grep -q 'ERRORS=0$' <<<"$inventory_result"; then
  inventory_count="$(sed -n 's/^COUNT=\([0-9][0-9]*\) ERRORS=0$/\1/p' <<<"$inventory_result")"
  pass "Tool inventory is valid ($inventory_count required checks)"
else
  printf '%s\n' "$inventory_result" >&2
  fail 'Tool inventory is malformed'
fi

if [[ -s PayloadsAllTheThings/README.md ]] \
  && [[ -d payload-box ]] \
  && find payload-box -mindepth 2 -maxdepth 2 -name README.md -print -quit | grep -q .; then
  pass 'Local payload repositories are present for the Docker build'
else
  fail 'PayloadsAllTheThings and payload-box must exist at the project root'
fi

legacy_missing=0
legacy_count=0
while IFS= read -r command_name; do
  [[ -n "$command_name" && "${command_name:0:1}" != '#' ]] || continue
  legacy_count=$((legacy_count + 1))
  if ! awk -F '\t' -v wanted="$command_name" \
    '$1 == "command" && $3 == wanted { found=1 } END { exit !found }' \
    scripts/tool-inventory.tsv; then
    printf '[FAIL] Original check_tools.sh command is not inventoried: %s\n' \
      "$command_name" >&2
    legacy_missing=1
  fi
done < config/original-check-tools.txt
if (( legacy_missing == 0 )); then
  pass "All $legacy_count original check_tools.sh names are inventoried"
else
  fail 'One or more original check_tools.sh names is not checked by the image'
fi

required_installers=(
  install-system-tools.sh
  install-zsh.sh
  install-network-tools.sh
  install-go.sh
  install-python.sh
  install-node.sh
  install-rust.sh
  install-ruby.sh
  install-binary-tools.sh
  install-source-tools.sh
  install-compatibility.sh
  install-assets.sh
  install-browser-automation.sh
  install-runtime-permissions.sh
)
missing_installer=0
for installer in "${required_installers[@]}"; do
  if [[ ! -f "scripts/$installer" ]] || ! grep -Fq "/tmp/install/$installer" Dockerfile; then
    printf '[FAIL] Dockerfile is not linked to scripts/%s\n' "$installer" >&2
    missing_installer=1
  fi
done
if (( missing_installer == 0 )); then
  pass 'Dockerfile invokes every required ecosystem installer'
else
  fail 'Dockerfile installer chain is incomplete'
fi

if grep -Fq 'verify-installation.sh' Dockerfile \
  && grep -Fq 'tool-inventory.tsv' Dockerfile; then
  pass 'Strict installation verification is a Docker build gate'
else
  fail 'Dockerfile does not run the strict tool verifier'
fi

if python3 scripts/verify-knowledge-base.py; then
  pass 'Hermes pentesting knowledge base covers the authoritative inventory'
else
  fail 'Hermes pentesting knowledge base is incomplete or malformed'
fi

if grep -Eq '^[[:space:]]*privileged:[[:space:]]*true([[:space:]]|$)' docker-compose.yml; then
  pass 'Compose privileged mode is explicitly enabled'
else
  fail 'Compose privileged mode is not enabled'
fi

if grep -Fq '/opt/data' docker-compose.yml \
  && grep -Fq '/root' docker-compose.yml \
  && grep -Fq '/workspace' docker-compose.yml; then
  pass 'Hermes data, root home, and workspace persistence are linked in Compose'
else
  fail 'Compose persistence mounts are incomplete'
fi

public_files=(Dockerfile docker-compose.yml versions.env secrets.env.example)
while IFS= read -r -d '' file; do public_files+=("$file"); done \
  < <(find scripts config -type f -print0)
while IFS= read -r -d '' file; do public_files+=("$file"); done \
  < <(find Rules -type f -print0)
if grep -nHE \
  '^(SHODAN_API_KEY|CENSYS_API_ID|CENSYS_API_SECRET|VIRUSTOTAL_API_KEY|INTERACTSH_AUTH_TOKEN|GITHUB_TOKEN)=.+$' \
  "${public_files[@]}" >/tmp/offensive-public-secret-scan.txt; then
  cat /tmp/offensive-public-secret-scan.txt >&2
  fail 'A credential variable has a non-empty value in a public/build file'
else
  pass 'No configured credential values occur in public/build files'
fi
rm -f /tmp/offensive-public-secret-scan.txt

if docker info >/dev/null 2>&1; then
  pass 'Current user can access the Docker engine'
else
  fail 'Cannot access Docker engine; run this script through sudo'
fi

if (( FAILURES > 0 )); then
  printf 'Preflight failed: %d of %d checks failed.\n' "$FAILURES" "$CHECKS" >&2
  exit 1
fi

printf 'Preflight passed: all %d checks succeeded.\n' "$CHECKS"
