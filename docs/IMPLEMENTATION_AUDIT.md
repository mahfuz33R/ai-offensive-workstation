# Implementation audit

Current source-level status:

| Requirement | Implementation |
|---|---|
| Direct stable Kali base | `kalilinux/kali-last-release` plus `kali-linux-headless` |
| Hermes on Kali | Direct stable-release install under `/usr/local/lib/hermes-agent` |
| Persistent skill/RAG/memory | Locked entrypoint sync into bind-mounted `/opt/data/skills` |
| Single private configuration | Ignored, mode-`600` root `.env` |
| Secret-free shell | Tracked root `.zshrc`; Compose performs credential injection |
| Latest Node/npm | Official checksummed Node resolver plus npm stable dist-tag |
| Chromium and Firefox | Kali packages plus Playwright engines and headless smoke tests |
| Tools and assets | Strict manifest gate plus substantive asset integrity checks |
| Network isolation | Bridge/NAT, host-local ports, no host namespace |
| Malware isolation | No network, no `.env`, named volumes, read-only filesystem |
| Portable private reuse | Encrypted GPG image/workspace/config bundle with checksums |
| Clean repository layout | Root operator files; internals grouped in docs/knowledge/scripts/tests |

Run the offline audit:

```bash
bash scripts/preflight.sh
```

Run the complete build and image audit:

```bash
bash scripts/build-and-verify.sh
```

Run persistence and service checks against an existing image:

```bash
bash scripts/verify-runtime.sh --recreate
```

An offline source audit cannot prove that upstream downloads will remain
available. The Docker build is the authoritative installation test because it
performs the downloads, validates installed artifacts, and launches both
browser engines.
