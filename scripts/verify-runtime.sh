#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RUNTIME_AUDIT_IMAGE:-ai-offensive-workstation:latest}"
API_PORT=8656
RECREATE=0
REUSE_ROUNDTRIP=0
AUDIT_ID="runtime-audit-$(date -u +%Y%m%dT%H%M%SZ)-$$"
ROOT_SENTINEL="$PROJECT_DIR/workspace/container-root/.${AUDIT_ID}"
DATA_SENTINEL="$PROJECT_DIR/workspace/container-opt/data/.${AUDIT_ID}"
WORKSPACE_SENTINEL="$PROJECT_DIR/workspace/.${AUDIT_ID}"
TMUX_SOCKET="audit-${AUDIT_ID}"
TEMP_DIR=
CYBERSTRIKE_SESSION_SENTINEL_ID=

usage() {
  cat <<'EOF'
Usage:
  bash scripts/verify-runtime.sh [--recreate] [--reuse-roundtrip]

--recreate
  Write temporary persistence sentinels, force-recreate the Compose services,
  verify all sentinels survived, and remove only those sentinels.

--reuse-roundtrip
  Create a real encrypted reuse bundle and restore it into an isolated
  temporary project. This requires substantial free disk space.
EOF
}

pass() {
  printf '[PASS] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  rm -f -- "$ROOT_SENTINEL" "$DATA_SENTINEL" "$WORKSPACE_SENTINEL"
  if [[ -n "${DOCKER+x}" ]]; then
    "${DOCKER[@]}" exec --user root ai-offensive-workstation \
      tmux -L "$TMUX_SOCKET" kill-server >/dev/null 2>&1 || true
    if [[ -n "$CYBERSTRIKE_SESSION_SENTINEL_ID" ]]; then
      "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
        curl -fsS -X DELETE \
        "http://127.0.0.1:4096/session/${CYBERSTRIKE_SESSION_SENTINEL_ID}?directory=%2Fworkspace" \
        >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    case "$TEMP_DIR" in
      /tmp/ai-offensive-runtime-audit.*) rm -rf -- "$TEMP_DIR" ;;
      "$PROJECT_DIR"/.runtime-audit.*) rm -rf -- "$TEMP_DIR" ;;
      *) printf '[WARN] Refusing to remove unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
    esac
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

while (($#)); do
  case "$1" in
    --recreate) RECREATE=1 ;;
    --reuse-roundtrip) REUSE_ROUNDTRIP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown argument: $1" ;;
  esac
  shift
done

cd "$PROJECT_DIR"

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi
"${DOCKER[@]}" info >/dev/null
"${DOCKER[@]}" image inspect "$IMAGE" >/dev/null

compose() {
  "${DOCKER[@]}" compose "$@"
}

create_cyberstrike_session_sentinel() {
  CYBERSTRIKE_SESSION_SENTINEL_ID="$(
    "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
      curl -fsS -X POST \
      'http://127.0.0.1:4096/session?directory=%2Fworkspace' \
      -H 'Content-Type: application/json' \
      --data "{\"title\":\"${AUDIT_ID}\"}" \
      | jq -er '.id'
  )"
  [[ "$CYBERSTRIKE_SESSION_SENTINEL_ID" == ses* ]] \
    || fail 'CyberStrike did not return a session persistence sentinel ID'
  pass 'CyberStrike session persistence sentinel was created'
}

check_and_delete_cyberstrike_session_sentinel() {
  local returned_id
  [[ -n "$CYBERSTRIKE_SESSION_SENTINEL_ID" ]] \
    || fail 'CyberStrike session persistence sentinel is missing'
  returned_id="$(
    "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
      curl -fsS \
      "http://127.0.0.1:4096/session/${CYBERSTRIKE_SESSION_SENTINEL_ID}?directory=%2Fworkspace" \
      | jq -er '.id'
  )"
  [[ "$returned_id" == "$CYBERSTRIKE_SESSION_SENTINEL_ID" ]] \
    || fail 'CyberStrike session did not survive container recreation'
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    curl -fsS -X DELETE \
    "http://127.0.0.1:4096/session/${CYBERSTRIKE_SESSION_SENTINEL_ID}?directory=%2Fworkspace" \
    >/dev/null
  CYBERSTRIKE_SESSION_SENTINEL_ID=
  pass 'CyberStrike session database survived recreation and the sentinel was removed'
}

container_id() {
  compose ps -a -q "$1"
}

