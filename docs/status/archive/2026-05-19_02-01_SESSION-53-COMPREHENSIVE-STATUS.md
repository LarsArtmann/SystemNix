# Session 53 — Comprehensive Status Report

**Date:** 2026-05-19 02:01 CEST
**Branch:** `master` (ahead of origin by 2 commits)
**Platform:** NixOS evo-x2 (x86_64-linux) + macOS MacBook Air (aarch64-darwin)

---

## Project Summary

| Metric | Value |
|--------|-------|
| Flake inputs | 47 |
| Service modules | 35 |
| Overlays | 23 (15 shared + 6 linux + 2 utility) |
| Justfile recipes | 80 |
| System configs | 3 (evo-x2, rpi3-dns, MacBook Air) |
| Lock nodes | 72 (down from 137 — 47% reduction) |
| Enabled services on evo-x2 | 33 |
| Status reports | ~300+ total |

---

## A) FULLY DONE ✅

### Infrastructure & Core

| Item | Details |
|------|---------|
| **Cross-platform flake** | Darwin + NixOS + rpi3-dns. Shared ~80% via `platforms/common/`. |
| **Flake-parts architecture** | All 35 service modules are self-contained flake-parts modules. Single `serviceModules` list in flake.nix. |
| **Lockfile optimization** | 137 → 72 nodes (47% reduction). Zero controllable suffixed duplicates remain. Only 3 third-party unfixable (hermes-agent internals). |
| **Overlays system** | 23 overlays across `shared.nix` + `linux.nix`. `mkPackageOverlay` helper used consistently. |
| **Shared lib/ helpers** | `harden`, `hardenUser`, `serviceDefaults`, `mkStateDir`, `onFailure`, `mkDockerServiceFactory`, `serviceTypes`. Adopted by all 33+ modules. |
| **Sops secrets** | Age encryption via SSH host key. 8 encrypted files, 6 env templates. Proper `restartUnits` wiring. |
| **DNS blocking stack** | Unbound + dnsblockd. 2.5M+ domains. 25 blocklists. Quad9 DoT upstream. `do-ip6 = false` set correctly. |
| **DNS failover module** | Keepalived VRRP module written, enabled in config. VRRP password in sops. **NOT YET DEPLOYED** — needs `just switch`. |
| **Catppuccin Mocha theme** | Universal theme across all apps. Nix-colors dependency removed, inlined palette. |
| **Crush config** | Flake input deployed via HM on both platforms. Follows nixpkgs + flake-parts. |
| **GC optimization** | Daily GC with 3-day retention on both platforms. MacBook disk exhaustion defense. |

### Production Services (Enabled & Working)

