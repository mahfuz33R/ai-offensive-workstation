# Command reference

Run commands from the project root.

## Configure and validate

```bash
bash scripts/configure-host.sh
$EDITOR .env
chmod 600 .env
bash scripts/preflight.sh
```

`configure-host.sh` preserves existing values in `.env`, updates host UID/GID
and absolute persistence paths, and can migrate values from a legacy
`secrets.env` or the older persistent Hermes `.env` if either is encountered.

## Build

```bash
# Clean build with current upstream releases
bash scripts/build-and-verify.sh

# Reuse Docker build cache
bash scripts/build-and-verify.sh --cached

# Verify an existing image without rebuilding it
bash scripts/build-and-verify.sh --verify-only
```

The build script runs preflight checks first. It then verifies Kali, the full
tool inventory, Hermes knowledge, Python environments, permissions, Zsh,
CyberStrike, agent-browser, Chromium, and Firefox.

## Start and use

```bash
sudo docker compose up -d --no-build
sudo docker compose ps
sudo docker compose logs -f workstation
sudo docker compose exec workstation zsh
sudo docker compose exec workstation hermes version
sudo docker compose down
```

Use root only for administration:

```bash
sudo docker compose exec workstation root zsh
```

Run one-time Hermes setup:

```bash
sudo docker compose --profile setup run --rm setup
```

Run the isolated malware-analysis shell:

```bash
sudo docker compose --profile malware run --rm malware-lab
```

## Verify

```bash
# Offline source, syntax, architecture, and knowledge checks
bash scripts/unit-test.sh

# Source checks plus Docker availability
bash scripts/preflight.sh --require-docker

# Existing-image runtime and mount audit
bash scripts/verify-runtime.sh

# Force service recreation and prove persistence
bash scripts/verify-runtime.sh --recreate

# Include encrypted reuse export/import round-trip
bash scripts/verify-runtime.sh --recreate --reuse-roundtrip
```

## Export and migrate

```bash
# Public/offline image package
bash scripts/export-image.sh

# Encrypted image plus private workspace and .env
bash scripts/reuse.sh export

# Verify without restoring
bash scripts/reuse.sh verify BUNDLE.tar.gpg

# Restore into an empty project directory
bash scripts/reuse.sh import BUNDLE.tar.gpg
```

See [REUSE.md](REUSE.md) before moving private state.
