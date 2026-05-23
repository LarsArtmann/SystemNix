# Session 79 — Post-Session-78 Jan Autostart Fix + System State

**Date:** 2026-05-23 12:36 CEST
**Boot:** 6h 56m ago (since 05:40)
**Previous Report:** Session 78 Post-Execution (2026-05-23 10:44)

---

## Executive Summary

Session 78 deployed 10 commits (Docker tag pinning, forward-auth, swap alerting, port registry, GPU config consolidation, type safety, Gatus monitoring). Session 79 investigated why Jan AI auto-starts and spawns a 1 GiB GPU-loaded llama-server on every login — root cause was niri-session-manager restoring Jan from saved session. Added Jan to `skip_apps` to prevent auto-restore. **19+ commits now undeployed**, all awaiting `just switch`.

---

## a) FULLY DONE ✅

### Session 78 (10 commits, deployed but not switched)

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
| `260125fa` | Session 78 status report | Documentation |

### Session 77 — OOM Crash Fixes (6 commits, undeployed)

| Commit | Description | Impact |
|--------|-------------|--------|
| `f757cc0b` | Add gopls to earlyoom --prefer list | OOM targeting |
| `9f6c418b` | Remove helium from --prefer + rewrite watchdogs + update flake.lock | Crash prevention |
| `08c267ce` | display-watchdog: use systemctl --user -M for niri restart | Fix system→user context |
| `b6ce680f` | display-watchdog: pass PRIMARY_USER env var | Fix system→user context |
| `c67277f3` | ZRAM swap 5% → 10% (6.4 → 12.8 GiB) | Swap headroom |
| `87109b85` | Homepage Docker memory constraints (V8 heap + cgroup) | Prevent node 11GB |

### Session 79 — Jan Autostart Fix (this session, undeployed)

- Added `"Jan"` to `skip_apps` in niri-session-manager config
- **Root cause chain:** niri-session-manager restores Jan window from `session.json` → Jan restores last thread → thread has model binding → `@janhq/llamacpp-extension` launches `llama-server` with `-ngl 99` (1 GiB, full GPU)
- niri-session-manager has no crash-vs-clean-shutdown distinction — always restores everything. `skip_apps` is the only control.

---

## b) PARTIALLY DONE 🔶

### gopls Memory Pressure

- Still at **9 procs, ~5.8 GiB** total (down from 13/9.7 GiB in session 77)
- `GOMEMLIMIT` not yet configured — each gopls instance unbounded
- Now #1 in earlyoom `--prefer` (correct victim), but root cause not fixed

### service-health-check Recurring Failures

- Failing every ~15 minutes with exit-code (ongoing since session 76)
- Not investigated — low priority but creates log noise

### Undeployed Changes

**19+ commits** across sessions 77, 78, 79 are committed but `just switch` has NOT been run:
- OOM crash fixes (earlyoom targeting, watchdog rewrites, ZRAM increase)
- Homepage memory constraints
- Docker tag pinning, forward-auth, swap alerting, port registry
- Jan autostart skip
- **ZRAM 5%→10% requires reboot to take effect**

---

## c) NOT STARTED ⬜

| Priority | Task | Notes |
|----------|------|-------|
| P0 | `just switch` + reboot to deploy all changes | ZRAM needs reboot |
| P0 | Verify watchdog rewrites work after deploy | Test display-watchdog |
| P0 | Add `GOMEMLIMIT=1GiB` to gopls instances | Cap at ~13 GiB max |
| P1 | Configure secondary LLM provider for Hermes | GLM-5.1 fallback |
| P1 | Verify hermes Python deps at runtime | No ImportError |
| P1 | Hermes git remote access (SSH deploy key) | Repo access |
| P1 | Investigate service-health-check failures | Every 15 min |
| P2 | Per-threshold SigNoz channel routing | Alert triage |
| P2 | Deploy Dozzle at `logs.home.lan` | Docker log viewer |
| P2 | Create `just status` command | Operational |
| P2 | Investigate boot time (1m44s initrd) | Faster reboots |
| P3 | nix-colors integration (~6h) | Theme consistency |
| P3 | Flake inputs audit (47 inputs) | Dependency hygiene |
| P3 | Provision Pi 3 for DNS failover | DNS resilience |

