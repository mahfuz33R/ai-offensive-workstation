#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="system"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

install_apt_system() {
  retry apt-get update
  retry apt-get install -y --no-install-recommends \
    bash build-essential ca-certificates chromium cmake curl file firefox-esr git gnupg gzip jq \
    ffmpeg less openssh-client sudo xz-utils \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    libcap2-bin libcurl4-openssl-dev libffi-dev libio-socket-ssl-perl \
    libjson-perl libnet-ssleay-perl libpcap-dev libssl-dev libxml-libxml-perl \
    libxml-writer-perl libxml2-dev libxslt1-dev lsb-release make nano \
    ninja-build openssl parallel perl pkg-config \
    pipx python3 python3-dev python3-pip python3-venv ripgrep ruby ruby-dev \
    tmux traceroute tree unzip vim wget zip zlib1g-dev
  rm -rf /var/lib/apt/lists/*
}

install_step "system and language-runtime packages" "Kali apt" install_apt_system
finish_installer
