#!/usr/bin/env bash
set -euo pipefail

HERMES_USER="${HERMES_USER:-hermes}"
HERMES_HOME="${HERMES_HOME:-/opt/data}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
HERMES_BUNDLED_SKILL_DIR="${HERMES_BUNDLED_SKILL_DIR:-/usr/local/share/hermes/skills/cybersecurity/offensive-workstation}"
HERMES_BUNDLED_CYBERSTRIKE_KB="${HERMES_BUNDLED_CYBERSTRIKE_KB:-/usr/local/share/hermes/knowledge/cyberstrike/cyberstrike-kb.sqlite3}"
HERMES_BUNDLED_WORKSTATION_KB="${HERMES_BUNDLED_WORKSTATION_KB:-/usr/local/share/hermes/knowledge/offensive-workstation/workstation-kb.sqlite3}"
CYBERSTRIKE_MEMORY_MARKER="[cyberstrike-local-kb]"
WORKSTATION_MEMORY_MARKER="[offensive-workstation-local-kb]"
HERMES_MEMORY_LIMIT=2200
HERMES_CYBERSTRIKE_MCP_SCRIPT="$HERMES_HOME/skills/cybersecurity/offensive-workstation/scripts/cyberstrike_mcp.py"

validate_id() {
  local label="$1" value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 2147483647 )); then
    printf 'workstation-entrypoint: invalid %s: %s\n' "$label" "$value" >&2
    exit 64
  fi
}

configure_runtime_identity() {
  local existing_user existing_group primary_group
  validate_id HERMES_UID "$HERMES_UID"
  validate_id HERMES_GID "$HERMES_GID"

  existing_user="$(getent passwd "$HERMES_UID" | cut -d: -f1 || true)"
  if [[ -n "$existing_user" && "$existing_user" != "$HERMES_USER" ]]; then
    printf 'workstation-entrypoint: UID %s belongs to %s\n' \
      "$HERMES_UID" "$existing_user" >&2
    exit 65
  fi

  existing_group="$(getent group "$HERMES_GID" | cut -d: -f1 || true)"
  if [[ -n "$existing_group" && "$existing_group" != "$HERMES_USER" ]]; then
    primary_group="$existing_group"
  else
    groupmod --non-unique --gid "$HERMES_GID" "$HERMES_USER"
    primary_group="$HERMES_USER"
  fi

  usermod --non-unique --uid "$HERMES_UID" \
    --gid "$primary_group" --shell /usr/bin/zsh "$HERMES_USER"
}

install_user_zshrc() {
  local destination="$1"
  if [[ ! -s "$destination" ]]; then
    install -m 0644 /etc/zsh/portable.zshrc "$destination"
  elif ! grep -Fq '/etc/zsh/portable.zshrc' "$destination"; then
    printf '\n# Kali AI Offensive Workstation managed shell settings\n' \
      >> "$destination"
    printf '[[ -r /etc/zsh/portable.zshrc ]] && source /etc/zsh/portable.zshrc\n' \
      >> "$destination"
  fi
}

prepare_writable_state() {
  install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 \
    "$HERMES_HOME" /home/hermes \
    "$HERMES_HOME/cyberstrike" \
    "$HERMES_HOME/cyberstrike/data" \
    "$HERMES_HOME/cyberstrike/config" \
    "$HERMES_HOME/cyberstrike/cache" \
    "$HERMES_HOME/cyberstrike/state"
  install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0755 \
    /workspace /workspace/bin /workspace/scripts /workspace/reports
  install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 \
    "$HERMES_HOME/skills/cybersecurity"

  install_user_zshrc /root/.zshrc
  install_user_zshrc /home/hermes/.zshrc
  chown "$HERMES_UID:$HERMES_GID" /home/hermes/.zshrc

  if [[ ! -e /home/hermes/.hermes ]]; then
    ln -s "$HERMES_HOME" /home/hermes/.hermes
    chown -h "$HERMES_UID:$HERMES_GID" /home/hermes/.hermes
  fi
}

