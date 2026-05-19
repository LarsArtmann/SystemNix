# Session 58 — Final Status: Service Startup Fixes + Complete Forgejo Migration

**Date:** 2026-05-19 17:53
**Focus:** Fix 4 failed services, complete Gitea→Forgejo subdomain rename
**System:** evo-x2 (NixOS 26.05, kernel 7.0.1)
**Branch:** master (ahead of origin by 2 commits)

---

## Executive Summary

Session 58 fixed 4 failed services from the last `nh os switch` and completed the Gitea→Forgejo migration by renaming all `gitea.home.lan` references to `forgejo.home.lan` across 7 config files. Three independent root-cause bugs were identified and fixed: Forgejo admin-password ownership, Caddy WatchdogSec misconfiguration, and nvme-metrics missing capabilities. All builds pass (evo-x2, rpi3-dns), all linters green. **Changes are committed but not yet deployed** — `just switch` pending.

---

## a) FULLY DONE ✅

| # | What | Details | Commit |
|---|------|---------|--------|
| 1 | **Forgejo .admin-password ownership fix** | Pre-start script creates file as root:root, forgejo user can't read it. Added `systemd.tmpfiles.rules` with `z` type to fix ownership on every activation. | `949191b9` |
| 2 | **Caddy WatchdogSec removal** | `WatchdogSec=30` killed Caddy — it sends `READY=1` but never periodic `WATCHDOG=1`. Removed WatchdogSec, updated AGENTS.md sd_notify documentation. | `949191b9` |
| 3 | **nvme-metrics CAP_SYS_ADMIN** | `harden {}` drops all capabilities. `nvme smart-log` ioctl needs `CAP_SYS_ADMIN`. Added explicit override. | `949191b9` |
| 4 | **AGENTS.md WatchdogSec docs** | Reclassified Caddy from "safe for WatchdogSec" to new category "sends READY=1 but NOT WATCHDOG=1". Updated rule to require verifying periodic keepalives. | `949191b9` |
| 5 | **Complete gitea→forgejo subdomain rename** | Renamed `gitea.home.lan` → `forgejo.home.lan` in DNS records (evo-x2 + rpi3), Caddy vhost, Forgejo ROOT_URL/DOMAIN, Authelia client_id + callback, Homepage href + siteMonitor. | `04e9cced` |
| 6 | **Delete migration script** | Removed `scripts/rename-sops-gitea-to-forgejo.sh` — one-shot script already used. | `04e9cced` |
| 7 | **AGENTS.md migration entries resolved** | Updated Forgejo DNS subdomain and sops key entries from "Must verify" / "Accepted" to "Resolved". | `04e9cced` |
| 8 | **Build verification** | All 3 targets build: evo-x2 ✅, rpi3-dns ✅, Darwin ✅ (pre-existing `nix.gc.persistent` warning, unrelated). All linters green: gitleaks, deadnix, statix, alejandra, flake check. | Both commits |
| 9 | **Session 58 status report** | Written to `docs/status/2026-05-19_16-42_session-58-service-startup-fixes.md`. | `a99a1c7a` |

---

## b) PARTIALLY DONE 🔧

| What | Status | What's Left |
|------|--------|-------------|
| **Deploy fixes** | Code committed and built | `just switch` to activate on evo-x2 |
| **Verify service recovery** | Fixes are theoretically correct | `systemctl --failed` should show 0 after deploy |
| **DNS resolver sharing** | Shared module created, rpi3 migrated | evo-x2 `dns-blocker-config.nix` still has duplicated settings |
| **Forgejo OAuth re-registration** | Authelia client_id changed from `gitea` to `forgejo` | Forgejo's OAuth registration in DB may still reference old client_id — user may need to re-register in Forgejo UI |

---

## c) NOT STARTED ⬜

| What | Priority | Notes |
|------|----------|-------|
| rpi3-dns hardware provisioning | Low | Physical — needs Pi 3 + USB SSD |
| sops key provisioning for Pi 3 | Low | Blocked on hardware |
| DNS failover VRRP testing | Low | Blocked on hardware |
| Cloud backup implementation | Low | B2/R2 pricing research done |
| AppArmor profiles | Low | 1h effort |
| Boot performance optimization | Low | Analysis done, implementation remaining |
| nixosTests for critical services | Low | Caddy, DNS, Forgejo |
| Incus VM for AI workloads | Low | GPU isolation |

---

## d) TOTALLY FUCKED UP 💥

