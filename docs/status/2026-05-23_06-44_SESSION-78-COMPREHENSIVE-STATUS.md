# Session 78 — Full Comprehensive Status Report

**Date:** 2026-05-23 06:44 CEST
**Platform:** NixOS unstable (nixos-unstable) | **Kernel:** 6.x
**Branch:** master — **up to date with origin**
**Previous Report:** Session 76 (2026-05-21 23:45)

---

## Executive Summary

8 commits since Session 76, spanning boot performance (serial8250 blacklist eliminated **1m31s** from initrd), display-watchdog fix (systemd --machine mode), ZRAM swap doubled (5%→10%), flake lock mass update (25+ inputs), homepage memory hardening (V8 heap cap + cgroup limit), and BuildFlow vendorHash fix. System is **stable and functional** — no crashes since the GPU recovery rewrite (Session 76). The serial8250 blacklist was the biggest single boot win, likely bringing initrd from 1m44s down to ~13s. Homepage memory was constrained from unbounded 1-2GB → hard 384M cgroup / 192M V8 heap.

**Remaining risks:** 3 Docker services use `"latest"` tags (non-reproducible), OpenSEO runs without auth, Forgejo admin password in plaintext, and Authelia client secrets hardcoded in nix. These are security debt that should be addressed before exposing services beyond the local network.

---

## A) FULLY DONE ✅

### 1. Boot Performance: serial8250 Blacklist (`6f0be6ca`)
- **Problem:** initrd spent 1m31s waiting for phantom serial ports (ttyS0-S3) on a machine with no serial hardware
- **Fix:** `module_blacklist=serial8250` in kernel params
- **Expected impact:** initrd drops from ~1m44s to ~13s — total boot ~2m15s
- **Status:** Committed, **not yet deployed** (awaiting `just switch`)

### 2. ZRAM Swap Expansion (`c67277f3`)
- **Before:** 5% of RAM (~6.4 GB compressed)
- **After:** 10% of RAM (~12.8 GB compressed)
- **Rationale:** System ran 16h at swap 0% then crashed — buffer was too small for AI workload spikes
- **Status:** Committed, **not yet deployed**

### 3. gopls OOM Priority (`f757cc0b`)
- Added gopls to OOM killer prefer list — kernel will kill gopls first under memory pressure
- gopls is a known memory hog (2-4 GB per instance, multiple instances common)
- **Status:** Committed, **not yet deployed**

### 4. Display Watchdog Fix (`08c267ce`, `b6ce680f`)
- **Problem:** system-level service couldn't restart user-level niri service (no D-Bus session)
- **Fix:** `systemctl --user -M "${PRIMARY_USER}@" restart niri.service` + PRIMARY_USER env var
- **Status:** Committed, **not yet deployed**

### 5. Flake Lock Mass Update (`9f6c418b`)
- 25+ inputs updated: all LarsArtmann Go repos, home-manager, NUR, niri, nixpkgs, helium
- **Status:** Committed, **not yet deployed**

### 6. Homepage Memory Constraints (`87109b85`, this session)
- `NODE_OPTIONS=--max-old-space-size=192` — caps V8 heap
- `MemoryMax = "384M"` — systemd cgroup hard limit
- **Rationale:** Homepage was consuming 1-2 GB due to Node.js V8 GC laziness on high-RAM systems
- **Status:** Committed, **not yet deployed**

### 7. BuildFlow vendorHash Fix (`e2a88535`)
- Stale vendorHash after go-branded-id/go-output version bumps from flake lock update
- **Status:** Committed, **not yet deployed**

### Previously Done (Session 75-76, Still Valid)
- Hermes extraDependencyGroups expanded (firecrawl, edge-tts, fal, exa) — deployed & running
- GPU recovery replaced with niri restart — deployed & working
- Nix versioning for all 16 LarsArtmann repos — complete
- Service target restructuring to graphical.target — deployed
- `/tmp` as tmpfs — deployed

---

## B) PARTIALLY DONE 🔧

### 1. Boot Performance
- **Done:** serial8250 blacklisted, TPM disabled, tmpfs for /tmp, service target restructuring
- **Remaining:** All recent commits NOT YET DEPLOYED — boot time gains are theoretical until `just switch`
- **Expected after deploy:** Firmware 32s + Loader 4s + Kernel 2s + Initrd ~13s + Userspace ~90s = **~2m20s** (down from 3m54s)

