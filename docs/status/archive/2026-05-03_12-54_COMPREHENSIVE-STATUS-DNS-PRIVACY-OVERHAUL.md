# SystemNix — Comprehensive Status Report

**Date:** 2026-05-03 12:54 CEST
**Branch:** master (up to date with origin)
**Platform:** NixOS (evo-x2) + macOS (Lars-MacBook-Air) + RPi3 (rpi3-dns)
**Session:** 19 — DNS Privacy Overhaul + Full Service Audit

---

## Session 19 Changes

### DNS: DoT Forwarding → Full Recursive Resolution

**Problem:** Unbound was forwarding ALL DNS queries to Cloudflare (1.1.1.1) and Quad9 (9.9.9.9) via DNS-over-TLS. This meant these third parties saw every DNS query made on the network.

**Fix:** Removed `forward-zone` from both evo-x2 and rpi3-dns configs. Added `root-hints = ":"` (uses unbound's built-in root hints) for full recursive resolution. Unbound now walks the DNS tree itself: root → TLD → authoritative — no third-party resolver involved.

**Files changed:**

- `modules/nixos/services/???` — wait, the dns-blocker module is at `platforms/nixos/modules/dns-blocker.nix`
- Removed `forward-zone` block, added `root-hints = ":"` inside `server`
- Removed dead `upstreamDNS` option + `caCertFile`/`caCertContent` variables
- `platforms/nixos/rpi3/default.nix` — same `forward-zone` → `root-hints` migration
- `platforms/shared/dns-blocklists.nix` — removed dead `upstreamDNS` list
- `platforms/nixos/system/dns-blocker-config.nix` — removed `inherit upstreamDNS`
- DNSSEC validation still works via `enableRootTrustAnchor = true`
- `just test-fast` passes

---

## a) FULLY DONE

### Infrastructure & Core

| Item                               | Status | Details                                                      |
| ---------------------------------- | ------ | ------------------------------------------------------------ |
| Flake architecture (flake-parts)   | ✅     | 29 NixOS modules, 34 flake inputs, 3 system targets          |
| Cross-platform Home Manager        | ✅     | 14 common programs shared across macOS + NixOS               |
| sops-nix secrets management        | ✅     | Age-encrypted via SSH host key, all secrets in sops          |
| Catppuccin Mocha theming           | ✅     | Universal across all apps, terminals, bars, login screen     |
| Shared blocklists                  | ✅     | 25 blocklists, 2.5M+ domains, shared between evo-x2 and rpi3 |
| DNS recursive resolution           | ✅     | Full root-hints recursive — no third-party DNS resolver      |
| DNSSEC validation                  | ✅     | Root trust anchor via `enableRootTrustAnchor`                |
| Custom overlays (14)               | ✅     | Shared + Linux-only, all private repos via `git+ssh://`      |
| Justfile task runner (90+ recipes) | ✅     | DNS, immich, gitea, camera, hermes, AI, disk, etc.           |
| ZRAM + BTRFS snapshots             | ✅     | systemd-boot, zstd compression, Timeshift                    |
| lib/systemd.nix hardening helpers  | ✅     | Reusable `harden {}` and `serviceDefaults {}`                |
| lib/rocm.nix GPU helper            | ✅     | ROCm runtime libs, env vars, `makeLdLibraryPath`             |
| ADRs (5)                           | ✅     | Home Manager, shell aliases, ZFS ban, sops, session restore  |
| Niri session save/restore          | ✅     | Timer-based snapshots, crash recovery, fallback apps         |
| EMEET PIXY webcam daemon           | ✅     | Full udev + systemd + waybar integration                     |

### Services — Production Ready

| Service            | Hardened                      | Service Defaults  | Status                              |
| ------------------ | ----------------------------- | ----------------- | ----------------------------------- |
| comfyui            | ✅ `harden + serviceDefaults` | ✅                | Best-in-class example               |
| taskchampion       | ✅ `harden + serviceDefaults` | ✅                | Full pattern                        |
| voice-agents       | ✅ `harden + serviceDefaults` | ✅                | Full pattern                        |
| signoz             | ✅ `harden`                   | ❌ Manual restart | Working                             |
| hermes             | ✅ `harden`                   | ❌ Manual restart | Working                             |
| homepage           | ✅ `harden`                   | ❌ Partial        | Working                             |
| minecraft          | ✅ `harden`                   | ❌ None           | Working                             |
| twenty             | ✅ `harden`                   | ❌ None           | Working                             |
| immich (server+ML) | ✅ `harden`                   | ❌ None           | Working                             |
| gitea (sync+token) | ✅ `harden`                   | ❌ None           | Working (main service NOT hardened) |

### Programs — All Cross-Platform

14 common programs: fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, activitywatch, keepassxc, chromium, pre-commit, ssh-config, shell-aliases

### Programs — NixOS-Specific

7 programs: niri-wrapped (872 lines), rofi, swaylock, wlogout, yazi, zellij, shells

### Hardware — evo-x2

| Component            | Status                                    |
| -------------------- | ----------------------------------------- |
| AMD GPU (Strix Halo) | ✅ mesa, ROCm, VA-API, Vulkan, monitoring |
| AMD NPU (XDNA)       | ✅ XRT runtime with boost 1.87 fix        |
| Bluetooth            | ✅ Audio source/sink, Blueman             |
| EMEET PIXY webcam    | ✅ Full daemon + waybar                   |

---

## b) PARTIALLY DONE

### Service Hardening Coverage

**Only 11 of 25+ service daemons use `lib/systemd.nix` hardening.** The rest have manual inline fields or no hardening at all:

| Service                | Issue                                                |
| ---------------------- | ---------------------------------------------------- |
| authelia               | Manual inline hardening — should use `harden`        |
| caddy                  | Manual inline hardening — should use `harden`        |
| gitea (main)           | NO hardening on the main gitea service               |
| file-and-image-renamer | Manual inline — should use `harden`                  |
| monitor365             | Manual inline — should use `harden`                  |
| immich-db-backup       | NO hardening at all                                  |
| twenty backup          | NO hardening at all                                  |
| signoz-provision       | NO hardening (oneshot)                               |
| amdgpu-metrics         | NO hardening (oneshot)                               |
| whisper-asr-pull       | NO hardening                                         |
| ollama                 | NO hardening — runs as user `lars` with `UMask 0007` |
| unsloth-setup          | NO hardening — runs pip installs as `lars`           |
| unsloth-studio         | NO hardening                                         |

### Service Defaults Coverage

**Only 4 of 25+ services use `serviceDefaults`:**

- ✅ comfyui, taskchampion, voice-agents (full)
- ⚠️ photomap (partial), homepage (partial)
- ❌ All others — manual `Restart`/`RestartSec` or missing entirely

### Taskwarrior + TaskChampion

- ✅ Client setup fully automated (deterministic client IDs + encryption)
- ⚠️ Encryption secret is a hardcoded deterministic hash in AGENTS.md — technically public
- ⚠️ No forward auth on tasks.home.lan (by design — uses client ID allowlisting)

### SigNoz Observability

- ✅ Full stack: query service, OTel collector, ClickHouse, node_exporter, cAdvisor
- ✅ Journald log collection, Prometheus scraping
- ⚠️ 741-line module — could be split into sub-modules
- ⚠️ Built from source (Go 1.25) — very slow build times

### macOS (Darwin)

- ✅ Basic system config + Home Manager
- ⚠️ Chrome policies need manual `sudo chrome-apply-policies`
- ⚠️ Keychain config is minimal (just activation script)
- ⚠️ Less tested than NixOS side

---

## c) NOT STARTED

### P1 SECURITY (43% done — 4 of 7 remaining)

| Task                                   | Priority | Notes                                               |
| -------------------------------------- | -------- | --------------------------------------------------- |
| Docker image digest pinning            | HIGH     | Twenty uses `version = "latest"` — not reproducible |
| Taskwarrior encryption secret rotation | MEDIUM   | Hardcoded deterministic hash is public              |
| Authelia client_secret via sops        | MEDIUM   | Currently hardcoded bcrypt hash inline              |
| Gitea admin password via sops          | MEDIUM   | Plaintext at `/var/lib/gitea/.admin-password`       |

### P5 DEPLOY/VERIFY (0% done — all 13 tasks)

All blocked on evo-x2 physical access. Need to `just switch` and verify:

- [ ] Full NixOS build from clean
- [ ] All services start correctly
- [ ] DNS resolution works with root hints
- [ ] SigNoz metrics flowing
- [ ] Immich photo upload
- [ ] Gitea web UI
- [ ] Homepage dashboard
- [ ] Authelia SSO flow
- [ ] Caddy TLS for all services
- [ ] Hermes Discord bot connectivity
- [ ] Niri desktop session
- [ ] EMEET PIXY camera daemon
- [ ] RPi3 DNS failover

### P9 FUTURE (17% done — 10 of 12 remaining)

| Task                         | Notes                                |
| ---------------------------- | ------------------------------------ |
| Papermark integration        | Researched, not started              |
| NixOS tests (NixOS VM tests) | Not started                          |
| Darwin full parity           | Not started                          |
| DNS-over-QUIC for clients    | Disabled — kills binary cache hits   |
| Full DoQ support             | Needs unbound patch + client support |
| Home Assistant               | Research only                        |
| ComfyUI workflows            | Planned                              |
| Jan AI data migration        | Planned                              |
| GPU partitioning             | Planned                              |
| Multi-seat NixOS             | Planned                              |

### RPi3 DNS Failover Cluster

- ✅ Module written (`dns-failover.nix`)
- ✅ RPi3 image config exists (`rpi3-dns`)
- ❌ Pi 3 hardware NOT provisioned
- ❌ Never tested

---

## d) TOTALLY FUCKED UP

### 🔴 Duplicated fail2ban Configuration

`fail2ban` is configured in **TWO places** with potentially conflicting settings:

1. `platforms/nixos/system/configuration.nix` — uses `daemonSettings.DEFAULT`
2. `modules/nixos/services/security-hardening.nix` — uses `daemonSettings.Definition`

These may silently conflict at runtime. One must be removed.

### 🔴 Docker Prune Duplication

Docker auto-prune is configured in BOTH:

1. `modules/nixos/services/default.nix` — `autoPrune = { enable = true; dates = "weekly"; }`
2. `platforms/nixos/system/scheduled-tasks.nix` — `docker-prune` timer with `lib.mkForce`

The timer uses `mkForce` to resolve the conflict, but the root cause (two definitions) remains.

### 🔴 Twenty CRM — Not Reproducible

`version = "latest"` Docker tag means the container image is non-deterministic. Every `just switch` could pull a different image.

### 🔴 Ollama — Zero Sandboxing

The ollama service runs as user `lars` with `UMask 0007`, no `PrivateTmp`, no `MemoryMax`, no sandboxing whatsoever. It's the least hardened service in the entire stack.

### 🔴 Multiple Services Without Module Guards

Several services reference config from other services without checking if they're enabled:

- `photomap.nix` → `config.services.immich.mediaLocation` (fails if immich disabled)
- `caddy.nix` → `config.services.immich.port` (fails if immich disabled)
- `ai-stack.nix` → `config.services.ai-models.paths` (fails if ai-models disabled)

### 🔴 Unbound control path bug (FIXED this session)

Was using `pkgs.unbound` for `unbound-control` binary instead of `config.services.unbound.package` — could mismatch if package overridden. Fixed in commit `a4c4128`.

---

## e) WHAT WE SHOULD IMPROVE

### 1. Service Hardening Consistency

**Only 44% of services use the shared `harden` function.** Target: 100%.

Priority migration targets:

1. `authelia.nix` — manual inline → `harden`
2. `caddy.nix` — manual inline → `harden`
3. `gitea.nix` main service — NO hardening → `harden`
4. `file-and-image-renamer.nix` — manual inline → `harden`
5. `monitor365.nix` — manual inline → `harden`
6. `ai-stack.nix` (ollama, unsloth) — NO hardening → `harden`

### 2. Service Defaults Consistency

**Only 16% of services use `serviceDefaults`.** All restart-capable services should use it.

### 3. Secrets Cleanup

| Secret                 | Current Location        | Should Be                     |
| ---------------------- | ----------------------- | ----------------------------- |
| Authelia client_secret | Inline bcrypt hash      | sops secret                   |
| Authelia user password | Inline argon2 hash      | sops secret                   |
| Gitea admin password   | Plaintext file          | sops secret                   |
| Gitea admin token      | Plaintext file          | sops secret                   |
| Taskwarrior encryption | Hardcoded in AGENTS.md  | sops secret                   |
| VRRP auth password     | Plaintext in nix config | sops secret (partially fixed) |

### 4. Module Interdependency Guards

Every cross-module reference needs `lib.mkIf` or `lib.optional` guards:

- photomap → immich
- caddy → immich, photomap, authelia
- ai-stack → ai-models

### 5. Documentation Bloat

- 246 docs in `docs/status/` (44 active + 202 archived)
- ~66% of active docs are >80% redundant with the prior one
- 8 recurring unresolved action items repeated across 10+ docs
- Consider: single living status doc, archive everything else

### 6. Docker Reproducibility

- Pin all Docker images to SHA256 digests
- Replace `version = "latest"` with explicit version tags
- Twenty CRM is the worst offender

### 7. Module Size

- `signoz.nix` — 741 lines, should split into query/collector/clickhouse sub-modules
- `niri-wrapped.nix` — 872 lines, could extract session save/restore
- `minecraft.nix` — 454 lines, could extract client options

### 8. RPi3 Deployment

The entire DNS failover cluster is code-only — never tested on hardware. The Pi 3 isn't even provisioned.

---

## f) Top 25 Things to Get Done Next

### P0 — Do This Week

| #   | Task                                                                                                    | Impact   | Effort |
| --- | ------------------------------------------------------------------------------------------------------- | -------- | ------ |
| 1   | **Deploy & verify evo-x2** — `just switch` + validate all services                                      | CRITICAL | High   |
| 2   | **Deduplicate fail2ban config** — remove one of the two definitions                                     | High     | Low    |
| 3   | **Deduplicate docker prune** — remove autoPrune or timer, not both                                      | High     | Low    |
| 4   | **Fix unguarded module refs** — add `mkIf` guards for photomap→immich, caddy→immich, ai-stack→ai-models | High     | Low    |
| 5   | **Migrate authelia to `harden` function**                                                               | Medium   | Low    |
| 6   | **Migrate caddy to `harden` function**                                                                  | Medium   | Low    |
| 7   | **Add `serviceDefaults` to all hardened services**                                                      | Medium   | Low    |

### P1 — Do This Month

| #   | Task                                                               | Impact | Effort |
| --- | ------------------------------------------------------------------ | ------ | ------ |
| 8   | **Pin Twenty CRM Docker image** to SHA256 digest                   | High   | Low    |
| 9   | **Harden ollama service** — add `harden {}` + `serviceDefaults {}` | High   | Medium |
| 10  | **Move authelia secrets to sops** — client_secret, user password   | High   | Medium |
| 11  | **Move gitea admin password to sops**                              | High   | Medium |
| 12  | **Harden gitea main service** — currently no hardening at all      | Medium | Low    |
| 13  | **Harden unsloth services** — ollama, setup, studio                | Medium | Medium |
| 14  | **Add `serviceDefaults` to signoz, hermes, twenty, immich**        | Medium | Low    |
| 15  | **Archive stale status docs** — keep last 5, archive the rest      | Low    | Low    |
| 16  | **Split signoz.nix** into sub-modules (query/collector/clickhouse) | Medium | Medium |

### P2 — Do This Quarter

| #   | Task                                                                                       | Impact | Effort |
| --- | ------------------------------------------------------------------------------------------ | ------ | ------ |
| 17  | **Provision RPi3 hardware** + test DNS failover cluster                                    | High   | High   |
| 18  | **Add NixOS VM tests** for critical services                                               | High   | High   |
| 19  | **Enable DNS-over-QUIC for clients** — fix binary cache hit issue                          | Medium | High   |
| 20  | **Darwin parity** — ensure macOS config is as complete as NixOS                            | Medium | Medium |
| 21  | **Move Taskwarrior encryption secret to sops**                                             | Medium | Low    |
| 22  | **Consolidate documentation** — single living status doc pattern                           | Low    | Medium |
| 23  | **Re-evaluate monitor365** — currently disabled for RAM, worth re-enabling?                | Low    | Low    |
| 24  | **Extract niri session save/restore** into separate module                                 | Low    | Medium |
| 25  | **Add module options for hardcoded paths** (Docker data-root, blocklist working dir, etc.) | Low    | Medium |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is the evo-x2 machine currently running the latest config?**

I can see commits, I can see that `just test-fast` passes, but I have no way to know:

- When was the last successful `just switch`?
- Which generation is currently booted?
- Are all 28 enabled services actually running?
- Does the DNS root-hints change from this session actually work in production?

This requires physical/SSH access to the machine. Every P5 deploy task is blocked on this.

---

## Session Stats

| Metric                        | Value                                                                 |
| ----------------------------- | --------------------------------------------------------------------- |
| Commits this session          | 2 (`39217c7`, `a4c4128`)                                              |
| Files modified this session   | 5 (dns-blocker, rpi3, dns-blocker-config, dns-blocklists, flake.lock) |
| Unstaged changes              | 2 (flake.lock hermes+NUR update, blocklist hash refresh)              |
| Services enabled              | 28                                                                    |
| Services hardened             | 11/25+ (44%)                                                          |
| Services with serviceDefaults | 4/25+ (16%)                                                           |
| Total TODO tasks              | 95 (62 done = 65%)                                                    |
| ADRs                          | 5                                                                     |
| Flake inputs                  | 34                                                                    |
| Justfile recipes              | ~90+                                                                  |
| Doc files                     | 246 (44 active + 202 archived)                                        |
| Known security issues         | 4 unfixed, 8 fixed                                                    |

---

_Arte in Aeternum_