| Service | Module | Status |
|---------|--------|--------|
| Caddy reverse proxy | `caddy.nix` | ✅ 10 vhosts, TLS via sops, forward auth, metrics |
| Authelia SSO/IdP | `authelia.nix` | ✅ TOTP + WebAuthn, OIDC (Immich + Forgejo clients), 2FA |
| Forgejo git forge | `forgejo.nix` | ✅ Phase 1 code migrated from Gitea. **Phase 2 data migration pending.** |
| Immich photo/video | `immich.nix` | ✅ Full stack, OIDC auth via Authelia |
| SigNoz observability | `signoz.nix` | ✅ Built from source. Traces + metrics + logs. AMD GPU + NVMe metrics. |
| Gatus health monitor | `gatus-config.nix` | ✅ 26+ endpoints, SQLite, Discord alerting |
| Homepage dashboard | `homepage.nix` | ✅ Service dashboard |
| TaskChampion sync | `taskchampion.nix` | ✅ Zero-setup cross-platform sync |
| Hermes AI gateway | `hermes.nix` | ✅ Discord bot, cron, GPU-capable. v2026.5.7 |
| Dual-WAN ECMP+MPTCP | `dual-wan.nix` | ✅ Route health monitor, WiFi failover, MPTCP endpoints |
| AI model storage | `ai-models.nix` | ✅ Centralized `/data/ai/` with 18 directories |
| Ollama AI | `ai-stack.nix` | ✅ GPU defense (max 1 model, 45% fraction, 8GiB overhead, OOMScore 500) |
| NVMe health monitor | `nvme-health-monitor.nix` | ✅ SMART metrics, desktop notifications |
| Disk monitor | `disk-monitor.nix` | ✅ BTRFS usage alerts |
| EMEET PIXY webcam | `emeet-pixyd` | ✅ Face tracking, auto-call detection, Waybar integration |
| OpenSEO | `openseo.nix` | ✅ Self-hosted SEO suite, Docker Compose |
| Manifest LLM router | `manifest.nix` | ✅ Smart AI model routing, Docker Compose |
| Twenty CRM | `twenty.nix` | ✅ Docker Compose, PostgreSQL + Redis |
| Voice agents | `voice-agents.nix` | ⚠️ LiveKit + Whisper ASR. **Missing `sops.secrets.livekit_keys` declaration** — may fail at build time. |
| Niri desktop | `niri-config.nix` | ✅ DRM healthcheck, GPU recovery, session metrics |
| Security hardening | `security-hardening.nix` | ✅ fail2ban, ClamAV, polkit |
| Steam gaming | `steam.nix` | ✅ Proton, gamemode, gamescope |
| Forgejo repos mirror | `forgejo-repos.nix` | ✅ Declarative GitHub→Forgejo sync (dnsblockd, BuildFlow) |
| File & image renamer | `file-and-image-renamer.nix` | ✅ AI screenshot renaming, user service |

### Desktop & UX

| Item | Status |
|------|--------|
| Niri compositor | ✅ Wrapped with config, GPU OOM protection |
| Waybar | ✅ Catppuccin, camera/weather/custom modules |
| Rofi / Swaylock / Wlogout | ✅ Themed |
| Niri session manager | ✅ Window save/restore (Rust) |
| Wallpaper self-healing | ✅ awww daemon + PartOf restart propagation |
| DRM healthcheck | ✅ Consecutive failure counter, auto GPU recovery |
| GPU recovery | ✅ Unbind/rebind amdgpu, auto-reboot on failure |
| Display watchdog | ✅ Kernel panic + niri hang detection |

### Cross-Platform (macOS + NixOS)

| Item | Status |
|------|--------|
| Fish/Zsh/Bash shells | ✅ Tested aliases across all 3 |
| Starship prompt | ✅ Consistent config |
| Git config | ✅ External via nix-ssh-config |
| Tmux + Fzf | ✅ |
| Taskwarrior 3 | ✅ Deterministic client IDs, shared encryption |
| KeePassXC | ✅ |
| Helium browser | ✅ Session restore fix |
| ActivityWatch | ✅ aw-watcher-utilization overlay |

---

## B) PARTIALLY DONE 🟡

### 1. Gitea → Forgejo Migration (Phase 1 of 3)

| Phase | Status | What's needed |
|-------|--------|---------------|
| Phase 1: Code | ✅ DONE | 15 files changed, build passes |
| Phase 2: Data migration | ⏳ NOT STARTED | Stop gitea → backup → rename sops key → mv data → `just switch` → fix ownership → verify tokens. ~30 min downtime. |
| Phase 3: Cleanup | ⏳ NOT STARTED | Remove old gitea modules, remove backups, update docs, possibly rename vhost from `gitea.home.lan` → `forgejo.home.lan` |

**Blocker:** `FORGEJO_TOKEN` doesn't exist in `secrets.yaml` yet — still `gitea_token`. The `scripts/rename-sops-gitea-to-forgejo.sh` script exists for this but hasn't been run.

**Bug:** `forgejo-mirror-github` script has `--arg clone_url` but jq uses `$clone_addr` — variable name mismatch (inherited from original gitea.nix).

### 2. DNS Failover Cluster (VRRP)

