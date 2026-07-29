# AI Offensive Workstation

A reproducible Kali Linux workstation for authorized security testing, with
Hermes Agent, CyberStrike, a verified tool inventory, local payload and
wordlist collections, and Chromium/Firefox browser automation.

The repository keeps only the files operators commonly edit at its root:

- `.env` — private machine settings and credentials; ignored by Git and Docker.
- `.env.example` — safe configuration template.
- `.zshrc` — tracked, secret-free shell configuration.
- `Dockerfile` and `docker-compose.yml` — build and runtime definitions.

Everything else is grouped under `docs/`, `knowledge/`, `scripts/`, `tests/`,
and `workspace/`.

Use this workstation only on systems and data you are authorized to test.

## Quick start

Requirements: Docker Engine with Compose v2, Bash, Git, and enough disk space
for Kali, security tools, browser engines, templates, and wordlists.

```bash
bash scripts/configure-host.sh
```

Edit `.env` and add only the API keys you actually use. Keep it private:

```bash
chmod 600 .env
```

Run source checks without building or starting Docker:

```bash
bash scripts/preflight.sh
```

Build from the current Kali release and verify the complete image:

```bash
bash scripts/build-and-verify.sh
```

Start the gateway and dashboard:

```bash
sudo docker compose up -d --no-build
sudo docker compose exec workstation zsh
```

The dashboard is host-local at `http://127.0.0.1:9119` by default. The Hermes
gateway is published only on `127.0.0.1:8642`.

## Configuration and secrets

`.env` is the single private configuration file. Docker Compose reads it for
project settings and injects its credentials into normal workstation services.
It is mode `600`, ignored by Git, and excluded from the Docker build context.

Never place credentials in `.zshrc`, the Dockerfile, Compose YAML, documentation,
or committed scripts. `.zshrc` is copied into the image and must remain public.

The isolated `malware-lab` profile does not inherit `.env`, host bind mounts, or
network access.

## What the build installs

- The official `kalilinux/kali-last-release` base and
  `kali-linux-headless`.
- Hermes Agent installed directly into `/usr/local/lib/hermes-agent`.
- CyberStrike and its browser worker.
- Latest compatible official Node.js and latest npm, with archive checksum
  verification.
- Playwright Chromium and Firefox plus Kali Chromium and Firefox ESR.
- Go, Python, Rust, Ruby, network, web, cloud, source-analysis, and
  exploitation utilities listed in `scripts/manifests/tool-inventory.tsv`.
- SecLists, WordList, nuclei templates, fuzzing templates, GF patterns,
  ProjectDiscovery/community templates, and bundled payload repositories.

The build fails when a required tool or asset is missing. It also launches
Chromium and Firefox headlessly and validates substantive wordlist, nuclei,
pattern, and payload collections.

## Hermes skills, RAG, and memory

The source skill lives at:

```text
knowledge/skills/offensive-workstation-pentesting/
```

It includes `SKILL.md`, the CyberStrike `AGENTS.md`, ethical-hacking
methodologies, tool/workflow guides, concise verified guidance, and
source-labeled RAG material. The build creates both a complete workstation
index and a precision CyberStrike index using FastEmbed, `sqlite-vec`, and
SQLite FTS5. No cloud embedding API or separate vector server is required. At
every gateway, dashboard, or setup start, the entrypoint safely synchronizes
the skill and both indexes into:

```text
/opt/data/skills/cybersecurity/offensive-workstation/
/opt/data/knowledge/offensive-workstation/workstation-kb.sqlite3
/opt/data/knowledge/cyberstrike/cyberstrike-kb.sqlite3
```

`/opt/data` is bound to `workspace/container-opt/data`, so the skill, RAG
material, Hermes configuration, authentication state, and future memories
survive container recreation. Small idempotent pointers for the complete RAG
and CyberStrike RAG are added to Hermes `MEMORY.md` only when absent and only
when they fit the memory limit. Existing memory is never replaced. User
projects, reports, targets, and notes live under `workspace/`.

The entrypoint also registers a bundled `cyberstrike` MCP server in Hermes.
Its nine `cyberstrike_*` tools communicate over stdio with a loopback-only
CyberStrike API service. Port 4096 is never published. If no CyberStrike server
password is supplied, Compose creates a process-only random value that is
neither printed nor stored. CyberStrike's session database, auth,
configuration, and state persist below `/opt/data/cyberstrike`.

Hermes searches all local ethical-hacking knowledge first, then uses the
smaller CyberStrike index when the intent is CyberStrike-specific:

```bash
workstation-kb search "authorized API access-control test workflow" --limit 8
workstation-kb status
workstation-kb verify
cyberstrike-kb search "how do I resume and export a session?" --limit 6
cyberstrike-kb status
cyberstrike-kb verify
hermes mcp test cyberstrike
```

Local RAG, API health, session storage, and `no_reply=true` message transport
work without a model API key. An actual CyberStrike AI response requires a
provider/model configured through the private `.env` or CyberStrike auth.

## Common operations

```bash
# Stop normal services
sudo docker compose down

# Run a full runtime and persistence audit
bash scripts/verify-runtime.sh --recreate

# Open a root shell only when required
sudo docker compose exec workstation root zsh

# Start the network-isolated malware profile
sudo docker compose --profile malware run --rm malware-lab

# Create an encrypted image + private-state migration bundle
bash scripts/reuse.sh export
```

## Project guide

- [How it works](docs/HOW_IT_WORKS.md)
- [Architecture and project map](docs/ARCHITECTURE.md)
- [Command reference](docs/COMMANDS.md)
- [Encrypted reuse and migration](docs/REUSE.md)
- [Exported image guide](docs/EXPORTED_IMAGE.md)
- [Implementation audit](docs/IMPLEMENTATION_AUDIT.md)
- [Third-party notices](docs/THIRD_PARTY_NOTICES.md)

Generated reports and target data belong in `workspace/reports/` and
`workspace/targets/`; they are deliberately not tracked.
