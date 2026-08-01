#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_OPTIONS=(--pull --no-cache)
SKIP_BUILD=0
USE_CACHE=0
temporary_root=

cleanup() {
  if [[ -n "$temporary_root" && -d "$temporary_root" ]]; then
    # The entrypoint deliberately maps these bind mounts to the container's
    # Hermes UID, which may not match the host caller. Empty their contents as
    # container root before removing the caller-owned mktemp directory.
    if [[ -n "${IMAGE:-}" ]] \
      && docker image inspect "$IMAGE" >/dev/null 2>&1; then
      docker run --rm --entrypoint /bin/sh \
        --volume "$temporary_root:/cleanup" "$IMAGE" \
        -c 'find /cleanup -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +' \
        >/dev/null 2>&1 || true
    fi
    rm -rf -- "$temporary_root"
  fi
}
trap cleanup EXIT

if [[ "${1:-}" == --verify-only ]]; then
  SKIP_BUILD=1
  shift
elif [[ "${1:-}" == --cached ]]; then
  BUILD_OPTIONS=(--pull)
  USE_CACHE=1
  shift
fi
BUILD_OPTIONS+=("$@")

bash scripts/preflight.sh --require-docker

if (( SKIP_BUILD )); then
  printf '\nUsing the existing image for post-build verification...\n'
else
  printf '\nBuilding the complete Kali workstation image...\n'
  build_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  if (( USE_CACHE )); then
    cache_bust_default=managed-cache
  else
    cache_bust_default="$build_stamp"
  fi
  export NODE_CACHE_BUST="${NODE_CACHE_BUST:-$cache_bust_default}"
  export HERMES_CACHE_BUST="${HERMES_CACHE_BUST:-$cache_bust_default}"
  export CYBERSTRIKE_CACHE_BUST="${CYBERSTRIKE_CACHE_BUST:-$cache_bust_default}"
  BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}" \
    docker compose build "${BUILD_OPTIONS[@]}"
fi

IMAGE="$(docker compose config --images | head -n1)"
[[ -n "$IMAGE" ]]
docker image inspect "$IMAGE" >/dev/null

entrypoint="$(docker image inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")"
if [[ "$entrypoint" != *'/usr/local/sbin/workstation-entrypoint'* ]]; then
  printf 'Image verification failed: unexpected entrypoint: %s\n' \
    "$entrypoint" >&2
  exit 1
fi
printf '[PASS] Kali workstation entrypoint is installed.\n'

temporary_root="$(mktemp -d)"
chmod 0755 "$temporary_root"
mkdir -p "$temporary_root"/{data,root,workspace}
chmod 0777 "$temporary_root"/{data,root,workspace}

runtime_options=(
  --rm
  --cap-add NET_ADMIN
  --cap-add NET_RAW
  --cap-add NET_BIND_SERVICE
  --env HERMES_UID=10000
  --env HERMES_GID=10000
  --volume "$temporary_root/data:/opt/data"
  --volume "$temporary_root/root:/root"
  --volume "$temporary_root/workspace:/workspace"
)

printf '\nChecking the complete inventory through the normal Hermes identity...\n'
docker run "${runtime_options[@]}" "$IMAGE" \
  check-tools /opt/security-manifest/tool-inventory.tsv \
  /tmp/hermes-user-tool-manifest.tsv

printf '\nChecking the bundled and runtime Hermes knowledge bases...\n'
docker run "${runtime_options[@]}" "$IMAGE" \
  check-knowledge --require-help
docker run "${runtime_options[@]}" "$IMAGE" bash -euc '
  test -s \
    /opt/data/skills/cybersecurity/offensive-workstation/SKILL.md
  workstation-kb verify >/dev/null
  cyberstrike-kb verify >/dev/null
  workstation-kb search \
    "authorized API access-control testing workflow" --limit 4 --json \
    | jq -e "length == 4 and all(.[]; .source and .authority and .content)" \
      >/dev/null
  cyberstrike-kb search \
    "CyberStrike session export and local API" --limit 4 --json \
    | jq -e "length == 4 and all(.[]; .source and .authority and .content)" \
      >/dev/null
  test -s /opt/data/knowledge/offensive-workstation/workstation-kb.sqlite3
  test -s /opt/data/knowledge/cyberstrike/cyberstrike-kb.sqlite3
  grep -Fq "[offensive-workstation-local-kb]" /opt/data/memories/MEMORY.md
  grep -Fq "[cyberstrike-local-kb]" /opt/data/memories/MEMORY.md
'
printf '[PASS] Full-workstation and CyberStrike hybrid retrieval pass.\\n'

printf '\nChecking the final shared Python environments...\n'
docker run --rm --entrypoint /opt/toolchains/python/bin/pip "$IMAGE" check
docker run --rm \
  --entrypoint /opt/toolchains/python-apps/sploitscan/bin/pip "$IMAGE" check
docker run --rm \
  --entrypoint /opt/toolchains/python-apps/cyberstrike-kb/bin/pip "$IMAGE" check
docker run --rm --entrypoint /usr/local/lib/hermes-agent/venv/bin/python \
  "$IMAGE" -c \
  'import telegram; assert telegram.__version__ == "22.6", telegram.__version__'