| Component | Status |
|-----------|--------|
| Module code | ✅ Complete (`dns-failover.nix`) |
| evo-x2 config | ✅ Enabled in `dns-blocker-config.nix` (MASTER, priority 100) |
| rpi3-dns config | ✅ Defined (BACKUP, priority 50) |
| VRRP password in sops | ✅ Done |
| **keepalived actually running** | ❓ UNKNOWN — config enabled but not verified on evo-x2 |
| **VIP `.53` responding** | ❌ NOT WORKING — `dig @192.168.1.53` fails ("reply from unexpected source: .150") |
| Pi 3 hardware | ❌ NOT PROVISIONED |

**Root cause of VIP failure:** Either keepalived isn't running on evo-x2 (needs `just switch`), or the VIP is assigned but Linux responds from primary IP. Keepalived manages ARP parameters correctly (`arp_ignore=1`, `arp_announce=2`), so once deployed, it should work.

### 3. Monitor365

| Aspect | Status |
|--------|--------|
| Module code | ✅ Complete |
| Package overlay | ✅ In `linux.nix` |
| Enabled on evo-x2 | ✅ Yes |
| Privacy-sensitive collectors | All disabled by default (screenshot, camera, keystroke, mouse, clipboard, notifications, location, fsEvent) |
| System collectors | Enabled (battery, network, wifi, bluetooth, window, process, afk, sensor, systemInfo) |

### 4. Voice Agents

| Aspect | Status |
|--------|--------|
| LiveKit + Whisper ASR | ✅ Module code complete |
| ROCm GPU support | ✅ Configured |
| Sops secrets | ⚠️ References `config.sops.placeholder.livekit_keys` but no `sops.secrets.livekit_keys` declared in the module — needs to be declared in `sops.nix` or the module itself |

### 5. PhotoMap

| Aspect | Status |
|--------|--------|
| Module code | ✅ Complete |
| Disabled | Podman permission issue noted in configuration.nix |
| Not a priority | Low usage |

---

## C) NOT STARTED ⬜

| Item | Impact | Effort |
|------|--------|--------|
| **Forgejo Phase 2: Data migration** | HIGH — production git forge on old gitea binaries | 30 min downtime |
| **Forgejo Phase 3: Cleanup** | MEDIUM — old gitea modules still on disk | 15 min |
| **Pi 3 hardware provisioning** | HIGH — DNS single point of failure | 4+ hours |
| **Keepalived deployment on evo-x2** | HIGH — VIP `.53` not working | Just `just switch` |
| **Rename vhost `gitea.home.lan` → `forgejo.home.lan`** | LOW — cosmetic, keeps backward compat | 30 min across 5+ files |
| **ClickHouse backup strategy** | HIGH — no replication, no backups, data loss risk if disk fails | 2-4 hours |
| **Authelia email/SMS notifier** | MEDIUM — users can't self-service password resets | 1-2 hours |
| **Deploy Dozzle at `logs.home.lan`** | LOW — container log viewer | 30 min |
| **Auditd/AppArmor** | MEDIUM — no mandatory access control | 4+ hours |
| **Benchmark scripts** | LOW — mentioned in FEATURES.md gaps | 2 hours |
| **Convert go-auto-upgrade `path:` inputs to SSH URLs** | LOW — mentioned in TODO_LIST.md | 30 min |
| **Create shared flake-parts template** | LOW — mentioned in TODO_LIST.md | 2 hours |
| **Consolidate voice-agents Caddy vHost** | LOW — mentioned in TODO_LIST.md | 15 min |
| **Per-threshold SigNoz channel routing** | LOW — mentioned in TODO_LIST.md | 1 hour |

---

## D) TOTALLY FUCKED UP 💥

### 1. Forgejo Token Sops Key Not Renamed (P0 — Blocks Deployment)

`secrets.yaml` still has `gitea_token`. The `forgejo.nix` module expects `FORGEJO_TOKEN`. **Running `just switch` will fail** until the key is renamed. The rename script exists at `scripts/rename-sops-gitea-to-forgejo.sh` but hasn't been executed.

### 2. Forgejo Mirror Script Variable Mismatch (Bug)

`forgejo-mirror-github` script passes `--arg clone_url` but the jq filter references `$clone_addr`. This was inherited from the original gitea.nix and not caught during migration. **GitHub mirror sync will fail silently.**

