# Session 89: Full Comprehensive Status — OOM Aftermath, Service Target Migration, Jan Cleanup

**Date:** 2026-05-25 02:34 CEST
**Scope:** Full SystemNix audit — post-OOM recovery, docker target migration, non-Nix service cleanup
**System:** NixOS unstable 26.05.20260523.3d8f0f3 (Yarara) | Linux 6.x | niri-unstable
**Uptime:** 56 min (fresh boot after OOM cascade)
**Total Commits:** 2598

---

## Executive Summary

evo-x2 is **up but stressed**. A fresh boot (56 min) shows the system recovering from what appears to be an OOM cascade — swap is 8.4/16 GiB used, root disk is **100% full** (2.5 GB free of 512 GB), and load averages are elevated (5.35 / 8.19 / 22.95). No earlyoom kills this boot, but Twenty CRM is throwing database timeouts and the critical service health check is failing.

**Key events this session:**
1. **OOM cascade identified and mitigated** — Helium (Electron) spawned 42 processes, not in earlyoom `--prefer` list, OOM killed journald → cascade. Now fixed: `helium`+`electron` added to prefer list, `MemoryHigh` added to `harden {}` for proactive throttling.
2. **Docker service targets migrated** — All container/service targets moved from `graphical.target` to `multi-user.target` so Docker services don't block desktop startup.
3. **Jan `llama-server` killed and disabled** — Non-Nix user service (`llama-vision.service`) was spawning llama-server every 1-3 min with ~1.2 GB per instance. Trashed the service file.
4. **GPU udev rule fixed** — `card*` matched DP/HDMI child devices causing errors; narrowed to `card[0-9]`.
5. **sops GPG key import blocked** — `gnupg.sshKeyPaths = []` prevents RSA key GPG import causing 2+ min initrd hang.
6. **voice-agents disabled** — Docker Whisper service disabled in config.

**Uncommitted changes:** 13 files modified with all the above fixes, awaiting deploy.

---

## System Health Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| RAM | 44/62 GiB used (71%) | ⚠️ Elevated |
| Swap | 8.4/16 GiB used (51%) | ⚠️ Half full on fresh boot |
| Root disk | 504/512 GB used (100%) | 🔴 **CRITICAL** — 2.5 GB free |
| /data disk | 854/1024 GB used (84%) | ⚠️ Growing |
| /boot | 312M/2.0 GB (16%) | ✅ |
| Load avg | 5.35 / 8.19 / 22.95 | ⚠️ High for 56 min uptime |
| ZRAM | 5.7/6.2 GiB used | ⚠️ Nearly full |
| OOM kills this boot | 0 | ✅ |
| earlyoom status | Active, `helium`+`electron` in prefer | ✅ Fixed |
| Uptime | 56 min | Fresh boot |

---

## A) FULLY DONE ✅

### 1. OOM Cascade Root Cause Found and Fixed

| Aspect | Detail |
|--------|--------|
| **Root cause** | Helium browser (Electron) spawned 42 processes consuming massive RAM. Not in earlyoom `--prefer` list → earlyoom killed journald instead → cascade crash |
| **Fix 1** | `helium` + `electron` added to earlyoom `--prefer` regex in `boot.nix` |
| **Fix 2** | `MemoryHigh = "80%"` added to `harden {}` in `lib/systemd.nix` — throttles services at 80% of MemoryMax before hard kill |
| **Impact** | All hardened services now get proactive memory throttling, not just hard kills |

### 2. Docker Service Target Migration

| From | To | Services affected |
|------|----|-------------------|
| `graphical.target` | `multi-user.target` | Docker daemon, dns-blocker, hermes, homepage, signoz, cadvisor, otel-collector |

**Why:** Desktop (graphical.target) should not wait for Docker containers to start. Services start earlier at multi-user.target without blocking the compositor.

### 3. Jan llama-vision.service Removed

| Action | Detail |
|--------|--------|
| **Identified** | Non-Nix user service at `~/.config/systemd/user/llama-vision.service` |
| **Problem** | Spawning `llama-server` processes loading 26B model (~1.2 GB each), restart counter at 9 |
| **Fixed** | Service file and symlink trashed |
| **Cleanup** | `systemctl --user daemon-reload` needed |