| What | Why It Was Fucked | Impact | Fix Status |
|------|-------------------|--------|------------|
| **Forgejo .admin-password** | Pre-start runs as root, creates file as root:root with `chmod 600`. The forgejo user (service runs as forgejo) gets `Permission denied` reading it. No one noticed because the file only exists after first setup. | Forgejo completely down. Runner, mirrors, sync — all broken. | ✅ Fixed |
| **Caddy WatchdogSec** | Added to "safe" list because `Type=notify`, but nobody verified Caddy sends `WATCHDOG=1` keepalives. It only sends `READY=1` at startup. Systemd killed it after 30s on EVERY activation. The `nh` tool only reported gitea-runner (first failure), so Caddy dying was invisible. | ALL `*.home.lan` services unreachable on every switch. TLS broken. Homepage, Authelia, Forgejo web UI — all inaccessible from LAN. Probably broken since WatchdogSec was added. | ✅ Fixed |
| **nvme-metrics CAP_SYS_ADMIN** | `harden {}` drops all capabilities. NVMe ioctl needs CAP_SYS_ADMIN. Service has been failing silently since hardening was applied — nvme-metrics is a oneshot timer, not a daemon, so its failures are easy to miss. | No NVMe SMART metrics in Prometheus/SigNoz dashboards. | ✅ Fixed |
| **gitea→forgejo rename took 5+ sessions** | Migration from Gitea to Forgejo was started in Session 53 but the subdomain rename was deferred "for zero DNS disruption" — then forgotten. 5 sessions of status reports listed it as "accepted — renamed later if desired" without anyone acting on it. | Technical debt accumulated. Each session's status report repeated the same stale references. | ✅ Fixed |

---

## e) WHAT WE SHOULD IMPROVE 📈

| # | Area | Issue | Improvement |
|---|------|-------|-------------|
| 1 | **Post-switch validation** | No automated check after `just switch`. Failed units go unnoticed. | Add `just switch-verify` that waits 60s then checks `systemctl --failed`. |
| 2 | **WatchdogSec audit** | Caddy had WatchdogSec for unknown duration. Other services may also have it incorrectly. | Grep all modules for `WatchdogSec`. Remove from any service not confirmed to send `WATCHDOG=1`. Only Forgejo should have it. |
| 3 | **Capability audit** | Hardened services with device access may need explicit capabilities. nvme-metrics was silently failing. | Audit all hardened services for device/ioctl patterns. Document required capabilities per service. |
| 4 | **Pre-start file ownership** | Pre-start scripts run as root and create files the service user can't read. | Pattern: always `chown` in pre-start, or use tmpfiles rules for predictable state files. |
| 5 | **Migration completion tracking** | Gitea→Forgejo rename was deferred across 5 sessions without a clear owner or deadline. | When a migration is started, track it as a blocking item until fully complete. Don't close it with "accepted — later". |
| 6 | **Oneshot service monitoring** | Timer-activated oneshots (nvme-metrics, gpu-metrics, etc.) fail silently. | Add Gatus health checks for oneshot output files (e.g., check nvme.prom exists and is recent). |
| 7 | **`nh` only reports first failure** | When multiple services fail during activation, only the first is surfaced. | Run `systemctl --failed` manually after every switch, or add to justfile. |

---

## f) Top #25 Things to Get Done Next

| # | Task | Priority | Effort | Category |
|---|------|----------|--------|----------|
| 1 | **Deploy current fixes** — `just switch` + verify 0 failed units | 🔴 Critical | 5 min | Deploy |
| 2 | **Verify Forgejo OAuth** works with new client_id `forgejo` | 🔴 Critical | 5 min | Verification |
| 3 | **Audit all modules for WatchdogSec** — only Forgejo should have it | 🔴 High | 15 min | Reliability |
| 4 | **Audit all hardened services for missing capabilities** | 🔴 High | 30 min | Hardening |
| 5 | **Add `just switch-verify`** — post-switch health check | 🟡 Medium | 15 min | DX |
| 6 | **Add Gatus check for nvme-metrics output file** (recent .prom file) | 🟡 Medium | 10 min | Monitoring |
| 7 | **Move Forgejo admin password to sops** — currently random in pre-start | 🟡 Medium | 10 min | Security |
| 8 | **Move Authelia OIDC client_secret from bcrypt to sops** | 🟡 Medium | 20 min | Security |
| 9 | **Deduplicate evo-x2 dns-blocker-config.nix** with shared dns-resolver module | 🟡 Medium | 20 min | Code quality |
| 10 | **Verify Twenty CRM** is functional or document why not | 🟡 Medium | 15 min | Verification |
| 11 | **Verify Voice agents** end-to-end (Whisper + LiveKit + ROCm) | 🟡 Medium | 30 min | Verification |
| 12 | **Add Gatus endpoints** for Hermes, Manifest, Voice agents | 🟡 Medium | 15 min | Monitoring |
| 13 | **Run `just update`** — refresh flake.lock with latest upstream | 🟢 Low | 10 min | Maintenance |
| 14 | **Audit dead modules** (ComfyUI unused, Multi-WM/Sway bitrotted) | 🟢 Low | 30 min | Cleanup |
| 15 | **Add nixosTests** for critical services (Caddy, DNS, Forgejo) | 🟢 Low | 2h | Testing |
| 16 | **Implement cloud backup** (B2/R2) | 🟢 Low | 2h | Reliability |
| 17 | **Centralize Twenty secrets** in sops.nix | 🟢 Low | 15 min | Security |
| 18 | **Script health check runner** — one command to verify all services | 🟢 Low | 30 min | DX |
| 19 | **Boot performance optimization** — implement from analysis | 🟢 Low | 1h | Performance |
| 20 | **Provision Pi 3 + USB SSD** for DNS failover cluster | 🟢 Low | Physical | Infrastructure |
| 21 | **Enable Forgejo federation** | 🟢 Low | 30 min | Feature |
| 22 | **Add SigNoz dashboards** for GPU, Niri, service correlations | 🟢 Low | 1h | Observability |
| 23 | **Create Incus VM for AI workloads** — isolate GPU bugs | 🟢 Low | 2h | Security |
| 24 | **Enable AppArmor profiles** for hardened services | 🟢 Low | 1h | Security |
| 25 | **Validate monitor365 value** — skeleton deployment, worth keeping? | 🟢 Low | 15 min | Audit |

