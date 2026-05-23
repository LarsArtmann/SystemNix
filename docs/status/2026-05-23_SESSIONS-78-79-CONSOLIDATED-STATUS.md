# Sessions 78–79 — Consolidated Status Report

**Date:** 2026-05-23 | **Covers:** Sessions 78 (06:44 → 10:44) + 79 (12:36)
**Platform:** NixOS unstable (nixos-unstable) | **Kernel:** 6.x
**Host:** evo-x2 (GMKtec Strix Halo, 128 GB RAM, AMD GPU)
**Branch:** master — **up to date with origin**

---

## Executive Summary

Three work phases over a single day:

1. **Session 78 pre-execution** (06:44) — Documented 8 commits from Sessions 76–77: boot performance (serial8250 blacklist, **1m31s** saved from initrd), display-watchdog rewrite (systemd `--machine` mode), ZRAM swap doubled (5%→10%), flake lock mass update (25+ inputs), homepage memory hardening (V8 heap cap 192M + 384M cgroup), and BuildFlow vendorHash fix.

2. **Session 78 execution** (10:44) — 10 more commits: all Docker `latest` tags pinned (twenty v2.7.3, manifest 6.6.1, openseo v0.0.15), `tasks.${domain}` forward-auth, swap-critical SigNoz alert, centralized port registry (`lib/ports.nix`, 26 ports), GPU config consolidation (`lib/rocm.nix`), `dockerImageTag` type rejecting `"latest"` at eval time, Gatus health checks for Hermes + EMEET PIXY, voice-agents Caddy vhosts consolidated with TLS + forward-auth, gpu-recovery dead code removed, manifest CORS fixed.

3. **Session 79** (12:36) — Investigated and fixed Jan AI auto-starting on every login (spawning 1 GiB GPU-loaded `llama-server`). Root cause: niri-session-manager restoring Jan from saved session. Added `"Jan"` to `skip_apps`. Also diagnosed gopls at 9 procs / ~5.8 GiB with no per-instance caps.

**Total: 19+ commits undeployed**, all awaiting `just switch` + reboot (ZRAM resize requires reboot). System is stable — no crashes since Session 76 GPU recovery rewrite.

---

## A) FULLY DONE ✅

### Session 78 Execution (10 commits)

| Commit | Description | Impact |
|--------|-------------|--------|
| `bccf73c5` | Pin Docker image tags: twenty→v2.7.3, manifest→6.6.1, openseo→v0.0.15 | Reproducibility |
| `bd14e13b` | Add forward-auth to `tasks.${domain}` via `protectedVHost` | Security |
| `8801c2d7` | Add swap-critical alert rule (>80%) to SigNoz | Monitoring |
| `b0f858e7` | Create `lib/ports.nix` — centralized port registry (26 ports) | Architecture |
| `c027aa31` | Consolidate `HSA_OVERRIDE_GFX_VERSION` via `lib/rocm.nix` | DRY |
| `bc98e09f` | Fix manifest CORS_ORIGIN + remove gpu-recovery dead code | Bug fix |
| `7c1dd5a2` | Add `dockerImageTag` type that rejects `"latest"` at eval time | Type safety |
| `3d1fbc93` | Add Gatus health checks for Hermes + EMEET PIXY | Monitoring |
| `4824008b` | Consolidate voice-agents Caddy vhosts with TLS + forward-auth | Security |
| `00137dcf` | Update AGENTS.md with new patterns | Documentation |

### Sessions 76–77 (8 commits)

| Commit | Description | Impact |
|--------|-------------|--------|
| `6f0be6ca` | Blacklist serial8250 — eliminates 1m31s initrd timeout | Boot perf |
| `f757cc0b` | Add gopls to earlyoom `--prefer` list | OOM targeting |
| `9f6c418b` | Flake lock mass update (25+ inputs) + earlyoom/watchdog rewrites | Deps + crash prevention |
| `08c267ce` | display-watchdog: `systemctl --user -M` for niri restart | Fix system→user context |
| `b6ce680f` | display-watchdog: pass PRIMARY_USER env var | Fix system→user context |
| `c67277f3` | ZRAM swap 5%→10% (6.4→12.8 GiB) | Swap headroom |
| `87109b85` | Homepage Docker memory constraints (V8 heap 192M + cgroup 384M) | Prevent node OOM |
| `e2a88535` | BuildFlow vendorHash fix for updated deps | Build fix |

### Session 79 — Jan Autostart Fix (undeployed)

