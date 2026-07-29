# Encrypted reuse and migration

`scripts/reuse.sh` moves the complete workstation to another machine without a
rebuild. It packages:

- The built Docker image.
- The persistent `workspace/`, including Hermes data and memory.
- The private root `.env`.
- A small portable runtime set containing Compose, shell configuration, docs,
  and restore scripts.

The package is encrypted with GPG symmetric AES-256 encryption and protected by
SHA-256 checksums. Treat it as highly sensitive: it can contain API keys,
authentication sessions, target information, notes, and reports.

## Export

Stop changing files during export, then run:

```bash
bash scripts/reuse.sh export
```

The script verifies that any existing workstation container uses the expected
project bind mounts, temporarily stops running services, saves the image,
archives private state, restarts the prior services, and prompts for a GPG
passphrase.

Choose a specific output path if needed:

```bash
bash scripts/reuse.sh export /secure/path/workstation.tar.gpg
```

For unattended local testing, point to a mode-`600` passphrase file:

```bash
REUSE_GPG_PASSPHRASE_FILE=/secure/path/passphrase \
  bash scripts/reuse.sh export workstation.tar.gpg
```

Never place the passphrase file beside the bundle when transporting it.

## Verify

Verification decrypts into a private temporary directory and checks the package
manifest without loading the image or restoring state:

```bash
bash scripts/reuse.sh verify workstation.tar.gpg
```

## Import

Copy the bundle and this project (or at minimum `scripts/reuse.sh`) into an empty
destination, then run:

```bash
bash scripts/reuse.sh import workstation.tar.gpg
```

Import verifies checksums, restores missing runtime files, restores the private
state with safe local ownership, updates machine-specific paths and UID/GID in
`.env`, and loads the Docker image.

Start it without rebuilding:

```bash
sudo docker compose up -d --no-build
```

Import refuses to overwrite an existing nonempty workspace or `.env`. To retain
both as timestamped backups before restore:

```bash
bash scripts/reuse.sh import workstation.tar.gpg --force
```

The backups are named `workspace.before-reuse-*` and
`.env.before-reuse-*`; both are ignored by Git and Docker. Remove them only
after independently confirming the restored workstation.

## What may still require login

Expired, revoked, device-bound, or provider-invalidated sessions may require
reauthentication after migration. The bundle preserves the local data but
cannot override an external provider’s authentication policy.
