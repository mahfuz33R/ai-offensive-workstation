#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="kali-base"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

verify_kali_repository_track() {
  local expected_suite
  case "${KALI_IMAGE:-kalilinux/kali-last-release}" in
    */kali-last-release)
      expected_suite=kali-last-snapshot
      ;;
    */kali-rolling)
      expected_suite=kali-rolling
      ;;
    *)
      log "Unsupported Kali image repository: ${KALI_IMAGE:-unset}"
      return 1
      ;;
  esac

  if ! grep -Rqs -- "$expected_suite" \
      /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    log "The selected image does not use the expected APT suite: $expected_suite"
    return 1
  fi
}

install_kali_standard_environment() {
  grep -Eq '^ID=kali$' /etc/os-release
  verify_kali_repository_track

  retry apt-get update
  apt-cache show kali-linux-headless >/dev/null
  # Nmap currently lives in Kali's non-free component. Verify the official
  # container sources expose all components needed by the headless metapackage
  # before beginning the large transaction.
  apt-cache show nmap >/dev/null
  retry apt-get -y full-upgrade
  retry apt-get install -y --no-install-recommends \
    kali-linux-headless gosu sudo tini util-linux
  rm -rf /var/lib/apt/lists/*

  dpkg-query -W -f='${Status}\n' kali-linux-headless \
    | grep -Fx 'install ok installed'
  command -v nmap >/dev/null
}

create_hermes_admin_user() {
  if ! getent group hermes >/dev/null; then
    groupadd --gid 10000 hermes
  fi
  if ! getent passwd hermes >/dev/null; then
    useradd --uid 10000 --gid hermes --create-home \
      --shell /usr/bin/zsh hermes
  fi

  install -d -o hermes -g hermes -m 0750 /home/hermes
  install -d -m 0750 /etc/sudoers.d
  printf 'hermes ALL=(ALL:ALL) NOPASSWD: ALL\n' \
    > /etc/sudoers.d/90-hermes-admin
  chmod 0440 /etc/sudoers.d/90-hermes-admin
  visudo --check --file=/etc/sudoers.d/90-hermes-admin
}

install_step "official Kali headless standard environment" \
  "official release-track apt full-upgrade and kali-linux-headless" \
  install_kali_standard_environment
install_step "Hermes administrative account" \
  "dedicated user with passwordless container-local sudo" \
  create_hermes_admin_user
finish_installer
