#!/usr/bin/env bash
# Run this INSIDE the running container (not during docker build) after
# starting it with --env-file secrets.env. It wires up the tools that
# need one-time API key configuration.
#
#   docker run -it --rm --env-file secrets.env ai-offensive-workstation bash
#   docker compose exec --user hermes workstation configure-security-secrets
#
set -uo pipefail

echo "[configure-secrets] Wiring up API keys from environment variables..."

if [ -n "${SHODAN_API_KEY:-}" ]; then
  shodan init "$SHODAN_API_KEY" && echo "[configure-secrets] shodan configured."
else
  echo "[configure-secrets] SHODAN_API_KEY not set - skipping shodan init."
fi

if [ -n "${CENSYS_API_ID:-}" ] && [ -n "${CENSYS_API_SECRET:-}" ]; then
  echo "[configure-secrets] Censys env vars are already exported (CENSYS_API_ID / CENSYS_API_SECRET) - censys-subdomain-finder will pick them up automatically."
else
  echo "[configure-secrets] CENSYS_API_ID / CENSYS_API_SECRET not set - censys-subdomain-finder will not work until you set them."
fi

if [ -n "${VIRUSTOTAL_API_KEY:-}" ]; then
  knockpy --set apikey-virustotal="$VIRUSTOTAL_API_KEY" && echo "[configure-secrets] knockpy VirusTotal key configured."
else
  echo "[configure-secrets] VIRUSTOTAL_API_KEY not set - skipping knockpy config."
fi

if [ -n "${INTERACTSH_AUTH_TOKEN:-}" ]; then
  echo "[configure-secrets] INTERACTSH_AUTH_TOKEN is set. Start it yourself when you need it:"
  echo "    interactsh-client -auth=\$INTERACTSH_AUTH_TOKEN"
else
  echo "[configure-secrets] INTERACTSH_AUTH_TOKEN not set - skipping."
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "[configure-secrets] GITHUB_TOKEN is set and available to GitHub-aware tools."
else
  echo "[configure-secrets] GITHUB_TOKEN not set - GitHub-dependent tools will use unauthenticated (rate-limited) requests."
fi

echo "[configure-secrets] Done."