- Added `"Jan"` to `skip_apps` in niri-session-manager config
- **Root cause chain:** niri-session-manager restores Jan from `session.json` → Jan restores last thread → thread has model binding → `@janhq/llamacpp-extension` launches `llama-server` with `-ngl 99` (1 GiB, full GPU)
- niri-session-manager has no crash-vs-clean-shutdown distinction — `skip_apps` is the only control

### Previously Done (Sessions 74–76, still valid)

- Hermes extraDependencyGroups expanded (firecrawl, edge-tts, fal, exa)
- GPU recovery replaced with niri restart — deployed & working
- Nix versioning for all 16 LarsArtmann repos
- Service target restructuring to graphical.target
- `/tmp` as tmpfs

---

## B) PARTIALLY DONE 🔧

### Memory Management

- **Done:** ZRAM doubled, gopls in OOM prefer, homepage constrained, swap alert rule
- **Not done:** No runtime verification — all changes undeployed
- **Not done:** gopls at 9 procs / ~5.8 GiB — `GOMEMLIMIT` not yet configured
- **Not done:** Docker container memory audit (deer-flow-frontend at 1.4 GB, no limit)
- **Not done:** Port 3001 conflict (monitor365-server vs openseo) — documented but not resolved

### Hermes Service

- **Working:** Discord, Anthropic, firecrawl, edge-tts, fal, exa extras loaded without ImportError
- **Broken:** Git `origin` remote unreachable from sandbox (no SSH deploy key)
- **Broken:** `sudo` blocked by `NoNewPrivileges=yes` systemd hardening
- **Untested:** Whether firecrawl/edge-tts/fal/exa tools actually work at runtime (import ≠ functional)
- **Tech debt:** `MemoryMax = "24G"` (absurdly high)

### Security

- **Done:** Docker tags pinned, tasks vhost protected, voice-agents vhosts protected with TLS + forward-auth
- **Not done:** OpenSEO `AUTH_MODE: local_noauth` — completely unauthenticated
- **Not done:** Forgejo admin password in plaintext file (not sops-managed)
- **Not done:** Authelia client secrets hardcoded as single bcrypt hash shared across all OIDC clients
- **Not done:** Only 2 OIDC clients registered (immich, forgejo) — hermes, twenty, openseo, voice-agents, homepage all lack SSO

### Documentation

- **Done:** AGENTS.md updated with new patterns (ports, dockerImageTag, caddy pattern)
- **Not done:** FEATURES.md still stale (ZRAM 50%→10%, boot time wrong, phantom scripts)
- **Not done:** TODO_LIST.md not updated since Session 75

### service-health-check

- Failing every ~15 minutes with exit-code (ongoing since Session 76)
- Not investigated — low priority but creates log noise

---

## C) NOT STARTED ⏳

### Infrastructure (Needs Deploy First)

- [ ] `just switch` + reboot to deploy all 19+ undeployed commits
- [ ] Verify boot time reduced (~2m20s expected from ~3m54s)
- [ ] Verify homepage memory ~150–200 MB (from 1–2 GB)
- [ ] Verify display-watchdog restarts niri correctly
- [ ] Verify ZRAM increased to 10% after reboot
- [ ] Verify Jan no longer auto-starts after reboot

### Hermes

- [ ] Configure secondary LLM provider (OpenRouter/OpenAI fallback)
- [ ] Fix Hermes git remote access (SSH deploy key)
- [ ] Fix Hermes sudo access (NoNewPrivileges blocks systemctl)
- [ ] Verify firecrawl/edge-tts/fal/exa tools work at runtime

### Security

- [ ] Investigate OpenSEO auth options (`local_auth` vs OIDC)
- [ ] Move Forgejo admin password to sops
- [ ] Register more OIDC clients in Authelia (hermes, twenty, openseo, voice-agents)
- [ ] Enable Immich hardware acceleration (GPU available, unused for transcoding)
- [ ] Investigate Ollama `wantedBy = []` — document rationale or fix

### Observability

- [ ] Check SigNoz provision logs — verify dashboards + rules created
- [ ] Test Discord alert channel
- [ ] Verify Gatus endpoints at `status.home.lan`
- [ ] Add SigNoz per-threshold channel routing (critical→Discord, warning→log)
- [ ] Add memory/swap alerting to Gatus (80% mem, 50% swap)

### Code Quality

