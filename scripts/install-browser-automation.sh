#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="browser"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/hermes/.playwright}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.58.2}"
AGENT_BROWSER_VERSION="${AGENT_BROWSER_VERSION:-latest}"

find_chromium() {
  local playwright_chromium
  if [[ -f /opt/hermes/node_modules/playwright/package.json ]]; then
    playwright_chromium="$(
      node -e "process.stdout.write(require('/opt/hermes/node_modules/playwright').chromium.executablePath())" \
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

install_hermes_browser_packages() {
  mkdir -p /opt/hermes "$PLAYWRIGHT_BROWSERS_PATH"
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --omit=dev --prefix /opt/hermes \
    "agent-browser@${AGENT_BROWSER_VERSION}" \
    "playwright@${PLAYWRIGHT_VERSION}"
}

install_playwright_chromium() {
  PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" \
    npm exec --prefix /opt/hermes -- playwright install --with-deps chromium
}

ensure_hermes_browser() {
  local playwright=/opt/hermes/node_modules/.bin/playwright
  local agent_browser=/opt/hermes/node_modules/.bin/agent-browser
  local chromium installed_playwright_version

  installed_playwright_version="$(
    node -p "require('/opt/hermes/node_modules/playwright/package.json').version" \
      2>/dev/null || true
  )"

  if [[ ! -x "$playwright" || ! -x "$agent_browser" \
    || "$installed_playwright_version" != "$PLAYWRIGHT_VERSION" ]]; then
    log "Installing the browser CLI bundle with Playwright ${PLAYWRIGHT_VERSION}"
    install_hermes_browser_packages
  fi

  chromium="$(find_chromium || true)"
  if [[ ! -x "$chromium" ]]; then
    log "Playwright Chromium is missing under ${PLAYWRIGHT_BROWSERS_PATH}; installing browser files"
    install_playwright_chromium
  fi
}

verify_hermes_browser() {
  local playwright=/opt/hermes/node_modules/.bin/playwright
  local agent_browser=/opt/hermes/node_modules/.bin/agent-browser
  local chromium agent_browser_version playwright_version

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
  "$agent_browser" --help </dev/null >/dev/null

  chromium="$(find_chromium)"
  if [[ ! -x "$chromium" ]]; then
    log "Could not find an executable Chromium under $PLAYWRIGHT_BROWSERS_PATH"
    return 1
  fi

  if ! timeout 30 "$chromium" --headless --no-sandbox --disable-gpu \
    --disable-dev-shm-usage --dump-dom 'data:text/html,<title>HermesBrowserOK</title>' \
    2>/dev/null | grep -q HermesBrowserOK; then
    log "Chromium smoke test failed: $chromium"
    return 1
  fi

  link_command "$agent_browser" agent-browser
  agent_browser_version="$(node -p "require('/opt/hermes/node_modules/agent-browser/package.json').version" 2>/dev/null || printf unknown)"
  playwright_version="$("$playwright" --version)"
  printf 'agent-browser\tnpm\tHermes\t%s\t%s\n' \
    "$agent_browser_version" "$agent_browser" >> "$RESOLVED_FILE"
  printf 'playwright\tnpm\tHermes\t%s\t%s\n' \
    "$playwright_version" "$playwright" >> "$RESOLVED_FILE"
  printf 'chromium\tplaywright\tHermes\tverified\t%s\n' \
    "$chromium" >> "$RESOLVED_FILE"
}

install_step "Hermes agent-browser, Playwright, and Chromium" "npm/playwright smoke test" verify_hermes_browser
finish_installer
