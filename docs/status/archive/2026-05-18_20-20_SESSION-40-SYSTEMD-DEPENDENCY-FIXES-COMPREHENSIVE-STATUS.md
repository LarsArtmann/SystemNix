# Session 40 — Comprehensive Status Report

**Date:** 2026-05-18 20:20 CEST
**Branch:** master (synced with origin)
**Platform:** macOS (remote SSH to evo-x2 NixOS)
**Flake check:** PASSING (0 errors, 3 external deprecation warnings)

---

## A) FULLY DONE

### Session 40 Work (this session)

| # | Item | Commit | Impact |
|---|------|--------|--------|
| 1 | **Fix systemd dependency chain for hermes.service** | `974b5075` | Added `sops-nix.service` + `unbound.service` to `after`/`wants`. Hermes was starting before DNS resolver was ready, causing Discord API connection failures on every `nh os switch`. |
| 2 | **Fix systemd dependency chain for all Docker services** | `974b5075` | Added `unbound.service` to `lib/docker.nix` defaults (affects whisper-asr, openseo, manifest, twenty). Docker image pulls need DNS to resolve registry hostnames — `network-online.target` only means "interface up", not "DNS resolver ready". |
| 3 | **Fix Docker image pull service DNS dependency** | `974b5075` | Added `unbound.service` to `${name}-pull` service `after`/`wants` in `lib/docker.nix`. |
| 4 | **Fix display-watchdog + niri-drm-healthcheck lib.sh sourcing** | `cdfe6c07` (previous session) | Inlined `state_*` functions from `lib.sh` into both scripts. `writeShellApplication` places scripts in `/nix/store/...` where `$(dirname "$0")/lib.sh` doesn't exist. `set -eu` caused immediate failure on every timer tick. |
| 5 | **Fix XDG_PROJECTS_DIR deprecation warning** | `cdfe6c07` (previous session) | Changed `XDG_PROJECTS_DIR` → `PROJECTS` in `platforms/nixos/users/home.nix` per Home Manager 26.05 deprecation. |

### Session 37-39 Work (today, earlier)

| # | Item | Status |
|---|------|--------|
| 6 | ComfyUI service disabled (prefer AI models via code) | Done — `3571bb98` |
| 7 | Flake.lock update — 15 inputs upgraded | Done — `cdfe6c07` |
| 8 | `mkPreparedSource` v2 — per-dep subModules, 4 repos migrated | Done — `94dbafb1` |
| 9 | `jscpd` package-lock artifact removed | Done — `3e5ce96d` |
| 10 | Netwatch added to installed packages | Done — `5aefb100` |
| 11 | `tor-browser` added to privacy packages | Done — `cdfe6c07` |
| 12 | All 5 repos version-fixed (vendorHash + build verification) | Done — `e64057c4` |

### Historical Milestones (Sessions 1-36)

| Milestone | Status |
|-----------|--------|
| Cross-platform Nix config (Darwin + NixOS) | Stable |
| 35 NixOS service modules (flake-parts) | All evaluating |
| DNS blocker stack (unbound + dnsblockd, 2.5M+ domains) | Production |
| Dual-WAN ECMP+MPTCP failover | Production |
| SigNoz observability pipeline | Production |
| GPU defense (Ollama memory limits, OOM protection) | Production — survived incident 2026-05-10 |
| Niri DRM healthcheck + GPU recovery | Production — self-heals or reboots |
| Display watchdog (dead display detection) | Fixed this session |
| EMEET PIXY webcam daemon | Production |
| Gatus health checks (26+ endpoints) | Production |
| Hermes AI gateway (Discord, cron) | Production |
| Centralized AI model storage (`/data/ai/`) | Production |
| Taskwarrior + TaskChampion cross-device sync | Production |
| 17 private Go repos as overlays via `_local_deps` pattern | Production |
| `lib/` shared helpers (harden, mkDockerService, mkStateDir, etc.) | Fully adopted |
| Catppuccin Mocha theme everywhere | Production |

---

## B) PARTIALLY DONE

| # | Item | What's Done | What's Missing |
|---|------|-------------|----------------|
| 1 | **niri-drm-healthcheck still uses old non-underscored vars in echo** | Functions inlined with `_state_*` prefix | Echo messages updated to `$_state_count`/`$_state_threshold` — **actually done, verified** |
| 2 | **rpi3-dns minimal NixOS image** | Module defined in flake.nix, overlays configured | Pi 3 hardware not provisioned — can't test or deploy |
| 3 | **DNS failover cluster (keepalived VRRP)** | Module written (`dns-failover.nix`), options defined | Depends on rpi3-dns being provisioned |
| 4 | **Caddy + Authelia forward auth** | Config deployed, working | Caddy failed on last `nh os switch` due to DNS race (should be fixed by unbound dependency) |
| 5 | **Hermes 0.11.0 → 0.13.0 upgrade** | Flake.lock updated, overlay patched | Failed to start during activation — DNS dependency was missing (now fixed, needs redeploy) |

