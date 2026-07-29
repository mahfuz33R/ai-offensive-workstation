#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="assets"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

WORDLISTS="$SECURITY_ASSETS_DIR/wordlists"
TEMPLATES="$SECURITY_ASSETS_DIR/templates"
PATTERNS="$SECURITY_ASSETS_DIR/patterns"
PAYLOADS="$SECURITY_ASSETS_DIR/payloads"

install_gf_patterns() {
  local destination="$PATTERNS/gf"
  mkdir -p "$destination"
  clone_asset_repo gf https://github.com/tomnomnom/gf.git /tmp/gf-source
  cp /tmp/gf-source/examples/*.json "$destination/"
  clone_asset_repo Gf-Patterns https://github.com/1ndianl33t/Gf-Patterns.git /tmp/gf-patterns
  cp /tmp/gf-patterns/*.json "$destination/"
  retry curl -fsSL -o "$destination/my-lfi.json" https://raw.githubusercontent.com/mrco24/Patterns/main/my-lfi.json
  rm -rf /tmp/gf-source /tmp/gf-patterns
}

install_lfi_payloads() {
  clone_asset_repo mrco24-lfi https://github.com/mrco24/mrco24-lfi.git /tmp/mrco24-lfi
  cp /tmp/mrco24-lfi/lfi_payloads.txt "$PAYLOADS/lfi_payloads.txt"
  rm -rf /tmp/mrco24-lfi
}

install_payload_repositories() {
  local source_root=/tmp/install/payload-sources
  local pat_source="$source_root/PayloadsAllTheThings"
  local box_source="$source_root/payload-box"
  local pat_destination="$PAYLOADS/PayloadsAllTheThings"
  local box_destination="$PAYLOADS/payload-box"

  test -s "$pat_source/README.md"
  test -d "$box_source"
  find "$box_source" -mindepth 2 -maxdepth 2 -name README.md -print -quit | grep -q .

  rm -rf "$pat_destination" "$box_destination"
  mkdir -p "$PAYLOADS"
  cp -a "$pat_source" "$pat_destination"
  cp -a "$box_source" "$box_destination"

  find "$pat_destination" "$box_destination" \
    -type d \( -name .git -o -name .github -o -name .vscode \) \
    -prune -exec rm -rf {} +

  {
    printf 'name\tpath\tsource\n'
    printf 'PayloadsAllTheThings\t%s\thttps://github.com/swisskyrepo/PayloadsAllTheThings\n' "$pat_destination"
    printf 'payload-box\t%s\thttps://github.com/payload-box\n' "$box_destination"
  } > "$PAYLOADS/payload-sources.tsv"

  find "$pat_destination" "$box_destination" -type f \
    | sed "s#^$PAYLOADS/##" \
    | sort > "$PAYLOADS/payload-repository-files.txt"
  test -s "$PAYLOADS/payload-repository-files.txt"
}

install_kiterunner_wordlists() {
  local destination="$WORDLISTS/kiterunner"
  mkdir -p "$destination"
  local file
  for file in routes-large.json.tar.gz routes-small.json.tar.gz; do
    retry curl -fsSL -o "$destination/$file" "https://wordlists-cdn.assetnote.io/rawdata/kiterunner/$file"
    tar -xf "$destination/$file" -C "$destination"
    rm -f "$destination/$file"
  done
}

install_amass_config() {
  mkdir -p "$TEMPLATES/amass"
  retry curl -fsSL -o "$TEMPLATES/amass/config.yaml" https://raw.githubusercontent.com/owasp-amass/amass/master/examples/config.yaml
  retry curl -fsSL -o "$TEMPLATES/amass/datasources.yaml" https://raw.githubusercontent.com/owasp-amass/amass/master/examples/datasources.yaml
}

install_xray_config() {
  local source=/tmp/xray-config destination="$TEMPLATES/xray"
  clone_asset_repo xray-config https://github.com/mrco24/xray-config.git "$source"
  mkdir -p "$destination" "$source/unpacked"
  unzip -q "$source/n.zip" -d "$source/unpacked"
  find "$source/unpacked" -type f \( -name '*.yaml' -o -name '*.yml' \) \
    -exec cp -f {} "$destination/" \;
  find "$destination" -type f -print -quit | grep -q .
  rm -rf "$source"
}

install_gau_config() {
  local destination="$TEMPLATES/gau"
  clone_asset_repo gau https://github.com/lc/gau.git /tmp/gau-source
  mkdir -p "$destination"
  cp /tmp/gau-source/.gau.toml "$destination/.gau.toml"
  rm -rf /tmp/gau-source
  rm -f "$COMMANDS_DIR/gau"
  cat > "$COMMANDS_DIR/gau" <<'WRAPPER'
#!/bin/sh
set -eu
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
if [ ! -f "${user_home}/.gau.toml" ]; then
  cp /opt/security-assets/templates/gau/.gau.toml "${user_home}/.gau.toml"
fi
exec /opt/toolchains/go/bin/gau "$@"
WRAPPER
  chmod 0755 "$COMMANDS_DIR/gau"
}

install_cent_templates() {
  local temporary_home=/tmp/cent-home
  mkdir -p "$temporary_home" "$TEMPLATES/cent-nuclei-templates"
  HOME="$temporary_home" /opt/toolchains/go/bin/cent init
  (cd "$TEMPLATES" && HOME="$temporary_home" /opt/toolchains/go/bin/cent -p cent-nuclei-templates)
  find "$TEMPLATES/cent-nuclei-templates" -type f -print -quit | grep -q .
  rm -rf "$temporary_home"
}

install_gf_runtime_wrapper() {
  local wrapper="$COMMANDS_DIR/gf"
  rm -f "$wrapper"
  cat > "$wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
pattern_dir="${user_home}/.gf"
mkdir -p "$pattern_dir"
cp -n /opt/security-assets/patterns/gf/*.json "$pattern_dir/" 2>/dev/null || true
exec /opt/toolchains/go/bin/gf "$@"
WRAPPER
  chmod 0755 "$wrapper"
}

install_webanalyze_data() {
  local destination="$TEMPLATES/webanalyze"
  mkdir -p "$destination"
  (cd "$destination" && /opt/toolchains/go/bin/webanalyze -update)
  test -s "$destination/technologies.json"
  rm -f "$COMMANDS_DIR/webanalyze"
  cat > "$COMMANDS_DIR/webanalyze" <<'WRAPPER'
#!/bin/sh
exec /opt/toolchains/go/bin/webanalyze -apps /opt/security-assets/templates/webanalyze/technologies.json "$@"
WRAPPER
  chmod 0755 "$COMMANDS_DIR/webanalyze"
}

verify_asset_collections() {
  local seclists_count nuclei_count gf_count payload_count

  test -s "$WORDLISTS/SecLists/README.md"
  test -d "$WORDLISTS/SecLists/Discovery/Web-Content"
  test -s "$TEMPLATES/nuclei-templates/README.md"
  test -d "$TEMPLATES/nuclei-templates/http"
  test -s "$PAYLOADS/payload-sources.tsv"
  test -s "$PAYLOADS/payload-repository-files.txt"

  git -C "$WORDLISTS/SecLists" rev-parse --verify HEAD >/dev/null
  git -C "$TEMPLATES/nuclei-templates" rev-parse --verify HEAD >/dev/null

  seclists_count="$(find "$WORDLISTS/SecLists" -type f | wc -l)"
  nuclei_count="$(
    find "$TEMPLATES/nuclei-templates" -type f \
      \( -name '*.yaml' -o -name '*.yml' \) | wc -l
  )"
  gf_count="$(find "$PATTERNS/gf" -type f -name '*.json' | wc -l)"
  payload_count="$(wc -l < "$PAYLOADS/payload-repository-files.txt")"

  (( seclists_count >= 100 ))
  (( nuclei_count >= 100 ))
  (( gf_count >= 5 ))
  (( payload_count >= 100 ))
  command -v nuclei >/dev/null
  nuclei -version >/dev/null 2>&1

  {
    printf 'asset-validation\tfiles\tSecLists\t%s\t%s\n' \
      "$seclists_count" "$WORDLISTS/SecLists"
    printf 'asset-validation\ttemplates\tnuclei\t%s\t%s\n' \
      "$nuclei_count" "$TEMPLATES/nuclei-templates"
    printf 'asset-validation\tpatterns\tgf\t%s\t%s\n' \
      "$gf_count" "$PATTERNS/gf"
    printf 'asset-validation\tfiles\tpayload-repositories\t%s\t%s\n' \
      "$payload_count" "$PAYLOADS/payload-repository-files.txt"
  } >> "$RESOLVED_FILE"
}

install_step "SecLists" "git asset" clone_asset_repo SecLists https://github.com/danielmiessler/SecLists.git "$WORDLISTS/SecLists"
install_step "WordList" "git asset" clone_asset_repo WordList https://github.com/orwagodfather/WordList.git "$WORDLISTS/WordList"
install_step "mrco24-wordlist" "git asset" clone_asset_repo mrco24-wordlist https://github.com/mrco24/mrco24-wordlist.git "$WORDLISTS/mrco24-wordlist"
install_step "nuclei-templates" "git asset" clone_asset_repo nuclei-templates https://github.com/projectdiscovery/nuclei-templates.git "$TEMPLATES/nuclei-templates"
install_step "fuzzing-templates" "git asset" clone_asset_repo fuzzing-templates https://github.com/projectdiscovery/fuzzing-templates.git "$TEMPLATES/fuzzing-templates"
install_step "jaeles-signatures" "git asset" clone_asset_repo jaeles-signatures https://github.com/jaeles-project/jaeles-signatures.git "$TEMPLATES/jaeles-signatures"
install_step "ghsec-jaeles-signatures" "git asset" clone_asset_repo ghsec-jaeles-signatures https://github.com/ghsec/ghsec-jaeles-signatures.git "$TEMPLATES/ghsec-jaeles-signatures"
install_step "GF patterns" "git/http assets" install_gf_patterns
install_step "LFI payloads" "git asset" install_lfi_payloads
install_step "Payload repositories" "local snapshot asset" install_payload_repositories
install_step "Kiterunner wordlists" "vendor assets" install_kiterunner_wordlists
install_step "Amass config" "upstream assets" install_amass_config
install_step "Xray config" "git asset" install_xray_config
install_step "GF runtime wrapper" "runtime config" install_gf_runtime_wrapper
install_step "webanalyze definitions" "runtime asset" install_webanalyze_data
install_step "gau default config" "runtime asset" install_gau_config
install_step "cent community templates" "upstream asset" install_cent_templates
install_step "wordlist, template, pattern, and payload integrity" \
  "structure, revision, count, and nuclei runtime checks" verify_asset_collections
finish_installer
