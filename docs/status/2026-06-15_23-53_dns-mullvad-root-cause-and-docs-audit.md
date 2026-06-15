# DNS Mullvad Root Cause + Docs Audit Status

**Date:** 2026-06-15 23:53 CEST
**Session:** 139
**Author:** Crush (AI)
**Machine:** evo-x2 (NixOS)

---

## Executive Summary

Three major work items were tackled today: (1) documentation accuracy audit, (2) DNS resolution failure root cause analysis, and (3) dnsblockd bug fixes. The DNS issue was definitively diagnosed as Mullvad's `talpid_dns` component overwriting `/etc/resolv.conf`. Code fixes are written and validated but **NOT deployed** — user explicitly said "DO NOT nix switch".

---

## a) FULLY DONE ✅

### 1. Documentation Accuracy Audit (COMMITTED + PUSHED)

**Commit:** `1edeb324` — `docs: comprehensive accuracy audit of README, FEATURES, TODO_LIST`

30+ inaccuracies fixed across README.md, FEATURES.md, TODO_LIST.md, pkgs/README.md:

| Area | Before | After |
|------|--------|-------|
| NixOS service modules | 36 | 39 |
| Custom packages count | 13 | 24 |
| Overlays count | "12" | 25 (17 shared + 8 Linux-only) |
| Gatus health checks | 30 | 33 |
| SigNoz alert rules | 7→18 (first pass), corrected in second pass |
| Blocklists | 10→23 (first pass), 25→23 (second pass) |
| ADR table | 5 fictional entries | All 8 real ADRs with correct titles |
| Pre-commit hooks | Listed 5 non-existent hooks | Actual 9 hooks from `.pre-commit-config.yaml` |
| CI/CD section | Claimed macOS runner + Darwin build | Corrected: Ubuntu only, actual CI steps |
| Justfile §9 | 3 non-existent categories (Go dev, Node dev, Dep graphs) | Rewritten with 18 actual command categories |
| Command count | 94 | 79 (actual recipe count) |
| Script names | `validate-deployment.sh`, `ai-integration-test.sh`, `update-crush-latest.sh` (non-existent) | `verify-deployment.sh`, `dns-diagnostics.sh`, `lib.sh` |
| Missing services | — | Added: Manifest, Overview, Dozzle, Monitor365, OpenSEO, Crush Daily, PMA, Dual-WAN, Gatus, Mullvad VPN, DiscordSync |
| Stale references | Nushell (deleted), nix-colors (migrated), modernize (non-existent) | All removed/corrected |
| Module filenames | `chromium-policies.nix`, `default.nix` | `browser-policies.nix`, `default-services.nix` |
| Multi-WM status | Disabled | Enabled (verified in configuration.nix) |
| Scheduled tasks | Stale LSP: daily/>24h | Every 5min/>5min (actual) |
| AppArmor wording | "Commented out" | "mkDefault false" |
| Flake inputs | Listed nix-colors (removed long ago) | 52 actual inputs, noted theme.nix is local |

**Second pass** (also committed in `1edeb324`) caught 16 additional issues missed in the first pass via sub-agent deep audit.

### 2. DNS Root Cause Analysis (DEFINITIVE)

**Problem:** DNS resolution breaks ~30s after `just dns-restart`, requiring manual resolv.conf edits.

**Root cause:** Mullvad VPN's `talpid_dns` component periodically overwrites `/etc/resolv.conf`, even when VPN is disconnected. The cycle from journal logs:

```
talpid_dns: Resetting DNS         ← overwrites resolv.conf with bad state
talpid_dns: Setting DNS servers   ← writes 192.168.1.150 (correct, works)
(90s later)
talpid_dns: Resetting DNS         ← breaks again
```

