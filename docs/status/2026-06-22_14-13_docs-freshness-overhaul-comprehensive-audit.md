# Status Report — 2026-06-22 14:13

## Session 144: Documentation Freshness Overhaul + Comprehensive Audit

**Scope:** Full project status audit following documentation freshness sprint
**Build:** ✅ `nix flake check --no-build` passes
**Commits:** 2,926 total | **Flake inputs:** 67 direct | **Services:** 39 modules (~33 enabled)

---

## a) FULLY DONE ✅

| Area | Details |
|------|---------|
| **Cross-platform Nix flake** | Single flake, Darwin + NixOS, 80% shared via `platforms/common/` |
| **flake-parts architecture** | 39 service modules auto-discovered, `_` prefix for helpers |
| **OOM hardening** | systemd-oomd (PSI 50%/20s), `user-1000.slice` MemoryHigh=56G/MemoryMax=64G, PSI metrics + Gatus alerting |
| **ssh-suspend-guard** | Holds `sleep` block inhibitor during SSH sessions — prevents idle suspend during remote work |
| **Pocket ID OIDC** | Passkey-only, declarative provisioning, SMTP wired, oauth2-proxy forward auth |
| **dnsblockd** | ~930-line production Go: dynamic TLS, 23 blocklists, 2.5M+ domains, 10-category system, temp-allow API, Prometheus metrics |
| **SigNoz observability** | 19 alert rules, 6 dashboards, custom `signoz.target`, JWT auto-gen, PSI pressure collector |
| **Gatus monitoring** | 38 health check endpoints, Discord alerting, SQLite storage |
| **BTRFS root snapshots** | btrbk daily, 14d+4w retention, verify timer |
| **Forgejo + mirror sync** | GitHub push mirrors, Actions runner, admin auto-setup, federation |
| **Immich** | PostgreSQL + Redis + ML, OAuth, VA-API transcoding, daily DB backup |
| **Homepage Dashboard** | `mkGroup`/`mkService` helpers, conditional tiles per service |
| **Documentation overhaul** | All 6 core docs updated: AGENTS.md, FEATURES.md, README.md, TODO_LIST.md, **ROADMAP.md** (new), **CHANGELOG.md** (new) |
| **Justfile removal** | Replaced with `nix run .#deploy`, `nix flake check --no-build`, flake apps, `scripts/` |
| **Port centralization** | All ports in `lib/ports.nix`, collision-protected |
| **Image registry** | All container refs via `lib/images.nix` with `mkRef` |
| **Pre-commit hooks** | 9 hooks: gitleaks, deadnix, statix, alejandra, nix-check, shellcheck, etc. |
| **CI/CD** | GitHub Actions: flake-update (weekly PR), nix-check (push/PR) |

---

## b) PARTIALLY DONE ⚠️

| Area | What Works | What's Missing |
|------|-----------|----------------|
| **Monitor365** | Agent + server enabled, DB path fixed, ActivityWatch integration | Server was crash-looping; status uncertain after last deploy. Needs `systemctl reset-failed` |
| **File & Image Renamer** | Re-enabled in config, Go 1.26.3 available | Pending deploy verification |
| **Darwin Home Manager** | Basic user config, packages, shells | No terminal/editor/theme parity with NixOS. 7-line HM config. Disk constrained (256GB, 90%+) |
| **BTRFS `/data`** | Mounted, zstd:3, Docker lives here | NOT snapshotted — BTRFS toplevel (subvolid=5). Manual migration needed |
| **Hermes AI gateway** | Discord bot, cron, system service, sops secrets | OpenAI API key not in sops (manual step), SSH deploy key not installed, fallback model not set |
| **Pocket ID email** | SMTP wired (Resend), sops secret added | Email sending not verified (login notification / verification test) |
| **Twenty CRM** | Docker Compose, PostgreSQL, Caddy at crm.home.lan | Intermittent 502s — Caddy logs show connection refused on port 3200 |
| **Gatus health checks** | 38 endpoints configured | 6 services showing DOWN — possibly wrong check URLs (SigNoz, Immich, Crush Daily, Ollama, Monitor365) |

---

## c) NOT STARTED 📋

| Area | Blocker |
|------|---------|
| **Raspberry Pi 3 DNS failover** | Hardware not purchased. Module + config ready |
| **Cloud backup (BorgBackup)** | No off-site backup exists. Hetzner StorageBox researched but not configured |
| **Auditd** | Blocked on NixOS 26.05 bug #483085 |
| **AppArmor** | Explicitly disabled (`mkDefault false`) |
| **Firewall deny-by-default** | NixOS allows all inbound; Docker punches holes |
| **Monitor365 agent→server auth** | No auth — anyone on LAN can POST data |
| **NPU workloads** | AMD XDNA driver loaded but nothing uses it |

