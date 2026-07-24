# Reuse an Authenticated AI Offensive Workstation

`reuse.sh` creates an encrypted migration bundle containing both the Docker
image and the private host-mounted state needed to reproduce the workstation on
another computer.

## What the encrypted bundle contains

- `ai-offensive-workstation:latest`
- Docker Hermes configuration, authentication, sessions, memories, and skills
  from `workspace/container-opt/data`
- Root-owned agent state, including Claude and browser profiles, from
  `workspace/container-root`
- The complete `workspace`
- `secrets.env`, when present
- Compose and offline runtime documentation

The bundle contains API keys, cookies, login sessions, browser state, shell
history, client data, and possibly security-assessment evidence. Anyone with
the bundle and its passphrase should be treated as having access to those
accounts and files.

## Requirements

Both computers need:

- Docker Engine and Docker Compose
- GnuPG (`gpg`)
- `gzip`, `tar`, and `sha256sum`
- Enough free disk space for the image, temporary plaintext archives, and the
  final encrypted bundle

Run `reuse.sh` as your normal host user. It invokes `sudo docker` only when the
current user cannot access Docker directly.

## Export from the original computer

Run from the project directory:

```bash
chmod +x reuse.sh
./reuse.sh export
```

Or choose the output name:

```bash
./reuse.sh export my-private-workstation.tar.gpg
```

The script:

1. Confirms `/root`, `/opt/data`, and `/workspace` use the expected persistent
   host mounts.
2. Detects running Compose services.
3. Stops them briefly so databases and session files are consistent.
4. Saves the Docker image.
5. Archives the persistent workspace and optional `secrets.env`; root-owned
   files are read through a short-lived Docker container without weakening
   their permissions.
6. Restarts the services that were previously running.
7. Creates checksums and encrypts the complete package with GPG AES-256.

If an older container does not yet have the persistent `/root` mount, preserve
it first and recreate the container:

```bash
bash scripts/migrate-container-root.sh
sudo docker compose up -d --no-build --force-recreate
```

GPG asks for the encryption passphrase interactively. Use a strong, unique
passphrase and store it separately from the bundle.

Copy these three files to the destination:

```text
my-private-workstation.tar.gpg
reuse.sh
reuse.md
```

Do not send the passphrase through the same channel used for the bundle.

## Verify without importing

```bash
./reuse.sh verify my-private-workstation.tar.gpg
```

This decrypts into a permission-restricted temporary directory under the
project, verifies every archive checksum, prints the manifest, and changes no
Docker or persistent workstation state. The plaintext temporary directory is
removed automatically.

## Import on the destination computer

Create or enter the destination project directory, place the three transferred
files there, then run:

```bash
chmod +x reuse.sh
./reuse.sh import my-private-workstation.tar.gpg
```

The script restores the private state, loads the image, and writes a new `.env`
using the destination project path and the destination user's UID/GID. It does
not copy the source computer's machine-specific `.env`.

If the destination already contains workspace files or `secrets.env`, import
stops without changing them. To preserve the existing state under timestamped
backup names and then restore the bundle:

```bash
./reuse.sh import my-private-workstation.tar.gpg --force
```

Start the restored workstation:

```bash
sudo docker compose up -d --no-build
sudo docker compose exec --user root workstation zsh
```

Verify it:

```bash
sudo docker compose exec --user hermes workstation check-tools
sudo docker compose exec --user hermes workstation check-knowledge --require-help
```

## Authentication limitations

Restoring the files reproduces the stored authentication state, but it cannot
guarantee every provider will accept it. Reauthentication can still be required
when:

- a token or cookie expired;
- a session was revoked;
- the provider binds sessions to a device, hostname, IP address, OS keyring, or
  hardware-backed credential;
- the destination architecture is incompatible with the exported image;
- the account provider prohibits session transfer.

If authentication fails, reauthenticate only that tool on the destination. Its
new state will remain in the restored persistent folders.

## Security and cleanup

- Never create an unencrypted reusable bundle.
- Never share a bundle with another person using your account sessions.
- Keep the bundle mode at `600`.
- Delete the bundle from temporary transfer media after verifying the
  destination.
- Keep timestamped `workspace.before-reuse-*` and
  `secrets.env.before-reuse-*` backups private; remove them manually only after
  confirming the import.
- If the bundle or passphrase is exposed, revoke affected sessions and rotate
  API keys immediately.