- [ ] Migrate services to use `lib/ports.nix` constants (currently reference docs only)
- [ ] Resolve port 3001 conflict (monitor365-server vs openseo)
- [ ] Fix `nix fmt` / shfmt script damage — exclude `.sh` from shfmt or fix formatter config
- [ ] Fix FEATURES.md — ZRAM 50%→10%, boot time, remove phantom scripts
- [ ] Update TODO_LIST.md
- [ ] Flake inputs audit — 47 inputs, find stale/unused
- [ ] Consolidate watchdog state management into shared `lib/watchdog-state.sh`
- [ ] Add display-state metrics to niri-health-metrics

### Hardware / External

- [ ] Provision Pi 3 for DNS failover cluster
- [ ] Wire Pi 3 as secondary DNS
- [ ] Darwin config parity check
- [ ] Deploy Dozzle at `logs.home.lan`
- [ ] Create `just status` command
- [ ] File niri-session-manager feature request: `crash_only_apps`

---

## D) TOTALLY FUCKED UP 💀

### 1. 19+ Commits Undeployed

All work since May 22 is committed and pushed but NOT running. Serial8250 blacklist (saves 1m31s boot), homepage memory cap (saves 1–2 GB RAM), ZRAM expansion, watchdog rewrites, all security fixes, Jan autostart skip — all theoretical until `just switch` + reboot. If OOM happens again before deploy, same black screen (old watchdog blind spots).

### 2. Port 3001 Conflict: monitor365 vs openseo

Both services default to port 3001. Port registry documents this but doesn't fix it. If both run simultaneously, one fails to bind.

### 3. `nix fmt` Damages Shell Scripts

`nix fmt` (treefmt → shfmt) reformatted `scripts/update-vendor-hash.sh` and `scripts/versions.sh`, mangling bash associative array keys (hyphens → spaces). Files were restored from git. Running `nix fmt`, `just format`, or the pre-commit hook on staged `.sh` files will silently break them.

### 4. OpenSEO: No Authentication

`AUTH_MODE: local_noauth` — the SEO suite has ZERO auth. Behind Caddy + Authelia forward-auth, but if Authelia is bypassed or misconfigured, it's wide open.

### 5. Authelia Client Secret: Single Hardcoded Hash

ALL OIDC clients share the SAME bcrypt client secret hash, hardcoded in the nix module. Not managed via sops. Any rotation requires changing nix code and redeploying.

### 6. Forgejo Admin Password in Plaintext

Auto-generated from `/dev/urandom`, stored at `/var/lib/forgejo/admin-password`. Any process on the machine can read it.

### 7. FEATURES.md and TODO_LIST.md Are Stale

FEATURES.md claims ZRAM is "50% of RAM (64GB)" — actual is 10% (~12.8 GB). 4 referenced scripts don't exist. TODO_LIST.md boot time estimate says "~35s" — never achieved.

### 8. Ollama Won't Autostart

`wantedBy = lib.mkForce []` means Ollama never auto-starts. Either deliberate GPU memory management (Ollama reserves VRAM even idle, `OLLAMA_GPU_OVERHEAD=8589934592` = 8 GB) or a debugging measure that became permanent. Needs documentation.

### 9. Immich Hardware Acceleration Disabled

`accelerationDevices = null` — not using the GPU for image/video transcoding on a machine with a powerful AMD GPU.

### 10. Service Hardening Inconsistencies

| Service | Weakened Setting | Reason |
|---------|-----------------|--------|
| Hermes | `MemoryMax = "24G"`, `ProtectHome = false` | Filesystem access |
| Voice Agents | `RestrictNamespaces = false`, `NoNewPrivileges = false` | Docker integration |
| OpenSEO | `ProtectHome = false`, `NoNewPrivileges = false` | Unknown |
| Immich (server+ML) | `ProtectHome = false`, `ProtectSystem = false` | Data access |
| AI Stack (Ollama) | `ProtectHome = false`, `NoNewPrivileges = false` | GPU access |
| Forgejo | `NoNewPrivileges = false` | Git operations |

---

## E) WHAT WE SHOULD IMPROVE 📈

### Critical (Before Next Deploy)

1. **DEPLOY** — `just switch` + reboot. OOM watchdog fixes are critical, ZRAM needs reboot.
2. **gopls memory limits** — `GOMEMLIMIT=1GiB` via Nix config. 9 instances × 1 GiB = 9 GiB cap vs uncontrolled growth.
3. **Fix `nix fmt` script damage** — exclude shell scripts from shfmt or fix formatter config.
4. **Investigate service-health-check failures** — every 15 min for days.