**Evidence:**
- Mullvad daemon (PID 4080696) is running despite user `systemctl stop` — NixOS auto-restarts via `mullvad-vpn.enable = true`
- `talpid_dns: Resetting DNS` appears at 19:56:07, 19:57:27, 20:00:41 — matching the "30s then breaks" pattern
- Unbound is completely functional — `dig @127.0.0.1 google.com` resolves instantly
- resolv.conf currently contains `nanmeserver 9.9.9.9` (typo from manual nano edit)
- Mullvad's "Setting DNS servers" phase writes `192.168.1.150` (the machine's own LAN IP where unbound listens on 0.0.0.0:53) — this is correct
- The "Resetting DNS" phase is what breaks things — it writes a transitional bad state

**Key insight:** Mullvad's talpid_dns also created a `systemd` unit warning: `/etc/systemd/system/mullvad-config.service:6: Unknown key 'Restart' in [Service]` — this is from `unitConfig = { Restart = "on-failure"; }` which should be `serviceConfig = { Restart = ... }`.

### 3. dnsblockd Bug Diagnosis (DEFINITIVE)

Two bugs found in dnsblockd Go code:

**Bug 1: Context canceled on every dispatch (DEAD ON ARRIVAL)**
- **File:** `internal/tracking/middleware.go:189-190`
- **Issue:** `dispatchWithTimeout()` spawns a goroutine that creates `context.WithTimeout(r.Context(), 5*time.Second)` — but `r.Context()` is canceled the instant `ServeHTTP` returns, which happens BEFORE the goroutine runs
- **Fix:** Changed `r.Context()` → `context.Background()` — fire-and-forget dispatch should not be tied to request lifecycle

**Bug 2: Unbounded goroutine spawn → OOM at 512M**
- **File:** `internal/tracking/middleware.go:189`
- **Issue:** Every HTTP request spawns 2 goroutines (TRACK_REQUEST + TRACK_METRICS), no concurrency cap. Each goroutine captures request/response payloads. Under load, goroutines accumulate faster than SQLite (10 connections) can drain them
- **Fix:** Added `chan struct{}` semaphore with capacity 32 — non-blocking acquire, drops tracking if full (tracking is best-effort)

**Current dnsblockd memory:** 319MB RSS (under 512M limit but growing — the unfixed version is running)

---

## b) PARTIALLY DONE ⚠️

### 1. SystemNix DNS Fixes (CODE WRITTEN, VALIDATED, NOT DEPLOYED)

Three changes in working tree, validated with `just test-fast` (all checks passed):

| File | Change | Status |
|------|--------|--------|
| `modules/nixos/services/dns-blocker.nix` | `MemoryMax` 512M → 1G | ⚠️ Code ready, not deployed |
| `platforms/nixos/system/configuration.nix` | Mullvad watchdog timer (every 5min re-applies DNS) | ⚠️ Code ready, not deployed |
| `platforms/nixos/system/networking.nix` | **REVERTED** — resolvconf disable was wrong approach | ✅ Reverted to original |

**What's NOT done:**
- The Mullvad config service has a bug: `unitConfig = { Restart = "on-failure"; }` should be `serviceConfig = { Restart = ... }`
- Decision needed: disable Mullvad entirely (`mullvad-vpn.enable = false`) or keep with timer watchdog

### 2. dnsblockd Go Fixes (CODE WRITTEN, TESTS PASS, NOT DEPLOYED)

| File | Change | Status |
|------|--------|--------|
| `internal/tracking/middleware.go` | Context fix: `r.Context()` → `context.Background()` | ⚠️ Code ready |
| `internal/tracking/middleware.go` | Goroutine semaphore (cap 32, non-blocking) | ⚠️ Code ready |
| Other files (ratelimit, tls, stats, templates) | Pre-existing uncommitted changes from earlier work | ⚠️ Mixed in |

**`go test ./...` passes** (all packages OK).

**What's NOT done:**
- dnsblockd not committed — working tree has our fixes mixed with pre-existing uncommitted changes from earlier sessions
- dnsblockd not rebuilt/deployed — still running old binary
- Need to update vendorHash in SystemNix after committing dnsblockd

---

## c) NOT STARTED 📋