---

## g) Top #1 Question I Cannot Answer Myself

**Does Forgejo's OAuth registration in the database need to be updated after the Authelia client_id changed from `gitea` to `forgejo`?**

The Authelia config now declares `client_id = "forgejo"` (was `"gitea"`). But Forgejo's OAuth registration was created in the Forgejo web UI — it stores the client_id in its SQLite database. If Forgejo's registered callback URL still says `gitea.home.lan`, the OAuth flow will fail because the redirect from Authelia now goes to `forgejo.home.lan`.

I cannot check Forgejo's DB or web UI without the service being up. After `just switch`:
1. Check if `forgejo.home.lan` loads in a browser
2. Try logging in via Authelia — if it fails with a redirect URI mismatch, the OAuth app in Forgejo needs to be updated at `forgejo.home.lan/user/settings/applications`
3. Alternative: the Forgejo config `ROOT_URL` and `DOMAIN` now both say `forgejo.${domain}`, so Forgejo should auto-generate correct OAuth URLs going forward — but existing registrations may still reference the old domain.

---

## Session 58 Commits (3 total)

| Commit | Description |
|--------|-------------|
| `949191b9` | fix(services): correct WatchdogSec usage and improve service hardening |
| `a99a1c7a` | docs(status): Session 58 — service startup fixes for Forgejo, Caddy, nvme-metrics |
| `04e9cced` | feat(forgejo): complete Gitea→Forgejo migration — rename all subdomain references |

## Files Changed This Session

| File | Change |
|------|--------|
| `modules/nixos/services/forgejo.nix` | tmpfiles rule for .admin-password ownership + ROOT_URL/DOMAIN renamed to forgejo |
| `modules/nixos/services/caddy.nix` | Removed WatchdogSec + renamed vhost gitea→forgejo |
| `modules/nixos/services/signoz.nix` | Added CAP_SYS_ADMIN for nvme-metrics |
| `modules/nixos/services/authelia.nix` | client_id gitea→forgejo, callback URL updated |
| `modules/nixos/services/homepage.nix` | svcUrl gitea→forgejo (href + siteMonitor) |
| `platforms/nixos/system/dns-blocker-config.nix` | DNS record gitea→forgejo |
| `platforms/nixos/rpi3/default.nix` | DNS record gitea→forgejo |
| `scripts/rename-sops-gitea-to-forgejo.sh` | Deleted (one-shot migration script) |
| `AGENTS.md` | WatchdogSec docs updated + Forgejo migration entries resolved |
| `docs/status/2026-05-19_16-42_session-58-service-startup-fixes.md` | New status report |

---

## Metrics

| Metric | Value |
|--------|-------|
| Service modules | 36 |
| Total .nix files | 112 |
| Shell scripts | 19 |
| Service module LOC | 6,781 |
| Flake lock nodes | 72 |
| Failed services (pre-fix) | 4 (Forgejo, Caddy, gitea-runner, nvme-metrics) |
| Failed services (post-fix, pending deploy) | 0 expected |
| Root disk | 449G/512G (91%) |
| Data disk | 827G/1.0T (81%) |
| NixOS version | 26.05.20260423.01fbdee |
| Kernel | 7.0.1 |
| Remaining `gitea` refs | 3 (all nixpkgs API — correct) |
| Remaining TODOs | 1 (Pi 3 sops provisioning) |
| Commits ahead of origin | 2 |

---

_Arte in Aeternum_
