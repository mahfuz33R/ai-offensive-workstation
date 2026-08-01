# ⚖️ Third-Party Software and Licenses

[← Project home](../README.md) · [Architecture](ARCHITECTURE.md) · [Public export](EXPORTED_IMAGE.md)

This repository builds and may redistribute many independent open-source projects. The project license does not replace the license, copyright, trademark or usage terms of any dependency.

## Bundled source snapshots

### PayloadsAllTheThings

- Upstream: <https://github.com/swisskyrepo/PayloadsAllTheThings>
- Repository path: `knowledge/payloads/PayloadsAllTheThings/`
- Bundled license: `knowledge/payloads/PayloadsAllTheThings/LICENSE`

### payload-box collections

- Upstream organization: <https://github.com/payload-box>
- Repository path: `knowledge/payloads/payload-box/`
- Individual collection license and notice files remain in their directories.

## Downloaded during the build

Major downloads include:

- Kali packages;
- Hermes Agent and CyberStrike;
- Go, Rust, Node.js/npm and Python packages;
- Playwright browser engines;
- SecLists and other wordlists;
- official/community Nuclei templates;
- ProjectDiscovery fuzzing templates;
- Jaeles signatures, GF patterns and Kiterunner routes;
- many independent security utilities.

Exact source URLs and resolved revisions/versions are recorded inside a built image at:

```text
/opt/security-manifest/resolved-versions.txt
```

Kali package metadata remains available through `dpkg`/APT, Python through package metadata, npm through lock/package files, and source checkouts through their retained Git metadata where applicable.

## Before redistributing an image

1. Review `/opt/security-manifest/resolved-versions.txt`.
2. Inspect upstream licenses for every included project relevant to your distribution.
3. Preserve required notices and source offers.
4. Check whether trademarks or service terms restrict presentation or use.
5. Do not distribute private `.env`, workspaces, sessions or target data.
6. Remember that some security tools can have legal restrictions independent of software licensing in your jurisdiction.

The [public image export](EXPORTED_IMAGE.md) omits private state but does not automatically solve third-party license compliance.
