# docs/agents/ — Agent Knowledge Library

Domain reference files split out of the root `AGENTS.md` on 2026-10-01
(the file had grown to ~600KB; the root file is now the need-to-know core
plus a routing table). Content was migrated **verbatim** (one duplicated
Gatus paragraph inside "Adding a Service" step 9 was collapsed; no other
edits).

**How to use:** the root `AGENTS.md` routing table sends you here by topic.
Service-specific deep context lives in `docs/services/<service>.md` (each
service has a runbook; sections migrated from AGENTS.md are marked
"Agent Notes (migrated from AGENTS.md 2026-10-01)").

## Files

| File                      | Scope                                                                     |
| ------------------------- | ------------------------------------------------------------------------- |
| `nix-flakes.md`           | Flake updates, lock/pin policy, Nix & nixpkgs gotchas, packaging notes    |
| `go-ecosystem.md`         | LarsArtmann Go repos, GOPRIVATE, go floors, vendorHash, CI deploy keys    |
| `integration-registry.md` | Adding a Service checklist, gate helpers, consuming upstream modules      |
| `systemd.md`              | Unit gotchas, activation/deploy semantics, BFQ tiers, boot mirror, Docker |
| `storage.md`              | BTRFS, snapshot pinning, pool/DAS, offsite Borg, buildcache               |
| `stability.md`            | Freeze history, memory guard, zram, kernel/network hardening              |
| `sso-dns.md`              | SSO/OIDC layers, Pocket ID, Caddy gotchas                                 |
| `secrets.md`              | Sops+Age, crush provider keys, secret-leak incident + purge runbook       |
| `desktop.md`              | DMS/Quickshell, niri, smart-audio, Helium, ActivityWatch                  |
| `monitoring.md`           | Gatus patterns, SigNoz, textfile collectors, ClickHouse traps             |
| `shell-devtools.md`       | Shell traps, direnv/fish/zellij/btop, qmd wiring                          |
| `git.md`                  | Git corruption recovery, history-rewrite checklist, push protection       |

## Provenance map (old AGENTS.md section → new home)

