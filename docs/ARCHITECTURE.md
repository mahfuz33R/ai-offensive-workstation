# Architecture and project map

This is the maintained project graph used to keep build inputs, runtime state,
Hermes knowledge, and private configuration logically connected.

```mermaid
flowchart TD
    ENV[".env<br/>private settings + credentials"] --> COMPOSE[docker-compose.yml]
    DOCKERFILE[Dockerfile] --> IMAGE[Kali workstation image]
    INSTALLERS[scripts/install-*.sh] --> IMAGE
    MANIFEST[scripts/manifests/tool-inventory.tsv] --> IMAGE
    PAYLOADS[knowledge/payloads] --> IMAGE
    SKILLS["knowledge/skills<br/>SKILL + AGENTS + RAG"] --> IMAGE

    COMPOSE --> WORKSTATION[workstation gateway]
    COMPOSE --> DASHBOARD[dashboard]
    COMPOSE --> CYBERAPI["cyberstrike-api<br/>loopback only"]
    COMPOSE --> SETUP[setup profile]
    IMAGE --> WORKSTATION
    IMAGE --> DASHBOARD
    IMAGE --> CYBERAPI
    IMAGE --> SETUP

    WORKSTATION --> DATA["workspace/container-opt/data<br/>Hermes config, auth, skills, memory"]
    DASHBOARD --> DATA
    CYBERAPI --> CYBERSTATE["/opt/data/cyberstrike<br/>sessions, auth, config, state"]
    CYBERSTATE --> DATA
    SETUP --> DATA
    WORKSTATION --> ROOT[workspace/container-root]
    WORKSTATION --> SHARED["workspace/<br/>projects, targets, reports, notes"]

    IMAGE --> BUNDLED["/usr/local/share/hermes/skills"]
    BUNDLED -->|locked runtime sync| DATA
    IMAGE --> VECTOR["immutable full + CyberStrike vector indexes"]
    VECTOR -->|atomic locked sync| DATA
    DATA --> MCP["Hermes cyberstrike MCP<br/>9 stdio tools"]
    MCP -->|"HTTP 127.0.0.1:4096"| CYBERAPI

    IMAGE --> MALWARE["malware-lab<br/>no network, named volumes, no .env"]
```

## Repository tree

```text
.
├── .env                         private operator configuration, ignored
├── .env.example                 safe configuration template
├── .zshrc                       public managed shell configuration
├── Dockerfile                   immutable image build
├── docker-compose.yml           services, mounts, ports, isolation
├── README.md                    primary operator entry point
├── docs/                        architecture and operating guides
├── knowledge/
│   ├── skills/                  Hermes skill, AGENTS policy, RAG sources
│   └── payloads/                tracked payload snapshots
├── scripts/
│   ├── manifests/               authoritative inventory and exclusions
│   ├── lib/                     shared installer primitives
│   ├── install-*.sh             image installation stages
│   ├── configure-host.sh        creates/updates private .env and workspace
│   ├── build-and-verify.sh      build plus image smoke tests
│   ├── preflight.sh             source and safety checks
│   ├── reuse.sh                 encrypted migration
│   └── verify-runtime.sh        service and persistence audit
├── tests/                       offline architecture/Compose tests
└── workspace/                   ignored persistent and operator-created data
```

## Edit boundaries

Most frequently edited:

- `.env` for local paths, versions, ports, and credentials.
- `README.md` for the primary operator workflow.
- `Dockerfile` and `docker-compose.yml` for build/runtime behavior.

Occasionally edited:

- `knowledge/skills/` when changing Hermes guidance or RAG content.
- `scripts/manifests/tool-inventory.tsv` together with the installer that adds
  or removes a required tool.
- `docs/` when behavior changes.

Generated, persistent, or normally untouched:

- `workspace/`.
- Vendored payload material under `knowledge/payloads/`.
- Installer internals under `scripts/lib/`.

## Invariants

- No secret is committed or copied into the image.
- The image build fails if a required tool or asset is absent.
- Skill, RAG, and AGENTS material always reaches persistent Hermes `/opt/data`.
- Hermes MCP configuration and CyberStrike sessions both survive recreation.
- Normal services share intended persistence; malware analysis does not.
- Published service ports remain host-local.
