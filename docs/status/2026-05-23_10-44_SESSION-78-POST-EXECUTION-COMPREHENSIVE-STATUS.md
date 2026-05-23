# Session 78 — Post-Execution Status Report

**Date:** 2026-05-23 10:44 CEST
**Platform:** NixOS unstable (nixos-unstable) | **Kernel:** 6.x
**Branch:** master — **up to date with origin**
**Previous Report:** Session 78 Planning (2026-05-23 06:44)

---

## Executive Summary

Session 78 executed 10 commits across Phases 2-6 of the execution plan. All Docker `latest` tags pinned, voice-agents Caddy vhosts consolidated with TLS + forward-auth, swap alert added, GPU config centralized, dead code removed, new type safety for Docker images, Gatus monitoring expanded. **18 commits total are undeployed** (8 from pre-session + 10 from this session), all awaiting `just switch`. The homepage memory constraints from earlier (V8 heap 192M + 384M cgroup) are among the undeployed changes. Build is clean — `just test-fast` passes with zero warnings.

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

### Pre-Session Commits (8 commits, also undeployed)

| Commit | Description |
|--------|-------------|
| `87109b85` | Homepage memory: V8 heap 192M + 384M cgroup |
| `c67277f3` | ZRAM swap 5%→10% |
| `b6ce680f` | Display-watchdog PRIMARY_USER env var |
| `08c267ce` | Display-watchdog systemd --machine mode |
| `9f6c418b` | Flake lock mass update (25+ inputs) |
| `f757cc0b` | gopls in OOM killer prefer list |
| `6f0be6ca` | Blacklist serial8250 (saves 1m31s boot) |
| `e2a88535` | BuildFlow vendorHash fix |

### Key Infrastructure Improvements

- **Port registry** (`lib/ports.nix`): 26 ports across 20 services, single source of truth. Exposed port 3001 conflict (monitor365 vs openseo).
- **`dockerImageTag` type** (`lib/types.nix`): Runtime eval-time rejection of `"latest"` tags. Used by manifest and openseo; twenty uses a let binding.
- **GPU config centralization**: `lib/rocm.nix` now used by ai-stack (gpu-python wrapper) and voice-agents (Docker compose). Single `gfxVersion` parameter.
- **Caddy vhost consolidation**: ALL vhosts now in `caddy.nix`. Voice-agents was the only outlier — now uses `protectedVHost` with TLS + forward-auth.
- **SigNoz alert rules**: 17 total (added swap-critical). All route to Discord.
- **Gatus endpoints**: 26 total (added Hermes + EMEET PIXY).

### Session Planning & Documentation

| Commit | Description |
|--------|-------------|
| `fe4c4204` | Session 78 comprehensive status report |
| `67fc1bda` | Session 78 execution plan (44 tasks, 7 phases) |

---

## B) PARTIALLY DONE 🔧

### Memory Management
- **Done:** ZRAM doubled, gopls in OOM prefer, homepage constrained, swap alert rule
- **Not done:** No runtime verification — all changes are undeployed
- **Not done:** Docker container memory audit (deer-flow-frontend at 1.4 GB, no limit)
- **Not done:** Port 3001 conflict (monitor365-server vs openseo) — documented but not resolved

### Security
- **Done:** Docker tags pinned, tasks vhost protected, voice-agents vhosts protected
- **Not done:** OpenSEO `AUTH_MODE: local_noauth` — needs investigation of what `local_auth` requires
- **Not done:** Forgejo admin password still in plaintext file
- **Not done:** Authelia client secrets still hardcoded as single bcrypt hash
- **Not done:** Only 2 OIDC clients registered (immich, forgejo)

### Documentation
- **Done:** AGENTS.md updated with new patterns (ports, dockerImageTag, caddy pattern)
- **Not done:** FEATURES.md still stale (ZRAM 50%→10%, boot time wrong, phantom scripts)
- **Not done:** TODO_LIST.md not updated since Session 75

---

