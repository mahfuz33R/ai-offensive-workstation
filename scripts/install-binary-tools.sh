#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="binary"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

ARCH="$(detect_arch)"

github_api_get() {
  local url="$1"
  local token_file=/run/secrets/github_token
  if [[ -s "$token_file" ]]; then
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $(<"$token_file")" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$url"
  else
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$url"
  fi
}

# Override the shared anonymous resolver for this secret-mounted build step.
# The retry log contains only the function name and URL, never the token.
github_latest_asset() {
  local name="$1" repo="$2" regex="$3" destination="$4"
  local api="https://api.github.com/repos/${repo}/releases/latest" json url tag
  json="$(retry github_api_get "$api")"
  tag="$(jq -r '.tag_name' <<<"$json")"
  url="$(jq -r --arg regex "$regex" \
    '.assets[] | select(.name | test($regex; "i")) | .browser_download_url' \
    <<<"$json" | head -n1)"
  [[ -n "$url" && "$url" != null ]]
  retry curl -fsSL -o "$destination" "$url"
  printf '%s\tgithub-release\t%s\t%s\t%s\n' \
    "$name" "$url" "$tag" "$destination" >> "$RESOLVED_FILE"
}

extract_and_link() {
  local name="$1" repo="$2" regex="$3" binary_name="$4" command_name="$5"
  local work archive binary
  work="$(mktemp -d)"
  archive="$work/release"
  github_latest_asset "$name" "$repo" "$regex" "$archive"
  case "$regex" in
    *zip*) unzip -q "$archive" -d "$work/out" ;;
    *tar*|*tgz*) mkdir -p "$work/out"; tar -xf "$archive" -C "$work/out" ;;
    *gz*) mkdir -p "$work/out"; gzip -dc "$archive" > "$work/out/$binary_name" ;;
    *) mkdir -p "$work/out"; cp "$archive" "$work/out/$binary_name" ;;
  esac
  binary="$(find "$work/out" -type f -name "$binary_name" -print -quit)"
  [[ -n "$binary" ]]
  install -m 0755 "$binary" "${COMMANDS_DIR}/$command_name"
  printf '%s\tbinary\t%s\t%s\t%s\n' \
    "$name" "$repo" "$ARCH" "${COMMANDS_DIR}/$command_name" >> "$RESOLVED_FILE"
  rm -rf "$work"
}

install_findomain() {
  if [[ "$ARCH" == amd64 ]]; then
    extract_and_link findomain Findomain/Findomain 'findomain-linux(\.zip)?$' findomain findomain
  else
    extract_and_link findomain Findomain/Findomain 'findomain-linux-aarch64(\.zip)?$' findomain findomain
  fi
}

install_aquatone() {
  local regex
  [[ "$ARCH" == amd64 ]] && regex='aquatone_linux_amd64_.*\.zip$' || regex='aquatone_linux_arm64_.*\.zip$'
  extract_and_link aquatone michenriksen/aquatone "$regex" aquatone aquatone
}

install_nrich() {
  [[ "$ARCH" == amd64 ]] || { log "nrich upstream package is amd64-only"; return 1; }
  local deb=/tmp/nrich_latest_amd64.deb url=https://gitlab.com/api/v4/projects/33695681/packages/generic/nrich/latest/nrich_latest_amd64.deb
  retry curl -fsSL -o "$deb" "$url"
  dpkg -i "$deb" || { apt-get update; apt-get install -fy; }
  rm -f "$deb"
  command -v nrich >/dev/null
  printf 'nrich\tdeb\t%s\tlatest\t%s\n' "$url" "$(command -v nrich)" >> "$RESOLVED_FILE"
}

install_x8() {
  local regex
  [[ "$ARCH" == amd64 ]] && regex='x86_64-linux-x8\.gz$' || regex='aarch64-linux-x8\.gz$'
  extract_and_link x8 Sh1Yo/x8 "$regex" x8 x8
}

install_unimap() {
  local regex binary_name
  if [[ "$ARCH" == amd64 ]]; then
    regex='unimap-linux-x64\.zip$'
    binary_name=unimap-linux
  else
    regex='unimap-aarch64\.zip$'
    binary_name=unimap-aarch64
  fi
  extract_and_link unimap Edu4rdSHL/unimap "$regex" "$binary_name" unimap
}

install_xray() {
  local regex
  [[ "$ARCH" == amd64 ]] && regex='xpoc_linux_amd64$' || regex='xpoc_linux_arm64$'
  local binary=/tmp/xray-release
  github_latest_asset xray chaitin/xray "$regex" "$binary"
  install -m 0755 "$binary" "$COMMANDS_DIR/xray"
  printf 'xray\tbinary\tchaitin/xray\t%s\t%s\n' \
    "$ARCH" "$COMMANDS_DIR/xray" >> "$RESOLVED_FILE"
  rm -f "$binary"
}

install_step "Findomain" "GitHub release" install_findomain
install_step "Aquatone" "GitHub release" install_aquatone
install_step "nrich" "vendor deb" install_nrich
install_step "x8" "GitHub release" install_x8
install_step "unimap" "GitHub release" install_unimap
install_step "Xray/XPOC" "GitHub release" install_xray
finish_installer