---

## d) TOTALLY FUCKED UP ❌

| Area | What's Wrong | Impact |
|------|-------------|--------|
| **DiscordSync** | **DISABLED** — needs migration from deleted `projection/v2` to `watermill.CatchUpSubscriber + stack.Materialize`. Bot non-functional | Discord channel backup bot completely down |
| **Mullvad VPN** | **DISABLED** — `talpid_dns` corrupts `/etc/resolv.conf` causing total DNS failure | No VPN; split-tunneling config rotting unused |
| **Status doc bloat** | **199 files** in `docs/status/` + **374 in archive** = 573 status reports. Finding anything is impossible | Knowledge buried; future sessions can't find relevant context |
| **Pre-session-100 docs not archived** | TODO from session 139 still open — "move pre-session-100 from `docs/status/` to `docs/status/archive/` (178 → ~30 files)" | Same bloat problem |
| **No deploy automation for BTRFS** | `nix run .#deploy` no longer creates pre-deploy snapshots (justfile removal removed this) | Rollback safety net gone for deploys |
| **Jan llama-server respawn** | Spawns new `llama-server` every 1-3 min (~1.2GB each), no cgroup limits | Memory leak; not a systemd service so can't be easily constrained |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Architecture
1. **Split mega-modules** — `signoz.nix` (778L), `monitor365.nix` (716L), `forgejo.nix` (582L) are too large. Extract sub-modules for maintainability
2. **Typed module options** — most modules use `mkEnableOption` only. Add typed options for ports, paths, timeouts → enables validation and testing
3. **Extract dnsblockd** — ~930 lines of production Go embedded in Nix config. Should be standalone repo
4. **Status report rotation** — implement automated archival (move docs older than 30 days to archive)

### Reliability
5. **Cloud backup** — single most critical gap. No off-site backup = catastrophic data loss risk
6. **Pre-deploy BTRFS snapshots** — restore the safety net removed with justfile
7. **Gatus URL audit** — 6 endpoints showing DOWN, likely misconfigured URLs

### Security
8. **Firewall deny-by-default** — transition from "allow all" to explicit allowlist
9. **Bind services to localhost** — Immich on `0.0.0.0`, should be `127.0.0.1` (Caddy proxies)
10. **Monitor365 auth** — unauthenticated POST endpoint on LAN

### Documentation
11. **Status report discipline** — 573 status files is insanity. Archive old ones, keep latest 20
12. **ADR consolidation** — 13 ADRs scattered across `docs/adr/` and `docs/architecture/`. Consolidate to one directory

---