### Post-Deploy Verification

5. **Verify boot time** — serial8250 blacklist should cut ~1m31s from initrd.
6. **Verify homepage memory** — V8 cap should bring it from 1–2 GB to ~200 MB.
7. **Verify manifest CORS** — fix changes `CORS_ORIGIN` from localhost to domain URL.
8. **Verify Jan skip** — confirm Jan doesn't auto-start after login.

### Security Debt

9. **Investigate OpenSEO auth** — determine if `local_auth` or OIDC is viable.
10. **Move Forgejo admin password to sops** — eliminate plaintext credential.
11. **Document Ollama `wantedBy = []`** rationale — or fix it.

### Architecture

12. **Consolidate watchdog state management** — three scripts with separate state persistence → `lib/watchdog-state.sh`.
13. **Test display recovery chain** — never verified `systemctl --user -M lars@` from display-watchdog system context.
14. **Resolve port 3001 conflict** — change one service to a different port.
15. **Migrate services to use `lib/ports.nix`** constants (currently reference docs only).
16. **Docker MemoryMax for SigNoz/Twenty** — not just Homepage.
17. **Service startup parallelism** — hermes 77s, twenty 49s, manifest 48s start sequentially.

### Documentation

18. **Fix FEATURES.md** — ZRAM 50%→10%, remove phantom scripts, update boot time.
19. **Update TODO_LIST.md** — mark completed items, update estimates.

### Operational

20. **Automated disk cleanup** — at 84% and trending up. Need nix-store GC automation.
21. **Create `just status` command** — automate status report generation.
22. **Deploy Dozzle** at `logs.home.lan` — Docker log tailing.

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Est. | Impact |
|---|----------|------|------|--------|
| 1 | **P0** | `just switch` + reboot — deploy ALL 19+ undeployed commits | 30m | Prevents repeat crash |
| 2 | **P0** | Verify watchdog rewrites work after deploy | 10m | Confirms crash fix |
| 3 | **P0** | Verify ZRAM increased to 10% after reboot | 2m | Confirms swap headroom |
| 4 | **P0** | Verify Jan no longer auto-starts after reboot | 2m | Confirms skip_apps |
| 5 | **P0** | Add `GOMEMLIMIT=1GiB` to gopls via Nix config | 15m | Caps gopls memory |
| 6 | **P0** | Fix `nix fmt` / shfmt script damage — exclude `.sh` or fix config | 15m | Prevents silent breakage |
| 7 | **P0** | Investigate service-health-check failures (every 15 min) | 20m | Stops alert spam |
| 8 | **P1** | Configure secondary LLM provider for Hermes | 30m | Hermes resilience |
| 9 | **P1** | Verify Hermes firecrawl/edge-tts/fal/exa at runtime | 15m | Confirms extras work |
| 10 | **P1** | Hermes git remote access (SSH deploy key) | 30m | Repo access |
| 11 | **P1** | Resolve port 3001 conflict (monitor365 vs openseo) | 10m | Prevents bind failure |
| 12 | **P1** | Docker MemoryMax for SigNoz/Twenty (not just Homepage) | 20m | Prevents memory runaway |
| 13 | **P1** | Investigate OpenSEO auth — can `local_auth` work? | 20m | Security |
| 14 | **P1** | Move Forgejo admin password to sops | 15m | Security |
| 15 | **P1** | Consolidate watchdog state management into shared lib | 45m | DRY, fewer bugs |
| 16 | **P1** | Add memory/swap alerting to Gatus (80% mem, 50% swap) | 30m | Early warning |
| 17 | **P2** | Fix FEATURES.md — ZRAM, boot time, phantom scripts | 15m | Doc accuracy |
| 18 | **P2** | Update TODO_LIST.md with current state | 15m | Doc accuracy |
| 19 | **P2** | Check SigNoz provision logs — verify dashboards/rules | 30m | Observability |
| 20 | **P2** | Test Discord alert channel | 10m | Alerting verification |
| 21 | **P2** | Deploy Dozzle at `logs.home.lan` | 45m | Real-time Docker logs |
| 22 | **P3** | Flake inputs audit — 47 inputs, find stale | 2h | Dependency hygiene |
| 23 | **P3** | Provision Pi 3 for DNS failover cluster | 4h | DNS resilience |
| 24 | **P3** | Investigate boot time: 1m44s initrd (post-serial8250) | 60m | Faster reboots |
| 25 | **P4** | Darwin config parity check | 2h | Cross-platform health |