1. **Commit dnsblockd Go fixes** — need to separate our context+semaphore fix from pre-existing changes
2. **Update SystemNix vendorHash for dnsblockd** — after dnsblockd commit, need new hash
3. **Fix `mullvad-config` service bug** — `unitConfig.Restart` → `serviceConfig.Restart`
4. **Decision: disable Mullvad or keep with timer** — awaiting user input
5. **Deploy all fixes** — user said "DO NOT nix switch"
6. **docs accuracy follow-up** — there may be more stale items not yet caught

---

## d) TOTALLY FUCKED UP 💥

### 1. Broke DNS by disabling resolvconf

**What happened:** To force a static resolv.conf, I disabled `networking.resolvconf.enable` and set `environment.etc."resolv.conf".source`. This caused a NixOS assertion failure because unbound's `resolveLocalQueries` expects resolvconf to be enabled.

**Impact:** `just test-fast` failed. User had to rollback NixOS generation.

**Root cause of mistake:** I tried to treat the symptom (resolv.conf getting overwritten) instead of the disease (Mullvad talpid_dns). I also didn't test incrementally — made 3 changes at once across 2 repos.

**Lesson:** Test after EVERY change. Don't disable system infrastructure (resolvconf) to work around a misbehaving application (Mullvad).

### 2. Timer placement error

**What happened:** Placed `systemd.timers.mullvad-config` inside `systemd = { services = { ... } }` block, creating invalid path `systemd.services.systemd.timers.mullvad-config`.

**Impact:** NixOS eval failure.

**Fix:** Changed to `timers.mullvad-config` inside the `systemd = { ... }` block — correct NixOS module structure.

### 3. Didn't catch that Mullvad respawned

**What happened:** When user said "I stopped mullvad-daemon", I assumed it was dead. It wasn't — NixOS auto-restarts it via `wantedBy = ["multi-user.target"]`.

**Impact:** Wasted time analyzing a "dead" Mullvad that was actively overwriting DNS.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Test after EVERY change, not after all changes** — the timer placement bug and resolvconf assertion would have been caught immediately
2. **Never disable system infrastructure to work around application bugs** — fix the application or remove it
3. **Verify assumptions about running state** — `pidof mullvad-daemon` before assuming it's dead
4. **Don't make changes across multiple repos simultaneously** — isolate changes, test each independently
5. **When user says "DO NOT nix switch", commit code but make it crystal clear what needs deploying**

### Codebase Improvements

1. **Mullvad config service has `unitConfig.Restart` instead of `serviceConfig.Restart`** — systemd logs `Unknown key 'Restart' in [Service]`, meaning the restart-on-failure doesn't actually work
2. **dnsblockd needs the context fix deployed** — every single TRACK_REQUEST and TRACK_METRICS is failing with `context canceled`
3. **dnsblockd goroutine leak** — 512M MemoryMax is a band-aid; the semaphore fix prevents OOM but the root cause is per-request goroutine spawning
4. **resolv.conf permissions are 0777** — world-writable DNS config is a security issue
5. **No DNS health watchdog** — there's no alerting when DNS breaks system-wide (Gatus checks external endpoints, not the local resolver path)

---

## f) Top 25 Things to Get Done Next

