# syntax=docker/dockerfile:1

ARG KALI_IMAGE=kalilinux/kali-last-release
ARG KALI_TAG=latest
ARG KALI_DIGEST=
FROM ${KALI_IMAGE}:${KALI_TAG}${KALI_DIGEST}

ARG KALI_IMAGE
ARG KALI_TAG
ARG KALI_DIGEST
ARG TARGETARCH
ARG GO_VERSION=1.26.5
ARG RUST_TOOLCHAIN=stable
ARG NODE_VERSION=latest
ARG NPM_VERSION=latest
ARG NODE_CACHE_BUST=manual
ARG PLAYWRIGHT_VERSION=1.62.0
ARG AGENT_BROWSER_VERSION=latest
ARG HERMES_VERSION=latest
ARG HERMES_CACHE_BUST=manual
ARG CYBERSTRIKE_VERSION=latest
ARG CYBERSTRIKE_CACHE_BUST=manual

LABEL org.opencontainers.image.title="ai-offensive-workstation" \
      org.opencontainers.image.description="Direct-installed Hermes and CyberStrike on the official stable Kali Linux release image" \
      org.opencontainers.image.base.name="${KALI_IMAGE}:${KALI_TAG}${KALI_DIGEST}" \
      org.opencontainers.image.vendor="AI Offensive Workstation"

USER root

ENV SECURITY_TOOLS_DIR=/opt/security-tools \
    SECURITY_ASSETS_DIR=/opt/security-assets \
    TOOLCHAINS_DIR=/opt/toolchains \
    SECURITY_MANIFEST_DIR=/opt/security-manifest \
    SECURITY_VENV=/opt/toolchains/python \
    GOPATH=/opt/toolchains/go \
    CARGO_HOME=/opt/toolchains/cargo \
    RUSTUP_HOME=/opt/toolchains/rustup \
    HERMES_HOME=/opt/data \
    HERMES_INSTALL_DIR=/usr/local/lib/hermes-agent \
    HERMES_BUNDLED_SKILL_DIR=/usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    HERMES_BUNDLED_CYBERSTRIKE_KB=/usr/local/share/hermes/knowledge/cyberstrike/cyberstrike-kb.sqlite3 \
    HERMES_BUNDLED_WORKSTATION_KB=/usr/local/share/hermes/knowledge/offensive-workstation/workstation-kb.sqlite3 \
    FASTEMBED_CACHE_PATH=/opt/security-assets/models/fastembed \
    BROWSER_TOOLS_DIR=/opt/browser-tools \
    PLAYWRIGHT_BROWSERS_PATH=/opt/browser-tools/playwright/.playwright \
    AGENT_BROWSER_EXECUTABLE_PATH=/opt/browser-tools/chromium \
    AGENT_BROWSER_ARGS="--no-sandbox,--disable-dev-shm-usage" \
    SHELL=/usr/bin/zsh \
    PATH="/workspace/bin:/workspace/scripts:/usr/local/go/bin:/opt/toolchains/node/bin:/opt/toolchains/go/bin:/opt/toolchains/python/bin:/opt/toolchains/cargo/bin:/opt/browser-tools/playwright/node_modules/.bin:${PATH}"

COPY scripts/lib/ /tmp/install/lib/
COPY scripts/install-kali-base.sh /tmp/install/
RUN KALI_IMAGE="${KALI_IMAGE}" bash /tmp/install/install-kali-base.sh

RUN mkdir -p \
      /workspace/bin /workspace/scripts /workspace/tools /workspace/config \
      /workspace/projects /workspace/targets /workspace/reports \
      /workspace/downloads /workspace/notes \
      /analysis/input /analysis/work /analysis/output \
      /opt/data /opt/security-tools /opt/security-assets /opt/toolchains \
      /opt/security-manifest /opt/browser-tools

COPY scripts/install-system-tools.sh /tmp/install/
RUN bash /tmp/install/install-system-tools.sh
COPY scripts/install-zsh.sh .zshrc /tmp/install/
RUN bash /tmp/install/install-zsh.sh
COPY scripts/install-network-tools.sh /tmp/install/
RUN bash /tmp/install/install-network-tools.sh
COPY scripts/install-go.sh /tmp/install/
RUN --mount=type=cache,target=/opt/toolchains/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GO_VERSION="${GO_VERSION}" TARGETARCH="${TARGETARCH}" bash /tmp/install/install-go.sh
COPY scripts/install-python.sh /tmp/install/
RUN bash /tmp/install/install-python.sh
COPY scripts/cyberstrike-kb.py scripts/install-cyberstrike-kb.sh /tmp/install/
RUN bash /tmp/install/install-cyberstrike-kb.sh
COPY scripts/install-node.sh /tmp/install/
RUN NODE_VERSION="${NODE_VERSION}" NPM_VERSION="${NPM_VERSION}" \
    NODE_CACHE_BUST="${NODE_CACHE_BUST}" TARGETARCH="${TARGETARCH}" \
    bash /tmp/install/install-node.sh
COPY scripts/install-rust.sh /tmp/install/
RUN RUST_TOOLCHAIN="${RUST_TOOLCHAIN}" bash /tmp/install/install-rust.sh

# Use a conservative Git transport so long source-tool clones can retry.
RUN git config --system http.version HTTP/1.1 \
    && git config --system http.lowSpeedLimit 1024 \
    && git config --system http.lowSpeedTime 30