---

## C) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | Mobile Nix integration (NixOnDroid / Termux) | Low | Research doc written (`e6ca78cc`), no implementation |
| 2 | Watchdogd hardware watchdog (SP5100 TCO) | Medium | Config partially broken (nixpkgs module bug with `device` and `reset-reason` sections) |
| 3 | DNS-over-QUIC (DoQ) via unbound | Low | Disabled — unbound not compiled with ngtcp2, kills binary cache hits |
| 4 | ComfyUI removal cleanup (Docker volumes, data migration) | Low | Service disabled but old data may still exist at `/data/ai/models/comfyui/` |
| 5 | Prometheus textfile collector for amdgpu metrics | Done | Already running — verify after deploy |
| 6 | `hostPlatform` → `stdenv.hostPlatform` migration | Won't fix | Auto-generated `hardware-configuration.nix`, upstream nixpkgs issue |
| 7 | SSH `matchBlocks` → `settings` migration | External | Comes from `nix-ssh-config` flake input, not local |

---

## D) TOTALLY FUCKED UP (Known Issues)

| # | Issue | Severity | Root Cause | Status |
|---|-------|----------|------------|--------|
| 1 | **Last `nh os switch` failed with 5 service failures** | CRITICAL | DNS race condition during activation — services started before unbound was ready. Fixed in this session by adding `unbound.service` dependency. **Needs redeploy to verify.** | Fixed in code, not yet deployed |
| 2 | **Darwin disk at 90-95%** (229 GB) | HIGH | nix-collect-garbage hangs, builds fail with errno=28. Need distributed builds to evo-x2 or aggressive cache clearing. | No fix — hardware constraint |
| 3 | **awww-daemon BrokenPipe crash loop** (v0.12.0) | MEDIUM | Upstream bug at `daemon/src/main.rs:712:32`. Worked around with `Restart=always` + `StartLimitBurst=3`. | Accepted — upstream bug |
| 4 | **~130W power ceiling** on evo-x2 | LOW | GMKtec firmware enforces PPT, no OS override. `ryzen_smu` lacks Strix Halo support. | Accepted — firmware limit |
| 5 | **watchdogd nixpkgs module broken** for `device` and `reset-reason` | LOW | nixpkgs generates unquoted string paths that watchdogd v4.1 can't parse. | Workaround — omit `device` from settings |
| 6 | **statix 0.5.8 can't parse Nix pipe operators** | LOW | Produces `:E:0:Error node` lines. Pre-commit hook filters these. | Accepted — upstream statix limitation |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Service dependency audit** — We just fixed hermes + Docker services, but should systematically audit ALL 35 service modules for missing `unbound.service` / `sops-nix.service` dependencies. A single missing dependency causes cryptic failures during activation.

2. **Activation smoke test** — After `nh os switch`, automatically verify that all enabled services are running. Could be a `just` recipe that checks `systemctl is-active` for every enabled service.

3. **`lib.sh` sourcing pattern** — We fixed the two scripts that used relative sourcing, but should consider a Nix-native approach: generate the state functions as a Nix derivation and pass the path as an argument to scripts.

4. **Overlay tooling completeness** — The `_local_deps` pattern works well but requires manual `vendorHash` updates across repos when a shared dependency changes. A `just` recipe or CI check that validates all overlay hashes would prevent cascading build failures.

### Code Quality

5. **Zero TODOs in codebase** — We have zero `TODO`/`FIXME`/`HACK` comments. This is both a strength (clean) and a risk (no tracking of known issues). Consider using Taskwarrior for tracking technical debt.

6. **Status reports proliferation** — 60+ status files in `docs/status/`. Most are historical. Consider an archival policy (move to `archive/` after 7 days).

7. **Home Manager deprecation warnings** — `programs.ssh.matchBlocks` → `programs.ssh.settings` is deprecated. This comes from the external `nix-ssh-config` flake input — need to update that repo.

### Operations

8. **Darwin disk management** — 229 GB at 95% is a ticking bomb. Need either distributed builds to evo-x2, aggressive GC automation, or a larger disk.

9. **DNS resolver hardening** — The entire system depends on unbound at `127.0.0.1`. If unbound crashes, ALL services fail. Consider a fallback mechanism or watchdog.

10. **Testing coverage** — We rely on `nix flake check` for validation but have no integration tests that verify services actually start. The `nh os switch` is the test, and failures are discovered in production.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical (P0) — Do Now

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Redeploy to evo-x2** — `nh os switch` to verify all dependency fixes work | 5 min | CRITICAL — 5 services were failing |
| 2 | **Verify all services running** after deploy — `systemctl --failed`, `just health` | 2 min | Confirm the fix |
| 3 | **Check unbound is running** — `systemctl status unbound` before any service start | 1 min | DNS is the foundation |

