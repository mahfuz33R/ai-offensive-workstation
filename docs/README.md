# 📚 AI Offensive Workstation Documentation

[← Main project page](../README.md)

Welcome. You can read these chapters in order or jump directly to your current task.

![System overview](assets/system-overview.svg)

## Recommended reading order

| Step | Chapter | You will learn |
|---:|---|---|
| 1 | [Beginner guide](BEGINNERS_GUIDE.md) | Docker, ports, agents, RAG, installation and first use |
| 2 | [How it works](HOW_IT_WORKS.md) | What happens during build, startup and each request |
| 3 | [Architecture](ARCHITECTURE.md) | Services, networks, persistence, identity and trust boundaries |
| 4 | [Hermes, APIs and RAG](HERMES_RAG_API.md) | Model orchestration, keys, vector search and custom knowledge |
| 5 | [Command cookbook](COMMANDS.md) | Copy-paste operational commands and quick diagnosis |

## Operations and maintenance

- [Encrypted backup and migration](REUSE.md)
- [Clean public/offline image export](EXPORTED_IMAGE.md)
- [Implementation and verification](IMPLEMENTATION_AUDIT.md)
- [Third-party software and licenses](THIRD_PARTY_NOTICES.md)

## Find an answer quickly

| Question | Answer |
|---|---|
| Which browser URL do I open? | `http://127.0.0.1:9119` — see [dashboard access](BEGINNERS_GUIDE.md#7-open-the-dashboard) |
| Why does port 8656 reject my browser? | It is an authenticated API — see [browser 401 explanation](HERMES_RAG_API.md#why-the-browser-address-bar-returns-401) |
| How do I reach a remote server? | Use an SSH tunnel — see [remote access](HERMES_RAG_API.md#remote-access-through-ssh) |
| Which key does what? | See [four kinds of secrets](HERMES_RAG_API.md#part-8-four-kinds-of-secrets) |
| How do I add my documents? | See [custom knowledge](HERMES_RAG_API.md#part-6-adding-your-own-knowledge-correctly) |
| How do I recover an interrupted build? | Use `bash scripts/build-and-verify.sh --cached` |
| Where should reports go? | `/workspace/reports/<engagement>/` |

> [!IMPORTANT]
> This documentation explains technical capability. Only explicit written authorization defines what you are allowed to test.
