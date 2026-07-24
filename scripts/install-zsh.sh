#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="zsh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

install_zsh_environment() {
  local source_config
  source_config="$(dirname "${BASH_SOURCE[0]}")/portable.zshrc"

  command -v zsh >/dev/null
  test -s "$source_config"

  rm -rf /opt/oh-my-zsh
  retry git clone --depth 1 \
    https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh
  test -s /opt/oh-my-zsh/oh-my-zsh.sh

  install -d -m 0755 /etc/zsh
  install -m 0644 "$source_config" /etc/zsh/portable.zshrc
  if ! grep -Fq '/etc/zsh/portable.zshrc' /etc/zsh/zshrc; then
    printf '\n# AI Offensive Workstation interactive shell\n' >> /etc/zsh/zshrc
    printf '[[ -r /etc/zsh/portable.zshrc ]] && source /etc/zsh/portable.zshrc\n' \
      >> /etc/zsh/zshrc
  fi

  usermod --shell /usr/bin/zsh root
  if getent passwd hermes >/dev/null; then
    usermod --shell /usr/bin/zsh hermes
  fi

  chmod -R a+rX,go-w /opt/oh-my-zsh

  printf 'oh-my-zsh\tgit\thttps://github.com/ohmyzsh/ohmyzsh.git\t%s\t%s\n' \
    "$(git -C /opt/oh-my-zsh rev-parse HEAD)" /opt/oh-my-zsh \
    >> "$RESOLVED_FILE"
  printf 'portable-zshrc\tconfiguration\tproject\t1\t%s\n' \
    /etc/zsh/portable.zshrc >> "$RESOLVED_FILE"
}

verify_zsh_environment() {
  [[ "$(getent passwd root | cut -d: -f7)" == /usr/bin/zsh ]]
  if getent passwd hermes >/dev/null; then
    [[ "$(getent passwd hermes | cut -d: -f7)" == /usr/bin/zsh ]]
  fi

  local temporary_home
  temporary_home="$(mktemp -d)"
  HOME="$temporary_home" TERM=dumb zsh -ic '
    [[ "$ZSH" == /opt/oh-my-zsh ]]
    [[ -n "$PROMPT" ]]
    (( $+functions[configure_prompt] ))
    (( $+functions[mkcd] ))
    alias ll >/dev/null
  '
  rm -rf "$temporary_home"
}

install_step "Zsh, Oh My Zsh, and portable workstation configuration" \
  "apt/git/system configuration" install_zsh_environment
install_step "root and Hermes interactive Zsh smoke test" \
  "offline interactive shell" verify_zsh_environment
finish_installer