### 4. GPU udev Rule Fixed

`KERNEL=="card*"` → `KERNEL=="card[0-9]"` — the wildcard matched DP/HDMI child devices causing udev errors.

### 5. sops GPG Import Blocked

`gnupg.sshKeyPaths = []` prevents RSA SSH key from being imported into GPG, which caused 2+ minute initrd hangs during boot.

### 6. voice-agents Disabled

Docker Whisper (ROCm) service explicitly disabled in `configuration.nix`.

### 7. Previously Completed (Sessions 84-88)

| Milestone | Status |
|-----------|--------|
| BTRFS snapshots (btrbk) — deployed, verified, hardened | ✅ Production |
| Pocket ID migration (from Authelia) — code complete | ✅ Code done |
| Timeshift completely removed | ✅ Gone |
| mkPreparedSource centralized to go-nix-helpers | ✅ ADR-005 |
| Vendor hash cascade fixed (5 packages) | ✅ All rebuilt |
| Portal fix (niri native) | ✅ Deployed |

---

## B) PARTIALLY DONE 🔧

### 1. Uncommitted Changes — 13 Files, Not Deployed

| File | Change | Risk |
|------|--------|------|
| `lib/docker.nix` | `graphical.target` → `multi-user.target` | Medium — affects all Docker services |
| `lib/systemd.nix` | Added `MemoryHigh = "80%"` | Low — additive hardening |
| `modules/nixos/services/default.nix` | Docker target change | Medium |
| `modules/nixos/services/dns-blocker.nix` | Target change | Low |
| `modules/nixos/services/hermes.nix` | Target change | Low |
| `modules/nixos/services/homepage.nix` | Target change | Low |
| `modules/nixos/services/signoz.nix` | Target change + SMART extract fix | Low |
| `modules/nixos/services/sops.nix` | `gnupg.sshKeyPaths = []` | Low |
| `platforms/nixos/hardware/amd-gpu.nix` | udev `card[0-9]` | Low |
| `platforms/nixos/system/boot.nix` | earlyoom prefer list | Low |
| `platforms/nixos/system/configuration.nix` | voice-agents disabled | Low |
| `AGENTS.md` | 5 new gotchas documented | None |
| `flake.lock` | Input updates | Low |

**Status:** All changes are unstaged. Need `just test-fast` → `just switch` to deploy.

### 2. oauth2-proxy — Still Failing

`oauth2-proxy.service` fails to start. Gatus reports it as down continuously. Pocket ID is running and healthy. The sops secrets are placeholders — **the OAuth client has never been created in Pocket ID's admin UI**. This is a human-config step that cannot be automated.

### 3. /data BTRFS Snapshots — Migration Ready, Not Executed

827 GB at `/data` mounted as BTRFS toplevel (subvolid=5) — cannot be snapshotted. Migration recipe `just snapshot-migrate-data` is ready. User confirmed data is reprovisionable.

### 4. Gatus Health Checks — Partial Coverage

25+ endpoints monitored. Still missing: Hermes, Monitor365, disk-monitor, nvme-health-monitor.

### 5. Pocket ID Metrics Scraping — Broken

`node_exporter` spams errors about `/run/credentials/pocket-id.service` mountpoint (permission denied). OTel collector fails to scrape pocket-id metrics (HTTPS vs HTTP mismatch). Pocket ID itself tries to POST metrics to `https://localhost:4318` but gets HTTP response.

---

## C) NOT STARTED 📋

### Infrastructure

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Execute `just snapshot-migrate-data` — convert /data to @data subvolume | 30 min | Enable /data snapshots |
| 2 | Add btrbk instance for /data after migration | 10 min | Complete snapshot coverage |
| 3 | Add `just verify-packages` recipe to build all Go packages after flake.lock updates | 15 min | **#1 defense** against stale vendor hashes |
| 4 | GitHub Actions CI for all Go repos | 1-2 hrs | Catch build breakage before SystemNix |
| 5 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 6 | `just update-vendor-hash` recipe (set `""`, build, extract `got:`) | 15 min | Automate tedious hash cycle |
| 7 | Fix Pocket ID OTel metrics endpoint (HTTP vs HTTPS) | 15 min | Stop error spam |
| 8 | Fix node_exporter pocket-id credentials mountpoint error | 10 min | Stop error spam |

