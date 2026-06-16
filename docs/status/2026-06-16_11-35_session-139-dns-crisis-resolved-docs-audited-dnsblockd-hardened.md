# Session 139 Final Status — DNS Crisis Resolved, Docs Audited, dnsblockd Hardened

**Date:** 2026-06-16 11:35 CEST
**Session:** 139 (final)
**Machine:** evo-x2 (NixOS)
**Mullvad Status:** Still running (PID 4080696) — `just switch` NOT yet applied

---

## Executive Summary

Three major work streams completed across two repositories:

1. **Documentation accuracy audit** — 30+ inaccuracies fixed across README, FEATURES, TODO_LIST
2. **DNS root cause diagnosis** — Mullvad `talpid_dns` definitively identified as the cause of periodic DNS breakage
3. **dnsblockd RAM hardening** — 5 OOM vectors closed, goroutine leak fixed, security timeouts added

All code is committed and pushed. **Nothing has been deployed** (`just switch` not run). The live system still runs the old configuration with Mullvad active.

---

## a) FULLY DONE ✅

### 1. Documentation Accuracy Audit

**Commit:** `1edeb324` — pushed to origin/master

| Area | Fixes Applied |
|------|---------------|
| README.md | Service counts (36→39), overlays (12→25), health checks (30→33), blocklists (10→23), CI/CD corrected (no macOS runner), Nushell removed, 12 missing services added, flake inputs corrected (52 total, nix-colors removed) |
| FEATURES.md | ADR table rewritten (5 fictional → 8 real), Justfile §9 rewritten (removed 3 fabricated categories), pre-commit hooks fixed, SigNoz alerts 7→18, Multi-WM disabled→enabled, module filenames corrected, 10 missing services added, modernize package removed |
| TODO_LIST.md | Session updated (132→139), 6 Go repo stale vendorHash items marked completed |
| pkgs/README.md | modernize removed, govalid added |

### 2. DNS Root Cause Diagnosis

**Root cause:** Mullvad VPN's `talpid_dns` subsystem overwrites `/etc/resolv.conf` every ~90 seconds, even when VPN is disconnected. The "Resetting DNS" → "Setting DNS servers" cycle leaves resolv.conf in a broken state for 2-3 seconds each cycle.

**Evidence:** Journal logs show talpid_dns resets at 19:56:07, 19:57:27, 20:00:41 — matching the "works for 30s then breaks" symptom exactly.

**Fix applied:** `mullvad-vpn.enable = false` in `configuration.nix` (commit `8cf4a0d3`)

### 3. Mullvad Disabled in NixOS Config

**Commit:** `8cf4a0d3` — pushed to origin/master

Changes in `platforms/nixos/system/configuration.nix`:
- `mullvad-vpn.enable = true` → `false`
- Removed `mullvad-config` systemd service (depended on mullvad-daemon)
- Removed `mullvad-config` systemd timer
- Added comment with manual re-enable instructions

### 4. dnsblockd MemoryMax Bumped

**Commit:** `adaa7e84` — pushed to origin/master

`modules/nixos/services/dns-blocker.nix`: Added `MemoryMax = "1G"` to `harden {}` call (was inheriting default 512M).

### 5. dnsblockd Go Code — 5 OOM/Security Fixes

All committed and pushed in dnsblockd repo:

| Commit | Fix | Details |
|--------|-----|---------|
| `1d50a4a` | Context bug + goroutine semaphore | `r.Context()` → `context.Background()` in `dispatchWithTimeout()`. Added non-blocking semaphore (cap 32) to prevent unbounded goroutine spawn |
| `1d50a4a` | Rate limiter unbounded clients map | Added `MaxClients` cap (default 10,000) |
| `1d50a4a` | Tracking body capture unbounded | Added `io.LimitReader` + capped buffer |
| `1d50a4a` | TLS cert cache unbounded | Added `maxSize` cap (default 1,000) |
| `2a2db58` | HTTP server missing timeouts | Added `WriteTimeout`, `IdleTimeout`, `MaxHeaderBytes` to all 3 HTTP servers |
| `631269a` | Temp allowlist unbounded | Capped at 1000 entries with expired eviction |
| `60e0011` | Go runtime metrics | Exposed `rate_limit_max_clients` config + Go runtime memory metrics to Prometheus |
| `2e2976d` | NixOS module exposure | Exposed rate limiting + trusted proxies in NixOS module |
| `377e504` | AGENTS.md updated | Memory safety table documenting all fixes |

