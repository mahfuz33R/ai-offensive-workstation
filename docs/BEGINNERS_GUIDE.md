# 🌱 Beginner Guide: From Zero to a Working AI Security Lab

[← Project home](../README.md) · [Command cookbook](COMMANDS.md) · [How it works](HOW_IT_WORKS.md) · [Troubleshooting](#troubleshooting)

> This chapter assumes you know how to open a terminal and type a command. Everything else is explained as it appears.

## 1. The five ideas you need

### Computer, host and server

The **host** is the real computer running Docker. It can be your laptop or a remote server. If it is remote, your **local computer** connects to it using SSH.

### Container and image

An **image** is a read-only template containing Kali, Hermes and the tools. A **container** is a running copy of that image.

Think of an image as a game installer and a container as the running game. Deleting the running game should not delete your saved progress; that is why this project stores important data in `workspace/` on the host.

### Port

A **port** is a numbered door used by network programs. This project uses:

| Port | Door for | How to use it |
|---:|---|---|
| `9119` | Hermes dashboard | Web browser |
| `8642` | Hermes OpenAI-compatible API | `curl`, Postman or an SDK with a bearer key |
| `4096` | CyberStrike API | Internal only; Hermes reaches it through MCP |

### AI agent

A chatbot usually returns text. An **AI agent** can also choose tools, read files, run commands and continue through multiple steps. Hermes is the agent framework in this project.

The model provides reasoning; Hermes provides the body around it: tools, memory, sessions, skills, API access and orchestration.

### RAG

Models do not automatically know your private documents or the exact help text installed in this image. **Retrieval-Augmented Generation (RAG)** searches a local library and attaches relevant passages to the question before the model answers.

RAG is an open-book exam, not brain surgery: it gives the model useful pages at answer time; it does not retrain or modify the model.

## 2. What happens when you run the project?

![System overview](assets/system-overview.svg)

1. Docker starts the `workstation` container.
2. A startup script checks the user ID and prepares writable folders.
3. The bundled Hermes skill and RAG databases are synchronized into persistent `/opt/data`.
4. Hermes starts its gateway on port `8642`.
5. A dashboard service becomes available on port `9119`.
6. CyberStrike starts internally on port `4096`.
7. You use the dashboard, an API client or a shell to work with Hermes.

## 3. Install Docker without guessing

Use Docker's installation instructions for your operating system. After installation, these commands must succeed:

```bash
docker --version
docker compose version
docker info
```

If `docker info` says permission denied, use `sudo docker ...` or configure your operating system's Docker group. Adding yourself to the Docker group effectively grants administrative control of the computer; understand that before doing it.

## 4. Download and configure the workstation

```bash
git clone https://github.com/mahfuz33R/ai-offensive-workstation.git
cd ai-offensive-workstation
bash scripts/configure-host.sh
chmod 600 .env
```

The last command makes `.env` readable only by its owner. This matters because `.env` can contain API keys.

### What belongs in `.env`?

Configuration uses `NAME=value` lines:

```dotenv
HERMES_DASHBOARD_PORT=9119
API_SERVER_KEY=a-long-random-secret
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
```

Leave provider keys empty if you do not use them. Never add spaces around `=` and never commit `.env` to Git.

Run this after editing it:

```bash
chmod 600 .env
```

## 5. Understand the build

Start with the cheap checks:

```bash
bash scripts/preflight.sh
```

Then build:

```bash
bash scripts/build-and-verify.sh
```

The build has many stages because different tools come from different ecosystems. It installs Kali packages first, then language runtimes, source tools, assets, browsers, CyberStrike, Hermes and knowledge indexes.

Green download progress does not always mean the full stage succeeded. The project launches both browsers and checks every required inventory entry after downloading them.

Useful variants:

```bash
# Reuse successful layers after an interrupted build
bash scripts/build-and-verify.sh --cached

# Verify an already built image without rebuilding
bash scripts/build-and-verify.sh --verify-only
```

## 6. Start, inspect and stop

```bash
sudo docker compose up -d --no-build
sudo docker compose ps
```

`-d` means “detached”: services continue in the background. `--no-build` means “use the image I already verified.”

View logs:

```bash
sudo docker compose logs --tail=100 workstation
sudo docker compose logs --tail=100 dashboard
sudo docker compose logs --tail=100 cyberstrike-api
```

Enter the normal Hermes shell:

```bash
sudo docker compose exec workstation zsh
```

Enter a root shell only when necessary:

```bash
sudo docker compose exec workstation root zsh
```

Stop services:

```bash
sudo docker compose down
```

`down` removes containers and their temporary network. It does not delete the host `workspace/` bind mounts.

## 7. Open the dashboard

On the Docker host, browse to:

```text
http://127.0.0.1:9119
```

For a remote server, run this on your local computer:

```bash
ssh -N \
  -L 9119:127.0.0.1:9119 \
  -L 8642:127.0.0.1:8642 \
  USER@SERVER_IP
```

Leave the SSH process running, then open `http://127.0.0.1:9119` locally.

> [!NOTE]
> SSH moves bytes between the two computers. It does not add an API key. Browsing to port `8642` directly will therefore show an authentication error.

## 8. Give Hermes an AI model

Hermes can perform local knowledge searches and health checks without a model
provider. To generate AI responses, it needs permission to call a model provider.

### Step 1: choose one provider

You need an account and API key from at least one provider supported by your
Hermes version. Open `.env`:

```bash
nano .env
```

Put the key after the matching name. This example uses OpenAI:

```dotenv
OPENAI_API_KEY=your-real-provider-key
```

Leave providers you do not use empty. A valid line has no spaces around `=` and
no quotation marks. Save the file, then restrict its permissions:

```bash
chmod 600 .env
```

### Step 2: run the interactive Hermes setup

The workstation image must already exist. If you have not built it, complete
[the build step](#5-understand-the-build) first. Then run:

```bash
sudo docker compose --profile setup run --rm setup
```

This creates a temporary setup container, asks Hermes's current setup questions,
and removes that temporary container when finished. Choose the provider that
matches the key in `.env`, then choose an available model. Setup preferences are
stored in the persistent `workspace/container-opt/data/` directory, not in the
temporary container.

The prompts and provider list can change when `HERMES_VERSION=latest` downloads a
new Hermes release. Follow the displayed provider names instead of expecting the
screen to look exactly like an older tutorial.

### Step 3: start or recreate the services

If the workstation is not running yet:

```bash
sudo docker compose up -d --no-build
```

If it was already running when you changed `.env`, recreate it so Docker injects
the new values:

```bash
sudo docker compose up -d --no-build --force-recreate
```

### Step 4: verify the configuration

```bash
sudo docker compose ps
sudo docker compose exec workstation hermes version
sudo docker compose exec workstation env COLUMNS=240 hermes skills list
sudo docker compose exec workstation hermes mcp test cyberstrike
sudo docker compose exec workstation workstation-kb verify
sudo docker compose exec workstation cyberstrike-kb verify
```

If Hermes lists the bundled skill, the CyberStrike MCP test succeeds and both
knowledge databases verify, the project integration is ready. Open
`http://127.0.0.1:9119` and send a small, harmless prompt such as “Explain what
RAG means without running any tools.” A provider authentication error at that
point normally means the provider key is missing, mistyped, expired or not
enabled for the selected model.

To change the model or provider later, edit `.env` if the provider key changes,
rerun the setup command, and recreate the services.

Do not confuse these secrets:

- a **provider key** lets Hermes call a model company;
- `API_SERVER_KEY` lets your API client call Hermes;
- `CYBERSTRIKE_SERVER_PASSWORD` is an optional internal CyberStrike server credential.

They are not interchangeable.

## 9. Learn the local knowledge system

Inside the workstation:

```bash
workstation-kb status
workstation-kb search "what is passive subdomain discovery?" --limit 5
cyberstrike-kb search "how are CyberStrike sessions stored?" --limit 5
```

`workstation-kb` searches the complete ethical-hacking library. `cyberstrike-kb` searches a smaller focused corpus and is more precise for CyberStrike questions.

Each result includes:

- source file and line range;
- heading;
- authority label;
- fused relevance score;
- the retrieved passage.

Read the source, not only the score. A relevant passage can still be outdated or inappropriate for your engagement.

## 10. Organize an authorized engagement

Create a predictable evidence tree:

```bash
export ENGAGEMENT=owned-training-lab
export OUTPUT_DIR="/workspace/reports/$ENGAGEMENT"
mkdir -p "$OUTPUT_DIR"/{raw,normalized,evidence,final}
```

Use these stages:

1. **Scope:** write down exact domains, IPs, accounts, time window and prohibited actions.
2. **Passive discovery:** collect existing public or local information.
3. **Low-rate validation:** make a small number of controlled requests.
4. **Manual verification:** reproduce candidates safely.
5. **Evidence:** save commands, timestamps, raw output and redacted proof.
6. **Report:** describe impact, reproduction and remediation without exposing secrets.

## 11. Ask Hermes well

Weak prompt:

```text
Hack this website completely.
```

Useful prompt:

```text
I own https://training.example.test and authorize testing only for this host
between 09:00 and 11:00 UTC. Begin with passive and low-rate HTTP discovery,
maximum 2 requests per second. Do not brute-force, exploit, modify data, create
persistence, contact third parties, or perform denial of service. Explain each
command first and save raw output under /workspace/reports/owned-training-lab.
Stop if sensitive data or instability appears.
```

The second prompt gives the agent boundaries it can actually follow.

## 12. Malware-analysis profile

The optional profile has no network, a read-only root filesystem, no injected `.env`, no added capabilities and Docker-managed volumes:

```bash
sudo docker compose --profile malware run --rm malware-lab
```

This reduces risk but does not make unknown malware safe. Use a disposable host or virtual machine for serious malware research.

## Troubleshooting

### Dashboard does not open

```bash
sudo docker compose ps
curl -I http://127.0.0.1:9119
sudo docker compose logs --tail=150 dashboard workstation
```

For a remote server, make sure the SSH tunnel is still running on the local computer.

### API says `Invalid gateway API key`

The API is reachable but the bearer header is absent or wrong. Browser address bars do not add this header. See [the API-key walkthrough](HERMES_RAG_API.md#part-9-testing-the-hermes-api).

### `.env` changed but containers use old values

```bash
sudo docker compose up -d --no-build --force-recreate
```

### A build stopped during a download or browser test

```bash
bash scripts/build-and-verify.sh --cached
```

Read the first installer error above Docker's final `failed to solve` line.

### A command is missing

Inside the container:

```bash
command -v COMMAND
check-tools
check-knowledge
```

### Where next?

- [How the complete lifecycle works](HOW_IT_WORKS.md)
- [Architecture and trust boundaries](ARCHITECTURE.md)
- [Hermes, RAG and API deep dive](HERMES_RAG_API.md)
- [Command cookbook](COMMANDS.md)