sync_bundled_skill() {
  local destination="$HERMES_HOME/skills/cybersecurity/offensive-workstation"
  local kb_destination="$HERMES_HOME/knowledge/cyberstrike/cyberstrike-kb.sqlite3"
  local kb_temporary="${kb_destination}.tmp.$$"
  local workstation_kb_destination="$HERMES_HOME/knowledge/offensive-workstation/workstation-kb.sqlite3"
  local workstation_kb_temporary="${workstation_kb_destination}.tmp.$$"
  local memory_dir="$HERMES_HOME/memories"
  local memory_file="$memory_dir/MEMORY.md"
  local memory_seed="$HERMES_BUNDLED_SKILL_DIR/references/cyberstrike/MEMORY-SEED.md"
  local workstation_memory_seed="$HERMES_BUNDLED_SKILL_DIR/references/WORKSTATION-MEMORY-SEED.md"
  local current_size seed_size separator_size
  [[ -s "$HERMES_BUNDLED_SKILL_DIR/SKILL.md" ]] || return 0

  # Gateway, dashboard, and setup can start together. Serialize the managed
  # skill refresh so the complete RAG corpus and AGENTS instructions always
  # land in the standard Hermes data tree without racing.
  exec 9>"$HERMES_HOME/.offensive-workstation-skill-sync.lock"
  flock 9
  install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 "$destination"
  cp -a "$HERMES_BUNDLED_SKILL_DIR/." "$destination/"
  chown -R "$HERMES_UID:$HERMES_GID" "$destination"

  if [[ -s "$HERMES_BUNDLED_CYBERSTRIKE_KB" ]]; then
    install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 \
      "$(dirname "$kb_destination")"
    install -o "$HERMES_UID" -g "$HERMES_GID" -m 0640 \
      "$HERMES_BUNDLED_CYBERSTRIKE_KB" "$kb_temporary"
    mv -f -- "$kb_temporary" "$kb_destination"
  fi
  if [[ -s "$HERMES_BUNDLED_WORKSTATION_KB" ]]; then
    install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 \
      "$(dirname "$workstation_kb_destination")"
    install -o "$HERMES_UID" -g "$HERMES_GID" -m 0640 \
      "$HERMES_BUNDLED_WORKSTATION_KB" "$workstation_kb_temporary"
    mv -f -- "$workstation_kb_temporary" "$workstation_kb_destination"
  fi

  install -d -o "$HERMES_UID" -g "$HERMES_GID" -m 0750 "$memory_dir"
  if [[ ! -e "$memory_file" ]]; then
    install -o "$HERMES_UID" -g "$HERMES_GID" -m 0640 \
      /dev/null "$memory_file"
  fi
  if [[ -s "$memory_seed" ]] \
    && ! grep -Fq "$CYBERSTRIKE_MEMORY_MARKER" "$memory_file"; then
    current_size="$(wc -c < "$memory_file")"
    seed_size="$(wc -c < "$memory_seed")"
    separator_size=0
    if (( current_size > 0 )); then
      separator_size=5
    fi
    if (( current_size + separator_size + seed_size <= HERMES_MEMORY_LIMIT )); then
      if (( current_size > 0 )); then
        printf '\n§\n\n' >> "$memory_file"
      fi
      cat "$memory_seed" >> "$memory_file"
    else
      printf 'workstation-entrypoint: MEMORY.md is too full to add the CyberStrike pointer\n' >&2
    fi
  fi
  if [[ -s "$workstation_memory_seed" ]] \
    && ! grep -Fq "$WORKSTATION_MEMORY_MARKER" "$memory_file"; then
    current_size="$(wc -c < "$memory_file")"
    seed_size="$(wc -c < "$workstation_memory_seed")"
    separator_size=0
    if (( current_size > 0 )); then
      separator_size=5
    fi
    if (( current_size + separator_size + seed_size <= HERMES_MEMORY_LIMIT )); then
      if (( current_size > 0 )); then
        printf '\n§\n\n' >> "$memory_file"
      fi
      cat "$workstation_memory_seed" >> "$memory_file"
    else
      printf 'workstation-entrypoint: MEMORY.md is too full to add the workstation RAG pointer\n' >&2
    fi
  fi
  chmod 0640 "$memory_file"
  chown "$HERMES_UID:$HERMES_GID" "$memory_file"
  flock -u 9
}

configure_cyberstrike_mcp() {
  local config_file="$HERMES_HOME/config.yaml"
  [[ -s "$HERMES_CYBERSTRIKE_MCP_SCRIPT" ]] || return 0

  # Every normal Compose service shares /opt/data and may start concurrently.
  # Serialize this one-time config addition and preserve a user's existing
  # server named "cyberstrike" if they intentionally customized it.
  exec 8>"$HERMES_HOME/.cyberstrike-mcp-config.lock"
  flock 8
  if /usr/local/lib/hermes-agent/venv/bin/python - "$config_file" <<'PY'
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
try:
    config = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
except FileNotFoundError:
    config = {}
servers = config.get("mcp_servers")
raise SystemExit(0 if isinstance(servers, dict) and "cyberstrike" in servers else 1)
PY
  then
    flock -u 8
    return 0
  fi

  printf 'y\n' | gosu "$HERMES_UID:$HERMES_GID" env \
    HOME=/home/hermes USER="$HERMES_USER" LOGNAME="$HERMES_USER" \
    HERMES_HOME="$HERMES_HOME" \
    hermes mcp add cyberstrike \
      --command /usr/local/lib/hermes-agent/venv/bin/python \
      --args "$HERMES_CYBERSTRIKE_MCP_SCRIPT"
  flock -u 8
}

configure_runtime_identity
prepare_writable_state
sync_bundled_skill
configure_cyberstrike_mcp

if [[ "${1:-}" == root ]]; then
  shift
  if (( $# == 0 )); then
    set -- zsh
  fi
  export HOME=/root
  export USER=root
  export LOGNAME=root
  export SHELL=/usr/bin/zsh
  exec "$@"
fi

if (( $# == 0 )); then
  set -- zsh
fi

export HOME=/home/hermes
export USER="$HERMES_USER"
export LOGNAME="$HERMES_USER"
export SHELL=/usr/bin/zsh
export HERMES_HOME
exec gosu "$HERMES_UID:$HERMES_GID" "$@"