## C) NOT STARTED ⏳

### Infrastructure (Needs Deploy First)
- [ ] Deploy all 18 undeployed commits via `just switch`
- [ ] Verify boot time reduced (~2m20s expected from ~3m54s)
- [ ] Verify homepage memory ~150-200MB (from 1-2GB)
- [ ] Verify display-watchdog restarts niri correctly

### Hermes
- [ ] Configure secondary LLM provider (OpenRouter/OpenAI fallback)
- [ ] Fix Hermes git remote access (SSH deploy key)
- [ ] Fix Hermes sudo access (NoNewPrivileges blocks systemctl)
- [ ] Verify firecrawl/edge-tts/fal/exa tools work at runtime

### Security
- [ ] Investigate OpenSEO auth options (local_auth vs OIDC)
- [ ] Move Forgejo admin password to sops
- [ ] Register more OIDC clients in Authelia (hermes, twenty, openseo, voice-agents)
- [ ] Enable Immich hardware acceleration

### Observability
- [ ] Check SigNoz provision logs — verify dashboards + rules created
- [ ] Test Discord alert channel
- [ ] Verify Gatus endpoints at status.home.lan
- [ ] Add SigNoz per-threshold channel routing (critical→Discord, warning→log)

### Code Quality
- [ ] Migrate services to use `lib/ports.nix` constants (currently reference docs only)
- [ ] Resolve port 3001 conflict (monitor365-server vs openseo)
- [ ] Fix FEATURES.md — ZRAM 50%→10%, boot time, remove phantom scripts
- [ ] Update TODO_LIST.md
- [ ] Flake inputs audit — 47 inputs, find stale/unused

### Hardware / External
- [ ] Provision Pi 3 for DNS failover cluster
- [ ] Wire Pi 3 as secondary DNS
- [ ] Investigate Ollama `wantedBy = []` — document rationale
- [ ] Darwin config parity check

---

## D) TOTALLY FUCKED UP 💀

### 1. 18 Commits Undeployed
All work since May 22 is committed and pushed but NOT running on the machine. The serial8250 blacklist (saves 1m31s boot), homepage memory cap (saves 1-2GB RAM), ZRAM expansion, and all security fixes are theoretical until `just switch`. This is the single biggest risk — if something breaks during deploy, we have many changes to bisect through.

### 2. Port 3001 Conflict: monitor365 vs openseo
Both services default to port 3001. The port registry documents this but doesn't fix it. If both services are running simultaneously, one will fail to bind. Need to either:
- Change openseo to a different port (e.g., 3010)
- Change monitor365-server to a different port
- Verify they actually conflict at runtime (monitor365-server is a user service that may not be running)

### 3. `nix fmt` Damaged Shell Scripts
During the Session 78 execution, `nix fmt` (treefmt → shfmt) reformatted `scripts/update-vendor-hash.sh` and `scripts/versions.sh`, mangling bash associative array keys (turning hyphens into spaces). The files were restored from git. This means the formatter config has a bug or shfmt is too aggressive. These scripts should be excluded from shfmt or the formatter config needs adjustment.

### 4. FEATURES.md and TODO_LIST.md Are Still Stale
- FEATURES.md claims ZRAM is "50% of RAM (64GB)" — actual is 10% (~12.8GB)
- TODO_LIST.md boot time estimate says "~35s" — never achieved
- 4 referenced scripts in FEATURES.md don't exist
- These docs give a false picture of the system to new sessions

### 5. Ollama Won't Autostart
`wantedBy = lib.mkForce []` in ai-stack.nix means Ollama never auto-starts. This is either:
- Deliberate GPU memory management (Ollama reserves VRAM even idle)
- A debugging measure that became permanent
- Needs documentation or reversal

---

## E) WHAT WE SHOULD IMPROVE 📈

### Immediate (Pre-Deploy)
1. **DEPLOY** — 18 commits need verification on the actual machine
2. **Fix `nix fmt` script damage** — exclude shell scripts from shfmt or fix the formatter config
3. **Resolve port 3001 conflict** — change one of the services to a different port

