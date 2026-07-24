# Docker Command Quick Help

Run commands from the project folder that contains `docker-compose.yml`.
Use `sudo` if your user is not in the Docker group.

## Setup And Build

```bash
docker --version
```
Check that Docker is installed.

```bash
docker compose version
```
Check that the Docker Compose plugin is installed.

```bash
bash scripts/configure-host.sh
```
Create the local `.env` file and persistent folders for this machine.

```bash
bash scripts/migrate-container-root.sh
```
Copy `/root` from an existing pre-persistence container before recreating it.

```bash
cp secrets.env.example secrets.env && chmod 600 secrets.env
```
Create the optional private security-tool API key file.

```bash
bash scripts/preflight.sh
```
Run host-side safety checks before building.

```bash
bash scripts/build-and-verify.sh
```
Build the full image from scratch and verify the installation.

```bash
bash scripts/build-and-verify.sh --cached
```
Rebuild using Docker cache after a failed or interrupted build.

Repeat only the post-build checks against the existing image:

```bash
bash scripts/build-and-verify.sh --verify-only
```
Verify the existing image without rebuilding or retagging it.

```bash
docker compose build --pull --no-cache
```
Run only the low-level clean image build without the wrapper checks.

```bash
docker image ls ai-offensive-workstation
```
Confirm that the workstation image exists.

## First Run

```bash
docker compose run --rm setup
```
Run the Hermes setup wizard once and save settings under `workspace/container-opt/data`.

```bash
docker compose up -d --no-build
```
Start the gateway and dashboard without rebuilding the image.

```bash
docker compose ps
```
Show service status; dashboard `PORTS` can be blank because it uses host networking.

```bash
docker compose logs -f workstation
```
Watch the Hermes gateway logs.

```bash
docker compose logs -f dashboard
```
Watch the Hermes dashboard logs.

## Dashboard

```bash
docker compose stop dashboard
```
Stop only the web dashboard while keeping the gateway running.

```bash
docker compose start dashboard
```
Start only the stopped dashboard container.

```bash
docker compose up -d --no-build dashboard
```
Recreate and start only the dashboard if its container was removed.

```bash
docker compose ps dashboard
```
Check only the dashboard service status.

```bash
curl http://127.0.0.1:9119/
```
Confirm that the local dashboard HTTP server responds.

```bash
ssh -L 9119:127.0.0.1:9119 username@server-ip
```
Forward a remote server dashboard to your local browser.

```bash
ssh -L 9120:127.0.0.1:9119 username@server-ip
```
Forward the remote dashboard to local port `9120` if local `9119` is busy.

## Use The Workstation

```bash
docker compose exec --user hermes workstation hermes
```
Open an interactive Hermes terminal session inside the running workstation.

```bash
docker compose exec --user hermes workstation check-tools
```
Verify installed tools from inside the running workstation.

```bash
docker compose exec --user hermes workstation check-knowledge --require-help
```
Verify the bundled Hermes skill and generated help references.

```bash
bash scripts/verify-runtime.sh --recreate
```
Audit running services, Zsh, Oh My Zsh, Tmux, tools, browser automation,
mounts, and persistence across forced container recreation.

```bash
bash scripts/verify-runtime.sh --recreate --reuse-roundtrip
```
Run the full runtime audit plus an encrypted reuse export/import round-trip in
an isolated temporary directory.

```bash
docker compose exec --user root workstation zsh
```
Open the default customized root Zsh shell inside the workstation container.

```bash
docker compose exec --user hermes workstation zsh
```
Open the same customized shell as the non-root Hermes gateway user.

```bash
docker compose exec --user root workstation tmux new -s workstation
```
Start a named Tmux session in the persistent root environment.

```bash
docker compose exec --user hermes workstation agent-browser --help
```
Confirm that Hermes browser automation is available.

```bash
docker compose exec --user hermes workstation cyberstrike --version
```
Confirm which official npm `latest` CyberStrike release was resolved at build time.

```bash
docker compose exec --user hermes workstation cyberstrike auth list
```
Inspect CyberStrike authentication without printing credential values.

```bash
docker compose exec --user hermes workstation cyberstrike models
```
List models discovered from the runtime provider environment.

```bash
docker compose exec --user hermes workstation \
  cyberstrike run --agent cyberstrike --model provider/model \
  --format json --dir /workspace/projects/owned-app \
  "Read-only review of this authorized project; no network or file changes"
```
Run one bounded CyberStrike task after creating the deny-first project policy
described in the bundled CyberStrike RAG.

## Stop, Restart, And Clean Up

```bash
docker compose restart dashboard
```
Restart only the dashboard service.

```bash
docker compose restart workstation
```
Restart only the Hermes gateway service.

```bash
docker compose restart
```
Restart all Compose services.

```bash
docker compose stop
```
Stop all services without deleting containers.

```bash
docker compose start
```
Start previously stopped services.

```bash
docker compose down
```
Stop and remove Compose containers and the Compose network.

```bash
docker compose up -d --no-build --force-recreate
```
Recreate containers from the current Compose file without rebuilding.

```bash
docker builder prune -af
```
Remove unused Docker build cache when builds or exports become stuck.

```bash
docker system df -v
```
Show Docker disk usage by images, containers, volumes, and build cache.

## Export And Offline Run

```bash
bash scripts/export-image.sh ai-offensive-workstation:latest ai-offensive-workstation.tar.gz
```
Export the image and offline runtime bundle.

```bash
./reuse/reuse.sh export
```
Create a private GPG-encrypted bundle containing the image, authenticated agent
state, browser sessions, secrets, and workspace. Read `reuse/reuse.md` first.

```bash
./reuse/reuse.sh import PRIVATE-BUNDLE.tar.gpg
```
Restore an encrypted authenticated-workstation bundle on another host.

```bash
gzip -dc ai-offensive-workstation.tar.gz | docker load
```
Import the exported image archive on another machine.

```bash
docker image save ai-offensive-workstation:latest | gzip > ai-offensive-workstation.tar.gz
```
Manually save the image archive if you do not use the export script.

```bash
docker run --rm --privileged --entrypoint /usr/local/bin/check-tools ai-offensive-workstation:latest /opt/security-manifest/tool-inventory.tsv /tmp/tool-manifest.tsv
```
Run the image's tool verification directly without Compose.
