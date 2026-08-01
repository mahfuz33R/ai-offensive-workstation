# 🔐 Encrypted Backup and Migration

[← Project home](../README.md) · [Beginner guide](BEGINNERS_GUIDE.md) · [Public image export](EXPORTED_IMAGE.md)

Use `scripts/reuse.sh` when you want another computer to receive both the built workstation and your private state without rebuilding everything.

> [!CAUTION]
> A reuse bundle can contain API keys, login sessions, cookies, target information, notes and reports. Treat it like an encrypted copy of your security workstation, not like a normal release archive.

## Public export versus private reuse

| Need | Tool | Includes private state? | Encrypted? |
|---|---|---:|---:|
| Give someone a clean image | `scripts/export-image.sh` | No | No |
| Move your configured workstation | `scripts/reuse.sh` | Yes | Yes |

## What the encrypted bundle contains

- the `ai-offensive-workstation:latest` Docker image;
- the complete persistent `workspace/` tree;
- Hermes configuration, memory and authentication state;
- CyberStrike sessions and state;
- The private root `.env`;
- a small portable set of Compose, shell, documentation and restore files;
- a manifest and SHA-256 checksums.

## Before exporting

Confirm:

```bash
docker --version
gpg --version
sudo docker image inspect ai-offensive-workstation:latest >/dev/null
```

Avoid editing reports or running important sessions during export. The script detects normal running services, verifies their `/root`, `/opt/data` and `/workspace` mounts, stops them for a consistent snapshot, and restarts the same services afterward.

## Interactive export

```bash
bash scripts/reuse.sh export
```

GPG asks for a passphrase. Use a long, unique passphrase that is not used anywhere else. The default output resembles:

```text
ai-offensive-workstation-reuse-20260801T120000Z.tar.gpg
```

Choose a specific destination:

```bash
bash scripts/reuse.sh export /secure/path/workstation.tar.gpg
```

The destination must not already exist.

## Unattended local export

Create a passphrase file outside the repository and away from the bundle:

```bash
chmod 600 /secure/path/reuse-passphrase
REUSE_GPG_PASSPHRASE_FILE=/secure/path/reuse-passphrase \
  bash scripts/reuse.sh export /secure/path/workstation.tar.gpg
```

Never transport the passphrase file beside the encrypted bundle.

## Verify before transport

```bash
bash scripts/reuse.sh verify /secure/path/workstation.tar.gpg
```

Verification decrypts into a private temporary directory, checks the outer package manifest and verifies SHA-256 checksums. It does not load the image or restore data.

## Import on another computer

Install Docker, GPG, gzip, SHA-256 tools and tar first. Copy the bundle and either the repository or at least `scripts/reuse.sh` to an empty destination.

Then:

```bash
bash scripts/reuse.sh import /path/workstation.tar.gpg
```

Import:

1. decrypts and verifies the package;
2. refuses to overwrite a non-empty workspace or existing `.env`;
3. restores missing runtime files;
4. restores private state without adopting archive ownership IDs;
5. applies safe local directory permissions;
6. reruns `configure-host.sh` for the new machine's UID/GID while preserving credentials;
7. loads the Docker image.

Start it afterward:

```bash
sudo docker compose up -d --no-build
bash scripts/verify-runtime.sh
```

Some provider sessions can require reauthentication if they expired, were revoked or are device-bound.

## Import when state already exists

Plain import stops rather than overwriting. If you deliberately want to replace the active state while preserving the old copy:

```bash
bash scripts/reuse.sh import /path/workstation.tar.gpg --force
```

`--force` moves existing data instead of deleting it:

Backup names follow the patterns `workspace.before-reuse-*` and
`.env.before-reuse-*`, where the wildcard is a UTC timestamp.

```text
workspace.before-reuse-<timestamp>/
.env.before-reuse-<timestamp>
```

Inspect those backups and remove them manually only after confirming the imported workstation is complete.

## Security model and limits

- GPG symmetric AES-256 protects confidentiality.
- SHA-256 checks detect corrupted package components after decryption.
- Mode `600` protects the final bundle from other local users.
- Temporary directories are mode `700` and cleanup accepts only expected path patterns.
- Import assumes the encrypted bundle comes from a trusted operator. Do not import an unknown bundle merely because someone supplies a passphrase.
- Encryption cannot protect an unlocked workstation or a compromised host.

## Recovery checklist

After import:

```bash
sudo docker compose ps
sudo docker compose exec workstation check-tools
sudo docker compose exec workstation workstation-kb verify
sudo docker compose exec workstation cyberstrike-kb verify
bash scripts/verify-runtime.sh --recreate
```

Confirm that expected reports, Hermes configuration and CyberStrike sessions exist before destroying the original machine or backups.