printf '[PASS] Hermes Telegram adapter dependency is image-baked.\n'

printf '\nChecking Kali, Hermes administration, CyberStrike, and global paths...\n'
docker run "${runtime_options[@]}" "$IMAGE" bash -euc '
  test "$(id -un)" = hermes
  test "$HOME" = /home/hermes
  test "$HERMES_HOME" = /opt/data
  test "$SHELL" = /usr/bin/zsh
  sudo -n test "$(sudo -n id -u)" = 0
  grep -Eq "^ID=kali$" /etc/os-release
  dpkg-query -W -f="\${Status}\n" kali-linux-headless \
    | grep -Fx "install ok installed"
  command -v hermes zsh tmux cyberstrike agent-browser >/dev/null
  hermes version >/dev/null
  hermes_browser="$(cd /usr/local/lib/hermes-agent && \
    venv/bin/python -c "from tools.browser_tool import _find_agent_browser; print(_find_agent_browser())")"
  test "$(readlink -f "$hermes_browser")" \
    = "$(readlink -f "$(command -v agent-browser)")"
  cyberstrike_version="$(cyberstrike --version)"
  package_version="$(jq -r .version /opt/security-tools/cyberstrike/node_modules/@cyberstrike-io/cyberstrike/package.json)"
  test "$cyberstrike_version" = "$package_version"
  [[ "$cyberstrike_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
  CYBERSTRIKE_DISABLE_MODELS_FETCH=1 timeout 30 cyberstrike --help >/dev/null
  test -d /usr/local/lib/hermes-agent
  test -s /usr/local/share/hermes/skills/cybersecurity/offensive-workstation/SKILL.md
  test -s /opt/security-manifest/tool-manifest.tsv
  test "$(readlink -f "$(command -v naabu)")" = /opt/toolchains/go/bin/naabu
  getcap "$(readlink -f "$(command -v nmap)")" | grep -q cap_net_raw
  getcap "$(readlink -f "$(command -v naabu)")" | grep -q cap_net_raw
'

printf '\nChecking standard Zsh locations for root and Hermes...\n'
docker run "${runtime_options[@]}" "$IMAGE" root zsh -ic '
  test "$ZSH" = /opt/oh-my-zsh
  (( $+functions[configure_prompt] ))
  (( $+functions[mkcd] ))
  alias ll >/dev/null
  cmp -s /etc/zsh/portable.zshrc /root/.zshrc
  cmp -s /etc/zsh/portable.zshrc /home/hermes/.zshrc
  test "$(getent passwd root | cut -d: -f7)" = /usr/bin/zsh
  test "$(getent passwd hermes | cut -d: -f7)" = /usr/bin/zsh
'

printf '\nChecking browser automation with Chromium and Firefox...\n'
docker run "${runtime_options[@]}" "$IMAGE" bash -euc '
  agent-browser --help >/dev/null
  test -x /opt/browser-tools/chromium
  test -x /opt/browser-tools/firefox
  command -v chromium firefox-esr playwright >/dev/null
  browser_session="runtime-build-$$"
  agent-browser --session "$browser_session" \
    open "data:text/html,<title>AgentBrowserRuntimeOK</title>" >/dev/null
  agent-browser --session "$browser_session" get title \
    | grep -q AgentBrowserRuntimeOK
  agent-browser --session "$browser_session" close >/dev/null
  chromium="$(find /opt/browser-tools/playwright/.playwright -maxdepth 6 \
    -type f \( -name chrome -o -name chromium \
    -o -name chrome-headless-shell -o -name headless_shell \
    -o -name chromium-browser \) -perm /111 -print -quit)"
  test -x "$chromium"
  timeout 30 "$chromium" --headless --no-sandbox --disable-gpu \
    --disable-dev-shm-usage \
    --dump-dom "data:text/html,<title>KaliWorkstationOK</title>" \
    2>/dev/null | grep -q KaliWorkstationOK
  export PLAYWRIGHT_BROWSERS_PATH=/opt/browser-tools/playwright/.playwright
  node - <<'"'"'NODE'"'"'
const { chromium, firefox } = require("/opt/browser-tools/playwright/node_modules/playwright");
(async () => {
  for (const [name, browserType] of [["chromium", chromium], ["firefox", firefox]]) {
    const options = { headless: true };
    if (name === "chromium")
      options.args = ["--no-sandbox", "--disable-dev-shm-usage"];
    const browser = await browserType.launch(options);
    const page = await browser.newPage();
    await page.setContent(`<title>${name}-build-ok</title>`);
    if (await page.title() !== `${name}-build-ok`)
      throw new Error(`${name} build smoke test failed`);
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
NODE
'

printf '\nImage build and verification passed.\n'
printf 'Verified image: %s\n' "$IMAGE"
printf 'Required inventory checks: %s\n' \
  "$(awk -F '\t' '!/^#/ && NF == 3 { count++ } END { print count+0 }' scripts/manifests/tool-inventory.tsv)"
printf 'Next command: sudo docker compose up -d --no-build\n'
printf 'Runtime audit: bash scripts/verify-runtime.sh --recreate\n'
