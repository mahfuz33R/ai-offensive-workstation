#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
LEGACY_SECRET_FILE="$PROJECT_DIR/secrets.env"
PERSISTENT_ROOT_DIR="$PROJECT_DIR/workspace/container-root"
PERSISTENT_OPT_DATA_DIR="$PROJECT_DIR/workspace/container-opt/data"
HERMES_ENV_FILE="$PERSISTENT_OPT_DATA_DIR/.env"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
API_SERVER_KEY=

if [[ "$HOST_UID" == 0 ]]; then
  HOST_UID=10000
  HOST_GID=10000
  printf 'Running as host root; using container identity 10000:10000.\n' >&2
fi

read_dotenv_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -v key="$key" '
    index($0, key "=") == 1 {
      print substr($0, length(key) + 2)
      exit
    }
  ' "$file"
}

setting() {
  local key="$1" default="$2" value
  value="$(read_dotenv_value "$ENV_FILE" "$key")"
  printf '%s\n' "${value:-$default}"
}

credential() {
  local key="$1" value
  value="$(read_dotenv_value "$ENV_FILE" "$key")"
  if [[ -z "$value" ]]; then
    value="$(read_dotenv_value "$LEGACY_SECRET_FILE" "$key")"
  fi
  if [[ -z "$value" ]]; then
    # Older Hermes installations can keep provider credentials in /opt/data.
    # Copy them into the single Compose .env without printing their values.
    value="$(read_dotenv_value "$HERMES_ENV_FILE" "$key")"
  fi
  printf '%s\n' "$value"
}

command -v openssl >/dev/null 2>&1 || {
  printf 'Required command not found: openssl\n' >&2
  exit 1
}

API_SERVER_KEY="$(credential API_SERVER_KEY)"
if [[ -z "$API_SERVER_KEY" ]]; then
  API_SERVER_KEY="$(openssl rand -hex 32)"
fi

mkdir -p \
  "$PERSISTENT_ROOT_DIR" \
  "$PERSISTENT_OPT_DATA_DIR" \
  "$PROJECT_DIR/workspace/bin" \
  "$PROJECT_DIR/workspace/scripts" \
  "$PROJECT_DIR/workspace/tools" \
  "$PROJECT_DIR/workspace/config" \
  "$PROJECT_DIR/workspace/projects" \
  "$PROJECT_DIR/workspace/targets" \
  "$PROJECT_DIR/workspace/reports" \
  "$PROJECT_DIR/workspace/downloads" \
  "$PROJECT_DIR/workspace/notes"

temporary="$(mktemp "$PROJECT_DIR/.env.tmp.XXXXXXXX")"
trap 'rm -f -- "$temporary"' EXIT
{
  printf '# Private workstation configuration. Keep mode 600; never commit.\n'
  printf 'COMPOSE_PROJECT_NAME=ai-offensive-workstation\n'
  printf 'HERMES_DATA_DIR=./workspace/container-opt/data\n'
  printf 'WORKSTATION_ROOT_DIR=./workspace/container-root\n'
  printf 'HERMES_UID=%s\n' "$HOST_UID"
  printf 'HERMES_GID=%s\n' "$HOST_GID"
  printf 'KALI_IMAGE=%s\n' "$(setting KALI_IMAGE kalilinux/kali-last-release)"
  printf 'KALI_TAG=%s\n' "$(setting KALI_TAG latest)"
  printf 'KALI_DIGEST=%s\n' "$(read_dotenv_value "$ENV_FILE" KALI_DIGEST)"
  printf 'HERMES_VERSION=%s\n' "$(setting HERMES_VERSION latest)"
  printf 'CYBERSTRIKE_VERSION=%s\n' "$(setting CYBERSTRIKE_VERSION latest)"
  printf 'NODE_VERSION=%s\n' "$(setting NODE_VERSION latest)"
  printf 'NPM_VERSION=%s\n' "$(setting NPM_VERSION latest)"
  printf 'GO_VERSION=%s\n' "$(setting GO_VERSION 1.26.5)"
  printf 'RUST_TOOLCHAIN=%s\n' "$(setting RUST_TOOLCHAIN stable)"
  printf 'PLAYWRIGHT_VERSION=%s\n' "$(setting PLAYWRIGHT_VERSION 1.62.0)"
  printf 'AGENT_BROWSER_VERSION=%s\n' "$(setting AGENT_BROWSER_VERSION latest)"
  printf 'HERMES_DASHBOARD_PORT=%s\n' "$(setting HERMES_DASHBOARD_PORT 9119)"
  printf 'API_SERVER_KEY=%s\n' "$API_SERVER_KEY"
  printf 'CYBERSTRIKE_SERVER_USERNAME=%s\n' \
    "$(setting CYBERSTRIKE_SERVER_USERNAME cyberstrike)"
  printf 'CYBERSTRIKE_SERVER_PASSWORD=%s\n' \
    "$(credential CYBERSTRIKE_SERVER_PASSWORD)"

  for key in \
    SHODAN_API_KEY CENSYS_API_ID CENSYS_API_SECRET VIRUSTOTAL_API_KEY \
    INTERACTSH_AUTH_TOKEN ANTHROPIC_API_KEY OPENAI_API_KEY \
    GOOGLE_API_KEY OPENROUTER_API_KEY GROQ_API_KEY; do
    printf '%s=%s\n' "$key" "$(credential "$key")"
  done
} > "$temporary"

chmod 0600 "$temporary"
mv -f "$temporary" "$ENV_FILE"
trap - EXIT

printf 'Saved the single private configuration file: %s\n' "$ENV_FILE"
printf 'Persistent /opt/data: %s\n' "$PERSISTENT_OPT_DATA_DIR"
printf 'Persistent /root: %s\n' "$PERSISTENT_ROOT_DIR"
printf 'UID:GID: %s:%s\n' "$HOST_UID" "$HOST_GID"