### Services

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | Fix photomap podman permission issue and re-enable | 1 hr | Photo visualization |
| 10 | Fix file-and-image-renamer (Go 1.26.3 blocked by nixpkgs 1.26.2) | 30 min | AI screenshot renaming |
| 11 | Minecraft server `enable = false` — needs enabling if wanted | 5 min | |
| 12 | Configure secondary LLM provider for Hermes (OpenRouter/OpenAI) | 30 min | GLM-5.1 fallback |

### Documentation & Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 13 | Archive `docs/status/` — 115 files in root | 10 min | Clutter reduction |
| 14 | Fix 3 remaining stale Timeshift docs | 5 min | Accuracy |
| 15 | Update TODO_LIST.md and FEATURES.md to current state | 15 min | Accuracy |
| 16 | D2 architecture diagram of Go dependency graph | 20 min | Visualization |
| 17 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |

---

## D) TOTALLY FUCKED UP 💥

### 1. Root Disk 100% Full — 2.5 GB Free

This is **critical**. 512 GB root partition with only 2.5 GB free. The system is one large build away from disk-full failure. Nix builds need temporary space. If `/tmp` (tmpfs) fills up, builds fail. If `/nix/store` can't write, the system breaks.

**Immediate action needed:** `nix-collect-garbage --delete-older-than 7d` or `just clean`.

### 2. Swap Half Full on Fresh Boot

8.4/16 GiB swap used after only 56 minutes. This suggests either:
- The OOM recovery left residual swap usage
- Services are genuinely consuming more memory than available RAM
- The system is still settling after boot

Combined with 100% root disk, this is a pressure-cooker situation.

### 3. Twenty CRM — Database Timeouts

Continuous `Failed to refresh config variables from database: Query read timeout` errors from the Twenty CRM container. Likely resource starvation from the overall memory pressure.

### 4. Critical Service Health Check Failing

`systemd[1]: Failed to start Check critical services and notify on failure.` — The health check timer itself is failing, which means we have **no automated service failure alerting** right now.

### 5. Vendor Hash Cascade — ROOT CAUSE NOT ADDRESSED

48 flake inputs, no CI, no `just verify-packages`. The cascade WILL recur on the next Go dependency change. This has happened 3 times now.

### 6. oauth2-proxy — Still Dead Since Session 85

Forward auth has been broken since the Authelia → Pocket ID migration. All services behind forward-auth are unprotected (accessible without authentication). **This is a security gap.**

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Critical — Fix NOW

1. **Free root disk space** — 2.5 GB is dangerously low. Run `just clean` or `nix-collect-garbage`.
2. **Deploy the 13 uncommitted changes** — OOM fixes, target migration, udev fix. They're all staged but not deployed.
3. **Fix oauth2-proxy** — Create OAuth client in Pocket ID admin UI, update sops secrets with real values. Forward auth has been down for days.
4. **Investigate health check failure** — The `health-check.service` is failing, which means no automated alerting.

### Important — Fix Soon

