# 📦 Public and Offline Image Export

[← Project home](../README.md) · [Encrypted private migration](REUSE.md) · [Beginner guide](BEGINNERS_GUIDE.md)

Use this workflow to move or publish a **clean built image** without your `.env`, Hermes memory, authentication sessions, targets or reports.

## What gets created?

```bash
bash scripts/export-image.sh \
  ai-offensive-workstation:latest \
  ai-offensive-workstation.tar.gz
```

The script creates:

1. a compressed Docker image archive;
2. an offline companion bundle containing Compose, `.env.example`, `.zshrc`, selected documentation and setup/reuse scripts.

The export is not encrypted because it should contain no private runtime state. Still review distribution and third-party license obligations before sharing it.

## Install on the destination computer

```bash
tar -xzf ai-offensive-workstation-offline-bundle.tar.gz
gzip -dc ai-offensive-workstation.tar.gz | sudo docker load
cd ai-offensive-workstation-offline-files
bash scripts/configure-host.sh
chmod 600 .env
nano .env
sudo docker compose up -d --no-build
```

Open `http://127.0.0.1:9119` locally or create the SSH tunnel documented in the [beginner guide](BEGINNERS_GUIDE.md#7-open-the-dashboard).

## Verify the exported archive

Create a checksum before transport:

```bash
sha256sum ai-offensive-workstation.tar.gz \
  ai-offensive-workstation-offline-bundle.tar.gz \
  > SHA256SUMS
```

On the destination:

```bash
sha256sum -c SHA256SUMS
```

## What this does not include

- `.env` or API/provider keys;
- `workspace/` projects and reports;
- Hermes persistent config, memory or auth;
- CyberStrike sessions;
- container root-home state.

If you need those, use the encrypted [reuse workflow](REUSE.md).
