# How Someone Else Runs The Exported Image

These steps are for a second computer or offline server that receives the
exported Docker image and the small runtime files needed to start it.

The rebuilt image already contains the workstation knowledge base and assets.
The receiving server does not need Internet access to install tools.

## What Is Inside The Image

The exported image includes:

```text
/opt/hermes
/opt/hermes/skills/cybersecurity/offensive-workstation/SKILL.md
/opt/hermes/skills/cybersecurity/offensive-workstation/references/
/opt/security-tools
/opt/security-assets
/opt/security-assets/payloads/PayloadsAllTheThings
/opt/security-assets/payloads/payload-box
/opt/toolchains
/opt/security-manifest
/opt/oh-my-zsh
/etc/zsh/portable.zshrc
/usr/local/bin/check-tools
/usr/local/bin/check-knowledge
/usr/local/bin/configure-security-secrets
/usr/local/bin/save-payload-note
```

This means Hermes can load the bundled offensive-workstation skill, tool guides,
workflow references, cleaned PDF-derived guides, and payload library references
directly from the image.

## What Is Not Inside The Image

These are intentionally not included:

```text
secrets.env
.env
workspace/container-opt/data
workspace/container-root
workspace
```

Those paths can contain private API keys, Hermes provider configuration,
sessions, memories, runtime skills, root shell history, tool configuration,
client data, reports, and target data. They must be created or mounted on the
receiving server.

## Files To Give Them

Give these files:

```text
ai-offensive-workstation.tar.gz
README.md
command.md
run_exported_image.md
docker-compose.yml
.env.example
secrets.env.example
```

If you use `scripts/export-image.sh`, it also creates an offline bundle named
like this by default:

```text
ai-offensive-workstation-offline-bundle.tar.gz
```

That bundle contains the image archive plus the README, `command.md`, this run
guide, `docker-compose.yml`, `.env.example`, and `secrets.env.example`.

Do not give them:

```text
secrets.env
.env
workspace/container-opt/data
workspace/container-root
workspace
```

Those files can contain private API keys, Hermes sessions, memories, reports, or
target data.

## Export On The Internet-Connected Machine

Build and verify the image first:

```bash
sudo bash scripts/build-and-verify.sh --cached
```

Export the image and offline bundle:

```bash
bash scripts/export-image.sh ai-offensive-workstation:latest ai-offensive-workstation.tar.gz
```

The script creates:

```text
ai-offensive-workstation.tar.gz
ai-offensive-workstation-offline-files/
ai-offensive-workstation-offline-bundle.tar.gz
```

For a no-Internet server, copy either:

```text
ai-offensive-workstation-offline-bundle.tar.gz
```

or copy the files inside `ai-offensive-workstation-offline-files/`.

## Unpack The Offline Bundle

On the offline server:

```bash
tar -xzf ai-offensive-workstation-offline-bundle.tar.gz
```

## Import The Image

On the other computer:

```bash
gzip -dc ai-offensive-workstation.tar.gz | sudo docker load
```

Confirm the image exists:

```bash
sudo docker image ls ai-offensive-workstation
```

## Run With Only The Image Archive

If the offline server receives only `ai-offensive-workstation.tar.gz` and not
the Compose files, it can still run the image manually:

```bash
mkdir -p workspace/container-root workspace/container-opt/data

sudo docker run -d \
  --name ai-offensive-workstation \
  --privileged \
  --shm-size 1g \
  -p 127.0.0.1:8642:8642 \
  -v "$PWD/workspace/container-opt/data:/opt/data" \
  -v "$PWD/workspace/container-root:/root" \
  -v "$PWD/workspace:/workspace" \
  ai-offensive-workstation:latest \
  gateway run
```

Start the dashboard as a second container:

```bash
sudo docker run -d \
  --name ai-offensive-workstation-dashboard \
  --privileged \
  --shm-size 1g \
  --network host \
  -v "$PWD/workspace/container-opt/data:/opt/data" \
  -v "$PWD/workspace/container-root:/root" \
  -v "$PWD/workspace:/workspace" \
  ai-offensive-workstation:latest \
  dashboard --host 127.0.0.1 --port 9119 --no-open --insecure
```