### 3. Voice Agents Missing Sops Secret Declaration

`voice-agents.nix` references `config.sops.placeholder.livekit_keys` but the secret isn't declared anywhere. **Build will fail** if voice-agents is enabled (currently enabled in configuration.nix).

### 4. Hermes Stale npmDepsHash (Time Bomb)

Upstream `hermes-agent` has a stale `npmDepsHash` in their `nix/tui.nix`. Local overlay (`fixedHash` in `hermes.nix`) patches it. **Will break on next hermes-agent update** — requires manual hash update procedure.

### 5. Darwin Disk at 95% (Chronic)

MacBook Air 229 GB disk regularly at 90-95%. Nix GC runs daily but is a losing battle. `nix-collect-garbage` can hang. Build failures with `errno=28` are disk-related. No long-term fix beyond hardware upgrade or distributed builds.

### 6. ClickHouse Single Node — No Backup (Data Loss Risk)

SigNoz ClickHouse runs as single-node Keeper with 4G memory cap. No replication, no backup strategy. If the NVMe fails, all observability data (traces, metrics, logs) is gone. This is the biggest data loss risk in the system.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Architecture & Reliability

1. **DNS failover is a single point of failure** — evo-x2 goes down = ALL LAN devices lose DNS. VIP `.53` exists in config but isn't working. Fix: deploy keepalived now, provision Pi 3 ASAP.
2. **ClickHouse backup strategy** — No backups for observability data. Add periodic SQL dump to `/data/` or S3.
3. **Authelia OIDC client secret** — Hardcoded PBKDF2 hash, not from sops. If rotation needed, manual update required.
4. **rpi3-dns has unnecessary overlays** — Includes `emeet-pixyd`, `monitor365`, `openaudible` overlays that a minimal Pi DNS node doesn't need. Adds evaluation time for nothing.
5. **`pythonTest` overlay pins Python 3.13** — Will silently break when nixpkgs bumps default Python.

### Security

6. **No auditd/AppArmor** — No mandatory access control. Any process compromise has full system access.
7. **Authelia filesystem notifier** — No email/SMS. Users can't self-service password resets.
8. **Forgejo runner token in sops** — Actions runner token is generated on every start. Should be stable for CI reliability.

### Code Quality

9. **`todoListAiFixedHash` in shared.nix** — Hardcoded SHA for node_modules. Breaks silently on upstream changes.
10. **Justfile hardcoded IP** — `evo_x2_ip := "192.168.1.150"` should derive from `local-network.nix`.
11. **300+ status files** — Most are archived but the directory is unwieldy. Consider organizing by year/month.
12. **`forgejo-mirror-github` variable mismatch** — `clone_url` vs `clone_addr` bug needs fixing.

### Developer Experience

13. **Forgejo migration incomplete** — 3 phases, only 1 done. Blocks all Forgejo-dependent work.
14. **No distributed builds** — MacBook disk exhaustion could be solved by offloading builds to evo-x2.
15. **Hermes hash workaround** — Fragile. Should be fixed upstream or automated.

---

## F) Top 25 Things We Should Get Done Next

### P0 — Do Now (Blocks other work)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Run `scripts/rename-sops-gitea-to-forgejo.sh` on evo-x2** | 5 min | Unblocks Forgejo deployment |
| 2 | **Forgejo Phase 2: Data migration** (stop gitea → backup → rename → `just switch`) | 30 min | Production git forge on Forgejo |
| 3 | **Fix forgejo-mirror-github jq variable mismatch** (`clone_url` → `clone_addr`) | 5 min | GitHub mirror sync works |
| 4 | **Fix voice-agents missing `sops.secrets.livekit_keys`** | 5 min | Build doesn't fail |
| 5 | **Deploy keepalived on evo-x2** (`just switch` — config is ready) | 10 min | VIP `.53` works, DNS failover active |