---

## G) TOP #1 QUESTION 🤔

**When can we run `just switch` + reboot?**

19+ undeployed commits including critical OOM crash fixes, watchdog rewrites, ZRAM increase, and Jan autostart skip. The system is running with old code that has the watchdog blind spots. Deploying requires a reboot (ZRAM resize) and active work may be disrupted.

Additionally: `llama-server` (1 GiB, GPU-loaded from Jan) is still running from before the skip_apps fix and won't go away until next reboot/login.

---

## System Vital Signs (Pre-Deploy)

| Metric | Value | Status |
|--------|-------|--------|
| **Branch** | master, up to date with origin | ✅ |
| **Build** | `just test-fast` passes, zero warnings | ✅ |
| **Undeployed commits** | 19+ (Sessions 76–79) | ⚠️ |
| **.nix files** | 112 | — |
| **Service modules** | 33 registered in flake.nix | — |
| **Flake inputs** | 47 | — |
| **SigNoz alert rules** | 17 (swap-critical added) | ✅ |
| **Gatus endpoints** | 26 (Hermes + EMEET PIXY added) | ✅ |
| **Docker tags pinned** | 3/3 (twenty, manifest, openseo) | ✅ |
| **Port registry** | 26 ports, 1 conflict documented | ⚠️ |
| **Security debt** | OpenSEO no auth, Forgejo plaintext, Authelia hardcoded | 🔴 |

### Live Metrics (Session 79, 12:36)

| Metric | Value | Status |
|--------|-------|--------|
| **Uptime** | 6h 56m | 🟢 Stable |
| **RAM** | 43/62 GiB (69%) | 🟡 Normal |
| **Swap** | 9.4/13 GiB (72%) | 🟡 High |
| **Disk** | 416/512 GiB (84%) | 🟡 Trending up |
| **Load** | 1.65 | 🟢 Light |
| **gopls** | 9 procs, ~5.8 GiB | 🟡 Top consumer |
| **crush** | 12 procs, ~1.2 GiB | 🟢 |
| **llama-server** | 1 proc, ~1 GiB | 🟡 (Jan, running) |
| **helium** | 15 procs, ~1.3 GiB | 🟢 |
| **Display** | connected, enabled, dpms=On | 🟢 |
| **service-health-check** | Failing every 15 min | 🔴 |

---

## Services Status

| Service | Enabled | Deployed | Issues |
|---------|---------|----------|--------|
| **Caddy** | ✅ | ✅ | All vhosts consolidated in caddy.nix |
| **Forgejo** | ✅ | ✅ | Admin password in plaintext |
| **Immich** | ✅ | ✅ | HW acceleration disabled |
| **Authelia** | ✅ | ✅ | 2 OIDC clients only, hardcoded secrets |
| **Homepage** | ✅ | ✅ | Memory fix committed, undeployed |
| **SigNoz** | ✅ | ✅ | 17 rules, swap-critical added |
| **Twenty** | ✅ | ✅ | Tag pinned to v2.7.3 |
| **Voice Agents** | ✅ | ✅ | Caddy vhosts now protected |
| **Hermes** | ✅ | ✅ | Git/sudo broken, tools untested, MemoryMax=24G |
| **Ollama** | ✅ | ❌ No autostart | `wantedBy = []` — rationale unknown |
| **Manifest** | ✅ | ✅ | Tag pinned to 6.6.1, CORS fixed |
| **OpenSEO** | ✅ | ✅ | Tag pinned to v0.0.15, **no auth** |
| **TaskChampion** | ✅ | ✅ | Forward-auth added, undeployed |
| **Gatus** | ✅ | ✅ | 26 endpoints, Hermes + EMEET PIXY added |
| **Monitor365** | ✅ | ✅ | Port 3001 conflict with openseo |
| **Deer Flow** | ✅ | ✅ | Frontend 1.4 GB, no memory limit |
| **DNS Blocker** | ✅ | ✅ | DoQ disabled (no ngtcp2) |
| **Dual WAN** | ✅ | ✅ | Clean |
| **Disk Monitor** | ✅ | ✅ | Clean |
| **NVMe Health** | ✅ | ✅ | Hardcoded /dev/nvme0n1 |
| **Display Manager** | ✅ | ✅ | Fix committed, undeployed |
| **Niri** | ✅ | ✅ | gpu-recovery dead code removed |
| **AI Models** | ✅ | ✅ | Clean |
| **PhotoMap** | ❌ | — | Disabled (podman permissions) |
| **Minecraft** | ❌ | — | Disabled |
| **File Renamer** | ❌ | — | Disabled (Go 1.26.3 blocker) |