Open Hermes:

```bash
sudo docker exec --user hermes -it ai-offensive-workstation hermes
```

Run setup manually if Hermes has not been configured yet:

```bash
sudo docker run --rm -it \
  --privileged \
  --shm-size 1g \
  -v "$PWD/workspace/container-opt/data:/opt/data" \
  -v "$PWD/workspace/container-root:/root" \
  -v "$PWD/workspace:/workspace" \
  ai-offensive-workstation:latest \
  setup
```

## Prepare Local Folders

Create persistent folders:

```bash
mkdir -p workspace/container-root workspace/container-opt/data
```

Create local environment files:

```bash
cp .env.example .env
cp secrets.env.example secrets.env
chmod 600 .env secrets.env
```

Edit `.env` so it points to that user's own home directory and UID/GID. The
normal values are:

```env
HERMES_DATA_DIR=/home/their-username/ai-offensive-workstation/workspace/container-opt/data
WORKSTATION_ROOT_DIR=/home/their-username/ai-offensive-workstation/workspace/container-root
HERMES_UID=1000
HERMES_GID=1000
```

These paths configure only Docker Hermes. A host-installed Hermes continues to
use `$HOME/.hermes`; the Docker setup never imports or modifies it.

They can get UID/GID with:

```bash
id -u
id -g
```

`secrets.env` is optional. It is only for security-tool API keys such as Shodan,
Censys, VirusTotal, GitHub, or Interactsh.

## Configure Hermes

Run the setup wizard:

```bash
sudo docker compose run --rm setup
```

This writes Hermes configuration to:

```text
workspace/container-opt/data
```

## Start The Workstation

Start the already-imported image without rebuilding:

```bash
sudo docker compose up -d --no-build
```

Check status:

```bash
sudo docker compose ps
```

Open a Hermes terminal session:

```bash
sudo docker compose exec --user hermes workstation hermes
```

## Verify The Imported Image

Run the required tool check:

```bash
sudo docker compose exec --user hermes workstation check-tools
```

Run the skill knowledge check:

```bash
sudo docker compose exec --user hermes workstation check-knowledge --require-help
```

For a stricter image-only check with an empty workspace mount:

```bash
tmp_workspace="$(mktemp -d)"
sudo docker run --rm --privileged \
  --user hermes \
  --volume "$tmp_workspace:/workspace" \
  --entrypoint /usr/local/bin/check-tools \
  ai-offensive-workstation:latest \
  /opt/security-manifest/tool-inventory.tsv \
  /tmp/tool-manifest.tsv
rm -rf "$tmp_workspace"
```

Success looks like:

```text
Verification passed: 191 required entries found.
```

## Dashboard

With the Compose files, the dashboard runs as its own service:

```bash
sudo docker compose up -d --no-build
sudo docker compose ps
```

The dashboard service uses host networking, so its `PORTS` column may be blank
in `docker compose ps`. That is normal. Confirm readiness with:

```bash
sudo docker compose logs --tail=80 dashboard
```

Look for:

```text
HERMES_DASHBOARD_READY port=9119
Hermes Web UI -> http://127.0.0.1:9119
```

Open it on the Docker host:

```text
http://127.0.0.1:9119
```

If Docker is running on a remote server that you access through SSH, forward the
remote dashboard port to your local computer:

```bash
ssh -L 9119:127.0.0.1:9119 username@server-ip
```

Keep the SSH session open, then open this on your local computer:

```text
http://127.0.0.1:9119
```

If local port `9119` is already busy:

```bash
ssh -L 9120:127.0.0.1:9119 username@server-ip
```

Then open:

```text
http://127.0.0.1:9120
```

## Root Access

Open a root shell:

```bash
sudo docker compose exec --user root workstation zsh
```

This is the image's default customized Zsh and Oh My Zsh shell. Use
`--user hermes` instead when you want the gateway's non-root identity.

Run one root command:

```bash
sudo docker compose exec --user root workstation apt-get update
```