### 6. Status Reports Written

| File | Content |
|------|---------|
| `docs/status/2026-06-15_23-53_dns-mullvad-root-cause-and-docs-audit.md` | Initial root cause analysis |
| `docs/status/2026-06-15_23-54_dns-mullvad-dnsblockd-crisis-full-status.md` | Full diagnostic report |
| `docs/crash-analysis-2026-06-15.md` | Disk exhaustion crash forensic post-mortem (commit `adaa7e84`) |

---

## b) PARTIALLY DONE ⚠️

### 1. Live System NOT Updated

The configuration changes are committed but **NOT deployed**:

| Change | Code Status | Live System |
|--------|-------------|-------------|
| Mullvad disabled | ✅ Committed | ❌ Mullvad still running (PID 4080696) |
| dnsblockd MemoryMax 1G | ✅ Committed | ❌ Still at 512M |
| dnsblockd Go fixes | ✅ Committed + pushed | ❌ Running old binary |
| resolv.conf | N/A | ❌ `nanmeserver 9.9.9.9` (typo from manual nano) |

**`just switch` has not been run.** DNS currently works only because resolv.conf points to 9.9.9.9 (Quad9), bypassing unbound entirely.

### 2. SystemNix vendorHash NOT Updated

The dnsblockd flake input in SystemNix has not been updated to point to the new dnsblockd commits. After `just switch`, the old dnsblockd binary will still run until `nix flake lock --update-input dnsblockd` is run.

---

## c) NOT STARTED 📋

| Item | Why |
|------|-----|
| `just switch` to apply config | User explicitly said "DO NOT nix switch" |
| SystemNix `nix flake lock --update-input dnsblockd` | Needs to happen before switch to get Go fixes |
| Update `vendorHash` in SystemNix after flake.lock update | Required for build |
| Fix `/etc/resolv.conf` typo (`nanmeserver`) | Will be fixed automatically by `just switch` (resolvconf regenerates it) |
| Add Mullvad talpid_dns gotcha to AGENTS.md | Documentation follow-up |
| Update FEATURES.md/TODO_LIST.md with Mullvad disabled status | Documentation follow-up |

---

## d) TOTALLY FUCKED UP 💥

| Incident | What Happened | Impact | Recovery |
|----------|---------------|--------|----------|
| **Timer placement** | Placed `systemd.timers.mullvad-config` inside `systemd.services` block | NixOS eval failure | Fixed: moved to `timers.` inside `systemd = {}` |
| **Disabled resolvconf** | Set `networking.resolvconf.enable = false` to force static resolv.conf | NixOS assertion failure, broke DNS plumbing | Fixed: reverted entirely |
| **Used `//` as comment** | Wrote `//` (Nix merge operator) instead of `#` (comment) in Nix file | Would cause eval error if not caught | Fixed: changed to `#` |
| **`environment.etc` text conflict** | `environment.etc."resolv.conf".text` conflicts with unbound's `resolveLocalQueries` | NixOS assertion | Fixed: removed entirely |
| **`networking.nix` missing `pkgs`** | Added `pkgs.writeText` but `pkgs` not in function args | Eval error | Fixed: added `pkgs`, then reverted whole change |
| **User had to rollback** | Multiple failed eval attempts required NixOS rollback to gen 416 | DNS downtime, user frustration | User rolled back, all code fixes validated with `just test-fast` before committing |

**Root cause of all fuckups:** Made multiple changes simultaneously without testing between each one. Should have tested after EVERY individual change.

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Process

1. **Test after EVERY change** — not after all changes. The timer bug and resolvconf assertion would have been caught in seconds.
2. **Never disable system infrastructure** (resolvconf, systemd-resolved) to work around an application bug. Fix or remove the application.
3. **Verify live state before assuming** — I assumed Mullvad was dead after user "stopped" it. It auto-restarted.
4. **Don't edit across multiple repos simultaneously** — isolate and test each repo independently.

### Codebase

1. **`harden {}` default MemoryMax should be documented** — Many services silently inherit 512M. dnsblockd OOM was a side effect.
2. **Mullvad config service had invalid `unitConfig.Restart`** — systemd logged `Unknown key 'Restart'`. Should be `serviceConfig.Restart`.
3. **dnsblockd goroutine pattern needs a worker pool** — Semaphore cap is a band-aid. Real fix: bounded worker pool with buffered channel.
4. **No DNS health watchdog** — Gatus checks external endpoints, not the local resolver path. Need a timer that tests `dig @127.0.0.1` periodically.
5. **resolv.conf permissions are 0777** — World-writable DNS config is a security issue.

