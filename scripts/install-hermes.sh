#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="hermes"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

HERMES_REPOSITORY="${HERMES_REPOSITORY:-NousResearch/hermes-agent}"
HERMES_VERSION="${HERMES_VERSION:-latest}"
HERMES_HOME="${HERMES_HOME:-/opt/data}"

resolve_stable_ref() {
  local release_url
  if [[ "$HERMES_VERSION" != latest ]]; then
    printf '%s\n' "$HERMES_VERSION"
    return
  fi

  release_url="$(
    retry curl -fsSL -o /dev/null -w '%{url_effective}' \
      "https://github.com/${HERMES_REPOSITORY}/releases/latest"
  )"
  [[ "$release_url" == \
    "https://github.com/${HERMES_REPOSITORY}/releases/tag/"* ]]
  printf '%s\n' "${release_url##*/}"
}

install_hermes_standard() {
  local resolved_ref installer_file installer_blob_sha
  local build_home installed_ref verification_repo
  resolved_ref="$(resolve_stable_ref)"
  [[ "$resolved_ref" =~ ^[A-Za-z0-9._/-]+$ ]]

  installer_file="$(mktemp)"
  verification_repo="$(mktemp -d)"
  git -C "$verification_repo" init -q
  git -C "$verification_repo" remote add origin \
    "https://github.com/${HERMES_REPOSITORY}.git"
  retry git -C "$verification_repo" fetch --depth 1 origin \
    "refs/tags/${resolved_ref}:refs/tags/${resolved_ref}"
  installer_blob_sha="$(
    git -C "$verification_repo" rev-parse "${resolved_ref}:scripts/install.sh"
  )"
  git -C "$verification_repo" show \
    "${resolved_ref}:scripts/install.sh" > "$installer_file"
  [[ "$(git hash-object "$installer_file")" == "$installer_blob_sha" ]]
  grep -Fq 'Hermes Agent Installer' "$installer_file"
  chmod 0755 "$installer_file"

  install -d -o hermes -g hermes -m 0750 "$HERMES_HOME"
  # Let the official root installer select its FHS command layout. The image
  # exports the same code path through HERMES_INSTALL_DIR for runtime tooling,
  # but passing that variable to the installer marks the directory "explicit"
  # and incorrectly moves the command shim into /root/.local/bin.
  HERMES_HOME="$HERMES_HOME" \
    env -u HERMES_INSTALL_DIR bash "$installer_file" \
      --skip-setup \
      --skip-browser \
      --branch "$resolved_ref"

  # Hermes deliberately excludes messaging adapters from its curated `all`
  # install. This workstation runs the gateway as an immutable, unprivileged
  # container process, so Telegram's lazy installer cannot safely modify the
  # agent venv at runtime. Install the exact upstream Telegram dependency while
  # the image is built instead.
  /opt/data/bin/uv pip install \
    --python /usr/local/lib/hermes-agent/venv/bin/python \
    'python-telegram-bot[webhooks]==22.6'
  /usr/local/lib/hermes-agent/venv/bin/python - <<'PY'
import telegram

assert telegram.__version__ == "22.6", telegram.__version__
PY

  # The runtime checkout is intentionally read-only to Hermes. Build the
  # dashboard while this installation step still runs as root so `hermes
  # dashboard` never attempts npm writes during container startup.
  (
    cd /usr/local/lib/hermes-agent
    npm run build -w web
  )
  test -s /usr/local/lib/hermes-agent/hermes_cli/web_dist/index.html

  test -x /usr/local/bin/hermes
  test -d /usr/local/lib/hermes-agent
  installed_ref="$(git -C /usr/local/lib/hermes-agent rev-parse HEAD)"

  build_home="$(mktemp -d)"
  HOME="$build_home" HERMES_HOME="$build_home/.hermes" \
    timeout 60 /usr/local/bin/hermes version >/dev/null
  rm -rf "$build_home" "$installer_file" "$verification_repo"

  printf 'hermes-agent\tgit-release\thttps://github.com/%s\t%s@%s\t%s\n' \
    "$HERMES_REPOSITORY" "$resolved_ref" "$installed_ref" \
    /usr/local/lib/hermes-agent >> "$RESOLVED_FILE"
  printf 'hermes-installer\tgithub-blob\thttps://github.com/%s\t%s@%s\t%s\n' \
    "$HERMES_REPOSITORY" "$resolved_ref" "$installer_blob_sha" \
    scripts/install.sh >> "$RESOLVED_FILE"
}

install_step "Hermes Agent latest stable standard installation" \
  "official release installer using the root-mode FHS layout" \
  install_hermes_standard
finish_installer
