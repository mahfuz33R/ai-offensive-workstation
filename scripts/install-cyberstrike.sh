#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="cyberstrike"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

CYBERSTRIKE_DIR="${SECURITY_TOOLS_DIR}/cyberstrike"
CYBERSTRIKE_PACKAGE="@cyberstrike-io/cyberstrike"
CYBERSTRIKE_NODE_COMPAT_DIR="/opt/toolchains/node-cyberstrike"

install_cyberstrike_node() {
  local arch node_arch resolved archive base checksum_file temporary

  arch="$(detect_arch)"
  case "$arch" in
    amd64) node_arch=x64 ;;
    arm64) node_arch=arm64 ;;
  esac
  resolved="$(
    retry curl -fsSL https://nodejs.org/dist/index.json \
      | jq -er --arg artifact "linux-${node_arch}" '
          map(select(
            (.version | startswith("v24."))
            and (.files | index($artifact))
          ))[0].version
        '
  )"
  [[ "$resolved" =~ ^v24\.[0-9]+\.[0-9]+$ ]]
  archive="node-${resolved}-linux-${node_arch}.tar.xz"
  base="https://nodejs.org/dist/${resolved}"
  temporary="$(mktemp -d)"
  checksum_file="$temporary/SHASUMS256.txt"

  retry curl -fsSL -o "$checksum_file" "$base/SHASUMS256.txt"
  retry curl -fsSL -o "$temporary/$archive" "$base/$archive"
  (
    cd "$temporary"
    grep -E "  ${archive}$" SHASUMS256.txt | sha256sum --check -
  )

  rm -rf "$CYBERSTRIKE_NODE_COMPAT_DIR"
  install -d -m 0755 "$CYBERSTRIKE_NODE_COMPAT_DIR"
  tar -xJf "$temporary/$archive" --strip-components=1 \
    -C "$CYBERSTRIKE_NODE_COMPAT_DIR"
  rm -rf "$temporary"
}

install_cyberstrike_browser() {
  local attempt compat_node

  compat_node="${CYBERSTRIKE_NODE_COMPAT_DIR}/bin/node"
  test -x "$compat_node"

  # The Playwright CDN occasionally leaves a completed transfer waiting for
  # the connection to close under the current Node line. CyberStrike 1.x pins
  # Playwright 1.x, so provision it with the supported Node 24 LTS runtime.
  # Bound each attempt so a transient CDN connection cannot hang the complete
  # image build indefinitely.
  for attempt in 1 2 3; do
    log "Installing CyberStrike's pinned Chromium revision (attempt ${attempt}/3)"
    if PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=120000 \
      PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/browser-tools/playwright/.playwright}" \
      timeout 300 "$compat_node" \
        "$CYBERSTRIKE_DIR/node_modules/playwright/cli.js" install chromium; then
      return 0
    fi
    log "Pinned Chromium installation attempt ${attempt} did not complete"
  done

  return 1
}