| Old AGENTS.md section                                              | New home                                                                                                                                                                                                           |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Key Procedures → CV Server                                         | `docs/services/cv.md` (appendix)                                                                                                                                                                                   |
| Key Procedures → Flake Updates                                     | `nix-flakes.md`                                                                                                                                                                                                    |
| Key Procedures → Adding a Service                                  | `integration-registry.md`                                                                                                                                                                                          |
| Key Procedures → Prevention Layers (table)                         | root `AGENTS.md` (kept)                                                                                                                                                                                            |
| Key Procedures → Prevention Layers (cross-platform para)           | `nix-flakes.md`                                                                                                                                                                                                    |
| Key Procedures → Prevention Layers (Gatus patterns)                | `monitoring.md`                                                                                                                                                                                                    |
| Key Procedures → Auth/DNS Gate Helpers                             | `integration-registry.md`                                                                                                                                                                                          |
| Key Procedures → Net VPN                                           | `docs/services/net-vpn.md` (appendix)                                                                                                                                                                              |
| Key Procedures → Consuming LarsArtmann Flakes                      | `integration-registry.md`                                                                                                                                                                                          |
| Key Procedures → Private Go Repos                                  | `go-ecosystem.md`                                                                                                                                                                                                  |
| All `### <Service>` sections (InboxClean … SearXNG)                | `docs/services/<service>.md` (new files or appendices)                                                                                                                                                             |
| Sops + Age / Crush Provider Keys / Secret Leak Incident            | `secrets.md`                                                                                                                                                                                                       |
| Crush Session DBs / crush-debug                                    | `docs/services/crush.md` (appendix)                                                                                                                                                                                |
| Hot-DB Service Tier                                                | `docs/services/hot-db.md` (appendix)                                                                                                                                                                               |
| SSO / OIDC Architecture                                            | `sso-dns.md`                                                                                                                                                                                                       |
| BTRFS / HDD Pool & DAS / Offsite Borg / Build Cache SSD            | `storage.md`                                                                                                                                                                                                       |
| Kernel & Network Hardening / ZRAM / Hardware Instability           | `stability.md`                                                                                                                                                                                                     |
| BFQ I/O Priority Tiers                                             | `systemd.md`                                                                                                                                                                                                       |
| Critical Rules (kept in root; 3 long rules condensed)              | root `AGENTS.md` + `git.md` / `nix-flakes.md` (full text)                                                                                                                                                          |
| Non-Obvious Gotchas → D-state                                      | `systemd.md`                                                                                                                                                                                                       |
| Non-Obvious Gotchas → Git zero-byte corruption                     | `git.md`                                                                                                                                                                                                           |
| Non-Obvious Gotchas → Multi-agent write discipline                 | root `AGENTS.md` (kept)                                                                                                                                                                                            |
| Non-Obvious Gotchas → Big self-contained HTML reports              | `docs/CONTRIBUTING.md` (appendix)                                                                                                                                                                                  |
| Non-Obvious Gotchas → Nix & Nixpkgs                                | `nix-flakes.md`                                                                                                                                                                                                    |
| Non-Obvious Gotchas → Systemd                                      | `systemd.md`                                                                                                                                                                                                       |
| Non-Obvious Gotchas → Caddy / SSO-OIDC / OpenSEO                   | `sso-dns.md`                                                                                                                                                                                                       |
| Non-Obvious Gotchas → BTRFS & Filesystems                          | `storage.md`                                                                                                                                                                                                       |
| Non-Obvious Gotchas → Docker & Containers                          | `systemd.md`                                                                                                                                                                                                       |
| Non-Obvious Gotchas → DNS (dnsblockd)                              | `docs/services/dnsblockd.md`                                                                                                                                                                                       |
| Non-Obvious Gotchas → Monitor365                                   | `docs/services/monitor365.md`                                                                                                                                                                                      |
| Non-Obvious Gotchas → DiscordSync                                  | `docs/services/discordsync.md` (appendix)                                                                                                                                                                          |
| Non-Obvious Gotchas → Desktop                                      | `desktop.md` (+ `docs/services/jan.md`)                                                                                                                                                                            |
| Non-Obvious Gotchas → SearXNG                                      | `docs/services/searxng.md`                                                                                                                                                                                         |
| Non-Obvious Gotchas → Other Services (per bullet)                  | `nix-flakes.md`, `monitoring.md`, `docs/services/{bank-sync,projects-management-automation,browser-history,forgejo,systemd-graph,systemd-timer-monitor}.md`, `integration-registry.md`, `desktop.md`, `sso-dns.md` |
| Non-Obvious Gotchas → WiFi Failover                                | `docs/services/wifi-failover.md`                                                                                                                                                                                   |
| Non-Obvious Gotchas → Shell & DevTools + qmd                       | `shell-devtools.md`                                                                                                                                                                                                |
| Non-Obvious Gotchas → Infrastructure Patterns (per bullet)         | `monitoring.md` (SigNoz/collectors), `integration-registry.md` (lib/VM-test), `systemd.md` (timeouts/smoke), `nix-flakes.md` (packaging/attic)                                                                     |
| Build & Deploy / Platform Constraints / Architecture / TODO System | root `AGENTS.md` (kept; boot-mirror detail → `systemd.md`)                                                                                                                                                         |

Anything not listed here was either kept in the root `AGENTS.md` or already
duplicated in an existing runbook. Authoritative audit: the migration spans
two commits — daemon-swept `d89029cf` (bulk split, includes the temporary
stray files) + completion `8e6409dd` (strays merged into runbooks);
`git diff d08ec9c1..8e6409dd -- AGENTS.md docs/` reconstructs it.
