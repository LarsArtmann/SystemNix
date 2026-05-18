# Forgejo Federation

ActivityPub-based federation for self-hosted software forges — "Mastodon for code."

## Protocols

| Protocol | Role |
|----------|------|
| **ActivityPub** | Transport layer (same as Mastodon, PeerTube) |
| **ForgeFed** | W3C extension defining forge-specific activities (issues, PRs, repos, patches) |
| **WebFinger** | Actor discovery (`@user@forge.example.com`) |
| **F3** | Friendly Forge Format — data portability between incompatible forges |

## Current Status (May 2025)

Active development, funded by Codeberg e.V. Early features shipping, core collaboration not yet available.

### What Works

- **Federated stars** — star a repo on another Forgejo instance
- **WebFinger + NodeInfo** — actor discovery endpoints
- **HTTP Signatures** — authenticated federation requests
- **E2E test framework** — two-instance federation test suite
- **Cross-platform following** — Forgejo ↔ GoToSocial user following (in progress)

### Not Yet Available

- Cross-instance issues / PRs
- Federated notifications
- Following repos across instances
- Instance blocking / moderation tools
- Full federation UI

## Roadmap (2025)

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Federated stars | Done |
| 2 | Federated unstars | In progress |
| 3 | Follow users across instances | In progress |
| 4 | Open issues on remote repos | Planned |
| 5 | Federated PRs / patches | Planned |
| 6 | Instance blocking & moderation | Planned |
| 7 | F3 data portability | Planned |

## Architecture

```
Forgejo A                    Forgejo B
┌──────────────┐             ┌──────────────┐
│ WebFinger    │◄───────────►│ WebFinger    │
│ Actor/Inbox  │  ActivityPub│ Actor/Inbox  │
│ HTTP Sigs    │────────────►│ HTTP Sigs    │
│ ForgeFed     │             │ ForgeFed     │
└──────────────┘             └──────────────┘
```

Each Forgejo instance is an ActivityPub **actor** with a keypair. Outbound activities are signed with HTTP Signatures and POSTed to the remote inbox. ForgeFed extends the ActivityStreams vocabulary with types like `Repository`, `Ticket`, `Patch`, and `Push`.

## Why It Matters

- **No walled gardens** — repos, issues, and reviews federate across independent instances
- **No vendor lock-in** — F3 enables migration between Gitea, GitLab, GitHub, Forgejo
- **Decentralized collaboration** — contribute to a repo without an account on that instance
- **Community governance** — no single corporation controls the network

## Migration from Gitea

Forgejo is API-compatible with Gitea. On NixOS, switch `services.gitea` → `services.forgejo` in your configuration. Data directories and databases are compatible.

## References

- [Forgejo](https://forgejo.org/)
- [ForgeFed Spec](https://forgefed.org/)
- [Forgejo vs Gitea](https://forgejo.org/compare-to-gitea/)
- [Federation Tracking Issue](https://codeberg.org/forgejo/forgejo/issues/59)
- [FOSDEM 2025 Talk](https://archive.fosdem.org/2025/schedule/event/fosdem-2025-5610-show-and-tell-federation-at-forgejo/)
