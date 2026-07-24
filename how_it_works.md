# How This Workstation Works

This project builds a large Docker image named `ai-offensive-workstation:latest`.
The image starts from the Hermes Agent Docker image and adds offensive security
tools, language runtimes, wordlists, payloads, browser automation, and a Hermes
pentesting skill. Interactive root and Hermes shells use a shared customized
Zsh and Oh My Zsh environment.

The upstream Hermes base follows `nousresearch/hermes-agent:latest` by default.
For a reproducible build, copy or uncomment the optional
`HERMES_DIGEST=@sha256:...` setting in the machine-specific `.env`. Leaving it
unset allows `--pull` to retrieve the current upstream image.

## Main Pieces

- `Dockerfile` builds the image.
- `docker-compose.yml` runs the image as the `workstation` service.
- `scripts/install-*.sh` install and verify the toolchains, tools, assets, and
  Hermes browser automation during the image build.
- `scripts/tool-inventory.tsv` is the authoritative list of required commands,
  paths, assets, and Linux capabilities.
- `Rules/offensive-workstation-pentesting/` is the bundled Hermes skill source.
- `workspace/` is your host working folder mounted into the container at
  `/workspace`.
- `workspace/container-opt/data` is mounted at `/opt/data` and stores Hermes
  configuration, API keys, sessions, memories, and user skills.
- `workspace/container-root` is mounted at `/root` and stores root-owned tool
  configuration, caches, Zsh history, and browser screenshots.

If Hermes is also installed directly on the host, it uses `$HOME/.hermes`.
Docker Hermes never mounts, imports, or modifies that directory. Its separate
configuration is always under `workspace/container-opt/data`.

## Build Flow

Run:

```bash
sudo bash scripts/build-and-verify.sh
```

The script performs this sequence:

1. Runs host-side preflight checks.
2. Builds the Docker image.
3. Verifies Hermes still uses its original `/init` entrypoint.
4. Runs `check-tools` inside the image as the non-root `hermes` user.
5. Runs `check-knowledge --require-help` inside the image.
6. Runs `pip check` for the shared Python environment.
7. Runs `pip check` for the isolated SploitScan Python environment.
8. Checks representative paths, Linux capabilities, and Hermes skill sync.

The image is only fully verified when the output ends with:

```text
Image build and verification passed.
```

## Runtime Flow

First configure Hermes:

```bash
sudo docker compose run --rm setup
```

The `setup` service is a one-shot service. It mounts the same `/opt/data`,
`/root`, and `/workspace` folders as the normal workstation, but disables the
Hermes dashboard inside the setup process so dashboard auth warnings do not
overwrite the wizard.

Start the workstation:

```bash
sudo docker compose up -d --no-build
```

This starts the gateway and dashboard as separate services:

- `workstation` runs the Hermes gateway command `gateway run`.
- Host `127.0.0.1:8642` maps to the gateway container port `8642`.
- `dashboard` uses host networking and binds directly to
  `127.0.0.1:${HERMES_DASHBOARD_PORT:-9119}`.
- `/opt/data` mapped from `./workspace/container-opt/data`
- `/root` mapped from `./workspace/container-root`
- `/workspace` mapped from this project folder's `workspace`

The dashboard starts by default on host-local port `9119`. Because it is bound
to `127.0.0.1`, use SSH port forwarding for a remote Docker host rather than
changing the bind address to `0.0.0.0`.

## Where Files Live

Stored inside the image:

- `/opt/hermes`
- `/opt/security-tools`
- `/opt/security-assets`
- `/opt/toolchains`
- `/opt/security-manifest`
- `/opt/oh-my-zsh`
- `/etc/zsh/portable.zshrc`
- `/opt/hermes/skills/cybersecurity/offensive-workstation`

Mounted from the host at runtime:

- `/opt/data` from `./workspace/container-opt/data`
- `/root` from `./workspace/container-root`
- `/workspace` from `./workspace`

This means your local `workspace/` files are not baked into the image. They
appear only when Compose mounts your host folder.

The rest of `/opt` must remain image-owned. Mounting a host folder over all of
`/opt` would hide Hermes, toolchains, installed tools, and security assets.

## Adding or Changing Hermes Skills

There are two ways to provide a `SKILL.md`, depending on when you want it to
exist.

### Before Docker Build: Bake the Skill Into the Image

Edit the bundled skill source here:

```text
Rules/offensive-workstation-pentesting/SKILL.md
```

If you add references, put them under:

```text
Rules/offensive-workstation-pentesting/references/
```

Then rebuild:

```bash
sudo bash scripts/build-and-verify.sh --cached
```

This bakes the skill into:

```text
/opt/hermes/skills/cybersecurity/offensive-workstation/
```

Use this method when you want everyone who receives the image to get the same
skill content.

### After Docker Run: Add or Override a Runtime Skill

Runtime Hermes skills live in the host data folder:

```text
workspace/container-opt/data/skills/
```

Inside the container, this is:

```text
/opt/data/skills/
```

For this bundled skill, the runtime synced location is normally:

```text
workspace/container-opt/data/skills/cybersecurity/offensive-workstation/SKILL.md
```

Use this method when the skill is personal, experimental, or should not be
baked into the image.

After editing runtime skills, verify:

```bash
sudo docker compose exec --user hermes workstation check-knowledge --require-help
sudo docker compose exec --user hermes workstation hermes skills list
```

## Root Permissions Inside Docker

The normal runtime user is `hermes`. For root access, run from the host:

```bash
sudo docker compose exec --user root workstation zsh
```

This opens the default customized Oh My Zsh environment. The same configuration
is available to the `hermes` user with:

```bash
sudo docker compose exec --user hermes workstation zsh
```

For one root command:

```bash
sudo docker compose exec --user root workstation apt-get update
```

Do not rely on `sudo` inside the container. Containers often do not include or
configure sudo. Use Docker's `--user root` option from the host.