install_cyberstrike() {
  local arch version_selector platform_package package_root platform_root
  local launcher native_binary worker installed_version platform_version
  local playwright_version browser_path package_integrity platform_integrity
  local build_home compat_node compat_node_version

  version_selector="${CYBERSTRIKE_VERSION:-latest}"
  arch="$(detect_arch)"
  case "$arch" in
    amd64)
      # Always use the portable baseline package. The official launcher can
      # select it on AVX2 and non-AVX2 hosts, and the resulting image remains
      # portable between Docker hosts.
      platform_package="@cyberstrike-io/cyberstrike-linux-x64-baseline"
      ;;
    arm64)
      platform_package="@cyberstrike-io/cyberstrike-linux-arm64"
      ;;
  esac

  build_home="$(mktemp -d)"
  install -d -m 0755 "$CYBERSTRIKE_DIR"

  # The official documentation recommends the npm latest tag. npm validates
  # registry integrity metadata while --ignore-scripts prevents the package
  # from writing build-time state into root's home. The wrapper below safely
  # provisions the required files in each runtime user's XDG data directory.
  HOME="$build_home" \
    XDG_DATA_HOME="$build_home/data" \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    npm install --prefix "$CYBERSTRIKE_DIR" \
      --save-exact --omit=dev --omit=optional --ignore-scripts \
      --no-audit --no-fund \
      "${CYBERSTRIKE_PACKAGE}@${version_selector}" \
      "${platform_package}@${version_selector}"

  # Keep Node latest as the workstation default while giving CyberStrike's
  # pinned Playwright release the LTS Node line it officially supports. This
  # uses Node's checksummed official archive, not an npm lifecycle installer.
  install_cyberstrike_node
  compat_node="${CYBERSTRIKE_NODE_COMPAT_DIR}/bin/node"
  test -x "$compat_node"
  compat_node_version="$("$compat_node" --version)"
  [[ "$compat_node_version" =~ ^v24\. ]]

  package_root="${CYBERSTRIKE_DIR}/node_modules/${CYBERSTRIKE_PACKAGE}"
  platform_root="${CYBERSTRIKE_DIR}/node_modules/${platform_package}"
  launcher="${CYBERSTRIKE_DIR}/node_modules/.bin/cyberstrike"
  native_binary="${platform_root}/bin/cyberstrike"
  worker="${package_root}/hackbrowser-worker.js"

  test -x "$launcher"
  test -x "$native_binary"
  test -s "$worker"
  test -f "$CYBERSTRIKE_DIR/node_modules/playwright/package.json"
  test -f "$CYBERSTRIKE_DIR/node_modules/playwright-core/package.json"

  installed_version="$(jq -r .version "$package_root/package.json")"
  platform_version="$(jq -r .version "$platform_root/package.json")"
  playwright_version="$(
    jq -r .version "$CYBERSTRIKE_DIR/node_modules/playwright/package.json"
  )"
  [[ "$installed_version" == "$platform_version" ]]
  [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]

  if [[ "$version_selector" == "latest" ]]; then
    [[ "$installed_version" == "$(
      npm view "${CYBERSTRIKE_PACKAGE}@latest" version
    )" ]]
  else
    [[ "$installed_version" == "$version_selector" ]]
  fi

  # Install the Chromium revision coupled to the Playwright dependency of the
  # resolved CyberStrike release. This remains correct when latest changes its
  # Playwright version and can coexist with agent-browser browser revisions.
  install_cyberstrike_browser
  browser_path="$(
    cd / && PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/browser-tools/playwright/.playwright}" \
      node -e "process.stdout.write(require('${CYBERSTRIKE_DIR}/node_modules/playwright').chromium.executablePath())"
  )"
  test -x "$browser_path"
  timeout 30 "$browser_path" --headless --no-sandbox --disable-gpu \
    --disable-dev-shm-usage \
    --dump-dom 'data:text/html,<title>CyberStrikeBrowserOK</title>' \
    2>/dev/null | grep -q CyberStrikeBrowserOK

  ln -sfn "$launcher" "$CYBERSTRIKE_DIR/cyberstrike"
  ln -sfn "$worker" "$CYBERSTRIKE_DIR/hackbrowser-worker.js"

  cat > "${COMMANDS_DIR}/cyberstrike" <<'WRAPPER'
#!/usr/bin/env sh
set -eu

user_home="${HOME:-}"
if [ -z "$user_home" ]; then
  user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
fi
if [ -z "$user_home" ]; then
  echo "cyberstrike: cannot determine a writable user home" >&2
  exit 1
fi

install_root=/opt/security-tools/cyberstrike
package_root="$install_root/node_modules/@cyberstrike-io/cyberstrike"
compat_node=/opt/toolchains/node-cyberstrike/bin/node
case "$(uname -m)" in
  x86_64|amd64)
    native_binary="$install_root/node_modules/@cyberstrike-io/cyberstrike-linux-x64-baseline/bin/cyberstrike"
    ;;
  aarch64|arm64)
    native_binary="$install_root/node_modules/@cyberstrike-io/cyberstrike-linux-arm64/bin/cyberstrike"
    ;;
  *)
    echo "cyberstrike: unsupported runtime architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
if [ ! -x "$native_binary" ]; then
  echo "cyberstrike: native binary is missing: $native_binary" >&2
  exit 1
fi
if [ ! -x "$compat_node" ]; then
  echo "cyberstrike: compatible Node runtime is missing: $compat_node" >&2
  exit 1
fi

if [ -n "${CYBERSTRIKE_PERSISTENT_HOME:-}" ]; then
  mkdir -p \
    "$CYBERSTRIKE_PERSISTENT_HOME/data" \
    "$CYBERSTRIKE_PERSISTENT_HOME/config" \
    "$CYBERSTRIKE_PERSISTENT_HOME/cache" \
    "$CYBERSTRIKE_PERSISTENT_HOME/state"
  export XDG_DATA_HOME="$CYBERSTRIKE_PERSISTENT_HOME/data"
  export XDG_CONFIG_HOME="$CYBERSTRIKE_PERSISTENT_HOME/config"
  export XDG_CACHE_HOME="$CYBERSTRIKE_PERSISTENT_HOME/cache"
  export XDG_STATE_HOME="$CYBERSTRIKE_PERSISTENT_HOME/state"
