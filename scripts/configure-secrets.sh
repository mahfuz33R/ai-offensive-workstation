#!/usr/bin/env bash
# Run this INSIDE the running container (not during docker build) after
# starting it through Compose, which injects the ignored root .env. It wires up
# the tools that need one-time API key configuration.
#
#   docker run -it --rm --env-file .env ai-offensive-workstation zsh
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

cyberstrike_provider=
for provider_key in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY GROQ_API_KEY; do
  if [ -n "${!provider_key:-}" ]; then
    cyberstrike_provider="${cyberstrike_provider:+$cyberstrike_provider, }$provider_key"
  fi
done
if [ -n "$cyberstrike_provider" ]; then
  echo "[configure-secrets] CyberStrike model credential environment detected: $cyberstrike_provider."
  echo "[configure-secrets] Verify provider/model discovery with: cyberstrike models"
else
  echo "[configure-secrets] No CyberStrike model provider key is set; add one to the ignored root .env before unattended runs."
fi

echo "[configure-secrets] Done."