### Post-Deploy Verification
4. **Verify boot time** — serial8250 blacklist should cut ~1m31s from initrd
5. **Verify homepage memory** — V8 cap should bring it from 1-2GB to ~200MB
6. **Verify manifest CORS** — the fix changes CORS_ORIGIN from localhost to domain URL

### Security Debt
7. **Investigate OpenSEO auth** — determine if `local_auth` or OIDC is viable
8. **Move Forgejo admin password to sops** — eliminate plaintext credential
9. **Document Ollama `wantedBy = []` rationale** — or fix it

### Documentation
10. **Fix FEATURES.md** — ZRAM 50%→10%, remove phantom scripts, update boot time
11. **Update TODO_LIST.md** — mark all completed items, update estimates

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | **P0** | **Deploy all 18 commits** via `just switch` | 🔴 Critical | XS |
| 2 | **P0** | **Verify boot time** after serial8250 blacklist (~2m20s expected) | 🟠 High | XS |
| 3 | **P0** | **Verify homepage memory** settles at ~200MB | 🟠 High | XS |
| 4 | **P0** | **Fix `nix fmt` script damage** — exclude shell scripts or fix shfmt config | 🟠 High | S |
| 5 | **P1** | **Resolve port 3001 conflict** (monitor365 vs openseo) | 🟡 Medium | XS |
| 6 | **P1** | **Investigate OpenSEO auth** — can `local_auth` work? | 🟠 High | S |
| 7 | **P1** | **Move Forgejo admin password to sops** | 🟡 Medium | S |
| 8 | **P1** | **Configure secondary LLM provider** for Hermes | 🟠 High | M |
| 9 | **P1** | **Fix Hermes git remote access** — SSH deploy key | 🟡 Medium | S |
| 10 | **P1** | **Verify Hermes firecrawl/edge-tts/fal/exa at runtime** | 🟡 Medium | M |
| 11 | **P1** | **Document Ollama `wantedBy = []`** rationale or fix it | 🟡 Medium | XS |
| 12 | **P1** | **Fix FEATURES.md** — ZRAM, boot time, phantom scripts | 🟡 Medium | S |
| 13 | **P1** | **Update TODO_LIST.md** with current state | 🟡 Medium | S |
| 14 | **P2** | **Migrate services to use `lib/ports.nix`** constants | 🟢 Low | M |
| 15 | **P2** | **Check SigNoz provision logs** — verify dashboards/rules | 🟡 Medium | S |
| 16 | **P2** | **Test Discord alert channel** | 🟡 Medium | XS |
| 17 | **P2** | **Verify Gatus endpoints** healthy | 🟡 Medium | XS |
| 18 | **P2** | **Add SigNoz channel routing** (critical→Discord, warning→log) | 🟡 Medium | S |
| 19 | **P2** | **Enable Immich hardware acceleration** | 🟡 Medium | S |
| 20 | **P2** | **Register more OIDC clients** in Authelia | 🟡 Medium | M |
| 21 | **P3** | **Flake inputs audit** — 47 inputs, find stale | 🟢 Low | M |
| 22 | **P3** | **Provision Pi 3** for DNS failover | 🟡 Medium | L |
| 23 | **P3** | **Fix Hermes sudo access** | 🟡 Medium | M |
| 24 | **P4** | **Darwin config parity check** | 🟢 Low | M |
| 25 | **P4** | **Deploy Dozzle** at logs.home.lan | 🟢 Low | S |

---

## G) TOP #1 QUESTION 🤔

**Should the `nix fmt` / treefmt / shfmt pipeline be fixed before the next deploy?**

During this session, `nix fmt` reformatted shell scripts and **broke** `scripts/update-vendor-hash.sh` by turning bash associative array keys like `[go-structure-linter]` into `[go - structure - linter]` (splitting hyphens with spaces). This was caught and the files were restored, but it means:

1. Running `nix fmt` will silently break these scripts
2. The pre-commit hook runs formatters — if these scripts are staged, they'd be mangled
3. The `just format` command could also damage them

Options:
- **Exclude `.sh` files from shfmt** in treefmt config
- **Fix the scripts** to use a format shfmt handles correctly
- **Pin shfmt version** or configuration to be less aggressive

This needs fixing before the deploy because the pre-commit hook runs formatters on every commit.

---

## System Vital Signs

| Metric | Value | Status |
|--------|-------|--------|
| **Branch** | master, up to date with origin | ✅ |
| **Build** | `just test-fast` passes, zero warnings | ✅ |
| **Undeployed commits** | 18 (8 pre-session + 10 this session) | ⚠️ |
| **.nix files** | 112 (was 111 — added lib/ports.nix) | — |
| **Service modules** | 33 registered in flake.nix | — |
| **Flake inputs** | 47 | — |
| **SigNoz alert rules** | 17 (added swap-critical) | ✅ |
| **Gatus endpoints** | 26 (added Hermes + EMEET PIXY) | ✅ |
| **Docker tags pinned** | 3/3 (twenty, manifest, openseo) | ✅ |
| **Port registry** | 26 ports, 1 conflict documented | ⚠️ |
| **Security debt** | OpenSEO no auth, Forgejo plaintext, Authelia hardcoded | 🔴 |

## Services Status

| Service | Enabled | Deployed | Issues |
|---------|---------|----------|--------|
| **Caddy** | ✅ | ✅ | All vhosts now consolidated in caddy.nix |
| **Forgejo** | ✅ | ✅ | Admin password in plaintext |
| **Immich** | ✅ | ✅ | HW acceleration disabled |
| **Authelia** | ✅ | ✅ | 2 OIDC clients only, hardcoded secrets |
| **Homepage** | ✅ | ✅ | Memory fix committed, undeployed |
| **SigNoz** | ✅ | ✅ | 17 rules, swap-critical added |
| **Twenty** | ✅ | ✅ | Tag pinned to v2.7.3 |
| **Voice Agents** | ✅ | ✅ | Caddy vhosts now protected |
| **Hermes** | ✅ | ✅ | Git/sudo broken, tools untested |
| **Ollama** | ✅ | ❌ No autostart | `wantedBy = []` — rationale unknown |
| **Manifest** | ✅ | ✅ | Tag pinned to 6.6.1, CORS fixed |
| **OpenSEO** | ✅ | ✅ | Tag pinned to v0.0.15, **no auth** |
| **TaskChampion** | ✅ | ✅ | Forward-auth added, undeployed |
| **Gatus** | ✅ | ✅ | 26 endpoints, Hermes + EMEET PIXY added |
| **Monitor365** | ✅ | ✅ | Port 3001 conflict with openseo |
| **Deer Flow** | ✅ | ✅ | Frontend 1.4GB, no memory limit |

## Commit History (Session 78)

```
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
67fc1bda docs(planning): Session 78 comprehensive execution plan — 44 tasks, 7 phases
fe4c4204 docs(status): Session 78 — comprehensive status post-boot-fix homepage-harden
87109b85 perf(homepage): add memory constraints to prevent unbounded Node.js growth
c67277f3 perf(boot): increase ZRAM swap from 5% to 10% of RAM
b6ce680f fix(display-watchdog): pass PRIMARY_USER env var to display-watchdog service
08c267ce fix(display-watchdog): use systemd --machine mode for --user service restart
9f6c418b chore(deps): update flake.lock with latest revisions across all inputs
f757cc0b perf(boot): add gopls to OOM killer prefer list as primary victim
6f0be6ca perf(boot): blacklist serial8250 to eliminate 1m31s initrd device timeout
```

## Architecture Changes This Session

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

AGENTS.md             ← UPDATED: documented new patterns
```

---

_Report generated at Session 78 close. All 18 commits pushed to origin, awaiting deploy._