## f) Top #25 Things to Get Done Next

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Deploy current config** — OOM hardening, ssh-suspend-guard, doc fixes are uncommitted/undeployed | 🔴 Critical | 5min | Deploy |
| 2 | **Cloud backup setup** — BorgBackup to Hetzner StorageBox | 🔴 Critical | 2h | Reliability |
| 3 | **Fix DiscordSync** — migrate from deleted projection/v2 to watermill | 🔴 High | 4h | Broken |
| 4 | **Archive old status docs** — move pre-session-100 to archive (178 files) | 🟡 Medium | 30min | Hygiene |
| 5 | **Audit Gatus endpoints** — fix 6 DOWN services, verify URLs | 🟡 Medium | 1h | Monitoring |
| 6 | **Reboot evo-x2** — verify boot time after NVMe APST fix | 🟡 Medium | 10min | Deploy |
| 7 | **Fix Twenty CRM 502s** — investigate container OOM or PG exhaustion | 🟡 Medium | 2h | Broken |
| 8 | **Pre-deploy BTRFS snapshot** — restore safety net in `scripts/deploy.sh` | 🟡 Medium | 30min | Reliability |
| 9 | **Verify Pocket ID email** — test login notification after SMTP wiring | 🟡 Medium | 10min | Verify |
| 10 | **Reset Monitor365** — `systemctl --user reset-failed monitor365-server` | 🟢 Low | 1min | Fix |
| 11 | **Add Hermes OpenAI key** — sops secret, manual step | 🟡 Medium | 5min | Config |
| 12 | **Firewall deny-by-default** — explicit allowlist for Caddy/SSH/DNS | 🟡 Medium | 1h | Security |
| 13 | **Bind Immich to localhost** — `host = "127.0.0.1"` | 🟢 Low | 5min | Security |
| 14 | **BTRFS `/data` subvolume migration** — create subvol, update fstab, rsync | 🟡 Medium | 1h | Reliability |
| 15 | **Split signoz.nix** (778L) — extract ClickHouse, OTel collector, dashboards | 🟡 Medium | 2h | Architecture |
| 16 | **Split monitor365.nix** (716L) — extract agent config, server config | 🟡 Medium | 2h | Architecture |
| 17 | **Add Monitor365 auth** — token-based agent→server authentication | 🟡 Medium | 3h | Security |
| 18 | **Investigate Jan llama-server respawn** — cgroup limits or service wrapper | 🟡 Medium | 2h | AI/ML |
| 19 | **Hermes SSH deploy key** — install private key, add public to GitHub | 🟢 Low | 10min | Config |
| 20 | **Swap investigation** — 8 GiB swap on 128 GiB RAM, check stale processes | 🟢 Low | 30min | Investigate |
| 21 | **Upstream PR: KeePassXC Chromium manifests** — trivially generated, benefits all | 🟢 Low | 1h | Upstream |
| 22 | **Upstream PR: aw-watcher-utilization poetry-core** — eliminates custom overlay | 🟢 Low | 1h | Upstream |
| 23 | **Disabled service triage** — voice-agents, minecraft, photomap: enable or remove | 🟢 Low | 30min | Cleanup |
| 24 | **NixOS tests** — expand `tests/` beyond exec-start-paths | 🟡 Medium | 4h | Quality |
| 25 | **Extract dnsblockd to standalone repo** — 930 lines of Go deserves its own repo | 🟡 Medium | 4h | Architecture |

---

## g) Top #1 Question I Cannot Figure Out Myself

**The DiscordSync migration: what exactly does "migrate from deleted projection/v2 to watermill.CatchUpSubscriber + stack.Materialize" mean in practice?**

The config comment at `configuration.nix:196` says:
```
discordsync.enable = false; # TODO: migrate from deleted projection/v2 to watermill.CatchUpSubscriber + stack.Materialize (ADR-0030)
```

This references ADR-0030 which doesn't exist in this repo (we have ADRs 001-007 + some others). The `projection/v2` package was apparently deleted from a dependency (likely a LarsArtmann Go repo — possibly `go-cqrs-lite`), and the DiscordSync code needs to be rewritten to use `watermill.CatchUpSubscriber` and `stack.Materialize` instead.

**I cannot determine:**
1. Which Go repo the deleted `projection/v2` lived in
2. What the new API signatures for `CatchUpSubscriber` / `Materialize` look like
3. Whether ADR-0030 exists in another repo or was never written
4. How much of the DiscordSync code needs rewriting vs. just updating imports

This requires domain knowledge of the LarsArtmann Go ecosystem (go-cqrs-lite, watermill integration) that isn't documented in SystemNix.

---

## Session Summary

| Metric | Value |
|--------|-------|
| Files modified | 4 (AGENTS.md, FEATURES.md, README.md, TODO_LIST.md) |
| Files created | 2 (ROADMAP.md, CHANGELOG.md) |
| Stale references fixed | ~40+ (all `just` commands, wrong counts, wrong statuses) |
| Build status | ✅ `nix flake check --no-build` passes |
| Active TODO items | 36 |
| Completed TODO items | 46 |
| Enabled services | ~33 of 39 modules |
| Disabled/broken services | 5 (discordsync, mullvad, voice-agents, minecraft, photomap) |

### Key Wins This Session
- Eliminated ALL stale `just`/justfile references across 4 docs (justfile was removed in a prior commit but docs still referenced 79+ commands)
- Fixed wrong counts: Gatus 33→38, SigNoz 18→19, dashboards 5→6
- Fixed wrong statuses: Mullvad ✅→🔧, DiscordSync ✅→🔧, earlyoom→systemd-oomd
- Created CHANGELOG.md (2900+ commits had no changelog)
- Created ROADMAP.md (6 themes, deferred ideas table)
- Fixed stale BTRFS pre-deploy snapshot claims
- Removed duplicate Monitor365 entry with inconsistent statuses

### Remaining Risk
- **flake.lock** has uncommitted changes from before this session — not committed (unrelated to docs work)
- **No off-site backup** remains the #1 systemic risk
- **DiscordSync** is down with an unclear migration path