COPY scripts/install-ruby.sh /tmp/install/
RUN bash /tmp/install/install-ruby.sh
COPY scripts/install-binary-tools.sh /tmp/install/
RUN TARGETARCH="${TARGETARCH}" bash /tmp/install/install-binary-tools.sh
COPY scripts/install-source-tools.sh /tmp/install/
RUN bash /tmp/install/install-source-tools.sh
COPY scripts/install-compatibility.sh /tmp/install/
RUN bash /tmp/install/install-compatibility.sh
COPY knowledge/payloads/PayloadsAllTheThings/ /tmp/install/payload-sources/PayloadsAllTheThings/
COPY knowledge/payloads/payload-box/ /tmp/install/payload-sources/payload-box/
COPY scripts/install-assets.sh /tmp/install/
RUN bash /tmp/install/install-assets.sh
COPY scripts/install-browser-automation.sh /tmp/install/
RUN PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION}" \
    AGENT_BROWSER_VERSION="${AGENT_BROWSER_VERSION}" \
    HERMES_CACHE_BUST="${HERMES_CACHE_BUST}" \
    bash /tmp/install/install-browser-automation.sh
COPY scripts/install-cyberstrike.sh /tmp/install/
RUN CYBERSTRIKE_VERSION="${CYBERSTRIKE_VERSION}" \
    CYBERSTRIKE_CACHE_BUST="${CYBERSTRIKE_CACHE_BUST}" \
    TARGETARCH="${TARGETARCH}" bash /tmp/install/install-cyberstrike.sh
COPY scripts/install-hermes.sh /tmp/install/
RUN HERMES_VERSION="${HERMES_VERSION}" \
    HERMES_CACHE_BUST="${HERMES_CACHE_BUST}" \
    bash /tmp/install/install-hermes.sh

COPY scripts/manifests/tool-inventory.tsv /opt/security-manifest/tool-inventory.tsv
COPY scripts/manifests/excluded-tools.txt /opt/security-manifest/excluded-tools.txt
COPY scripts/configure-secrets.sh scripts/generate-help-reference.sh \
  scripts/save-payload-note.sh scripts/install-runtime-permissions.sh \
  scripts/verify-knowledge-base.py scripts/verify-installation.sh \
  scripts/workstation-entrypoint.sh /tmp/install/
COPY --chown=root:root knowledge/skills/offensive-workstation-pentesting/ \
  /usr/local/share/hermes/skills/cybersecurity/offensive-workstation/

RUN chmod 0755 /tmp/install/configure-secrets.sh \
      /tmp/install/generate-help-reference.sh \
      /tmp/install/install-runtime-permissions.sh \
      /tmp/install/save-payload-note.sh \
      /tmp/install/verify-knowledge-base.py \
      /tmp/install/verify-installation.sh \
      /tmp/install/workstation-entrypoint.sh \
    && install -m 0755 /tmp/install/configure-secrets.sh \
      /usr/local/bin/configure-security-secrets \
    && install -m 0755 /tmp/install/save-payload-note.sh \
      /usr/local/bin/save-payload-note \
    && install -m 0755 /tmp/install/workstation-entrypoint.sh \
      /usr/local/sbin/workstation-entrypoint \
    && /tmp/install/generate-help-reference.sh \
      /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    && /usr/local/bin/cyberstrike-kb \
      --database /usr/local/share/hermes/knowledge/cyberstrike/cyberstrike-kb.sqlite3 \
      index \
      --skill-root /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    && /usr/local/bin/cyberstrike-kb \
      --database /usr/local/share/hermes/knowledge/cyberstrike/cyberstrike-kb.sqlite3 \
      verify \
    && /usr/local/bin/workstation-kb \
      --database /usr/local/share/hermes/knowledge/offensive-workstation/workstation-kb.sqlite3 \
      index \
      --skill-root /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    && /usr/local/bin/workstation-kb \
      --database /usr/local/share/hermes/knowledge/offensive-workstation/workstation-kb.sqlite3 \
      verify \
    && /tmp/install/verify-knowledge-base.py --require-help \
         --inventory /opt/security-manifest/tool-inventory.tsv \
         --skill-dir /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    && /tmp/install/install-runtime-permissions.sh \
    && /tmp/install/verify-installation.sh \
      /opt/security-manifest/tool-inventory.tsv \
      /opt/security-manifest/tool-manifest.tsv \
    && install -m 0755 /tmp/install/verify-installation.sh /usr/local/bin/check-tools \
    && install -m 0755 /tmp/install/verify-knowledge-base.py /usr/local/bin/check-knowledge \
    && printf 'offensive-workstation-pentesting\thermes-skill\tRules\t1.0.0\t%s\n' \
         /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
         >> /opt/security-manifest/resolved-versions.txt \
    && find /opt/data -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + \
    && ln -sfn /opt/data /home/hermes/.hermes \
    && chmod -R a+rX,go-w /opt/security-manifest \
         /usr/local/lib/hermes-agent \
         /opt/security-assets/models \
         /usr/local/share/hermes/knowledge/cyberstrike \
         /usr/local/share/hermes/knowledge/offensive-workstation \
         /usr/local/share/hermes/skills/cybersecurity/offensive-workstation \
    && chown -R hermes:hermes /home/hermes /opt/data /workspace /analysis \
         /opt/browser-tools/playwright/.playwright \
    && rm -rf /var/lib/apt/lists/* /root/.cache /root/.whatwaf /root/.gf \
         /root/.gau.toml /tmp/*

HEALTHCHECK --interval=5m --timeout=30s --start-period=30s --retries=1 \
  CMD ["check-tools", "/opt/security-manifest/tool-inventory.tsv", "/tmp/security-health-manifest.tsv"]

WORKDIR /workspace
EXPOSE 8656 9119

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/workstation-entrypoint"]
CMD ["hermes", "gateway", "run"]