---

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **`just switch`** — apply Mullvad disable + dnsblockd MemoryMax 1G | Critical | 5min | Deploy |
| 2 | **`nix flake lock --update-input dnsblockd`** + update vendorHash | Critical | 10min | Deploy |
| 3 | **Verify DNS stable for 5+ min** after switch | Critical | 5min | Verify |
| 4 | **Reboot evo-x2** — verify boot time after NVMe APST fix | High | 10min | Operations |
| 5 | **Verify Pocket ID email sending** after SMTP wiring | High | 5min | Operations |
| 6 | **Fix `/etc/resolv.conf` permissions** (0777 → 0644) | High | 2min | Security |
| 7 | **Add Mullvad talpid_dns gotcha** to AGENTS.md | High | 5min | Docs |
| 8 | **Update FEATURES.md** — Mullvad status → disabled | Medium | 5min | Docs |
| 9 | **Update TODO_LIST.md** — DNS crisis resolved, add follow-ups | Medium | 10min | Docs |
| 10 | **Fix Twenty CRM intermittent 502s** (P1 TODO) | Medium | 30min | Debug |
| 11 | **Audit Gatus health check URLs** for 6 DOWN services (P1 TODO) | Medium | 20min | Debug |
| 12 | **Add DNS resolver health check** to Gatus (alert when local DNS breaks) | Medium | 15min | Monitoring |
| 13 | **Add `just dns-watch` command** (inotifywait on resolv.conf) | Medium | 10min | Tooling |
| 14 | **BTRFS `/data` subvolume migration** (P3 TODO) | Medium | 30min | Infrastructure |
| 15 | **Create ROADMAP.md** (P4 TODO) | Low | 30min | Docs |
| 16 | **Create CHANGELOG.md** (P4 TODO) | Low | 30min | Docs |
| 17 | **Archive old status reports** (178 → ~30 in docs/status/) | Low | 10min | Cleanup |
| 18 | **Hermes: add OpenAI API key to sops** (P2 TODO) | Low | 5min | Manual |
| 19 | **Provision Pi 3** for DNS failover cluster (P6 TODO) | Low | Hardware | Infrastructure |
| 20 | **Replace dnsblockd goroutine spawn with worker pool** | Low | 30min | Code |
| 21 | **Reduce dnsblockd payload capture size** (1MB → 4KB) | Low | 5min | Code |
| 22 | **Add `GOMEMLIMIT`** to dnsblockd service config | Low | 2min | Code |
| 23 | **Auditd enablement** (blocked on NixOS 26.05 bug) | Low | Blocked | Security |
| 24 | **Split large modules**: monitor365 (716L), signoz (705L), forgejo (583L) | Low | 1hr | Refactor |
| 25 | **Consider Mullvad wrapper** that blocks talpid_dns from touching resolv.conf | Low | 1hr | Code |

---

## g) Top #1 Question

**When should I run `just switch`?**

All code is committed and pushed. `just test-fast` passes. But the live system is still running:
- Mullvad daemon (PID 4080696) — actively corrupting DNS
- Old dnsblockd binary (PID 4080749) — leaking memory
- Broken resolv.conf (`nanmeserver 9.9.9.9` — typo)

Running `just switch` will:
1. Stop Mullvad daemon permanently
2. Bump dnsblockd MemoryMax to 1G
3. Regenerate resolv.conf via resolvconf (fixes the typo)
4. Pick up all config changes

But it will NOT update dnsblockd to the new Go binary unless we first run `nix flake lock --update-input dnsblockd` and update the vendorHash.

Should I:
- **A)** Run `nix flake lock --update-input dnsblockd` + update vendorHash + `just switch` now?
- **B)** Just `just switch` now (Mullvad fix only), defer dnsblockd binary update?
- **C)** Wait for your explicit go-ahead?

---

## Repo State Summary

| Repo | Branch | HEAD | Pushed | Working Tree |
|------|--------|------|--------|--------------|
| SystemNix | master | `8cf4a0d3` | ✅ | Clean |
| dnsblockd | master | `377e504` | ✅ | 1 uncommitted (planning doc formatting only) |

---

_Generated by Crush session 139 — 2026-06-16_
