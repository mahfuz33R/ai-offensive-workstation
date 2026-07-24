#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_OPTIONS=(--pull --no-cache)
SKIP_BUILD=0
if [[ "${1:-}" == --verify-only ]]; then
  SKIP_BUILD=1
  shift
elif [[ "${1:-}" == --cached ]]; then
  BUILD_OPTIONS=(--pull)
  shift
fi
BUILD_OPTIONS+=("$@")

bash scripts/preflight.sh

if (( SKIP_BUILD )); then
  printf '\nUsing the existing image for post-build verification...\n'
else
  printf '\nBuilding the complete portable image...\n'
  BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}" docker compose build "${BUILD_OPTIONS[@]}"
fi

IMAGE="$(docker compose config --images | head -n1)"
[[ -n "$IMAGE" ]]
docker image inspect "$IMAGE" >/dev/null

entrypoint="$(docker image inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")"
if [[ "$entrypoint" != *'/init'* ]]; then
  printf 'Image verification failed: expected Hermes /init entrypoint, found %s\n' "$entrypoint" >&2
  exit 1
fi
printf '[PASS] Hermes /init remains the image entrypoint.\n'

temporary_workspace="$(mktemp -d)"
trap 'rm -rf "$temporary_workspace"' EXIT
chmod 0755 "$temporary_workspace"

printf '\nChecking the image as the non-root Hermes user with an empty /workspace mount...\n'
docker run --rm --privileged \
  --user hermes \
  --volume "$temporary_workspace:/workspace" \
  --entrypoint /usr/local/bin/check-tools \
  "$IMAGE" \
  /opt/security-manifest/tool-inventory.tsv \
  /tmp/hermes-user-tool-manifest.tsv

printf '\nChecking the Hermes pentesting knowledge base as the non-root user...\n'
docker run --rm \
  --user hermes \
  --entrypoint /usr/local/bin/check-knowledge \
  "$IMAGE" --require-help

printf '\nChecking the final shared Python environment...\n'
docker run --rm \
  --entrypoint /opt/toolchains/python/bin/pip \
  "$IMAGE" check

printf '\nChecking the isolated SploitScan Python environment...\n'
docker run --rm \
  --entrypoint /opt/toolchains/python-apps/sploitscan/bin/pip \
  "$IMAGE" check

printf '\nChecking representative immutable paths and runtime identity...\n'
docker run --rm --privileged \
  --user hermes \
  --entrypoint /bin/bash \
  "$IMAGE" -euc '
    test "$(id -un)" = hermes
    command -v hermes >/dev/null
    command -v zsh >/dev/null
    command -v tmux >/dev/null
    tmux -V | grep -q "^tmux "
    test "$SHELL" = /usr/bin/zsh
    test "$(getent passwd root | cut -d: -f7)" = /usr/bin/zsh
    test "$(getent passwd hermes | cut -d: -f7)" = /usr/bin/zsh
    test -s /opt/oh-my-zsh/oh-my-zsh.sh
    test -s /etc/zsh/portable.zshrc
    test -d /opt/security-tools
    test -d /opt/security-assets
    test -s /opt/hermes/skills/cybersecurity/offensive-workstation/SKILL.md
    test -s /opt/security-manifest/tool-manifest.tsv
    test "$(readlink -f "$(command -v naabu)")" = /opt/toolchains/go/bin/naabu
    getcap "$(readlink -f "$(command -v nmap)")" | grep -q cap_net_raw
    getcap "$(readlink -f "$(command -v naabu)")" | grep -q cap_net_raw
  '

printf '\nChecking the default interactive Zsh environment...\n'
docker run --rm \
  --user root \
  --env HOME=/tmp/root-zsh-home \
  --entrypoint /usr/bin/zsh \
  "$IMAGE" -ic '
    test "$ZSH" = /opt/oh-my-zsh
    (( $+functions[configure_prompt] ))
    (( $+functions[mkcd] ))
    alias ll >/dev/null
  '

printf '\nChecking Hermes bundled-skill synchronization with empty data...\n'
docker run --rm \
  --user hermes \
  --env HOME=/tmp/hermes-data \
  --env HERMES_HOME=/tmp/hermes-data \
  --entrypoint /bin/bash \
  "$IMAGE" -euc '
    mkdir -p "$HERMES_HOME"
    /opt/hermes/.venv/bin/python /opt/hermes/tools/skills_sync.py
    test -s "$HERMES_HOME/skills/cybersecurity/offensive-workstation/SKILL.md"
    /usr/local/bin/check-knowledge \
      --inventory /opt/security-manifest/tool-inventory.tsv \
      --skill-dir "$HERMES_HOME/skills/cybersecurity/offensive-workstation" \
      --require-help
    COLUMNS=240 hermes skills list | grep -F offensive-workstation-pentesting >/dev/null
  '

printf '\nImage build and verification passed.\n'
printf 'Verified image: %s\n' "$IMAGE"
printf 'Required inventory checks: %s\n' \
  "$(awk -F '\t' '!/^#/ && NF == 3 { count++ } END { print count+0 }' scripts/tool-inventory.tsv)"
printf 'Next command: sudo docker compose up -d --no-build\n'
printf 'Runtime audit: bash scripts/verify-runtime.sh --recreate\n'
