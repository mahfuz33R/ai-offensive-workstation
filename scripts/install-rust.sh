#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="rust"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"

install_rust_runtime() {
  retry curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh
  sh /tmp/rustup-init.sh -y --no-modify-path --default-toolchain "$RUST_TOOLCHAIN"
  rm -f /tmp/rustup-init.sh
  printf 'rust\truntime\thttps://rustup.rs\t%s\t%s\n' "$(rustc --version)" "$CARGO_HOME/bin/rustc" >> "$RESOLVED_FILE"
}

install_nthim() {
  cargo install NtHiM
  link_command "$CARGO_HOME/bin/NtHiM" NtHiM
  printf 'NtHiM\tcargo\tcrates.io\tlatest\t/usr/local/bin/NtHiM\n' >> "$RESOLVED_FILE"
}

install_feroxbuster() {
  cargo install feroxbuster
  link_command "$CARGO_HOME/bin/feroxbuster" feroxbuster
  printf 'feroxbuster\tcargo\tcrates.io\tlatest\t/usr/local/bin/feroxbuster\n' >> "$RESOLVED_FILE"
}

install_step "Rust ${RUST_TOOLCHAIN}" "runtime" install_rust_runtime
install_step "NtHiM" "cargo" install_nthim
install_step "feroxbuster" "cargo" install_feroxbuster
install_step "Rust command smoke tests" "offline --help" \
  smoke_help_commands NtHiM feroxbuster
finish_installer