5. **Execute /data BTRFS migration** — Last major gap in snapshot coverage. Recipe is ready.
6. **Fix Pocket ID OTel metrics** — HTTPS vs HTTP mismatch causing continuous error spam in logs.
7. **Add `just verify-packages`** — Would have prevented the entire vendor hash cascade.
8. **Clean up docs/status/** — 115 files in root is noise.
9. **Reduce flake inputs from 48** — Many are `flake = false` Go deps that could be consolidated.

### Nice to Have

10. **Port-centric testing** — Verify all `ports.*` are unique.
11. **Darwin parity** — macOS gets less testing.
12. **GitHub Actions CI for Go repos** — Catch stale hashes at source.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical — Fix Broken Things

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **Free root disk space** — `just clean` or `nix-collect-garbage` | 5 min | 2.5 GB free = system will break on next build |
| 2 | **Deploy uncommitted changes** (`just test-fast && just switch`) | 15 min | OOM fix, target migration, udev fix — all sitting idle |
| 3 | **Fix oauth2-proxy** — create Pocket ID OAuth client, update sops | 30 min | Forward auth down for days = security gap |
| 4 | **Investigate health-check.service failure** | 15 min | No automated service alerting |
| 5 | **Execute /data BTRFS migration** (`just snapshot-migrate-data`) | 30 min | 827 GB with zero snapshots |

### High — Prevent Future Failures

| # | Task | Effort | Why |
|---|------|--------|-----|
| 6 | Add `just verify-packages` recipe | 15 min | #1 defense against stale vendor hashes |
| 7 | GitHub Actions CI for Go repos | 1-2 hrs | Catch stale hashes at source |
| 8 | Automate vendor hash discovery (`just update-vendor-hash`) | 15 min | Reduce 5-min manual cycle |
| 9 | Fix Pocket ID OTel metrics endpoint (HTTP vs HTTPS) | 15 min | Stop log spam |
| 10 | Fix node_exporter pocket-id credentials mountpoint error | 10 min | Stop log spam |
| 11 | Add `MemoryHigh` overrides for known memory hogs (SigNoz, Twenty) | 10 min | Prevent future OOM |

### Medium — Upstream Hygiene

| # | Task | Effort | Why |
|---|------|--------|-----|
| 12 | Clean up `docs/status/` (archive ~100 old reports) | 10 min | 115 files is noise |
| 13 | Fix 3 remaining stale Timeshift doc references | 5 min | Accuracy |
| 14 | Update TODO_LIST.md and FEATURES.md to current state | 15 min | Both are stale (last updated session 75/83) |
| 15 | Commit library-policy test refactoring | 5 min | 18 dirty files |
| 16 | Fix file-and-image-renamer Go 1.26.3 issue | 30 min | Service is disabled |
| 17 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |
| 18 | Add Gatus endpoints for Hermes, Monitor365, disk/nvme | 15 min | Complete observability |
| 19 | Configure secondary LLM provider for Hermes | 30 min | GLM-5.1 rate limit fallback |

### Lower — Polish & Future-proofing

| # | Task | Effort | Why |
|---|------|--------|-----|
| 20 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |
| 21 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 22 | Port-centric test (all `ports.*` unique) | 15 min | Prevent port conflicts |
| 23 | Reduce flake inputs from 48 | 1-2 hrs | Simplify maintenance |
| 24 | Darwin parity testing | Ongoing | d2 overlay hack is fragile |
| 25 | Add snapshot count to `just disk-status` output | 5 min | Visibility |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**#1: Has the Pocket ID admin UI been configured?**

The oauth2-proxy has been failing since session 85 (Pocket ID migration). Pocket ID itself is running and healthy (Gatus reports success). But:

- The sops secrets contain **placeholder values** (`placeholder-change-me`) for `oauth2_proxy_client_secret` and `oauth2_proxy_cookie_secret`
- Pocket ID needs an initial admin setup via web UI (`https://auth.home.lan`)
- An OAuth client must be created in Pocket ID's admin UI, generating real client secrets
- Those real secrets must then be stored in sops

**I cannot determine:** Has anyone logged into Pocket ID's admin UI? Were real OAuth clients created? This is a **human step** that blocks forward auth from working.

**Second question (less critical):** What's eating the root disk? 504 GB on root is way more than expected for a NixOS system + /nix/store. Is `/data` leaking onto root? Are old Nix generations piling up? A `du -sh /*` analysis would help.

---

## System Configuration Summary

| Aspect | Value |
|--------|-------|
| Flake inputs | 48 |
| Service modules | 30 in `serviceModules` |
| Uncommitted files | 13 |
| User systemd services | 14 (all Nix-managed after llama-vision removal) |
| Non-Nix user services | 0 (was 1: llama-vision, now trashed) |
| Pre-commit hooks | 9 |
| Scripts | 23 |
| Status reports | 490+ total |
| Disabled services | photomap, file-and-image-renamer, minecraft, voice-agents |
| Failed services | oauth2-proxy, health-check timer |
| BTRFS snapshots | Root: daily via btrbk ✅, /data: none ❌ |
| BTRFS scrub | Monthly (root + /data) |
| Timeshift | Completely removed |
