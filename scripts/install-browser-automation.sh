#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="browser"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

export BROWSER_TOOLS_DIR="${BROWSER_TOOLS_DIR:-/opt/browser-tools}"
export BROWSER_PACKAGE_DIR="${BROWSER_PACKAGE_DIR:-${BROWSER_TOOLS_DIR}/playwright}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-${BROWSER_PACKAGE_DIR}/.playwright}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.62.0}"
AGENT_BROWSER_VERSION="${AGENT_BROWSER_VERSION:-latest}"

find_chromium() {
  local playwright_chromium
  if [[ -f "$BROWSER_PACKAGE_DIR/node_modules/playwright/package.json" ]]; then
    playwright_chromium="$(
      node -e "process.stdout.write(require('${BROWSER_PACKAGE_DIR}/node_modules/playwright').chromium.executablePath())" \
        2>/dev/null || true
    )"
    if [[ -x "$playwright_chromium" ]]; then
      printf '%s\n' "$playwright_chromium"
      return 0
    fi
    return 1
  fi
  find "$PLAYWRIGHT_BROWSERS_PATH" -maxdepth 6 -type f \
    \( -name 'chrome' -o -name 'chromium' -o -name 'chrome-headless-shell' \
       -o -name 'headless_shell' -o -name 'chromium-browser' \) \
    -perm /111 -print -quit 2>/dev/null
}

find_firefox() {
  local playwright_firefox
  if [[ -f "$BROWSER_PACKAGE_DIR/node_modules/playwright/package.json" ]]; then
    playwright_firefox="$(
      node -e "process.stdout.write(require('${BROWSER_PACKAGE_DIR}/node_modules/playwright').firefox.executablePath())" \
        2>/dev/null || true
    )"
    if [[ -x "$playwright_firefox" ]]; then
      printf '%s\n' "$playwright_firefox"
      return 0
    fi
  fi
  find "$PLAYWRIGHT_BROWSERS_PATH" -maxdepth 6 -type f \
    \( -name 'firefox' -o -name 'firefox-bin' \) \
    -perm /111 -print -quit 2>/dev/null
}

install_hermes_browser_packages() {
  mkdir -p "$BROWSER_PACKAGE_DIR" "$PLAYWRIGHT_BROWSERS_PATH"
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --omit=dev --prefix "$BROWSER_PACKAGE_DIR" \
    "agent-browser@${AGENT_BROWSER_VERSION}" \
    "playwright@${PLAYWRIGHT_VERSION}"
}

install_playwright_browsers() {
  # Kali already receives Chromium, Firefox ESR, and their native runtime
  # libraries from install-system-tools.sh. Playwright's --with-deps path
  # assumes Ubuntu and can request obsolete Ubuntu package names on Kali.
  PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" \
    npm exec --prefix "$BROWSER_PACKAGE_DIR" -- \
      playwright install chromium firefox
}

verify_agent_browser() {
  local agent_browser="$1" session="image-build-$$"
  local attempt rc title output
  output="$(mktemp)"

  # agent-browser starts a client/daemon pair on the first real command. On a
  # busy BuildKit worker that cold start can exceed the old 45-second wrapper,
  # and a later unguarded `get title` timeout escaped as exit 124. Retry the
  # complete transaction, bound every daemon call, and retain useful output if
  # all attempts fail.
  for attempt in 1 2 3; do
    : > "$output"
    log "Launching agent-browser smoke test (attempt ${attempt}/3)"
    if timeout --kill-after=10 90 "$agent_browser" --session "$session" \
        open 'data:text/html,<title>AgentBrowserOK</title>' \
        >"$output" 2>&1; then
      if title="$(
        timeout --kill-after=5 30 "$agent_browser" --session "$session" \
          get title 2>>"$output"
      )" && [[ "$title" == *AgentBrowserOK* ]]; then
        timeout --kill-after=5 15 "$agent_browser" --session "$session" \
          close >/dev/null 2>&1 || true
        rm -f "$output"
        return 0
      fi
      rc=$?
      log "agent-browser title check failed on attempt ${attempt} (exit ${rc})"
    else
      rc=$?
      log "agent-browser launch failed on attempt ${attempt} (exit ${rc})"
    fi

    timeout --kill-after=5 15 "$agent_browser" --session "$session" \
      close >/dev/null 2>&1 || true
  done

  log "agent-browser could not launch and query its configured Chromium"
  tail -n 80 "$output" >&2 || true
  rm -f "$output"
  return 1
}