---

## d) TOTALLY FUCKED UP 💀

### Nothing new this session.

Previous crash (Session 77, May 23 ~05:39) fully root-caused and fixed. Fixes are committed but **not yet deployed** — system is running with old watchdogs that have the blind spots.

### Ongoing risks:

1. **Undeployed watchdog fixes** — if OOM happens again before `just switch`, same black screen
2. **gopls at 5.8 GiB** — still #1 memory consumer, no per-instance caps
3. **Swap at 72% (9.4/13 GiB)** — high but not critical. zram nearly full (3.2/3.2 GiB)
4. **llama-server still running** — Jan was started before the skip_apps fix. Will persist until next login

---

## e) WHAT WE SHOULD IMPROVE 📈

### Critical

1. **Deploy everything** — 19+ commits undeployed. The OOM watchdog fixes are critical.
2. **gopls memory limits** — `GOMEMLIMIT=1GiB` via Nix config. 9 instances × 1 GiB = 9 GiB cap vs current 5.8 GiB uncontrolled growth potential.
3. **service-health-check** — Failing every 15 min for days. Diagnose or disable.

### Architecture

4. **Consolidate watchdog state management** — Three scripts (niri-drm-healthcheck, display-watchdog, gpu-recovery) each have their own state persistence. Extract to `lib/watchdog-state.sh`.
5. **Test display recovery chain** — Never verified `systemctl --user -M lars@` works from display-watchdog system context.
6. **Watchdog display-state metrics** — niri-health-metrics only counts journal errors, not actual DRM state.
7. **niri-session-manager upstream feature request** — `crash_only_apps` list would allow Jan restore only after crash, not every login.

### Operational

8. **Disk at 84%** — Trending up. Need automated nix-store GC.
9. **Boot time 3m54s** — 1m44s initrd still slow.
10. **Swap zram at 100%** (3.2/3.2 GiB) — the 5%→10% increase (to 6.4 GiB) is undeployed.

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Task | Est. | Impact |
|---|----------|------|------|--------|
| 1 | **P0** | `just switch` + reboot — deploy ALL 19+ undeployed commits | 30m | Prevents repeat crash |
| 2 | **P0** | Verify watchdog rewrites work after deploy | 10m | Confirms crash fix |
| 3 | **P0** | Verify ZRAM increased to 10% after reboot | 2m | Confirms swap headroom |
| 4 | **P0** | Verify Jan no longer auto-starts after reboot | 2m | Confirms skip_apps |
| 5 | **P0** | Add `GOMEMLIMIT=1GiB` to gopls via Nix config | 15m | Caps gopls memory |
| 6 | **P0** | Investigate service-health-check failures (every 15 min) | 20m | Stops alert spam |
| 7 | **P1** | Configure secondary LLM provider for Hermes | 30m | Hermes resilience |
| 8 | **P1** | Verify hermes Python deps at runtime | 15m | Confirms session 75 |
| 9 | **P1** | Hermes git remote access (SSH deploy key) | 30m | Repo access |
| 10 | **P1** | Docker MemoryMax for SigNoz/Twenty (not just Homepage) | 20m | Prevents node proliferation |
| 11 | **P1** | Add memory/swap alerting to Gatus (80% mem, 50% swap) | 30m | Early warning |
| 12 | **P1** | Consolidate watchdog state management into shared lib | 45m | DRY, fewer bugs |
| 13 | **P1** | Add display-state metrics to niri-health-metrics | 20m | Observability |
| 14 | **P2** | Check SigNoz Discord alert channel works | 30m | Alerting verification |
| 15 | **P2** | Add per-threshold SigNoz channel routing | 45m | Alert triage |
| 16 | **P2** | Deploy Dozzle at `logs.home.lan` | 45m | Real-time Docker logs |
| 17 | **P2** | Create `just status` command | 30m | Operational |
| 18 | **P2** | Investigate boot time: 1m44s initrd | 60m | Faster reboots |
| 19 | **P2** | Automated disk cleanup (nix-store GC, Docker images) | 30m | Prevents disk fill |
| 20 | **P3** | nix-colors integration | 6h | Theme consistency |
| 21 | **P3** | Flake inputs audit (47 inputs) | 2h | Dependency hygiene |
| 22 | **P3** | Provision Pi 3 for DNS failover cluster | 4h | DNS resilience |
| 23 | **P3** | Add earlyoom post-kill hook (`-N` flag) for logging | 30m | OOM forensics |
| 24 | **P3** | File niri-session-manager feature: `crash_only_apps` | 15m | Conditional restore |
| 25 | **P4** | Investigate `vm.swappiness=1` — too aggressive for OOM? | 30m | Swap tuning |