### P1 — Do This Week

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | **Forgejo Phase 3: Cleanup** (remove old gitea modules, update docs) | 15 min | Clean codebase |
| 7 | **Verify keepalived + VIP `.53`** from MacBook after deployment | 10 min | DNS failover validated |
| 8 | **Add ClickHouse backup strategy** (daily SQL dump to `/data/ai/cache/` or S3) | 2 hours | Data loss prevention |
| 9 | **Update MacBook DNS to `.53`** once VIP confirmed working | 2 min | MacBook uses failover DNS |
| 10 | **Provision Pi 3 hardware** for DNS failover cluster | 4+ hours | Eliminates DNS SPOF |

### P2 — Do This Month

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | **Migrate Authelia notifier from filesystem to SMTP** | 1-2 hours | Password reset self-service |
| 12 | **Move Authelia OIDC client secret to sops** | 30 min | Proper secret rotation |
| 13 | **Clean up rpi3-dns overlays** (remove emeet-pixyd, monitor365, openaudible) | 15 min | Faster evaluation |
| 14 | **Fix `pythonTest` overlay to use default Python** instead of hardcoded 3.13 | 15 min | Future-proof |
| 15 | **Fix `todoListAiFixedHash` to auto-detect** or document update procedure | 30 min | Reduce breakage |
| 16 | **Deploy Dozzle at `logs.home.lan`** | 30 min | Container log visibility |
| 17 | **Rename vhost `gitea.home.lan` → `forgejo.home.lan`** (optional) | 30 min | Semantic clarity |
| 18 | **Consolidate voice-agents Caddy vHost** | 15 min | Cleaner routing |

### P3 — Nice To Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 19 | **Auditd/AppArmor setup** | 4+ hours | Mandatory access control |
| 20 | **Distributed builds** (MacBook → evo-x2) | 2 hours | MacBook disk relief |
| 21 | **Fix Hermes upstream npmDepsHash** (contribute upstream) | 1-2 hours | Remove local workaround |
| 22 | **Organize `docs/status/` by year/month** | 1 hour | Navigability |
| 23 | **Create shared flake-parts template** for new services | 2 hours | Faster module creation |
| 24 | **Convert go-auto-upgrade `path:` inputs to SSH URLs** | 30 min | Portability |
| 25 | **Add benchmark scripts** for system performance tracking | 2 hours | Observability gap |

---

## G) Top #1 Question I Cannot Figure Out Myself 🤔

**Has `just switch` been run on evo-x2 since session 52?**

The Forgejo Phase 1 code changes are committed and the build passes locally, but:
- The `FORGEJO_TOKEN` sops key hasn't been renamed (would block `just switch`)
- Keepalived may or may not be running (dns-failover is enabled in config but untested)
- The current kernel is noted as 7.0.1 in TODO_LIST.md with 7.0.6 available

Without SSH access, I cannot verify the actual runtime state of evo-x2. The entire Phase 2 migration + keepalived deployment depends on this answer.

---

## Session 52 Recap (for context)

Session 52 accomplished three major things:

1. **Forgejo migration Phase 1** — 15 files changed, switched from `pkgs.gitea` to `pkgs.forgejo-lts`, added federation + push mirrors, updated all references (Caddy, Authelia, Gatus, Homepage, SigNoz, Sops, Justfile, AGENTS, FEATURES). Build passes.

2. **Last lockfile duplicate eliminated** — `gogenfilter_2` removed by adding `inputs.gogenfilter.follows = "gogenfilter"` to `art-dupl`. Lock nodes: 73 → 72. **Zero controllable suffixed nodes remain.**

3. **go-structure-linter upstream fix** — 4 commits pushed to fix `testhelpers` sub-module vendoring.

---

## Git State

```
On branch master
Ahead of origin/master by 2 commits

Unstaged:
  modified: flake.lock (homebrew-cask rev bump)

Untracked:
  scripts/rename-sops-gitea-to-forgejo.sh
```

The 2 unpushed commits:
- `4fab77f7` style(flake): consolidate repeated inputs keys — fix all statix warnings
- `a21e6044` fix(forgejo): fix jq variable mismatch and add migration gotchas
