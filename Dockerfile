# syntax=docker/dockerfile:1

ARG HERMES_IMAGE=nousresearch/hermes-agent
ARG HERMES_TAG=latest
ARG HERMES_DIGEST=
FROM ${HERMES_IMAGE}:${HERMES_TAG}${HERMES_DIGEST}

ARG HERMES_IMAGE
ARG HERMES_TAG
ARG HERMES_DIGEST
ARG TARGETARCH
ARG GO_VERSION=1.26.5
ARG RUST_TOOLCHAIN=stable

LABEL org.opencontainers.image.title="ai-offensive-workstation" \
      org.opencontainers.image.description="Hermes Agent with a technology-organized offensive security toolchain" \
      org.opencontainers.image.base.name="${HERMES_IMAGE}:${HERMES_TAG}"

USER root

ENV SECURITY_TOOLS_DIR=/opt/security-tools \
    SECURITY_ASSETS_DIR=/opt/security-assets \
    TOOLCHAINS_DIR=/opt/toolchains \
    SECURITY_MANIFEST_DIR=/opt/security-manifest \
    SECURITY_VENV=/opt/toolchains/python \
    GOPATH=/opt/toolchains/go \
    CARGO_HOME=/opt/toolchains/cargo \
    RUSTUP_HOME=/opt/toolchains/rustup \
    PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/.playwright \
    SHELL=/usr/bin/zsh \
    PATH="/workspace/bin:/workspace/scripts:/usr/local/go/bin:/opt/toolchains/go/bin:/opt/toolchains/python/bin:/opt/toolchains/cargo/bin:${PATH}"

COPY scripts/lib/ /tmp/install/lib/

RUN mkdir -p \
      /workspace/bin /workspace/scripts /workspace/tools /workspace/config \
      /workspace/projects /workspace/targets /workspace/reports \
      /workspace/downloads /workspace/notes /workspace/malware \
      /opt/security-tools /opt/security-assets /opt/toolchains /opt/security-manifest

COPY scripts/install-system-tools.sh /tmp/install/
RUN bash /tmp/install/install-system-tools.sh
COPY scripts/install-zsh.sh config/portable.zshrc /tmp/install/
RUN bash /tmp/install/install-zsh.sh
COPY scripts/install-network-tools.sh /tmp/install/
RUN bash /tmp/install/install-network-tools.sh
COPY scripts/install-go.sh /tmp/install/
RUN GO_VERSION="${GO_VERSION}" TARGETARCH="${TARGETARCH}" bash /tmp/install/install-go.sh
COPY scripts/install-python.sh /tmp/install/
RUN bash /tmp/install/install-python.sh
COPY scripts/install-node.sh /tmp/install/
RUN bash /tmp/install/install-node.sh
COPY scripts/install-rust.sh /tmp/install/
RUN RUST_TOOLCHAIN="${RUST_TOOLCHAIN}" bash /tmp/install/install-rust.sh
# GitHub occasionally leaves long-lived HTTP/2 clone streams stalled inside
# container network namespaces. Force Git's more conservative HTTP/1.1 path
# and fail genuinely idle transfers so the installer's retry logic can act.
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
COPY PayloadsAllTheThings/ /tmp/install/payload-sources/PayloadsAllTheThings/
COPY payload-box/ /tmp/install/payload-sources/payload-box/
COPY scripts/install-assets.sh /tmp/install/
RUN bash /tmp/install/install-assets.sh
COPY scripts/install-browser-automation.sh /tmp/install/
RUN bash /tmp/install/install-browser-automation.sh

COPY scripts/tool-inventory.tsv /opt/security-manifest/tool-inventory.tsv
COPY config/excluded-tools.txt /opt/security-manifest/excluded-tools.txt
COPY scripts/configure-secrets.sh scripts/generate-help-reference.sh \
  scripts/save-payload-note.sh \
  scripts/install-runtime-permissions.sh scripts/verify-knowledge-base.py \
  scripts/verify-installation.sh /tmp/install/
COPY --chown=root:root Rules/offensive-workstation-pentesting/ \
  /opt/hermes/skills/cybersecurity/offensive-workstation/

RUN chmod 0755 /tmp/install/configure-secrets.sh \
      /tmp/install/generate-help-reference.sh \
      /tmp/install/install-runtime-permissions.sh \
      /tmp/install/save-payload-note.sh \
      /tmp/install/verify-knowledge-base.py \
      /tmp/install/verify-installation.sh \
    && install -m 0755 /tmp/install/configure-secrets.sh \
      /usr/local/bin/configure-security-secrets \
    && install -m 0755 /tmp/install/save-payload-note.sh \
      /usr/local/bin/save-payload-note \
    && /tmp/install/generate-help-reference.sh \
      /opt/hermes/skills/cybersecurity/offensive-workstation \
    && /tmp/install/verify-knowledge-base.py --require-help \
         --inventory /opt/security-manifest/tool-inventory.tsv \
         --skill-dir /opt/hermes/skills/cybersecurity/offensive-workstation \
    && /tmp/install/install-runtime-permissions.sh \
    && /tmp/install/verify-installation.sh \
      /opt/security-manifest/tool-inventory.tsv \
      /opt/security-manifest/tool-manifest.tsv \
    && install -m 0755 /tmp/install/verify-installation.sh /usr/local/bin/check-tools \
    && install -m 0755 /tmp/install/verify-knowledge-base.py /usr/local/bin/check-knowledge \
    && printf 'offensive-workstation-pentesting\thermes-skill\tRules\t1.0.0\t%s\n' \
         /opt/hermes/skills/cybersecurity/offensive-workstation >> /opt/security-manifest/resolved-versions.txt \
    && chmod -R a+rX,go-w /opt/security-manifest \
         /opt/hermes/skills/cybersecurity/offensive-workstation \
    && chown -R hermes:hermes /workspace \
    && rm -rf /var/lib/apt/lists/* /root/.cache /root/.whatwaf /root/.gf \
         /root/.gau.toml /tmp/*

HEALTHCHECK --interval=5m --timeout=30s --start-period=30s --retries=1 \
  CMD ["check-tools", "/opt/security-manifest/tool-inventory.tsv", "/tmp/security-health-manifest.tsv"]

WORKDIR /workspace

# Keep the Hermes base image ENTRYPOINT and CMD unchanged. Its /init process
# must remain PID 1 so s6-overlay can initialize and supervise the gateway.