wait_for_workstation() {
  local id status attempt
  id="$(container_id workstation)"
  [[ -n "$id" ]] || fail 'workstation container does not exist'
  for attempt in {1..72}; do
    status="$("${DOCKER[@]}" inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id")"
    case "$status" in
      healthy)
        pass 'workstation health check is healthy'
        return 0
        ;;
      unhealthy|exited|dead)
        compose logs --tail=160 workstation >&2 || true
        fail "workstation entered terminal state: $status"
        ;;
    esac
    sleep 5
  done
  compose logs --tail=160 workstation >&2 || true
  fail 'workstation did not become healthy within six minutes'
}

wait_for_dashboard() {
  local configured_port port attempt
  configured_port="$(sed -n 's/^HERMES_DASHBOARD_PORT=//p' "$PROJECT_DIR/.env" | tail -n1)"
  port="${HERMES_DASHBOARD_PORT:-${configured_port:-9119}}"
  for _ in {1..60}; do
    if curl -fsS --max-time 3 "http://127.0.0.1:${port}/" >/dev/null; then
      pass "dashboard responds on 127.0.0.1:${port}"
      return 0
    fi
    sleep 2
  done
  compose logs --tail=160 dashboard >&2 || true
  fail "dashboard did not respond on 127.0.0.1:${port}"
}

read_private_setting() {
  local key="$1"
  awk -v key="$key" '
    index($0, key "=") == 1 {
      print substr($0, length(key) + 2)
      exit
    }
  ' "$PROJECT_DIR/.env"
}