ensure_hermes_browser() {
  local playwright="$BROWSER_PACKAGE_DIR/node_modules/.bin/playwright"
  local agent_browser="$BROWSER_PACKAGE_DIR/node_modules/.bin/agent-browser"
  local chromium firefox installed_playwright_version

  installed_playwright_version="$(
    node -p "require('${BROWSER_PACKAGE_DIR}/node_modules/playwright/package.json').version" \
      2>/dev/null || true
  )"

  if [[ ! -x "$playwright" || ! -x "$agent_browser" \
    || "$installed_playwright_version" != "$PLAYWRIGHT_VERSION" ]]; then
    log "Installing the browser CLI bundle with Playwright ${PLAYWRIGHT_VERSION}"
    install_hermes_browser_packages
  fi

  chromium="$(find_chromium || true)"
  firefox="$(find_firefox || true)"
  if [[ ! -x "$chromium" || ! -x "$firefox" ]]; then
    log "Playwright Chromium or Firefox is missing; installing both headless browser engines"
    install_playwright_browsers
  fi
}

verify_hermes_browser() {
  local playwright="$BROWSER_PACKAGE_DIR/node_modules/.bin/playwright"
  local agent_browser="$BROWSER_PACKAGE_DIR/node_modules/.bin/agent-browser"
  local chromium firefox agent_browser_version playwright_version

  ensure_hermes_browser

  if [[ ! -x "$playwright" ]]; then
    log "Missing executable: $playwright"
    return 1
  fi
  if [[ ! -x "$agent_browser" ]]; then
    log "Missing executable: $agent_browser"
    return 1
  fi
  if [[ ! -d "$PLAYWRIGHT_BROWSERS_PATH" ]]; then
    log "Missing Playwright browser directory: $PLAYWRIGHT_BROWSERS_PATH"
    return 1
  fi

  "$playwright" --version
  if ! timeout --kill-after=5 30 "$agent_browser" --help \
      </dev/null >/dev/null; then
    log "agent-browser help command did not complete"
    return 1
  fi

  chromium="$(find_chromium)"
  if [[ ! -x "$chromium" ]]; then
    log "Could not find an executable Chromium under $PLAYWRIGHT_BROWSERS_PATH"
    return 1
  fi
  firefox="$(find_firefox)"
  if [[ ! -x "$firefox" ]]; then
    log "Could not find an executable Firefox under $PLAYWRIGHT_BROWSERS_PATH"
    return 1
  fi

  command -v chromium firefox-esr >/dev/null

  if ! timeout 30 "$chromium" --headless --no-sandbox --disable-gpu \
    --disable-dev-shm-usage --dump-dom 'data:text/html,<title>HermesBrowserOK</title>' \
    2>/dev/null | grep -q HermesBrowserOK; then
    log "Chromium smoke test failed: $chromium"
    return 1
  fi

  ln -sfn "$chromium" "$BROWSER_TOOLS_DIR/chromium"
  ln -sfn "$firefox" "$BROWSER_TOOLS_DIR/firefox"
  export AGENT_BROWSER_EXECUTABLE_PATH="$BROWSER_TOOLS_DIR/chromium"
  export AGENT_BROWSER_ARGS="${AGENT_BROWSER_ARGS:---no-sandbox,--disable-dev-shm-usage}"

  link_command "$agent_browser" agent-browser
  if ! verify_agent_browser "$agent_browser"; then
    return 1
  fi

  if ! PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" \
    timeout --kill-after=10 120 node - "$BROWSER_PACKAGE_DIR" <<'NODE'
const packageDir = process.argv[2];
const { chromium, firefox } = require(`${packageDir}/node_modules/playwright`);
(async () => {
  for (const [name, browserType] of [["chromium", chromium], ["firefox", firefox]]) {
    const options = { headless: true };
    if (name === "chromium")
      options.args = ["--no-sandbox", "--disable-dev-shm-usage"];
    const browser = await browserType.launch(options);
    const page = await browser.newPage();
    await page.setContent(`<title>${name}-headless-ok</title>`);
    if (await page.title() !== `${name}-headless-ok`)
      throw new Error(`${name} title smoke test failed`);
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
NODE
  then
    log "Playwright Chromium/Firefox smoke test timed out or failed"
    return 1
  fi

  link_command "$playwright" playwright

  agent_browser_version="$(node -p "require('${BROWSER_PACKAGE_DIR}/node_modules/agent-browser/package.json').version" 2>/dev/null || printf unknown)"
  playwright_version="$("$playwright" --version)"
  printf 'agent-browser\tnpm\tHermes\t%s\t%s\n' \
    "$agent_browser_version" "$agent_browser" >> "$RESOLVED_FILE"
  printf 'playwright\tnpm\tHermes\t%s\t%s\n' \
    "$playwright_version" "$playwright" >> "$RESOLVED_FILE"
  printf 'chromium\tplaywright\tHermes\tverified\t%s\n' \
    "$chromium" >> "$RESOLVED_FILE"
  printf 'firefox\tplaywright\tHermes\tverified\t%s\n' \
    "$firefox" >> "$RESOLVED_FILE"
  printf 'agent-browser-chromium\tconfiguration\tproject\tverified\t%s\n' \
    "$BROWSER_TOOLS_DIR/chromium" >> "$RESOLVED_FILE"
}

install_step "Hermes agent-browser, Playwright, Chromium, and Firefox" \
  "npm/playwright dual-engine smoke test" verify_hermes_browser
finish_installer