### High (P1) — This Week

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4 | **Audit ALL 35 service modules for missing dependencies** — grep for `network-online.target` without `unbound.service` | 30 min | Prevent future DNS races |
| 5 | **Create `just smoke-test` recipe** — verify all enabled services are active after switch | 30 min | Catch failures immediately |
| 6 | **Fix `programs.ssh.matchBlocks` deprecation** in `nix-ssh-config` repo | 1 hr | Silence 3 evaluation warnings |
| 7 | **Hermes 0.13.0 verification** — check if new features work, config changes needed | 30 min | Major version bump |
| 8 | **Clean up ComfyUI remnants** — remove Docker volumes, old data, service references | 15 min | Reclaim disk + clean closure |

### Medium (P2) — This Month

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | **Archive old status reports** — move >7-day reports to `docs/status/archive/` | 10 min | Clean docs |
| 10 | **Darwin distributed builds to evo-x2** — configure `builders` in nix.conf | 2 hr | Solve disk exhaustion |
| 11 | **Niri 2026-05-15 update verification** — check for regressions, config changes | 30 min | Stability |
| 12 | **Display watchdog integration test** — verify recovery ladder works end-to-end | 1 hr | Confidence in self-healing |
| 13 | **GPU memory monitoring alert** — add Gatus check for GPU VRAM usage | 30 min | Early warning for OOM |
| 14 | **DNS failover cluster provisioning** — set up Pi 3 with rpi3-dns config | 3 hr | High availability DNS |
| 15 | **Taskwarrior backup automation** — `just task-backup` via cron/hermes | 30 min | Data safety |
| 16 | **Sops secret rotation audit** — check age of all secrets, rotate stale ones | 1 hr | Security |

### Low (P3) — Backlog

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 17 | **Unbound `do-ip6` documentation** — add comment explaining WHY it's disabled on every instance | 15 min | Prevent future removal |
| 18 | **Overlay hash validation CI** — check all 17 private repo vendorHashes | 2 hr | Prevent cascade failures |
| 19 | **`lib.sh` Nix-native approach** — generate state functions from Nix, pass path to scripts | 1 hr | Eliminate copy-paste |
| 20 | **Mobile Nix integration** — NixOnDroid for Android tablet | 4 hr | Cross-device consistency |
| 21 | **watchdogd fix or replace** — hardware watchdog for kernel panics | 2 hr | Crash recovery |
| 22 | **BTRFS snapshot automation** — periodic snapshots of `/data` before service updates | 1 hr | Rollback capability |
| 23 | **Caddy config testing** — verify all virtual hosts resolve correctly after changes | 30 min | Prevent proxy failures |
| 24 | **Flake inputs cleanup** — audit unused inputs, consolidate follows | 1 hr | Build performance |
| 25 | **Documentation refresh** — AGENTS.md is 400+ lines, consider splitting into domain docs | 2 hr | Maintainability |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why does the evo-x2 DNS resolver fail with `[::1]:53 connection refused` instead of `127.0.0.1:53`?**

The `nameservers = ["127.0.0.1"]` config in `networking.nix` should make glibc use IPv4 localhost. But the error shows glibc trying IPv6 `[::1]:53`. This suggests either:

1. **`resolv.conf` has `::1` in it** — possible if something other than our config writes to `/etc/resolv.conf`
2. **glibc `getaddrinfo()` prefers IPv6** when both `127.0.0.1` and `::1` are available, even if resolv.conf only has `127.0.0.1`
3. **unbound binds to `::1` but not `0.0.0.0`** — our config has `interface = ["0.0.0.0" "::0"]` which should cover both, but unbound may not be listening on `::1` if IPv6 is partially broken

I cannot verify because I don't have SSH access to the NixOS machine from this session (the paste shows it was SSH'd from MacBook). **Please check after deploy: `cat /etc/resolv.conf` and `ss -tlnp | grep :53` on evo-x2.**

---

## Infrastructure Summary

| Metric | Value |
|--------|-------|
| NixOS service modules | 35 |
| Shell scripts | 17 |
| Home Manager programs | 14 |
| Custom packages | 6 |
| Overlays | 3 |
| Shared lib files | 7 |
| Total .nix lines | ~11,149 |
| Private Go repo overlays | 17 |
| DNS blocked domains | 2.5M+ |
| Gatus monitored endpoints | 26+ |
| Unpushed commits | 0 |
| `nix flake check` | PASSING |
| TODOs/FIXMEs in codebase | 0 |
| Evaluation warnings | 4 (3 external SSH, 1 upstream hostPlatform) |

## Session Activity

**20 commits today** (2026-05-17 through 2026-05-18), covering:
- Sessions 35-39: ecosystem maintenance, dep fixes, refactoring
- Session 40 (this): systemd dependency fixes, script lib.sh inlining, deprecation fixes

---

_Generated by Crush (Session 40)_