---

## g) My Top #1 Question

**When can we run `just switch` + reboot?**

There are 19+ undeployed commits including critical OOM crash fixes, watchdog rewrites, ZRAM increase, and Jan autostart skip. The system is running with old code that has the watchdog blind spots. However, deploying requires a reboot (ZRAM resize) and you're actively working (load 1.65, 19 users).

The llama-server process (1 GiB, GPU-loaded from Jan) is still running from before the skip_apps fix and won't go away until next reboot/login.

---

## System Metrics (Current)

| Metric | Value | Status |
|--------|-------|--------|
| Uptime | 6h 56m | 🟢 Stable |
| RAM | 43/62 GiB (69%) | 🟡 Normal |
| Swap | 9.4/13 GiB (72%) | 🟡 High |
| Disk | 416/512 GiB (84%) | 🟡 Trending up |
| Load | 1.65 | 🟢 Light |
| gopls | 9 procs, ~5.8 GiB | 🟡 Top consumer |
| crush | 12 procs, ~1.2 GiB | 🟢 |
| llama-server | 1 proc, ~1 GiB | 🟡 (Jan, running) |
| helium | 15 procs, ~1.3 GiB | 🟢 |
| niri | Running, display OK | 🟢 |
| Display | connected, enabled, dpms=On | 🟢 |
| service-health-check | Failing every 15 min | 🔴 |

---

## Commits This Session (Session 79)

| Commit | Description |
|--------|-------------|
| (unstaged) | fix(session): add Jan to niri-session-manager skip_apps |

## Commits Since Session 77 Status Report

| Commit | Description |
|--------|-------------|
| `260125fa` | docs(status): Session 78 post-execution comprehensive status |
| `00137dcf` | docs(AGENTS.md): document new lib helpers, dockerImageTag type, caddy pattern |
| `4824008b` | fix(security): consolidate voice-agents Caddy vhosts with TLS + forward-auth |
| `3d1fbc93` | feat(monitoring): add Gatus health checks for Hermes and EMEET PIXY |
| `7c1dd5a2` | feat(types): add dockerImageTag type that rejects 'latest' |
| `bc98e09f` | fix(manifest) + refactor(niri): fix CORS origin + remove gpu-recovery dead code |
| `c027aa31` | refactor(gpu): consolidate HSA_OVERRIDE_GFX_VERSION via lib/rocm.nix |
| `b0f858e7` | feat(lib): add centralized port registry to prevent conflicts |
| `8801c2d7` | feat(monitoring): add swap usage critical alert rule to SigNoz |
| `bd14e13b` | fix(security): add forward-auth to tasks.${domain} vhost |
| `bccf73c5` | fix(security): pin Docker image tags to specific versions |
| `67fc1bda` | docs(planning): Session 78 comprehensive execution plan |
| `fe4c4204` | docs(status): Session 78 comprehensive status |
| `02512e7a` | docs(status): Session 77 — OOM crash root cause analysis |
| `87109b85` | perf(homepage): add memory constraints |
| `c67277f3` | perf(boot): increase ZRAM swap from 5% to 10% |
| `b6ce680f` | fix(display-watchdog): pass PRIMARY_USER env var |
| `08c267ce` | fix(display-watchdog): use systemctl --machine mode |
| `9f6c418b` | chore(deps): update flake.lock + fix earlyoom + rewrite watchdogs |
| `f757cc0b` | perf(boot): add gopls to OOM killer prefer list |

---

_Arte in Aeternum_
