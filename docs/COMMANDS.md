# ⌨️ Command Cookbook

[← Project home](../README.md) · [Beginner guide](BEGINNERS_GUIDE.md) · [Architecture](ARCHITECTURE.md) · [Hermes/RAG/API](HERMES_RAG_API.md)

Commands are grouped by intention. Run host commands from the repository directory unless a section says “inside the workstation.”

> [!TIP]
> Copy one command block at a time. Read it before pressing Enter. Replace uppercase placeholders such as `USER` and `SERVER_IP`.

## Host setup

```bash
# First download: clone main and enter the repository
git clone --branch main https://github.com/mahfuz33R/ai-offensive-workstation.git
cd ai-offensive-workstation

# Create/update private .env and persistent directories
bash scripts/configure-host.sh

# Protect private configuration
chmod 600 .env

# Source-only checks; no image build or container startup
bash scripts/preflight.sh
```

## Build and image verification

```bash
# Clean managed build: pulls base and ignores old layer cache
bash scripts/build-and-verify.sh

# Reuse valid layers after interruption
bash scripts/build-and-verify.sh --cached

# Verify the existing image only
bash scripts/build-and-verify.sh --verify-only
```

The build is authoritative because it downloads upstream software, launches browsers, checks dependencies and validates all inventory entries.

## Configure Hermes

After building the image, add one model-provider key to `.env`, then run the
interactive setup:

```bash
nano .env
chmod 600 .env
sudo docker compose --profile setup run --rm setup
```

Choose the same provider whose key is present in `.env`. Preferences persist in
`workspace/container-opt/data/`. If services were already running when `.env`
changed, recreate them:

```bash
sudo docker compose up -d --no-build --force-recreate
```

Verify the integration after startup:

```bash
sudo docker compose exec workstation hermes version
sudo docker compose exec workstation env COLUMNS=240 hermes skills list
sudo docker compose exec workstation hermes mcp test cyberstrike
sudo docker compose exec workstation workstation-kb verify
sudo docker compose exec workstation cyberstrike-kb verify
```

See [Hermes, RAG and API](HERMES_RAG_API.md) for provider keys, gateway
authentication and persistence details.

## Start and stop

```bash
# Start normal services without rebuilding
sudo docker compose up -d --no-build

# Show containers, health and ports
sudo docker compose ps

# Stop and remove normal containers/network; keep persistent host data
sudo docker compose down

# Recreate services after changing .env
sudo docker compose up -d --no-build --force-recreate
```

### Restart the Compose-managed gateway

Run this on the host, from the repository directory:

```bash
sudo docker compose restart workstation dashboard cyberstrike-api
sudo docker compose ps
```

Do not run `hermes gateway start`, `hermes gateway stop` or
`hermes gateway restart` inside the container. Those commands manage a Hermes
background service, but this project runs the gateway as the foreground process
owned by Docker Compose. Do not click **Restart Gateway** in the Hermes
dashboard either: that button runs `hermes gateway restart` inside the
dashboard container. A second gateway then collides with the healthy foreground
gateway and reports `Port 8656 already in use`. Keep port `8656` unchanged and
restart the Compose services from the host instead.

### Recover a Hermes gateway restart loop

First save the failure evidence, then stop the complete stack:

```bash
sudo docker compose logs --no-color --tail=200 workstation dashboard \
  > /tmp/ai-offensive-workstation-restart.log
sudo docker compose down
```

Remove only the disposable gateway process markers and restore the configured
Hermes ownership. These commands do not remove provider keys, configuration,
sessions, reports or RAG databases:

```bash
sudo rm -f -- \
  workspace/container-opt/data/gateway.pid \
  workspace/container-opt/data/gateway.lock

hermes_uid="$(sed -n 's/^HERMES_UID=//p' .env | tail -n1)"
hermes_gid="$(sed -n 's/^HERMES_GID=//p' .env | tail -n1)"
test -n "$hermes_uid" && test -n "$hermes_gid"
sudo chown -R "${hermes_uid}:${hermes_gid}" workspace/container-opt/data
sudo chmod 750 workspace/container-opt/data
sudo chmod 600 workspace/container-opt/data/.env
```

Recreate and verify all three services:

```bash
sudo docker compose up -d --no-build --force-recreate
sudo docker compose ps
sudo docker compose logs --tail=80 workstation dashboard
curl -fsS http://127.0.0.1:9119/ >/dev/null
```

If the log still reports `PermissionError: /opt/data/.env`, recheck ownership:

```bash
stat -c '%u:%g %a %n' workspace/container-opt/data/.env
```

If `gateway-restart.log` reports `Port 8656 already in use` immediately after
you clicked the dashboard restart button, the existing gateway owns the port;
do not configure a second port. Run the host-side recovery procedure above.

## Logs

```bash
# Follow all service logs
sudo docker compose logs -f

# Last 150 lines from one service
sudo docker compose logs --tail=150 workstation
sudo docker compose logs --tail=150 dashboard
sudo docker compose logs --tail=150 cyberstrike-api
```

Press `Ctrl+C` to stop following logs; it does not stop the containers.

## Shell access

```bash
# Normal Hermes user
sudo docker compose exec workstation zsh

# Explicit container root shell
sudo docker compose exec workstation root zsh

# One non-interactive command
sudo docker compose exec -T workstation check-tools
```

Inside the workstation, `sudo` is passwordless and container-local.

## Dashboard and remote SSH tunnel

Local dashboard:

```text
http://127.0.0.1:9119
```

From your local computer to a remote Docker server:

```bash
ssh -N \
  -L 9119:127.0.0.1:9119 \
  -L 8656:127.0.0.1:8656 \
  USER@SERVER_IP
```

With a non-default SSH port:

```bash
ssh -p 2222 -N \
  -L 9119:127.0.0.1:9119 \
  -L 8656:127.0.0.1:8656 \
  USER@SERVER_IP
```

Robust background tunnel:

```bash
ssh -fNT \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -L 9119:127.0.0.1:9119 \
  -L 8656:127.0.0.1:8656 \
  USER@SERVER_IP
```

## Hermes API

Load the key from the server `.env` when working directly on the server:

```bash
export API_SERVER_KEY="$(sed -n 's/^API_SERVER_KEY=//p' .env | tr -d '\r\n')"
```

Test model discovery:

```bash
curl -sS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  http://127.0.0.1:8656/v1/models | jq
```

Test skill discovery:

```bash
curl -sS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  http://127.0.0.1:8656/v1/skills | jq
```

Clear the shell variable:

```bash
unset API_SERVER_KEY
```

Browser address bars cannot supply the bearer header. Use `http://127.0.0.1:9119` for the UI.

## Local RAG

Run inside the workstation:

```bash
# Complete ethical-hacking corpus
workstation-kb search "authorized API access-control workflow" --limit 8

# Focused CyberStrike corpus
cyberstrike-kb search "resume and inspect a session" --limit 6

# Machine-readable results
workstation-kb search "safe HTTP discovery" --limit 5 --json | jq

# Metadata and integrity
workstation-kb status
workstation-kb verify
cyberstrike-kb status
cyberstrike-kb verify
```

## Hermes skills and MCP

```bash
# Confirm skill discovery
COLUMNS=240 hermes skills list | grep offensive-workstation-pentesting

# Inspect MCP servers
hermes mcp list

# Test the local CyberStrike bridge
hermes mcp test cyberstrike
```

## CyberStrike basics

```bash
cyberstrike --version
cyberstrike --help
cyberstrike models
cyberstrike agent list
cyberstrike debug paths
```

Prefer Hermes's `cyberstrike_*` MCP tools for live session automation because the bridge validates paths and known API routes.

## Configure optional tool credentials

After adding relevant values to `.env` and recreating services:

```bash
sudo docker compose exec workstation configure-security-secrets
```

This configures supported tools without placing credentials in committed files.

## Workspace and engagement setup

Inside the workstation:

```bash
export ENGAGEMENT=owned-application-review
export OUTPUT_DIR="/workspace/reports/$ENGAGEMENT"
mkdir -p "$OUTPUT_DIR"/{raw,normalized,evidence,final}
```

Useful paths:

```bash
cd /workspace/projects
cd /workspace/targets
cd /workspace/reports
cd /workspace/notes
```

## Verify tools and knowledge

```bash
check-tools
check-knowledge
check-knowledge --require-help
```

Reports normally land in `/workspace/reports/`. If that location is not writable, the tool verifier uses `/tmp`.

## Full runtime audit

Run from the host after an image exists:

```bash
# Services, mounts, ports, identity, tools, browsers, RAG, API and MCP
bash scripts/verify-runtime.sh

# Also prove state survives forced recreation
bash scripts/verify-runtime.sh --recreate

# Also exercise encrypted export/verify/import in an isolated temporary area
bash scripts/verify-runtime.sh --recreate --reuse-roundtrip
```

## Malware-analysis profile

```bash
sudo docker compose --profile malware run --rm malware-lab
```

It has no network and does not receive normal `.env` or workspace binds.

## Save a reviewed payload note

Inside the workstation:

```bash
save-payload-note \
  --category xss \
  --name harmless-training-marker \
  --source manual-lab-validation \
  --notes "For the owned training application only" \
  --payload '<script>console.log("training-marker")</script>'
```

Saved notes are marked `candidate-needs-revalidation` and belong under the persistent workspace.

## Encrypted migration

```bash
bash scripts/reuse.sh export
bash scripts/reuse.sh verify PATH/TO/BUNDLE.tar.gpg
bash scripts/reuse.sh import PATH/TO/BUNDLE.tar.gpg
```

Read [REUSE.md](REUSE.md) before using `--force`.

## Public/offline image export

```bash
bash scripts/export-image.sh \
  ai-offensive-workstation:latest \
  ai-offensive-workstation.tar.gz
```

This does not include `.env` or private workspace state.

## Update workflow

```bash
git status
git pull origin main
bash scripts/preflight.sh
bash scripts/build-and-verify.sh --cached
sudo docker compose up -d --no-build --force-recreate
bash scripts/verify-runtime.sh
```

Read upstream changes before rebuilding because several dependencies intentionally track current releases.

## Fast diagnosis table

| Symptom | First command |
|---|---|
| Dashboard unavailable | `sudo docker compose logs --tail=150 dashboard workstation` |
| Hermes API returns 401 | Verify bearer header and recreate after `.env` changes |
| Browser URL `/v1/models` returns invalid key | Normal; use dashboard `9119` or an API client |
| Build stopped | Find the first installer error, then use `--cached` |
| Tool missing | `check-tools` |
| RAG result missing | `workstation-kb status && workstation-kb verify` |
| CyberStrike unavailable | `sudo docker compose logs --tail=150 cyberstrike-api` |
| Changed environment ignored | `sudo docker compose up -d --no-build --force-recreate` |
| Workstation/dashboard restart loop | [Recover stale gateway state](#recover-a-hermes-gateway-restart-loop) |
