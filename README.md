# AI Offensive Workstation

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Validate source](https://github.com/mahfuz33R/ai-offensive-workstation/actions/workflows/validate.yml/badge.svg)](https://github.com/mahfuz33R/ai-offensive-workstation/actions/workflows/validate.yml)
[![Docker](https://img.shields.io/badge/runtime-Docker-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/engine/install/)
[![Shell: Zsh](https://img.shields.io/badge/shell-Zsh-black?logo=zsh)](https://www.zsh.org/)
[![Use: Authorized Security Testing](https://img.shields.io/badge/use-authorized%20testing-darkred)](#responsible-use)

A persistent, portable Docker workstation that combines Hermes Agent, browser
automation, a customized Zsh environment, and a verified offensive-security
toolchain. Build it once, then reuse the same image without reinstalling tools
on every start.

## Highlights

- Hermes Agent with a purpose-built pentesting knowledge library
- Customized Zsh, Oh My Zsh, autosuggestions, syntax highlighting, and Tmux
- Go, Python, Rust, Ruby, and Node.js toolchains
- 191 verified commands, assets, paths, and Linux capabilities
- 136 primary tool guides, 25 aliases, and 14 operational workflows
- Persistent `/root`, `/opt/data`, and `/workspace` host mounts
- Encrypted migration of authenticated workstation state
- Current Hermes `latest` base by default, with optional digest pinning

## Documentation

| Guide | Purpose |
| --- | --- |
| [Quick command reference](command.md) | Common build, run, shell, dashboard, and verification commands |
| [How the workstation works](how_it_works.md) | Architecture, persistence, image contents, and runtime behavior |
| [Reuse an authenticated workstation](reuse.md) | Encrypted migration to another Docker host |
| [Run an exported image](run_exported_image.md) | Offline and image-only deployment |
| [Third-party notices](THIRD_PARTY_NOTICES.md) | Bundled payload sources and licensing |

## Responsible use

Use these security tools only on systems you own or have explicit written
permission to test. You are responsible for complying with applicable laws,
contracts, and rules of engagement.

## What is included

This project builds one large Docker image containing:

- Hermes Agent
- Zsh, Oh My Zsh, autosuggestions, and syntax highlighting
- Go, Python, Rust, Ruby, and Node.js
- Offensive-security commands from Hackers
- Wordlists, payloads, templates, and browser automation
- A checker that confirms everything is present

You build the image once. After that, starting the container does **not** install
the tools again.

## The simple idea

Think of the Docker image as a packed suitcase:

- `docker compose build` packs Hermes and all the tools into the suitcase.
- `docker compose up` opens and runs the suitcase.
- `docker compose down` closes it.
- `docker save` lets you carry the suitcase to another computer.

Your reports and Hermes settings are stored outside the suitcase so they are not
lost when a container is replaced.

## Before you begin

You need:

1. A Linux computer with enough free disk space. This image is large.
2. Docker Engine with the Docker Compose plugin.
3. Internet access during the first build.
4. This project folder.

Open a terminal and check Docker:

```bash
docker --version
docker compose version
```

Purpose: these commands only display versions. They do not change anything.

If both commands print version numbers, Docker is installed. If you see
`command not found`, install Docker before continuing.

> Your computer may require `sudo` for Docker. `sudo` asks for your Linux
> password and gives Docker the required permission.

## Step 1: Open the project folder

Clone the repository:

```bash
git clone https://github.com/mahfuz33R/ai-offensive-workstation.git
cd ai-offensive-workstation
```

Purpose: `git clone` downloads the Docker source and bundled payload assets;
`cd` enters the folder containing the `Dockerfile` and `docker-compose.yml`.

Confirm that you are in the correct folder:

```bash
pwd
ls
```

You should see files such as:

```text
Dockerfile
docker-compose.yml
README.md
scripts
```

## Step 2: Create the persistent folders

```bash
mkdir -p workspace/container-root workspace/container-opt/data
```

Purpose:

- `workspace/container-root` stores the complete interactive `/root` home.
- `workspace/container-opt/data` stores Hermes settings, API keys, sessions,
  memories, and files written below `/opt/data`.
- `workspace` stores your projects, targets, notes, downloads, and reports.
- `mkdir -p` creates the folders if they do not exist. It is safe to run again.

## Step 3: Prepare optional security-tool API keys

Some tools can use Shodan, Censys, VirusTotal, GitHub, or Interactsh credentials.
The tools install without these keys, but their online API features may not work.

Create your private secrets file:

```bash
cp secrets.env.example secrets.env
chmod 600 secrets.env
nano secrets.env
```

Purpose:

- `cp` creates your private file from the example.
- `chmod 600` allows only your Linux user to read or change it.
- `nano` opens it for editing.

Replace empty values with credentials that belong to you. In Nano, press
`Ctrl+O`, then Enter to save. Press `Ctrl+X` to exit.

Do not paste credentials into the `Dockerfile`, README, or installation scripts.
The `secrets.env` file is intentionally excluded from the image.

If you do not have these API keys, leave the values empty and continue.

## Step 4: Save the host settings once

Create the machine-specific `.env` and persistent directories:

```bash
bash scripts/configure-host.sh
```

Purpose: the script detects the project path, user ID, and group ID. It stores
them in the project's `.env` file and creates the persistent `/root`,
`/opt/data`, and workspace folders. It never reads, copies, or changes the host
Hermes installation under `$HOME/.hermes`. Docker Compose reads `.env`
automatically.

Run this command once after cloning and again after moving the project to a
different host. You do **not** need to export `HERMES_DATA_DIR`, `HERMES_UID`,
or `HERMES_GID` manually.

The `.env` file is machine-specific and excluded from Git and the Docker image.
It does not contain your security-tool API keys.

Host Hermes and Docker Hermes are independent installations:

| Installation | Configuration directory |
|---|---|
| Hermes installed directly on the host | `$HOME/.hermes` |
| Hermes in this Docker workstation | `workspace/container-opt/data` |

Changing one directory does not update the other. Run the Docker setup wizard
when `workspace/container-opt/data` is new or intentionally empty.

If an older workstation container already contains useful files under `/root`,
copy them before recreating that container:

```bash
bash scripts/migrate-container-root.sh
```

This migration requires Docker access and may ask for the host sudo password.

## Step 5: Build the complete image

Use the combined safety, build, and verification command:

```bash
sudo bash scripts/build-and-verify.sh
```

This is the recommended first build. It checks the Compose file, shell syntax,
secret exclusions, installer linkage, and inventory before building. After the
build, it checks the image again as the non-root `hermes` user while an empty
folder is mounted at `/workspace`. This proves that installed tools are inside
the image and are not accidentally hidden in the workspace mount.

The lower-level build command is: [Note: Automaticly run if you run previous command and all preflight test pass successfully]

```bash
sudo docker compose build --pull --no-cache
```

Purpose:

- `sudo` provides Docker permission.
- `docker compose build` creates the image.
- `--pull` checks for the current Hermes base image.
- `--no-cache` performs a clean first build instead of reusing old build layers.

During the build Docker will:

1. Download the current official Hermes Agent `latest` base image.
2. Install system and network packages.
3. Install Go, Python, Rust, Ruby, and Node tools.
4. Download source tools, wordlists, templates, and browser files.
5. Check every required command and asset.
6. Fail the build if anything required is missing.

This can take a long time. Leave the terminal open. A slow download is normal.

Successful output ends without a red error and creates this image:

```text
ai-offensive-workstation:latest
```

Confirm it exists:

```bash
sudo docker image ls ai-offensive-workstation
```

If the build fails, look near the end of the output for the first tool marked
`failed` or `missing`. Fix that error and run the build command again. You may
omit `--no-cache` on later attempts so Docker can reuse completed layers:

```bash
sudo bash scripts/build-and-verify.sh --cached
```

The first command uses a clean build by default. The `--cached` option above
deliberately reuses successful layers after you fix a download problem.
If a build has completed and only a post-build assertion needs to be repeated,
use `sudo bash scripts/build-and-verify.sh --verify-only`; it never rebuilds or
retags the existing image.

By default, the build wrapper follows `nousresearch/hermes-agent:latest` and
uses `--pull` to retrieve the current upstream image. For a reproducible build, uncomment the
optional `HERMES_DIGEST=@sha256:...` line in your local `.env`. Keep the leading
`@` because Docker appends this value directly to the image tag.

```bash
sudo bash scripts/build-and-verify.sh --pull
```

## Step 6: Run the Hermes setup wizard

Do this once after the first successful build:

```bash
sudo docker compose run --rm setup
```

Purpose:

- `docker compose run` starts a temporary container for one command.
- `setup` is the one-shot setup service in `docker-compose.yml`.
- `setup` starts the Hermes setup wizard.
- `--rm` removes the temporary setup container when the wizard finishes.
- Your answers remain safe in `workspace/container-opt/data` even though the temporary
  container is removed.

The wizard asks which AI provider and model you want to use. Enter an API key
for the provider you choose. Follow the questions displayed in the terminal.

Hermes itself is already installed in the image. This wizard configures Hermes;
it does not reinstall it.

## Step 7: Start the workstation

```bash
sudo docker compose up -d --no-build
```

Purpose:

- `up` creates and starts the workstation container.
- `-d` runs it in the background so you can keep using the terminal.
- `--no-build` guarantees that Compose uses the completed image and does not
  begin another installation build.

The container starts:

- the Hermes gateway;
- the Hermes dashboard on host-local port `9119`;
- the Docker health checker.

## Step 8: Check whether it started correctly

```bash
sudo docker compose ps
```

Purpose: displays the container state. Look for `Up` and eventually `healthy`.
The dashboard service uses host networking, so its `PORTS` column may be blank;
that is normal.

Watch the Hermes logs:

```bash
sudo docker compose logs -f workstation
```

Purpose: displays live messages from Hermes. Press `Ctrl+C` to stop watching the
logs. This does not stop the container.

Watch the dashboard logs if the browser page does not open:

```bash
sudo docker compose logs -f dashboard
```

Purpose: displays live messages from the Hermes web dashboard service.

Open the dashboard in a browser on this same computer:

```text
http://127.0.0.1:9119
```

The dashboard logs should include:

```text
HERMES_DASHBOARD_READY port=9119
Hermes Web UI -> http://127.0.0.1:9119
```

The dashboard container runs `hermes dashboard`. The gateway container runs
`hermes gateway run`. These are separate Hermes processes.

The dashboard is reachable only from the Docker host by default because the
dashboard service uses host networking and binds Hermes to `127.0.0.1`.
Do not change the dashboard host to `0.0.0.0`; Hermes refuses unauthenticated
non-loopback dashboard binds.

If Docker is running on a remote server over SSH, keep the dashboard bound to
`127.0.0.1` and create an SSH tunnel from your local computer:

```bash
ssh -L 9119:127.0.0.1:9119 username@server-ip
```

Keep that SSH terminal open. Then open this on your local computer:

```text
http://127.0.0.1:9119
```

If local port `9119` is already busy, forward a different local port:

```bash
ssh -L 9120:127.0.0.1:9119 username@server-ip
```

Then open:

```text
http://127.0.0.1:9120
```

### Stop or start only the dashboard

The dashboard is the web UI. If you do not need browser access, stop only the
dashboard and keep the Hermes gateway running:

```bash
sudo docker compose stop dashboard
```

After this, `http://127.0.0.1:9119` will stop responding, but terminal Hermes
and the gateway service can continue running.

Start only the dashboard again:

```bash
sudo docker compose start dashboard
```

If the dashboard container was removed, recreate only that service:

```bash
sudo docker compose up -d --no-build dashboard
```

Check only the dashboard:

```bash
sudo docker compose ps dashboard
sudo docker compose logs --tail=80 dashboard
```

For remote SSH access, closing the SSH tunnel also closes browser access from
your local machine. Press `Ctrl+C` in the terminal running:

```bash
ssh -L 9119:127.0.0.1:9119 username@server-ip
```

You can also use Hermes from the terminal:

```bash
sudo docker compose exec --user hermes workstation hermes
```

## Step 9: Check every installed tool

```bash
sudo docker compose exec workstation check-tools
```

Purpose:

- `exec` runs a command inside the already-running container.
- `check-tools` checks all canonical tool names, all legacy names from
  `check_tools.sh`, language runtimes, Hermes, wordlists, templates, and other
  required assets.

A successful result ends with a message similar to:

```text
Verification passed: ... required entries found.
```

Read the detailed report:

```bash
sudo docker compose exec workstation \
  cat /workspace/reports/tool-manifest.tsv
```

Check Docker's automatic health result:

```bash
sudo docker inspect \
  --format '{{.State.Health.Status}}' \
  ai-offensive-workstation
```

Expected result:

```text
healthy
```

The build already performs the same strict check. Docker repeats it every five
minutes while the container is running.

Check the Hermes pentesting knowledge library:

```bash
sudo docker compose exec --user hermes workstation check-knowledge --require-help
```

This verifies that every primary command has a guide, every compatibility alias
points to a canonical guide, internal links work, sources are recorded, and the
installed-version help snapshots exist.

Run the complete service, shell, browser, Tmux, mount, and persistence audit:

```bash
bash scripts/verify-runtime.sh --recreate
```

For the largest audit, including an encrypted reuse export/import round-trip in
an isolated temporary directory:

```bash
bash scripts/verify-runtime.sh --recreate --reuse-roundtrip
```

The reuse round-trip requires enough temporary disk space for another image
archive and another copy of the private workspace.

## Step 10: Open the default root Zsh shell

```bash
sudo docker compose exec --user root workstation zsh
```

Purpose: opens the customized Zsh and Oh My Zsh environment as root. This is
the primary interactive maintenance shell. The Hermes gateway itself continues
to run as the non-root `hermes` user.

The prompt, completion, history behavior, aliases, autosuggestions, syntax
highlighting, and key bindings come from:

```text
/etc/zsh/portable.zshrc
```

You can now run tools such as:

```bash
nmap --version
subfinder -h
nuclei -h
ffuf -h
```

Leave the container shell with:

```bash
exit
```

Leaving the shell does not stop the Hermes gateway.

For a non-root shell matching the gateway user:

```bash
sudo docker compose exec --user hermes workstation zsh
```

Both users have `/usr/bin/zsh` as their login shell. Bash remains installed for
build scripts and scripts that explicitly start with `#!/usr/bin/env bash`.
Those scripts work normally when launched from Zsh; the shebang selects Bash
for the script without changing your interactive shell.

Press `Ctrl+P` inside Zsh to switch between the two-line and one-line prompts.
The Oh My Zsh Git plugin is enabled. Autosuggestions and syntax highlighting
are provided by the image's Debian packages.

Project automation remains written in Bash because it uses Bash-specific
syntax. You can launch it normally from Zsh:

```zsh
bash scripts/preflight.sh
sudo bash scripts/build-and-verify.sh --cached
```

Do not `source` these files into Zsh. Executing them starts the interpreter
declared by their Bash shebang and returns to Zsh when they finish.

Tmux is installed and verified by `check-tools`. Start a persistent terminal
session from the root Zsh shell with:

```zsh
tmux new -s workstation
```

Detach with `Ctrl+B`, then `D`, and reconnect with:

```zsh
tmux attach -t workstation
```

Tmux sessions survive shell disconnection but not container removal. Files,
Zsh history, and Tmux configuration under `/root` remain persistent on the
host.

To customize the baked shell, edit:

```text
config/portable.zshrc
```

Then rebuild with:

```bash
sudo bash scripts/build-and-verify.sh --cached
```

## Hermes Agent: setup, files, daily use, and browser

### Where Hermes is installed

Hermes is already installed inside the Docker image at `/opt/hermes`. You do
not need to install Hermes on the host computer. `/opt/hermes` is deliberately
read-only to the normal `hermes` user so an agent session cannot accidentally
damage its own installation.

All changeable Hermes data lives at `/opt/data` inside the container. Compose
maps that directory to the host directory recorded as `HERMES_DATA_DIR` in
`.env`. On a normal installation this is `workspace/container-opt/data`.
It is separate from `$HOME/.hermes`, which belongs only to a host-installed
Hermes and is never mounted or imported by this project.

| Inside the container    | Normal host location        | Purpose                                        |
| ----------------------- | --------------------------- | ---------------------------------------------- |
| `/opt/data/config.yaml` | `workspace/container-opt/data/config.yaml` | Model, tools, and behavior configuration       |
| `/opt/data/.env`        | `workspace/container-opt/data/.env`        | AI-provider and Hermes integration credentials |
| `/opt/data/sessions`    | `workspace/container-opt/data/sessions`    | Conversation sessions                          |
| `/opt/data/memories`    | `workspace/container-opt/data/memories`    | Persistent memories                            |
| `/opt/data/skills`      | `workspace/container-opt/data/skills`      | Installed and user-created skills              |
| `/opt/data/home`        | `workspace/container-opt/data/home`        | Home used by Hermes tool subprocesses          |
| `/opt/data/logs`        | `workspace/container-opt/data/logs`        | Persistent Hermes and gateway logs             |
| `/opt/data/profiles`    | `workspace/container-opt/data/profiles`    | Additional Hermes profiles                     |

Do not confuse these two files:

- `workspace/container-opt/data/.env` configures Hermes and its AI providers.
- This project's `secrets.env` passes optional Shodan, Censys, VirusTotal,
  GitHub, and Interactsh values to security tools.

Never publish either file.

### Initial setup and later reconfiguration

Before the gateway is started for the first time, run:

```bash
sudo docker compose run --rm setup
```

This opens the full setup wizard and saves its result under `/opt/data`. The
temporary setup container is deleted, but the bind-mounted data remains.

To safely run the full wizard again later, stop the gateway first so two Hermes
processes do not write to the same data directory:

```bash
sudo docker compose down
sudo docker compose run --rm setup
sudo docker compose up -d --no-build
```

Useful maintenance commands against a running container are:

```bash
sudo docker compose exec --user hermes workstation hermes doctor
sudo docker compose exec --user hermes workstation hermes model
sudo docker compose exec --user hermes workstation hermes tools
```

- `hermes doctor` diagnoses configuration and dependency problems.
- `hermes model` changes or inspects the model provider.
- `hermes tools` changes enabled toolsets.

Open an interactive Hermes terminal chat with:

```bash
sudo docker compose exec --user hermes workstation hermes
```

For normal gateway use, port `8642` is the gateway/API port. The dashboard uses
port `9119` and binds to `127.0.0.1` on the Docker host, so another computer
cannot connect directly. Prefer SSH forwarding for remote servers. The
dashboard service uses host networking, so Docker Compose may show an empty
`PORTS` column for it even when it is running correctly.

### Let Hermes browse the web with Chromium

The image contains Hermes' `agent-browser` CLI, Playwright, and a headless
Chromium. The build performs an offline Chromium launch and fails if the
browser cannot start. Compose also gives Chromium 1 GB of shared memory.

Enable Browser Automation in the Hermes tool setup:

```bash
sudo docker compose exec --user hermes workstation hermes setup tools
```

Select Browser Automation and local browser mode. Alternatively, use
`hermes tools` and make sure the `browser` toolset is enabled.

Verify the baked browser command:

```bash
sudo docker compose exec --user hermes workstation agent-browser --help
```

Then ask Hermes in the dashboard or chat:

```text
Open https://example.com, read the page title, and take a screenshot.
```

Chromium is normally headless: Hermes can navigate, click, type, extract page
content, and capture screenshots, but a normal Chromium window does not appear
on the host desktop. The container needs outbound internet access. A website
can still require login, show a CAPTCHA, or block automated browsers.

Hermes can run outside Docker if installed separately using the official
Hermes installation method, but that is a second, independent installation.
This project intentionally runs Hermes inside Docker so Hermes and all security
tools share the same environment.

Official references: [Hermes Docker guide](https://hermes-agent.nousresearch.com/docs/user-guide/docker/)
and [Hermes Browser Automation](https://hermes-agent.nousresearch.com/docs/user-guide/features/browser).

### Pentesting knowledge skill

The image includes a Hermes skill named:

```text
offensive-workstation-pentesting
```

Its source is in `Rules/offensive-workstation-pentesting` in this project. The
image bakes it into:

```text
/opt/hermes/skills/cybersecurity/offensive-workstation
```

At container startup, Hermes synchronizes the bundled skill into the persistent
data directory:

```text
/opt/data/skills/cybersecurity/offensive-workstation
```

On the host, that normally appears at:

```text
workspace/container-opt/data/skills/cybersecurity/offensive-workstation
```

The setup wizard must include bundled skills. Choosing a blank-slate or
no-skills setup intentionally prevents bundled skills from being synchronized.

Confirm that Hermes discovered it:

```bash
sudo docker compose exec --user hermes workstation \
  COLUMNS=240 hermes skills list | grep offensive-workstation-pentesting
```

In a Hermes chat, load the master router with:

```text
/offensive-workstation-pentesting
```

You can also ask naturally:

```text
Use the offensive workstation pentesting skill to select a safe reconnaissance
workflow for my authorized test domain.
```

The master file tells Hermes which focused reference to load. For example, the
Nuclei guide is:

```text
references/tools/nuclei.md
```

Hermes can load it internally with:

```text
skill_view("offensive-workstation-pentesting", "references/tools/nuclei.md")
```

`skill_view` is a Hermes tool call, not a command to type in Bash. The library
uses on-demand references so the agent does not consume context by loading all
135 guides at once.

If you edit the persistent copy under `workspace/container-opt/data/skills`, start a new chat
or enter this in an existing Hermes chat:

```text
/reload-skills
```

If you edit the project copy under `Rules`, rebuild the image. Unmodified
persistent copies are updated during synchronization; Hermes preserves a copy
that you have customized.

## Root, sudo, chmod, and permission errors

There is no `sudo` command inside this container by design. `sudo` belongs on
the host and authorizes the host's Docker command. Docker then decides which
user runs inside the container.

Use the customized root Zsh shell for interactive maintenance:

```bash
sudo docker compose exec --user root workstation zsh
```

Use the non-root Hermes shell when you want the same identity as the gateway:

```bash
sudo docker compose exec --user hermes workstation zsh
```

Run one command as container root without opening a shell:

```bash
sudo docker compose exec --user root workstation \
  chmod +x /workspace/scripts/my-tool.sh
```

If `chmod +x` says `Permission denied`, first check the path:

- `/opt/hermes`, `/opt/security-tools`, `/opt/security-assets`, and
  `/opt/toolchains` are immutable image content. Do not edit them at runtime.
- `/workspace` is the correct place for your scripts and cloned tools.
- Because `/workspace` is a host bind mount, host ownership and filesystem
  permissions apply.

The simplest and most persistent solution is to leave the container and change
the file on the host:

```bash
chmod +x workspace/scripts/my-tool.sh
```

If earlier root commands made the workspace root-owned, repair it on the host:

```bash
sudo chown -R "$(id -u):$(id -g)" workspace
chmod +x workspace/scripts/my-tool.sh
```

The `.env` file created by `scripts/configure-host.sh` passes your host UID and
GID to Hermes. Run that configuration script as your normal host user, not
through `sudo`.

Root changes made only in a running container disappear when the container is
recreated. Persistent custom files belong under `workspace`; permanent system
tools belong in an installer script followed by an image rebuild.

## Configure optional security-tool keys

If you filled in `secrets.env`, run:

```bash
sudo docker compose exec --user hermes workstation configure-security-secrets
```

Purpose: gives runtime credentials to tools that require a one-time setup step.
It does not install software.

## Stop, start, and restart

Stop and remove the running container:

```bash
sudo docker compose down
```

This does not delete the image or any files under `workspace`.

Start it again later:

```bash
sudo docker compose up -d --no-build
```

Restart the running container:

```bash
sudo docker compose restart workstation
```

## Carry the full image to another computer

The image contains Hermes, tool binaries, source checkouts, language
environments, browser files, wordlists, payloads, and templates. The other
computer only needs Docker to run it.

Export the image:

```bash
bash scripts/export-image.sh
```

Purpose: runs `docker save`, compresses the image, and creates:

```text
ai-offensive-workstation.tar.gz
ai-offensive-workstation-offline-files/
ai-offensive-workstation-offline-bundle.tar.gz
```

The archive includes all parent image layers, including Hermes. It can be very
large. The offline bundle contains the image archive plus:

```text
README.md
command.md
run_exported_image.md
docker-compose.yml
.env.example
secrets.env.example
```

Copy `ai-offensive-workstation-offline-bundle.tar.gz` to the other computer, or
copy the files inside `ai-offensive-workstation-offline-files/`.

Import the image on the other computer:

```bash
gzip -dc ai-offensive-workstation.tar.gz | sudo docker load
```

Purpose:

- `gzip -dc` decompresses the archive.
- `docker load` imports the complete image into Docker.
- No security tools are downloaded or compiled during import.

Then create the data folders, configure Hermes, and start it:

```bash
bash scripts/configure-host.sh
sudo docker compose run --rm setup
sudo docker compose up -d --no-build
```

## Move an already-configured workstation

The image intentionally does not contain private credentials, Hermes memories,
or your reports. To move those too, copy these folders separately:

```text
workspace/container-opt/data
workspace/container-root
workspace
```

Place them in the same locations on the destination computer before starting
the container.

Never share `workspace/container-opt/data`, `workspace/container-root`, or
`secrets.env` publicly. They may contain private API keys, browser state,
shell history, and conversation data.

To migrate the image and authenticated private state together, use the
separately encrypted reuse workflow:

```bash
./reuse.sh export
```

See [`reuse.md`](reuse.md) before using it. The resulting bundle is equivalent
to transferring account sessions and must never be shared publicly.

## Where everything lives

| Location                 | What it contains                                     | Stored in image?                |
| ------------------------ | ---------------------------------------------------- | ------------------------------- |
| `/opt/hermes`            | Hermes Agent application                             | Yes                             |
| `/opt/security-tools`    | Security-tool source and mixed-language tools        | Yes                             |
| `/opt/security-assets`   | Wordlists, templates, patterns, payloads             | Yes                             |
| `/opt/toolchains`        | Go, Python, Rust, and installed command environments | Yes                             |
| `/opt/security-manifest` | Inventory and build verification reports             | Yes                             |
| `/opt/oh-my-zsh`         | Shared Oh My Zsh framework                           | Yes                             |
| `/etc/zsh/portable.zshrc` | System-wide customized interactive Zsh configuration | Yes                            |
| `/opt/hermes/skills/cybersecurity/offensive-workstation` | Baked pentesting knowledge skill | Yes |
| `/opt/data`              | Hermes settings, keys, sessions, memories            | No—mounted from `workspace/container-opt/data` |
| `/root`                  | Root history, caches, tool configuration, screenshots | No—mounted from `workspace/container-root` |
| `/workspace`             | Your targets, reports, projects, notes, downloads    | No—mounted from `workspace`     |

Do not bind-mount the whole host `container-opt` directory onto `/opt`.
`/opt/hermes`, `/opt/security-tools`, `/opt/security-assets`, and
`/opt/toolchains` are immutable image content. Covering them with an empty or
stale host directory prevents Hermes and installed tools from starting.

## Important security warning

The Compose configuration uses:

```yaml
privileged: true
```

This allows raw-packet scanners and capture tools to work, but it gives the
container powerful access to the host. Do not run unknown scripts or malware in
this container. Do not use the tools against systems without permission.

## Quick command list

After reading the detailed steps, this is the short version:

```bash
cd /home/his3nb3rg/AiPentest/ai-offensive-workstation
bash scripts/configure-host.sh
sudo bash scripts/build-and-verify.sh
sudo docker compose run --rm setup
sudo docker compose up -d --no-build

sudo docker compose ps
sudo docker compose exec --user hermes workstation check-tools
sudo docker compose exec --user hermes workstation check-knowledge --require-help
```

## Adding your own scripts and tools

This section is for users who want to edit the workstation after the main image
has been built.

### Choose the correct location

Use these persistent folders:

| Host folder         | Container folder     | Use it for                                           |
| ------------------- | -------------------- | ---------------------------------------------------- |
| `workspace/scripts` | `/workspace/scripts` | Shell, Python, or other scripts you edit             |
| `workspace/tools`   | `/workspace/tools`   | Cloned source projects and private tool environments |
| `workspace/bin`     | `/workspace/bin`     | Executable commands and links                        |
| `workspace/config`  | `/workspace/config`  | Custom inventories and configuration                 |
| `workspace/reports` | `/workspace/reports` | Verification and scan reports                        |

`/workspace/bin` and `/workspace/scripts` are already on `PATH`. This means a
properly executable file in either folder can be called by name from Hermes or
from a container shell.

Files under `/workspace` persist because Compose mounts the host's `workspace`
folder into the container. They survive `docker compose down` and container
replacement.

Do not store editable tools under `/opt/security-tools`. That location belongs
to the immutable image and is replaced when you rebuild the image.

### Add a custom shell script

Create the script on the host:

```bash
nano workspace/scripts/my-tool
```

Example content:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "My custom tool is running."
```

Save the file and make it executable:

```bash
chmod +x workspace/scripts/my-tool
```

Purpose: the first line selects Bash, and `chmod +x` allows Linux to execute the
file as a command.

Test it inside the running container:

```bash
sudo docker compose exec --user hermes workstation my-tool
```

Hermes can call the same `my-tool` command because `/workspace/scripts` is on
the container's `PATH`.

If a script is not executable, it can still be run explicitly:

```bash
sudo docker compose exec --user hermes workstation \
  bash /workspace/scripts/my-tool
```

### Create a persistent command link

For custom tools, link commands into `/workspace/bin`, not `/usr/bin`.

Example:

```bash
ln -sfn ../scripts/my-tool workspace/bin/my-tool
```

Purpose:

- `ln -s` creates a symbolic link.
- `-f` replaces an old link with the same name.
- `-n` prevents Linux from following an existing directory link.
- The relative target works both on the host and at `/workspace/bin` inside the
  container.

Verify the link:

```bash
sudo docker compose exec --user hermes workstation command -v my-tool
sudo docker compose exec --user hermes workstation my-tool
```

Expected path:

```text
/workspace/bin/my-tool
```

You can create a traditional system link as root:

```bash
sudo docker compose exec --user root workstation \
  ln -sfn /workspace/scripts/my-tool /usr/local/bin/my-tool
```

However, `/usr/local/bin` belongs to the container layer. A link created there
at runtime disappears if the container is removed and recreated. A link under
`workspace/bin` is the recommended persistent method.

### Install a Python tool at runtime

Do not install runtime Python packages into Hermes' Python environment. Give the
custom tool its own virtual environment under `/workspace/tools`:

```bash
sudo docker compose exec --user hermes workstation bash -lc '
  python3 -m venv /workspace/tools/my-python-env
  /workspace/tools/my-python-env/bin/pip install --upgrade pip
  /workspace/tools/my-python-env/bin/pip install httpie
  ln -sfn /workspace/tools/my-python-env/bin/http /workspace/bin/http
'
```

Purpose:

- `python3 -m venv` creates an isolated Python environment.
- `pip install httpie` is only an example; replace `httpie` with your package.
- The final link makes the package command available through `/workspace/bin`.

Verify it:

```bash
sudo docker compose exec --user hermes workstation command -v http
sudo docker compose exec --user hermes workstation http --version
```

The virtual environment remains in `workspace/tools` after the container stops.

### Install a Go tool at runtime

Use workspace-owned Go directories so the runtime installation does not try to
write into the immutable `/opt/toolchains` directory:

```bash
sudo docker compose exec --user hermes workstation bash -lc '
  mkdir -p /workspace/tools/go /workspace/bin
  GOPATH=/workspace/tools/go \
  GOBIN=/workspace/bin \
  go install github.com/OWNER/PROJECT/cmd/COMMAND@latest
'
```

Replace the example module path with the real Go installation path. The compiled
binary is written directly to persistent `/workspace/bin`.

Verify it:

```bash
sudo docker compose exec --user hermes workstation command -v COMMAND
sudo docker compose exec --user hermes workstation COMMAND --help
```

### Install a Rust tool at runtime

```bash
sudo docker compose exec --user hermes workstation bash -lc '
  mkdir -p /workspace/tools/cargo /workspace/tools/cargo-home
  CARGO_HOME=/workspace/tools/cargo-home \
    cargo install --root /workspace/tools/cargo TOOL_NAME
  ln -sfn /workspace/tools/cargo/bin/TOOL_NAME /workspace/bin/TOOL_NAME
'
```

Replace `TOOL_NAME` with the crate and command name. The Cargo installation is
kept under the persistent workspace.

### Clone and expose a source tool at runtime

Example for a source repository containing `tool.py`:

```bash
sudo docker compose exec --user hermes workstation bash -lc '
  git clone https://github.com/OWNER/PROJECT.git /workspace/tools/PROJECT
  chmod +x /workspace/tools/PROJECT/tool.py
  ln -sfn /workspace/tools/PROJECT/tool.py /workspace/bin/tool
'
```

If the Python file does not have a correct `#!/usr/bin/env python3` first line,
create a small launcher instead of a direct link:

```bash
cat > workspace/bin/tool <<'EOF'
#!/usr/bin/env bash
cd /workspace/tools/PROJECT
exec python3 /workspace/tools/PROJECT/tool.py "$@"
EOF
chmod +x workspace/bin/tool
```

### Verify runtime-added tools

Copy the editable custom inventory once:

```bash
cp workspace/config/custom-tools.tsv.example \
  workspace/config/custom-tools.tsv
```

Edit it:

```bash
nano workspace/config/custom-tools.tsv
```

The format is three tab-separated fields:

```text
kind<TAB>display-name<TAB>thing-to-check
```

Supported kinds:

- `command` checks whether a command is available on `PATH`.
- `path` checks whether a file or directory exists.
- `asset` checks that a file is non-empty or a directory contains something.

Example inventory:

```text
command	my-tool	my-tool
command	httpie	http
path	my-source-project	/workspace/tools/PROJECT
asset	my-wordlists	/workspace/tools/my-wordlists
```

The spaces between fields must be real Tab characters. In Nano, press the Tab
key between each field.

Run the same verifier used by the image build:

```bash
sudo docker compose exec --user hermes workstation check-tools \
  /workspace/config/custom-tools.tsv \
  /workspace/reports/custom-tool-manifest.tsv
```

Read the report:

```bash
sudo docker compose exec --user hermes workstation \
  cat /workspace/reports/custom-tool-manifest.tsv
```

The command exits with an error if a required custom entry is missing. Runtime
custom tools are deliberately separate from the built-in Docker health check,
so an experimental script cannot make the main workstation unhealthy.

### Runtime installation versus image installation

A runtime installation is useful for testing, but it is not automatically added
to the Docker image archive.

| Method                                       | Survives container recreation? |      Included by `docker save`? |
| -------------------------------------------- | -----------------------------: | ------------------------------: |
| File under `/workspace`                      |                            Yes | No; copy `workspace` separately |
| Runtime `apt install` in the container       |                             No |                              No |
| Runtime change under `/usr/local/bin`        |                             No |                              No |
| Tool added to an installer and image rebuilt |                            Yes |                             Yes |

If the tool must travel inside `ai-offensive-workstation.tar.gz`, add it to the
build rather than only installing it at runtime.

### Permanently bake another tool into the image

1. Choose the installer matching its technology:
   - APT/general dependency: `scripts/install-system-tools.sh`
   - APT network package: `scripts/install-network-tools.sh`
   - Go module: `scripts/install-go.sh`
   - Python package/project: `scripts/install-python.sh`
   - Rust crate: `scripts/install-rust.sh`
   - Ruby gem/project: `scripts/install-ruby.sh`
   - Prebuilt release: `scripts/install-binary-tools.sh`
   - Shell, C, Perl, or mixed source: `scripts/install-source-tools.sh`
   - Wordlist/template/payload: `scripts/install-assets.sh`

2. Add the installation step using the existing examples in that file. Install
   immutable source under `/opt/security-tools`, assets under
   `/opt/security-assets`, and commands under `/usr/local/bin`.

3. Add a required row to `scripts/tool-inventory.tsv`.

   Command example:

   ```text
   command	new-tool	new-tool
   ```

   Asset example:

   ```text
   asset	new-tool-templates	/opt/security-assets/templates/new-tool
   ```

4. Add the tool's purpose and authoritative source to
   `scripts/generate-rules.py`, then regenerate and validate its guide:

   ```bash
   python3 scripts/generate-rules.py --force
   python3 scripts/verify-knowledge-base.py
   ```

   Review the generated guide under
   `Rules/offensive-workstation-pentesting/references/tools`. Replace generic
   examples with safe commands confirmed by the upstream documentation. The
   Docker build captures the final installed command's help automatically.

5. Check the edited scripts before building:

   ```bash
   find scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
   docker compose config -q
   ```

6. Rebuild the image:

   ```bash
   sudo docker compose build
   ```

7. Start the rebuilt container and verify everything:

   ```bash
   sudo docker compose up -d --no-build --force-recreate
   sudo docker compose exec workstation check-tools
   sudo docker compose exec --user hermes workstation check-knowledge --require-help
   ```

If the new required tool is absent, `verify-installation.sh` stops the image
build. Once the build passes, the tool is part of the portable image and will be
included by `scripts/export-image.sh`.