wait_for_gateway_api() {
  local api_key attempt
  api_key="$(read_private_setting API_SERVER_KEY)"
  (( ${#api_key} >= 8 )) \
    || fail 'API_SERVER_KEY is absent or too short in the private .env'
  for attempt in {1..72}; do
    if curl -fsS --max-time 3 \
        -H "Authorization: Bearer $api_key" \
        "http://127.0.0.1:${API_PORT}/health" \
        | jq -e '.status == "ok" or .healthy == true' >/dev/null; then
      pass "authenticated Hermes API responds on 127.0.0.1:${API_PORT}"
      return 0
    fi
    sleep 5
  done
  compose logs --tail=200 workstation >&2 || true
  fail 'Hermes API did not respond within six minutes'
}

wait_for_cyberstrike_api() {
  local id status attempt
  id="$(container_id cyberstrike-api)"
  [[ -n "$id" ]] || fail 'cyberstrike-api container does not exist'
  for attempt in {1..72}; do
    status="$("${DOCKER[@]}" inspect --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "$id")"
    case "$status" in
      healthy)
        pass 'CyberStrike API health check is healthy'
        return 0
        ;;
      unhealthy|exited|dead)
        compose logs --tail=160 cyberstrike-api >&2 || true
        fail "cyberstrike-api entered terminal state: $status"
        ;;
    esac
    sleep 5
  done
  compose logs --tail=160 cyberstrike-api >&2 || true
  fail 'cyberstrike-api did not become healthy within six minutes'
}

assert_mount() {
  local service="$1" destination="$2" expected="$3" id actual
  id="$(container_id "$service")"
  [[ -n "$id" ]] || fail "$service container does not exist"
  actual="$("${DOCKER[@]}" inspect --format \
    "{{range .Mounts}}{{if eq .Destination \"$destination\"}}{{.Source}}{{end}}{{end}}" \
    "$id")"
  [[ "$actual" == "$(realpath -m "$expected")" ]] \
    || fail "$service $destination mount is $actual, expected $(realpath -m "$expected")"
  pass "$service $destination uses the expected host bind"
}

check_sentinels_in_container() {
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/root/.${AUDIT_ID}"
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/opt/data/.${AUDIT_ID}"
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    test -f "/workspace/.${AUDIT_ID}"
  pass 'persistence sentinels are visible in /root, /opt/data, and /workspace'
}

run_core_runtime_checks() {
  local workstation_id dashboard_id cyberstrike_id network_mode
  local dashboard_network_mode cyberstrike_network_mode privileged_status
  local network_name network_driver network_internal gateway_host_ip dashboard_host_ip
  local api_key unauthenticated_status
  local -a attached_networks
  workstation_id="$(container_id workstation)"
  dashboard_id="$(container_id dashboard)"
  cyberstrike_id="$(container_id cyberstrike-api)"
  network_mode="$("${DOCKER[@]}" inspect --format \
    '{{.HostConfig.NetworkMode}}' "$workstation_id")"
  dashboard_network_mode="$("${DOCKER[@]}" inspect --format \
    '{{.HostConfig.NetworkMode}}' "$dashboard_id")"
  cyberstrike_network_mode="$("${DOCKER[@]}" inspect --format \
    '{{.HostConfig.NetworkMode}}' "$cyberstrike_id")"
  privileged_status="$("${DOCKER[@]}" inspect --format \
    '{{.HostConfig.Privileged}}' "$workstation_id")"
  [[ "$network_mode" != host && "$network_mode" != none ]] \
    || fail "workstation network mode is not bridge/NAT: $network_mode"
  [[ "$dashboard_network_mode" == "container:$workstation_id" ]] \
    || fail "dashboard does not share the workstation network namespace"
  [[ "$cyberstrike_network_mode" == "container:$workstation_id" ]] \
    || fail "cyberstrike-api does not share the workstation network namespace"
  [[ "$privileged_status" == false ]] \
    || fail 'workstation unexpectedly runs privileged'
  "${DOCKER[@]}" inspect --format '{{json .Mounts}}' "$workstation_id" \
    | grep -Fv '/var/run/docker.sock' >/dev/null
  mapfile -t attached_networks < <(
    "${DOCKER[@]}" inspect --format \
      '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{"\n"}}{{end}}' \
      "$workstation_id" | sed '/^$/d'
  )
  (( ${#attached_networks[@]} == 1 )) \
    || fail 'workstation must attach to exactly one project bridge'
  network_name="${attached_networks[0]}"
  network_driver="$("${DOCKER[@]}" network inspect --format '{{.Driver}}' "$network_name")"
  network_internal="$("${DOCKER[@]}" network inspect --format '{{.Internal}}' "$network_name")"
  [[ "$network_driver" == bridge && "$network_internal" == false ]] \
    || fail "workstation network is not an outbound bridge: $network_driver/$network_internal"
  gateway_host_ip="$("${DOCKER[@]}" inspect --format \
    "{{(index (index .HostConfig.PortBindings \"${API_PORT}/tcp\") 0).HostIp}}" \
    "$workstation_id")"
  dashboard_host_ip="$("${DOCKER[@]}" inspect --format \
    '{{(index (index .HostConfig.PortBindings "9119/tcp") 0).HostIp}}' \
    "$workstation_id")"
  [[ "$gateway_host_ip" == 127.0.0.1 && "$dashboard_host_ip" == 127.0.0.1 ]] \
    || fail "published services are not loopback-only: $gateway_host_ip/$dashboard_host_ip"
  "${DOCKER[@]}" inspect --format '{{json .HostConfig.PortBindings}}' \
    "$workstation_id" | grep -Fv '"4096/tcp"' >/dev/null \
    || fail 'CyberStrike API port 4096 is unexpectedly published'
  pass 'workstation uses outbound bridge/NAT, loopback ports, an internal CyberStrike API, no privileged mode, and no Docker socket'

  api_key="$(read_private_setting API_SERVER_KEY)"
  unauthenticated_status="$(
    curl -sS -o /dev/null -w '%{http_code}' \
      "http://127.0.0.1:${API_PORT}/v1/models"
  )"
  [[ "$unauthenticated_status" == 401 ]] \
    || fail "Hermes API accepted an unauthenticated request: HTTP $unauthenticated_status"
  curl -fsS -H "Authorization: Bearer $api_key" \
    "http://127.0.0.1:${API_PORT}/v1/models" \
    | jq -e '.data | type == "array" and length > 0' >/dev/null \
    || fail 'Hermes API did not return its authenticated model catalog'
  curl -fsS -H "Authorization: Bearer $api_key" \
    "http://127.0.0.1:${API_PORT}/v1/skills" \
    | jq -e '
        (.data | type == "array")
        and any(.data[]; .name == "offensive-workstation-pentesting")
      ' >/dev/null \
    || fail 'Hermes API did not return the offensive-workstation skill'
  pass 'Hermes API rejects unauthenticated access and serves authenticated models and skills'

  "${DOCKER[@]}" exec --user root \
    --env HOME=/root --env USER=root --env LOGNAME=root \
    ai-offensive-workstation zsh -ic '
    [[ "$ZSH" == /opt/oh-my-zsh ]]
    [[ "$SHELL" == /usr/bin/zsh ]]
    [[ -n "$PROMPT" ]]
    (( $+functions[configure_prompt] ))
    (( $+functions[toggle_prompt] ))
    (( $+functions[mkcd] ))
    (( ${plugins[(Ie)git]} ))
    alias ll >/dev/null
    command -v hermes zsh tmux go python3 node cargo nmap nuclei >/dev/null
    grep -Eq "^ID=kali$" /etc/os-release
    dpkg-query -W -f="\${Status}\n" kali-linux-headless \
      | grep -Fx "install ok installed"
  '
  pass 'Kali standard environment and root Zsh configuration load'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation zsh -ic '
    [[ "$(id -un)" == hermes ]]
    [[ "$ZSH" == /opt/oh-my-zsh ]]
    [[ "$SHELL" == /usr/bin/zsh ]]
    (( $+functions[configure_prompt] ))
    alias ll >/dev/null
    test ! -w /usr/local/lib/hermes-agent
    sudo -n test "$(sudo -n id -u)" = 0
    command -v hermes check-tools check-knowledge agent-browser cyberstrike >/dev/null
    hermes version >/dev/null
  '
  pass 'Hermes Zsh loads, image code is protected, and container-local sudo works'

  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" new-session -d -s workstation-audit
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" has-session -t workstation-audit
  "${DOCKER[@]}" exec --user root ai-offensive-workstation \
    tmux -L "$TMUX_SOCKET" kill-server
  pass 'Tmux creates, finds, and removes an isolated session'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    check-tools /opt/security-manifest/tool-inventory.tsv \
    /tmp/runtime-audit-tool-manifest.tsv
  pass 'all required tool, asset, path, and capability checks pass'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    check-knowledge --require-help
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    env COLUMNS=240 hermes skills list \
    | grep -F offensive-workstation-pentesting >/dev/null
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
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
    grep -Fq "[offensive-workstation-local-kb]" /opt/data/memories/MEMORY.md
    grep -Fq "[cyberstrike-local-kb]" /opt/data/memories/MEMORY.md
  '
  pass 'Hermes skill discovery and both persistent hybrid RAG indexes pass'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    hermes mcp list | grep -F cyberstrike >/dev/null
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    hermes mcp test cyberstrike >/dev/null
  "${DOCKER[@]}" exec -i --user hermes ai-offensive-workstation \
    /usr/local/lib/hermes-agent/venv/bin/python - <<'PY'
import asyncio
import json
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def main():
    script = (
        "/opt/data/skills/cybersecurity/offensive-workstation/"
        "scripts/cyberstrike_mcp.py"
    )
    params = StdioServerParameters(
        command="/usr/local/lib/hermes-agent/venv/bin/python",
        args=[script],
        env=dict(os.environ),
    )
    session_id = None
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as client:
            await client.initialize()
            tools = await client.list_tools()
            names = {tool.name for tool in tools.tools}
            required = {
                "cyberstrike_health",
                "cyberstrike_create_session",
                "cyberstrike_send_message",
                "cyberstrike_get_messages",
                "cyberstrike_delete_session",
            }
            assert len(names) == 9 and required <= names
            health = await client.call_tool("cyberstrike_health", {})
            assert not health.isError and '"healthy":true' in health.content[0].text.replace(" ", "")
            try:
                created = await client.call_tool(
                    "cyberstrike_create_session",
                    {"title": "Runtime MCP transport audit"},
                )
                assert not created.isError
                session_id = json.loads(created.content[0].text)["id"]
                sent = await client.call_tool(
                    "cyberstrike_send_message",
                    {
                        "session_id": session_id,
                        "message": "Runtime transport marker; no model invocation.",
                        "no_reply": True,
                    },
                )
                assert not sent.isError
                messages = await client.call_tool(
                    "cyberstrike_get_messages",
                    {"session_id": session_id},
                )
                assert not messages.isError
                assert "Runtime transport marker" in messages.content[0].text
            finally:
                if session_id:
                    deleted = await client.call_tool(
                        "cyberstrike_delete_session",
                        {"session_id": session_id, "confirm": True},
                    )
                    assert not deleted.isError


asyncio.run(main())
PY
  pass 'Hermes discovers nine CyberStrike MCP tools and the live session round-trip passes'

  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation \
    agent-browser --help >/dev/null
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
    browser_session="runtime-audit-$$"
    agent-browser --session "$browser_session" \
      open "data:text/html,<title>AgentBrowserRuntimeAuditOK</title>" >/dev/null
    agent-browser --session "$browser_session" get title \
      | grep -q AgentBrowserRuntimeAuditOK
    agent-browser --session "$browser_session" close >/dev/null
    cyberstrike_version="$(cyberstrike --version)"
    package_version="$(jq -r .version /opt/security-tools/cyberstrike/node_modules/@cyberstrike-io/cyberstrike/package.json)"
    test "$cyberstrike_version" = "$package_version"
    [[ "$cyberstrike_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
    CYBERSTRIKE_DISABLE_MODELS_FETCH=1 timeout 30 cyberstrike --help >/dev/null
    cyberstrike debug paths | grep -F "/opt/data/cyberstrike/" >/dev/null
    test -f /opt/data/cyberstrike/data/cyberstrike/cyberstrike.db
    test -L "$CYBERSTRIKE_PERSISTENT_HOME/data/cyberstrike/bin/hackbrowser-worker.js"
    test -L "$CYBERSTRIKE_PERSISTENT_HOME/data/cyberstrike/node_modules/playwright"
  '
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
    chromium="$(find /opt/browser-tools/playwright/.playwright -maxdepth 6 -type f \
      \( -name chrome -o -name chromium -o -name chrome-headless-shell \
         -o -name headless_shell -o -name chromium-browser \) \
      -perm /111 -print -quit)"
    test -x "$chromium"
    timeout 30 "$chromium" --headless --no-sandbox --disable-gpu \
      --disable-dev-shm-usage \
      --dump-dom "data:text/html,<title>RuntimeAuditOK</title>" \
      2>/dev/null | grep -q RuntimeAuditOK
  '
  "${DOCKER[@]}" exec --user hermes ai-offensive-workstation bash -euc '
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
    await page.setContent(`<title>${name}-runtime-ok</title>`);
    if (await page.title() !== `${name}-runtime-ok`)
      throw new Error(`${name} runtime smoke test failed`);
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
NODE
  '
  pass 'agent-browser, Chromium, and Firefox headless launches pass'
}

run_reuse_roundtrip() {
  local passphrase_file bundle import_dir dependency_bin dependency_log
  local protection_dir protection_log
  command -v gpg >/dev/null || fail 'gpg is required for reuse round-trip'
  command -v openssl >/dev/null || fail 'openssl is required for reuse round-trip'
  TEMP_DIR="$(mktemp -d "$PROJECT_DIR/.runtime-audit.XXXXXXXX")"
  chmod 0700 "$TEMP_DIR"
  passphrase_file="$TEMP_DIR/passphrase"
  bundle="$TEMP_DIR/workstation.tar.gpg"
  import_dir="$TEMP_DIR/import"
  openssl rand -hex 48 > "$passphrase_file"
  chmod 0600 "$passphrase_file"

  dependency_bin="$TEMP_DIR/dependency-bin"
  dependency_log="$TEMP_DIR/dependency-check.log"
  mkdir -p "$dependency_bin"
  ln -s "$(command -v dirname)" "$dependency_bin/dirname"
  if PATH="$dependency_bin" /bin/bash "$PROJECT_DIR/scripts/reuse.sh" export \
      "$TEMP_DIR/dependency-test.tar.gpg" >"$dependency_log" 2>&1; then
    fail 'reuse export accepted a host without its required Docker command'
  fi
  grep -F 'required command not found: docker' "$dependency_log" >/dev/null \
    || fail 'reuse dependency failure did not identify the missing command'
  pass 'reuse dependency checks reject a missing required command'

  protection_dir="$TEMP_DIR/mount-protection"
  protection_log="$TEMP_DIR/mount-protection.log"
  mkdir -p \
    "$protection_dir/wrong-root" \
    "$protection_dir/workspace/container-root" \
    "$protection_dir/workspace/container-opt/data"
  mkdir -p "$protection_dir/scripts"
  cp "$PROJECT_DIR/scripts/reuse.sh" "$protection_dir/scripts/reuse.sh"
  chmod 0755 "$protection_dir/scripts/reuse.sh"
  {
    printf 'services:\n'
    printf '  workstation:\n'
    printf '    image: %s\n' "$IMAGE"
    printf '    entrypoint: /bin/sleep\n'
    printf '    command: ["300"]\n'
    printf '    volumes:\n'
    printf '      - ./wrong-root:/root\n'
    printf '      - ./workspace/container-opt/data:/opt/data\n'
    printf '      - ./workspace:/workspace\n'
  } > "$protection_dir/docker-compose.yml"
  (
    cd "$protection_dir"
    "${DOCKER[@]}" compose up -d --no-build
    trap '"${DOCKER[@]}" compose down --remove-orphans >/dev/null 2>&1 || true' \
      EXIT INT TERM
    if REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
        ./scripts/reuse.sh export "$TEMP_DIR/mount-protection.tar.gpg" \
        >"$protection_log" 2>&1; then
      fail 'reuse export accepted an incorrect /root bind source'
    fi
    grep -F 'container /root is not mounted from' "$protection_log" >/dev/null \
      || fail 'reuse mount-protection failure did not identify the bad /root bind'
  )
  pass 'reuse mount protection rejects an incorrect bind source'

  REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
    "$PROJECT_DIR/scripts/reuse.sh" export "$bundle"
  REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
    "$PROJECT_DIR/scripts/reuse.sh" verify "$bundle"

  mkdir -p "$import_dir/scripts"
  cp "$PROJECT_DIR/scripts/reuse.sh" "$import_dir/scripts/reuse.sh"
  chmod 0755 "$import_dir/scripts/reuse.sh"
  (
    cd "$import_dir"
    REUSE_GPG_PASSPHRASE_FILE="$passphrase_file" \
      ./scripts/reuse.sh import "$bundle"
    "${DOCKER[@]}" compose config -q
  )

  [[ -s "$import_dir/workspace/container-opt/data/config.yaml" ]] \
    || fail 'reuse import did not restore container Hermes config.yaml'
  cmp -s \
    "$PROJECT_DIR/workspace/container-opt/data/config.yaml" \
    "$import_dir/workspace/container-opt/data/config.yaml" \
    || fail 'restored container Hermes config.yaml differs from the source'
  [[ -f "$import_dir/.env" ]] \
    || fail 'reuse import did not restore the private .env'
  [[ "$(stat -c '%a' "$import_dir/.env")" == 600 ]] \
    || fail 'restored .env does not have permissions 600'
  [[ -s "$import_dir/docker-compose.yml" ]] \
    || fail 'reuse import did not restore docker-compose.yml'
  pass 'encrypted reuse export, verify, and isolated import round-trip pass'
}

printf 'Starting the existing image without rebuilding...\n'
compose up -d --no-build
wait_for_workstation
wait_for_gateway_api
wait_for_dashboard
wait_for_cyberstrike_api

assert_mount workstation /root "$PROJECT_DIR/workspace/container-root"
assert_mount workstation /opt/data "$PROJECT_DIR/workspace/container-opt/data"
assert_mount workstation /workspace "$PROJECT_DIR/workspace"
assert_mount dashboard /root "$PROJECT_DIR/workspace/container-root"
assert_mount dashboard /opt/data "$PROJECT_DIR/workspace/container-opt/data"
assert_mount dashboard /workspace "$PROJECT_DIR/workspace"
assert_mount cyberstrike-api /root "$PROJECT_DIR/workspace/container-root"
assert_mount cyberstrike-api /opt/data "$PROJECT_DIR/workspace/container-opt/data"
assert_mount cyberstrike-api /workspace "$PROJECT_DIR/workspace"
pass 'Container Hermes uses only the project data directory, independently of host Hermes'

run_core_runtime_checks

if (( RECREATE == 1 )); then
  create_cyberstrike_session_sentinel
  printf '%s\n' "$AUDIT_ID" > "$ROOT_SENTINEL"
  printf '%s\n' "$AUDIT_ID" > "$DATA_SENTINEL"
  printf '%s\n' "$AUDIT_ID" > "$WORKSPACE_SENTINEL"
  check_sentinels_in_container
  compose up -d --no-build --force-recreate
  wait_for_workstation
  wait_for_gateway_api
  wait_for_dashboard
  wait_for_cyberstrike_api
  assert_mount workstation /root "$PROJECT_DIR/workspace/container-root"
  assert_mount workstation /opt/data "$PROJECT_DIR/workspace/container-opt/data"
  assert_mount workstation /workspace "$PROJECT_DIR/workspace"
  [[ -f "$ROOT_SENTINEL" && -f "$DATA_SENTINEL" && -f "$WORKSPACE_SENTINEL" ]] \
    || fail 'one or more host persistence sentinels disappeared after recreation'
  check_sentinels_in_container
  check_and_delete_cyberstrike_session_sentinel
  pass 'all persistent data survived forced container recreation'
  run_core_runtime_checks
fi

if (( REUSE_ROUNDTRIP == 1 )); then
  run_reuse_roundtrip
fi

printf '\nRuntime audit passed.\n'