fi

data_root="${XDG_DATA_HOME:-${user_home}/.local/share}/cyberstrike"
mkdir -p "$data_root/bin" "$data_root/node_modules"

ln -sfn "$package_root/hackbrowser-worker.js" \
  "$data_root/bin/hackbrowser-worker.js"
for package_name in playwright playwright-core; do
  destination="$data_root/node_modules/$package_name"
  if [ -L "$destination" ] || [ ! -e "$destination" ]; then
    ln -sfn "$install_root/node_modules/$package_name" "$destination"
  fi
done

# The npm package ships built-in web and skill resources. Seed them once in
# writable user state without replacing user changes on later invocations.
for bundled_name in web skill; do
  source_path="$package_root/$bundled_name"
  destination="$data_root/$bundled_name"
  if [ -d "$source_path" ] && [ ! -e "$destination" ]; then
    cp -R "$source_path" "$destination"
  fi
done

export CYBERSTRIKE_BIN_PATH="$native_binary"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/browser-tools/playwright/.playwright}"
export CYBERSTRIKE_DISABLE_AUTOUPDATE="${CYBERSTRIKE_DISABLE_AUTOUPDATE:-1}"
export PATH="/opt/toolchains/node-cyberstrike/bin:$PATH"
exec "$compat_node" "$install_root/node_modules/.bin/cyberstrike" "$@"
WRAPPER
  chmod 0755 "${COMMANDS_DIR}/cyberstrike"

  installed_version="$(
    HOME="$build_home/home" \
    XDG_DATA_HOME="$build_home/data" \
    XDG_CONFIG_HOME="$build_home/config" \
    XDG_CACHE_HOME="$build_home/cache" \
    CYBERSTRIKE_DISABLE_MODELS_FETCH=1 \
    "${COMMANDS_DIR}/cyberstrike" --version
  )"
  [[ "$installed_version" == "$platform_version" ]]
  HOME="$build_home/home" \
    XDG_DATA_HOME="$build_home/data" \
    XDG_CONFIG_HOME="$build_home/config" \
    XDG_CACHE_HOME="$build_home/cache" \
    CYBERSTRIKE_DISABLE_MODELS_FETCH=1 \
    timeout 30 "${COMMANDS_DIR}/cyberstrike" --help </dev/null >/dev/null
  test -L "$build_home/data/cyberstrike/bin/hackbrowser-worker.js"
  test -L "$build_home/data/cyberstrike/node_modules/playwright"
  test -L "$CYBERSTRIKE_DIR/hackbrowser-worker.js"

  package_integrity="$(
    jq -r '.packages["node_modules/@cyberstrike-io/cyberstrike"].integrity' \
      "$CYBERSTRIKE_DIR/package-lock.json"
  )"
  platform_integrity="$(
    jq -r --arg path "node_modules/${platform_package}" \
      '.packages[$path].integrity' "$CYBERSTRIKE_DIR/package-lock.json"
  )"
  [[ "$package_integrity" == sha512-* ]]
  [[ "$platform_integrity" == sha512-* ]]

  printf 'cyberstrike\tnpm\t%s@%s\t%s\t%s\n' \
    "$CYBERSTRIKE_PACKAGE" "$version_selector" "$installed_version" \
    "$CYBERSTRIKE_DIR/cyberstrike" >> "$RESOLVED_FILE"
  printf 'cyberstrike-native\tnpm\t%s@%s\t%s\t%s\n' \
    "$platform_package" "$version_selector" "$platform_version" \
    "$native_binary" >> "$RESOLVED_FILE"
  printf 'cyberstrike-hackbrowser-worker\tnpm\t%s@%s\t%s\t%s\n' \
    "$CYBERSTRIKE_PACKAGE" "$version_selector" "$installed_version" \
    "$worker" >> "$RESOLVED_FILE"
  printf 'cyberstrike-playwright\tnpm\tplaywright\t%s\t%s\n' \
    "$playwright_version" \
    "$CYBERSTRIKE_DIR/node_modules/playwright" >> "$RESOLVED_FILE"
  printf 'cyberstrike-node\tnpm\tnode@24\t%s\t%s\n' \
    "$compat_node_version" "$compat_node" >> "$RESOLVED_FILE"

  rm -r -- "$build_home"
}

install_step "CyberStrike latest" \
  "official npm release with registry integrity verification" install_cyberstrike
finish_installer