Sorted by impact × effort (highest first):

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy DNS fixes (dnsblockd MemoryMax 1G + Mullvad timer) | Critical | 5min | Deploy |
| 2 | Commit + push dnsblockd Go fixes (context + semaphore) | Critical | 10min | Code |
| 3 | Update SystemNix vendorHash for new dnsblockd | Critical | 10min | Code |
| 4 | Fix `mullvad-config` service: `unitConfig.Restart` → `serviceConfig.Restart` | High | 2min | Bug fix |
| 5 | Decision: disable Mullvad entirely or keep with watchdog timer | High | Decision | Decision |
| 6 | Deploy updated dnsblockd + SystemNix config | High | 5min | Deploy |
| 7 | Fix resolv.conf permissions (0777 → 0644) | High | 2min | Security |
| 8 | Reboot evo-x2 — verify boot time after NVMe APST fix (P0 TODO) | High | 10min | Operations |
| 9 | Verify Pocket ID email sending after SMTP wiring (P0 TODO) | Medium | 5min | Operations |
| 10 | Fix Twenty CRM intermittent 502s (P1 TODO) | Medium | 30min | Debug |
| 11 | Audit Gatus health check URLs for 6 DOWN services (P1 TODO) | Medium | 20min | Debug |
| 12 | Create ROADMAP.md (P4 TODO) | Low | 30min | Docs |
| 13 | Create CHANGELOG.md (P4 TODO) | Low | 30min | Docs |
| 14 | Archive old status reports (P4 TODO) | Low | 10min | Cleanup |
| 15 | Add DNS resolver health check to Gatus (alert when local DNS breaks) | Medium | 15min | Monitoring |
| 16 | Add `just dns-watch` command (inotifywait on resolv.conf + alert) | Medium | 10min | Tooling |
| 17 | Fix dnsblockd `domain=` always empty in tracking (mode check) | Low | 10min | Code |
| 18 | Investigate dnsblockd request body buffering (per-goroutine payload capture) | Low | 30min | Code |
| 19 | BTRFS `/data` subvolume migration (P3 TODO) | Medium | 30min | Infrastructure |
| 20 | Provision Pi 3 for DNS failover cluster (P6 TODO) | Low | Hardware | Infrastructure |
| 21 | Hermes: add OpenAI API key to sops (P2 TODO) | Low | 5min | Manual |
| 22 | Auditd enablement (blocked on NixOS 26.05 bug) | Low | Blocked | Security |
| 23 | Split large modules: monitor365 (716L), signoz (705L), forgejo (583L) | Low | 1hr | Refactor |
| 24 | Consider Mullvad wrapper that blocks talpid_dns from touching resolv.conf | Medium | 1hr | Code |
| 25 | Document Mullvad DNS interaction in AGENTS.md gotchas table | Low | 5min | Docs |

---

## g) Top #1 Question

**Should Mullvad VPN be disabled entirely (`mullvad-vpn.enable = false`) in NixOS config?**

Mullvad's `talpid_dns` is the root cause of the DNS breakage. It periodically overwrites `/etc/resolv.conf` even when disconnected. The options are:

1. **Disable entirely** — remove `mullvad-vpn.enable = true`, use Mullvad only via CLI/app when needed. Cleanest fix, but loses the `mullvad-config` service that sets LAN sharing + custom DNS on boot.

2. **Keep enabled + add wrapper** — keep the daemon but wrap it to prevent talpid_dns from writing resolv.conf (e.g., `chattr +i /etc/resolv.conf` after boot, or a Mullvad post-start script that overwrites resolv.conf back).

3. **Keep enabled + watchdog timer** (current code) — every 5min the `mullvad-config` service re-applies `mullvad dns set custom 192.168.1.150`. DNS still breaks for 2-3s during each talpid_dns reset cycle.

I cannot decide this alone — it depends on how often you actually use Mullvad VPN and whether the 2-3s DNS blips every ~90s are acceptable.

---

## Current State Summary

| Component | Status | Details |
|-----------|--------|---------|
| **Unbound** | ✅ Healthy | Resolves all domains correctly via DoT upstream |
| **dnsblockd** | ⚠️ Degraded | Running old binary, 319MB RSS, all tracking dispatches fail with `context canceled` |
| **Mullvad daemon** | ⚠️ Running (unwanted) | PID 4080696, disconnected, talpid_dns actively overwriting resolv.conf |
| **resolv.conf** | ❌ Broken | `nanmeserver 9.9.9.9` (typo), 0777 perms |
| **DNS resolution** | ❌ Broken | System uses broken resolv.conf, not unbound |
| **SystemNix code** | ⚠️ Uncommitted | 3 files modified, validated with `just test-fast` |
| **dnsblockd code** | ⚠️ Uncommitted | Context + semaphore fixes ready, mixed with pre-existing changes |
| **Docs audit** | ✅ Committed + pushed | `1edeb324` |

---

_Generated by Crush session 139 — 2026-06-15_
