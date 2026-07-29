# Exported image

Use `scripts/export-image.sh` when you need a public/offline image package that
does not include private workspace state or `.env`.

```bash
bash scripts/export-image.sh \
  ai-offensive-workstation:latest \
  ai-offensive-workstation.tar.gz
```

The script produces the compressed Docker image and an offline bundle containing
the image, Compose file, `.env.example`, `.zshrc`, selected operator docs, and
setup/reuse scripts.

On the destination:

```bash
tar -xzf ai-offensive-workstation-offline-bundle.tar.gz
gzip -dc ai-offensive-workstation.tar.gz | sudo docker load
bash scripts/configure-host.sh
$EDITOR .env
sudo docker compose up -d --no-build
```

For a private migration that includes Hermes configuration, authentication,
memory, reports, and credentials, use [REUSE.md](REUSE.md) instead. That flow is
encrypted; the public image export is not.