### 2. Hermes Service
- **Working:** Discord, Anthropic, firecrawl, edge-tts, fal, exa extras loaded without ImportError
- **Broken:** Git `origin` remote unreachable from sandbox (no SSH deploy key)
- **Broken:** `sudo` blocked by `NoNewPrivileges=yes` systemd hardening
- **Untested:** Whether firecrawl/edge-tts/fal/exa tools actually WORK at runtime (import ≠ functional)
- **Tech debt:** `MemoryMax = "24G"` (absurdly high), `fixedHash` workaround for upstream npmDepsHash bug

### 3. Memory Management
- **Done:** ZRAM doubled, gopls in OOM prefer list, homepage constrained
- **Not done:** No automated memory/swap alerting in SigNoz or Gatus
- **Not done:** Docker container memory audit (deer-flow-frontend at 1.4 GB, no limits)

### 4. Security
- **Done:** Authelia SSO protecting most services, sops for secrets
- **Not done:** OpenSEO has `AUTH_MODE: local_noauth` — completely unauthenticated
- **Not done:** Forgejo admin password in plaintext file (not sops-managed)
- **Not done:** Authelia client secrets are a single hardcoded bcrypt hash shared across all OIDC clients
- **Not done:** `tasks.${domain}` vhost unprotected by forward-auth in Caddy

### 5. TODO_LIST.md / FEATURES.md
- **TODO_LIST.md:** Last updated Session 75 — many items are stale (boot time "expected ~35s" is wrong, ZRAM % wrong)
- **FEATURES.md:** ZRAM says "50% of RAM (64GB)" — actual is 10% (~12.8GB). 4 referenced scripts don't exist.

---

## C) NOT STARTED ⏳

### Infrastructure
- [ ] **Deploy all committed changes** — 8 commits awaiting `just switch`
- [ ] **Verify boot time** after serial8250 blacklist — should see dramatic improvement
- [ ] **Verify homepage memory** settles at ~150-200 MB after deploy
- [ ] **Configure secondary LLM provider** for Hermes (OpenRouter/OpenAI as GLM-5.1 fallback)
- [ ] **Hermes git remote access** — SSH deploy key for sandbox
- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix

### Observability
- [ ] **Check SigNoz provision logs** — verify dashboards + rules created
- [ ] **Test Discord alert channel** — `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints** — `status.home.lan` healthy
- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log)
- [ ] **Add memory/swap alerting** to SigNoz or Gatus

### Code Quality
- [ ] **Pin Docker image tags** — twenty, manifest, openseo all use `"latest"`
- [ ] **Add auth to OpenSEO** — currently `local_noauth`
- [ ] **Move Forgejo admin password to sops**
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern
- [ ] **Flake inputs audit** — 47 inputs, find stale/unused ones
- [ ] **nix-colors integration** — migrate 17+ hardcoded colors (~6h)
- [ ] **Deploy Dozzle** at logs.home.lan for Docker log tailing
- [ ] **Create `just status` command** for automated status reports
- [ ] **Convert go-auto-upgrade `path:` inputs to SSH URLs**
- [ ] **Create shared flake-parts template** (mkGoPackage, checks, devshells)

### Darwin
- [ ] **Darwin config parity check** — ensure macOS config hasn't drifted
- [ ] **Disk space management** — Darwin at 90-95% full, 229 GB disk

---

## D) TOTALLY FUCKED UP 💀

### 1. Homepage Memory (ROOT CAUSE: Node.js V8 GC laziness)
- **Was consuming 1-2 GB** for a static dashboard with health probes
- Root cause: V8 defaults to ~1.5 GB heap ceiling on 64-bit systems with available RAM. GC doesn't reclaim until approaching the limit. Homepage barely needs 150 MB.
- **Fix applied:** `--max-old-space-size=192` + `MemoryMax=384M` — **NOT YET DEPLOYED**

### 2. Docker `latest` Tags — Reproducibility Time Bomb
- **twenty.nix:** `imageTag = "latest"` — every deploy pulls whatever Docker Hub has today
- **manifest.nix:** `imageTag = "latest"` — same problem
- **openseo.nix:** `imageTag = "latest"` — same problem
- This is fundamentally incompatible with Nix's reproducibility guarantee. A `just switch` today and a `just switch` next month may produce different running systems.

### 3. OpenSEO: No Authentication
- `AUTH_MODE: local_noauth` — the SEO suite has ZERO auth
- Exposed at `seo.${domain}` behind Caddy + Authelia forward-auth, but if Authelia is bypassed or misconfigured, the service is wide open
- Should use `AUTH_MODE: local_auth` or integrate with Authelia OIDC

### 4. Authelia Client Secret: Single Hardcoded Hash
- ALL OIDC clients (immich, forgejo) share the SAME bcrypt client secret hash, hardcoded directly in the nix module
- Not managed via sops — any rotation requires changing nix code and redeploying
- New OIDC clients (hermes, voice-agents, twenty, openseo) need to be registered

### 5. Forgejo Admin Password in Plaintext
- Auto-generated from `/dev/urandom`, stored in a plaintext file at `/var/lib/forgejo/admin-password`
- Not in sops — any process on the machine can read it
- Should be managed via sops or at minimum file permissions restricted further

### 6. Immich Hardware Acceleration Disabled
- `accelerationDevices = null` — not using the GPU for image/video transcoding
- On a machine with a powerful AMD GPU, this wastes CPU cycles and makes video playback slower

### 7. FEATURES.md and TODO_LIST.md Are Stale
- FEATURES.md claims ZRAM is "50% of RAM (64GB)" — actual is 10% (~12.8GB)
- 4 referenced scripts in FEATURES.md don't exist (marked ❌ BROKEN)
- TODO_LIST.md boot time estimate says "~35s" — never achieved, initrd alone was 1m44s

### 8. Service Hardening Inconsistencies
Multiple services have significantly weakened systemd sandboxing:
| Service | Weakened Setting | Reason |
|---------|-----------------|--------|
| Hermes | `MemoryMax = "24G"`, `ProtectHome = false` | Needs filesystem access |
| Voice Agents | `RestrictNamespaces = false`, `NoNewPrivileges = false` | Docker integration |
| OpenSEO | `ProtectHome = false`, `NoNewPrivileges = false` | Unknown |
| Immich (server+ML) | `ProtectHome = false`, `ProtectSystem = false` | Needs data access |
| AI Stack (Ollama) | `ProtectHome = false`, `NoNewPrivileges = false` | GPU access |
| Forgejo | `NoNewPrivileges = false` | Git operations |

---

## E) WHAT WE SHOULD IMPROVE 📈

### Critical (Do Before Anything Else)
1. **DEPLOY ALL COMMITTED CHANGES** — 8 commits sitting undeployed since May 22. The serial8250 blacklist alone saves 1m31s per boot. Homepage memory fix prevents OOM cascading.
2. **Pin Docker image tags** — replace all `"latest"` with specific versions for twenty, manifest, openseo
3. **Add auth to OpenSEO** — change `local_noauth` to `local_auth` or integrate OIDC
4. **Move Forgejo admin password to sops** — eliminate plaintext credential storage

### High Impact
5. **Verify Hermes tools work at runtime** — firecrawl/edge-tts/fal/exa import cleanly but are untested functionally
6. **Configure secondary LLM provider** — GLM-5.1 is SPOF for all Hermes automation
7. **Fix Hermes git remote access** — SSH deploy key for sandboxed service
8. **Add memory/swap alerting** to SigNoz or Gatus — the system crashed from OOM and there's still no automated warning
9. **Audit Docker container memory limits** — deer-flow-frontend at 1.4 GB with no limit

### Architecture
10. **Consolidate HSA_OVERRIDE_GFX_VERSION** — hardcoded in voice-agents.nix AND ai-stack.nix, should be a shared constant
11. **Register more OIDC clients in Authelia** — hermes, twenty, openseo, voice-agents, homepage all lack SSO integration
12. **Enable Immich hardware acceleration** — GPU is available and unused for transcoding
13. **Service startup parallelism** — hermes 77s, twenty 49s, manifest 48s start sequentially

### Code Quality
14. **Flake inputs audit** — 47 inputs, need to identify stale ones (e.g., ComfyUI deleted but its input may still exist)
15. **Create `just status` command** — automate status report generation
16. **Fix FEATURES.md/TODO_LIST.md** — ZRAM 50%→10%, boot time estimates, remove broken script references
17. **Clean up gpu-recovery dead code** in niri-config.nix (disabled service with `wantedBy = mkForce []`)
18. **Derive all hardcoded ports from config options** — EMEET PIXY port 8090, whisper port 7860, etc.

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort | Status |
|---|----------|------|--------|--------|--------|
| 1 | **P0** | **Deploy all 8 committed changes** — serial8250 boot fix, ZRAM, homepage memory, watchdog, flake update | 🔴 Critical | Low | Uncommitted deploy |
| 2 | **P0** | **Verify boot time after deploy** — expect ~2m20s (down from 3m54s) | High | Low | Blocked on #1 |
| 3 | **P0** | **Verify homepage memory after deploy** — expect ~150-200 MB (down from 1-2 GB) | High | Low | Blocked on #1 |
| 4 | **P0** | **Pin Docker image tags** — twenty, manifest, openseo all on `"latest"` | 🔴 Reproducibility | Low | Not started |
| 5 | **P0** | **Add auth to OpenSEO** — `local_noauth` is a security hole | 🔴 Security | Low | Not started |
| 6 | **P1** | **Move Forgejo admin password to sops** | Medium | Medium | Not started |
| 7 | **P1** | **Verify Hermes firecrawl/edge-tts/fal/exa tools work** | High | Medium | Not started |
| 8 | **P1** | **Configure secondary LLM provider** for Hermes | High | Medium | Not started |
| 9 | **P1** | **Fix Hermes git remote access** — SSH deploy key | Medium | Medium | Not started |
| 10 | **P1** | **Add memory/swap alerting** to SigNoz/Gatus | High | Medium | Not started |
| 11 | **P1** | **Audit Docker container memory limits** — deer-flow 1.4GB | Medium | Low | Not started |
| 12 | **P1** | **Fix `tasks.${domain}` vhost** — unprotected by forward-auth | Medium | Low | Not started |
| 13 | **P2** | **Check SigNoz provision logs** — verify dashboards + rules | Medium | Low | Not started |
| 14 | **P2** | **Test Discord alert channel** | Medium | Low | Not started |
| 15 | **P2** | **Verify Gatus endpoints** healthy | Medium | Low | Not started |
| 16 | **P2** | **Add SigNoz channel routing** (critical→Discord) | Medium | Medium | Not started |
| 17 | **P2** | **Enable Immich hardware acceleration** | Medium | Low | Not started |
| 18 | **P2** | **Deploy Dozzle** at logs.home.lan | Medium | Low | Not started |
| 19 | **P2** | **Provision Pi 3** for DNS failover cluster | High | High | Not started |
| 20 | **P2** | **Fix FEATURES.md** — ZRAM 50%→10%, remove broken script refs | Low | Low | Not started |
| 21 | **P3** | **Flake inputs audit** — 47 inputs, find stale | Low | Medium | Not started |
| 22 | **P3** | **Consolidate HSA_OVERRIDE_GFX_VERSION** into shared constant | Low | Low | Not started |
| 23 | **P3** | **Register more OIDC clients** in Authelia | Medium | Medium | Not started |
| 24 | **P3** | **Clean up gpu-recovery dead code** in niri-config.nix | Low | Low | Not started |
| 25 | **P4** | **Create `just status` command** for automated reports | Low | Low | Not started |

---

## G) TOP #1 QUESTION 🤔

**Why is Ollama set to `wantedBy = lib.mkForce []`?**

In `ai-stack.nix:66`, Ollama's systemd service has `wantedBy = lib.mkForce []` — this means Ollama will **never auto-start on boot**. It must be manually started each time. On a machine where Ollama is actively used for AI inference and Hermes likely depends on it, this seems intentional but undocumented.

**Is this deliberate?** Possible reasons:
1. GPU memory contention — Ollama reserves VRAM even idle, starving niri/compositor
2. The `ai-models` module pulls models on demand, so Ollama is started by a dependent service
3. It was a debugging measure that became permanent

The `OLLAMA_MAX_LOADED_MODELS=1` and `OLLAMA_GPU_OVERHEAD=8589934592` (8 GB) settings suggest GPU memory pressure is a real concern. But if Ollama is needed for Hermes tools, it should auto-start — or at minimum, there should be a documented activation mechanism.

---

## System Vital Signs (As Configured, Pre-Deploy)

| Metric | Value | Status |
|--------|-------|--------|
| **Branch** | master, up to date with origin | ✅ |
| **Build test** | `just test-fast` passes (as of last run) | ✅ |
| **.nix files** | 111 files | — |
| **Service modules** | 32 (in flake.nix serviceModules list) | — |
| **Flake inputs** | 47 (in lock file) | — |
| **Service module LOC** | 6,720 lines across 34 .nix files | — |
| **Undeployed commits** | 8 (since Session 76) | ⚠️ |
| **Disabled services** | photomap, minecraft, file-and-image-renamer | — |
| **Security debt** | 3 × `latest` tags, 1 × no auth, 2 × plaintext secrets | 🔴 |
| **Boot time (current)** | 3m54s (pre-serial8250 fix) | ⚠️ |
| **Boot time (expected)** | ~2m20s (post-deploy) | 🟡 |

## Services Status

| Service | Enabled | Deployed | Issues |
|---------|---------|----------|--------|
| **Caddy** | ✅ | ✅ | Reverse proxy, auto_https off |
| **Forgejo** | ✅ | ✅ | Admin password in plaintext |
| **Immich** | ✅ | ✅ | HW acceleration disabled |
| **Authelia** | ✅ | ✅ | Client secrets hardcoded, only 2 OIDC clients |
| **Homepage** | ✅ | ✅ | Memory fix committed but undeployed |
| **SigNoz** | ✅ | ✅ | ClickHouse single-node, provision unverified |
| **Twenty** | ✅ | ✅ | `latest` Docker tag |
| **Voice Agents** | ✅ | ✅ | Weakened sandbox, no TLS on Caddy vhosts |
| **Hermes** | ✅ | ✅ | Git/sudo broken, tools untested, MemoryMax=24G |
| **Ollama** | ✅ | ❌ No autostart | `wantedBy = []`, GPU headroom concerns |
| **Manifest** | ✅ | ✅ | `latest` Docker tag, relative secrets path |
| **OpenSEO** | ✅ | ✅ | **No authentication**, `latest` tag |
| **TaskChampion** | ✅ | ✅ | Clean |
| **Monitor365** | ✅ | ✅ | Clean |
| **DNS Blocker** | ✅ | ✅ | DoQ disabled (no ngtcp2) |
| **Dual WAN** | ✅ | ✅ | Clean |
| **Gatus** | ✅ | ✅ | Endpoints unverified |
| **Disk Monitor** | ✅ | ✅ | Clean |
| **NVMe Health** | ✅ | ✅ | Hardcoded /dev/nvme0n1 |
| **Deer Flow** | ✅ | ✅ | Frontend 1.4GB, no memory limit |
| **Display Manager** | ✅ | ✅ | Fix committed, undeployed |
| **Niri** | ✅ | ✅ | gpu-recovery dead code |
| **Security Hardening** | ✅ | ✅ | — |
| **AI Models** | ✅ | ✅ | Clean |
| **PhotoMap** | ❌ | — | Disabled (podman permissions) |
| **Minecraft** | ❌ | — | Disabled |
| **File Renamer** | ❌ | — | Disabled (Go 1.26.3 blocker) |

## Commits Since Session 76

```
87109b85 perf(homepage): add memory constraints to prevent unbounded Node.js growth
c67277f3 perf(boot): increase ZRAM swap from 5% to 10% of RAM
b6ce680f fix(display-watchdog): pass PRIMARY_USER env var to display-watchdog service
08c267ce fix(display-watchdog): use systemd --machine mode for --user service restart
9f6c418b chore(deps): update flake.lock with latest revisions across all inputs
f757cc0b perf(boot): add gopls to OOM killer prefer list as primary victim
6f0be6ca perf(boot): blacklist serial8250 to eliminate 1m31s initrd device timeout
e2a88535 fix(buildflow): update vendorHash for updated dependencies
```

## Architecture Overview

```
evo-x2 (GMKtec Strix Halo, 128GB RAM, AMD GPU)
├── Boot: systemd-boot → NixOS unstable
├── Desktop: Niri (Wayland) + Waybar
├── Networking: Dual-WAN (eno1 + wlan0, MPTCP) + Unbound DNS
├── Reverse Proxy: Caddy (auto_https off, dnsblockd certs)
├── Auth: Authelia (SSO/OIDC, 2 clients)
├── Observability: SigNoz + Gatus + cAdvisor + Node Exporter
├── AI: Ollama (no autostart) + gpu-python + AI Models
├── CRM: Twenty (Docker, latest tag)
├── Media: Immich (no GPU accel)
├── Dev: Forgejo + TaskChampion
├── Dashboards: Homepage + Manifest (LLM router) + OpenSEO (no auth)
├── Voice: Whisper-asr + LiveKit (Docker)
├── Agent: Hermes (6 extras, git/sudo broken)
├── Monitoring: Monitor365 + Disk Monitor + NVMe Health
└── DNS: Unbound + dnsblockd + dual-WAN failover
```

---

_Report generated by Session 78. All undeployed commits require `just switch` to take effect._