---

## Architecture Overview

```
evo-x2 (GMKtec Strix Halo, 128GB RAM, AMD GPU)
├── Boot: systemd-boot → NixOS unstable
├── Desktop: Niri (Wayland) + Waybar
├── Networking: Dual-WAN (eno1 + wlan0, MPTCP) + Unbound DNS
├── Reverse Proxy: Caddy (auto_https off, dnsblockd certs)
├── Auth: Authelia (SSO/OIDC, 2 clients)
├── Observability: SigNoz (17 rules) + Gatus (26 endpoints) + cAdvisor + Node Exporter
├── AI: Ollama (no autostart) + gpu-python + AI Models + Jan (skip_apps)
├── CRM: Twenty (Docker, pinned v2.7.3)
├── Media: Immich (no GPU accel)
├── Dev: Forgejo + TaskChampion
├── Dashboards: Homepage + Manifest (LLM router, pinned 6.6.1) + OpenSEO (no auth, pinned v0.0.15)
├── Voice: Whisper-asr + LiveKit (Docker)
├── Agent: Hermes (6 extras, git/sudo broken)
├── Monitoring: Monitor365 + Disk Monitor + NVMe Health
└── DNS: Unbound + dnsblockd + dual-WAN failover
```

### New This Session

```
lib/
├── ports.nix          ← NEW: centralized port registry (26 ports)
├── types.nix          ← UPDATED: added dockerImageTag type
└── default.nix        ← UPDATED: exports `ports`

modules/nixos/services/
├── caddy.nix          ← UPDATED: added voice/whisper vhosts with TLS + forward-auth
├── gatus-config.nix   ← UPDATED: added Hermes + EMEET PIXY checks
├── manifest.nix       ← UPDATED: pinned tag, dockerImageTag type, fixed CORS
├── niri-config.nix    ← UPDATED: removed gpu-recovery dead code
├── openseo.nix        ← UPDATED: pinned tag, dockerImageTag type
├── signoz-alerts.nix  ← UPDATED: added swap-critical rule
├── twenty.nix         ← UPDATED: pinned tag to v2.7.3
├── voice-agents.nix   ← UPDATED: rocm.nix import, removed inline Caddy vhosts
└── ai-stack.nix       ← UPDATED: rocm.nix in gpu-python wrapper
```

---

## Full Commit History (Sessions 76–79)

```
95aeca25 fix(session): prevent Jan AI from auto-starting on every login + session 79 status
260125fa docs(status): Session 78 post-execution comprehensive status
00137dcf docs(AGENTS.md): document new lib helpers, dockerImageTag type, and caddy pattern
4824008b fix(security): consolidate voice-agents Caddy vhosts with TLS + forward-auth
3d1fbc93 feat(monitoring): add Gatus health checks for Hermes and EMEET PIXY
7c1dd5a2 feat(types): add dockerImageTag type that rejects 'latest'
bc98e09f fix(manifest) + refactor(niri): fix CORS origin + remove gpu-recovery dead code
c027aa31 refactor(gpu): consolidate HSA_OVERRIDE_GFX_VERSION via lib/rocm.nix
b0f858e7 feat(lib): add centralized port registry to prevent conflicts
8801c2d7 feat(monitoring): add swap usage critical alert rule to SigNoz
bd14e13b fix(security): add forward-auth to tasks.${domain} vhost
bccf73c5 fix(security): pin Docker image tags to specific versions
67fc1bda docs(planning): Session 78 comprehensive execution plan
fe4c4204 docs(status): Session 78 comprehensive status
87109b85 perf(homepage): add memory constraints to prevent unbounded Node.js growth
c67277f3 perf(boot): increase ZRAM swap from 5% to 10% of RAM
b6ce680f fix(display-watchdog): pass PRIMARY_USER env var to display-watchdog service
08c267ce fix(display-watchdog): use systemd --machine mode for --user service restart
9f6c418b chore(deps): update flake.lock with latest revisions across all inputs
f757cc0b perf(boot): add gopls to OOM killer prefer list as primary victim
6f0be6ca perf(boot): blacklist serial8250 to eliminate 1m31s initrd device timeout
e2a88535 fix(buildflow): update vendorHash for updated dependencies
```

---

_Arte in Aeternum_
