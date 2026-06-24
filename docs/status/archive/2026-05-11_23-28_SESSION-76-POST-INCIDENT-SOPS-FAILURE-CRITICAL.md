# SystemNix Full Comprehensive Status Report

**Date:** 2026-05-11 23:28 CEST
**Uptime:** 47 minutes (3rd boot today)
**Session:** 76 — Post-Incident Recovery

---

## Executive Summary

**SYSTEM IS SEVERELY DEGRADED.** A sops-nix misconfiguration (`owner = "gatus"` referencing a non-existent user) prevented ALL secrets from being decrypted at boot, causing a catastrophic cascade: Caddy, Authelia, ClickHouse, Immich, LiveKit, Gatus, Hermes, Twenty, Manifest, OpenSEO, SigNoz, dnsblockd, and niri-health-metrics are ALL down. The fix was committed (`d663dc2e`) but the booted generation still has the broken sops manifest. A `just switch` is required immediately to recover.

---

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| **Kernel** | Linux 7.0.1 | OK |
| **NixOS** | 26.05.20260423.01fbdee (unstable) | OK |
| **Nix** | 2.34.6 | OK |
| **Uptime** | 47 min (3rd boot today) | WARN |
| **Load** | 1.16, 3.85, 5.10 | High (recovering) |
| **Memory** | 36G/62G used (61%) | OK |
| **Swap** | 9.1G/25G used (36%) | Elevated |
| **Root disk** | 80% used, 99G free of 512G | WARN |
| **Data disk** | 80% used, 206G free of 1.0T | WARN |
| **Nix store** | 94G | Needs clean |
| **GPU (AMD)** | Active, niri running | OK |
| **DNS (Unbound)** | Active | OK |
| **DNS Blocker (dnsblockd)** | Crashed (no secrets) | CRITICAL |
| **Compositor (Niri)** | Running | OK |
| **Sops secrets** | NONE DECRYPTED | **CRITICAL** |

---

## Incident Timeline — 2026-05-11

### Boot 1: May 10 20:10 — CRASHED (~26 hours uptime)

| Time | Event |
|------|-------|
| May 10 20:11 | **Boot completes.** sops secrets decrypt successfully (gatus-env has `owner = "gatus"` — this was the OLD config) |
| May 10 20:11 | Caddy starts but hits **WatchdogSec=30 timeout** → SIGABRT. TLS cert maintenance (`certmagic.(*Cache).maintainAssets`) hangs |
| May 10 20:11-20:12 | Caddy restart loop (3x watchdog → start-limit-hit). Recovers after cooldown |
| May 10 20:30+ | Niri starts spamming `Error::DeviceMissing` at ~8/second — 410,014 total errors over 26 hours |
| May 11 11:17-11:49 | Caddy watchdog crash cycle repeats (3x SIGABRT → start-limit-hit → cooldown → repeat) |
| May 11 20:11 | Memory pressure: `mem avail: 4146 of 43118 MiB (9.62%)` — earlyoom threshold approached |
| May 11 22:00-22:21 | Caddy watchdog crash cycle intensifies (8 SIGABRTs in 21 min) |
| May 11 22:31 | User initiates `just switch` (builds generation 316 with sops fix) |
| May 11 22:32 | **Manual reboot** to apply new generation |

### Boot 2: May 11 22:32 — FAILED (8 minutes)

| Time | Event |
|------|-------|
| 22:32 | Boot starts with generation 316 |
| 22:32 | **sops-install-secrets FAILS:** `failed to lookup user 'gatus': user: unknown user gatus` |
| 22:32 | **ALL secrets missing:** `/run/secrets/` is empty |
| 22:32-22:40 | Every secret-dependent service crashes in cascade (Caddy, ClickHouse, Authelia, Immich, LiveKit, Gatus, Hermes, etc.) |
| 22:40 | **Manual reboot** again |

### Boot 3: May 11 22:41 — CURRENT (47 min uptime)

| Time | Event |
|------|-------|
| 22:41 | Same generation 316 boots |
| 22:41 | **Same sops failure:** `failed to lookup user 'gatus': user: unknown user gatus` |
| 22:41 | `/run/secrets/` is **EMPTY** — zero secrets decrypted |
| 22:41-23:20 | All secret-dependent services in permanent crash loop |
| 23:16 | User attempted `just switch` to rebuild + apply — Caddy briefly started but hit watchdog timeout again |
| 23:17+ | ClickHouse: `Failed to set up mount namespacing: /var/log/clickhouse-server: No such file or directory` — log dir missing |

---

## a) FULLY DONE

| Area | Details |
|------|---------|
| **Cross-platform flake** | Darwin + NixOS shared config (~80% via `platforms/common/`) |
| **Niri compositor** | Running, wrapped config, session manager, wallpaper self-healing, DRM healthcheck |
| **GPU defense** | OLLAMA_MAX_LOADED_MODELS=1, GPU overhead reservation, per-service memory fractions, OOMScoreAdjust |
| **GPU recovery** | Unbind/rebind script, auto-reboot on failure, consecutive DRM error counter |
| **DNS stack** | Unbound + dnsblockd, 2.5M+ domains blocked, Quad9 DoT upstream (when secrets work) |
| **Overlay architecture** | Extracted to `overlays/` directory, shared + linux-only separation |
| **Service hardening** | All services use `harden{}` from shared lib, 100% adoption |
| **Shared lib** | `lib/` with systemd.nix, user-harden.nix, service-defaults.nix, types.nix, rocm.nix, mkGraphicalUserService |
| **Taskwarrior sync** | Zero-config cross-platform sync via TaskChampion, deterministic client IDs |
| **AI model storage** | Centralized `/data/ai/` structure, all services reference `services.ai-models.paths` |
| **Observability design** | SigNoz pipeline (node_exporter, cAdvisor, journald, OTLP) — built but currently broken |
| **Health monitoring** | Gatus with 26+ endpoints, Discord alerting — designed but currently broken |
| **EMEET PIXY webcam** | Full daemon with auto-tracking, Waybar integration, HID state sync |
| **Catppuccin Mocha** | Universal theme across all apps, terminals, bars, login screen |
| **Justfile task runner** | 50+ commands for all operations, grouped by category |
| **Quality tooling** | treefmt + alejandra + deadnix + shellcheck + statix integrated |
| **Justfile-based build** | No raw nixos-rebuild, all operations via `just` |
| **Caddy port references** | All ports derived from service module options, never hardcoded |
| **Sops fix committed** | `d663dc2e` — changed gatus-env owner from "gatus" to "root" (but not yet applied) |

---

## b) PARTIALLY DONE

| Area | Status | Blocker |
|------|--------|---------|
| **SigNoz observability** | Built from source, all components defined, alert rules + dashboards committed | **Down** — ClickHouse can't start (missing `/var/log/clickhouse-server`), secrets missing |
| **Gatus health checks** | 26+ endpoints defined, Discord alerting, SQLite storage | **Down** — sops secrets missing, environmentFile can't load |
| **Hermes AI gateway** | Installed, system user, state dirs, sops templates | **Down** — sops secrets missing |
| **Authelia SSO** | Full config with OIDC, forward auth on Caddy | **Down** — sops secrets missing |
| **Immich photo management** | Docker-based, OAuth integration | **Down** — sops secrets missing (credentials fail) |
| **OpenSEO** | Docker-compose wrapper, DataForSEO integration | **Down** — sops secrets missing |
| **Caddy reverse proxy** | TLS with dnsblockd certs, all service vhosts defined | **Down** — sops secrets missing + watchdog timeout pattern |
| **Twenty CRM** | Docker-compose, running but unreachable | Running but Caddy can't proxy |
| **Manifest LLM router** | Docker-compose, running but unreachable | Running but Caddy can't proxy |
| **dnsblockd** | Active but crashing every 60s | sops secrets missing |
| **niri-health-metrics** | Script works, prometheus textfile collector | Permission denied writing to textfile dir |
| **rpi3-dns** | NixOS config committed, flake builds | **Not provisioned** — Pi 3 hardware not set up |
| **DNS failover (Keepalived)** | Module written, VRRP config ready | **Blocked** by rpi3-dns provisioning |
| **ClickHouse** | Part of SigNoz stack, built from source | `/var/log/clickhouse-server` missing — tmpfiles rule not creating it |

---

## c) NOT STARTED

| Area | Notes |
|------|-------|
| **rpi3-dns provisioning** | Pi 3 hardware not yet provisioned, image not flashed |
| **DNS failover cluster** | Blocked by rpi3-dns |
| **Automated backup rotation** | No offsite backup strategy for photos, databases |
| **MacBook Air config sync** | Darwin side not tested recently |
| **Terraform/OpenTofu infra-as-code** | No declarative cloud resource management |
| **VPN gateway** | No WireGuard/Tailscale for remote access |
| **Mail server** | Not considered |
| **CI/CD pipeline** | No automated testing on push (just manual `just test`) |
| **Disaster recovery plan** | No documented recovery procedure for total failure |
| **Security audit** | No formal penetration testing or vulnerability scanning |
| **Bandwidth monitoring** | No network traffic analysis beyond node_exporter |
| **Log retention policy** | No defined rotation/cleanup for service logs |
| **Multi-arch cache** | No binary cache for aarch64-linux builds |

---

## d) TOTALLY FUCKED UP

### CRITICAL: Sops-nix Complete Failure (ROOT CAUSE)

**What:** `sops-install-secrets` fails at boot with:
```
failed to lookup user 'gatus': user: unknown user gatus
```

**Impact:** ZERO secrets decrypted. `/run/secrets/` is completely empty. EVERY service that depends on secrets is dead.

**Root cause:** The `gatus-env` sops template in `modules/nixos/services/sops.nix` had `owner = "gatus"`. The nixpkgs `services.gatus` module creates the `gatus` user, but sops-nix runs in the initrd phase BEFORE systemd creates users. The sops manifest validation fails because the `gatus` user doesn't exist yet.

**Fix committed:** `d663dc2e` changed `owner = "root"` and `group = "root"` for the gatus-env template. **BUT** the booted generation was built from a different store path that still has the old manifest. Even after `just switch` at 23:16, the booted generation is the same.

**Action required:** `just switch` again to activate the fixed generation, then reboot (or switch to test mode).

### CRITICAL: ClickHouse Missing Log Directory

**What:** ClickHouse fails with:
```
Failed to set up mount namespacing: /var/log/clickhouse-server: No such file or directory
```

**Impact:** ClickHouse can never start, which means SigNoz is completely non-functional (no metrics, traces, or logs storage).

**Root cause:** The ClickHouse service has `LogsDirectory` or `LogNamespace` pointing to `/var/log/clickhouse-server`, but no tmpfiles rule creates this directory. The signoz module creates `/var/lib/signoz` but not the log directory.

### CRITICAL: Caddy Watchdog Timeout Loop

**What:** Caddy repeatedly killed by SIGABRT from systemd watchdog (30s timeout).

**Pattern:** Caddy starts → hangs on TLS cert maintenance (`certmagic.(*Cache).maintainAssets`) → watchdog kills it after 30s → restart → repeat.

**Root cause:** When dnsblockd TLS certs are available, Caddy tries to maintain them but hangs. Possible causes:
1. DNS resolution failure (dnsblockd is down → *.home.lan resolves nowhere)
2. TLS cert storage corruption
3. Caddy + internal TLS for home.lan is not a good fit (certmagic expects ACME)

**Impact:** All reverse-proxied services unreachable, even those that are running (Twenty, Manifest).

### HIGH: niri-health-metrics Permission Denied

**What:** `niri-health-metrics.service` fails writing to `/var/lib/prometheus-node-exporter/textfile_collectors/niri.prom.tmp` — `Permission denied`.

**Root cause:** The textfile collector directory is owned by `nobody:nogroup` but niri-health-metrics runs as a different user (likely root but with hardened filesystem restrictions).

### HIGH: dnsblockd Persistent Crash Loop

**What:** dnsblockd starts, waits 60s for sops secrets, then crashes. Repeats indefinitely.

**Impact:** DNS blocking is non-functional. TLS cert serving for `*.home.lan` is broken. All services with `*.home.lan` virtual hosts are unreachable.

### MEDIUM: Niri DeviceMissing Spam (410K+ per boot)

**What:** Niri logs `error doing early import: Error::DeviceMissing` at ~8/second continuously.

**Impact:** Log noise, journal disk waste. Does not appear to affect functionality (niri is running fine). Likely a non-critical DRM buffer import error.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Sops user dependency ordering** — sops-nix runs in initrd before users exist. Any secret owned by a service user (not root/primaryUser) is fragile. Should audit ALL sops secrets to ensure owners exist at initrd time, or use `neededForUsers` pattern.
2. **Caddy TLS architecture** — Using certmagic (designed for ACME/Let's Encrypt) with static self-signed certs is architecturally wrong. Consider switching to manually-loaded TLS certs without certmagic's maintenance goroutines.
3. **ClickHouse tmpfiles** — Need explicit tmpfiles rule for `/var/log/clickhouse-server` or remove the log directory requirement from the hardened service config.
4. **Service dependency chain** — Too many services depend on secrets → Caddy → DNS → each other. Need better degradation: services should start in reduced mode without secrets rather than crash-looping.
5. **WatchdogSec on Caddy** — The 30s watchdog is too aggressive for a service doing TLS cert maintenance. Either increase timeout, use a health endpoint check instead, or remove watchdog for non-ACME setups.
6. **Generation rollback safety** — The system has 316 generations. Need a mechanism to quickly identify and rollback to a known-good generation.

### Operations

7. **Boot-time secret validation** — Add a boot check that verifies `/run/secrets/` is populated before starting dependent services.
8. **Service health gating** — Don't start downstream services (Immich, Gatus, etc.) until their dependencies (Caddy, ClickHouse) are healthy.
9. **ClickHouse log rotation** — The missing `/var/log/clickhouse-server` suggests no one tested ClickHouse from a clean boot on this generation.
10. **Nix store cleanup** — 94G is excessive. Schedule regular `nix-collect-garbage` and lower `keep-outputs`/`keep-derivations`.
11. **Docker image cleanup** — 37.5GB whisper Docker image is massive. Consider a lighter ASR image.
12. **Reboot documentation** — No documented procedure for "how to recover from total secret failure."

### Monitoring

13. **Boot-time alerting** — Gatus can't alert if it's down. Need a separate, minimal health checker that runs without secrets.
14. **Sops failure alerting** — sops-install-secrets failures should trigger immediate notification.
15. **Journal size limits** — With 410K niri DeviceMissing errors per boot, journal grows fast. Configure `SystemMaxUse` and rate limiting.

---

## f) Top 25 Things We Should Get Done Next

| # | Priority | Task | Impact |
|---|----------|------|--------|
| 1 | **P0** | **Apply `just switch` to activate sops fix + reboot** | Recovers ALL services |
| 2 | **P0** | **Fix ClickHouse `/var/log/clickhouse-server` missing** | Recovers SigNoz observability |
| 3 | **P0** | **Fix niri-health-metrics textfile permissions** | Recovers niri health metrics |
| 4 | **P0** | **Investigate Caddy watchdog timeout — increase or remove WatchdogSec** | Stops Caddy crash loop |
| 5 | **P1** | Audit ALL sops secrets for initrd-time user existence | Prevents future sops failures |
| 6 | **P1** | Add boot-time secret validation check (is `/run/secrets/` populated?) | Early detection |
| 7 | **P1** | Fix niri DeviceMissing spam — investigate if fixable upstream | Reduces log noise 99% |
| 8 | **P1** | Clean Nix store: `nix-collect-garbage -d` + lower retention | Reclaims ~30-40G |
| 9 | **P1** | Replace whisper-asr Docker image (37.5G!) with lighter alternative | Reclaims disk |
| 10 | **P2** | Add systemd hardening for ClickHouse (LogsDirectory tmpfiles rule) | Proper fix for ClickHouse |
| 11 | **P2** | Write disaster recovery doc (total failure → recovery steps) | Operational resilience |
| 12 | **P2** | Add minimal boot-time health check (independent of Gatus/secrets) | Alerting during sops failures |
| 13 | **P2** | Configure journal size limits and rate limiting for niri | Prevents disk fill |
| 14 | **P2** | Test Darwin (macOS) config sync | Cross-platform integrity |
| 15 | **P3** | Evaluate Caddy TLS architecture — manual cert loading vs certmagic | Architectural improvement |
| 16 | **P3** | Add service dependency gating (don't start X until Y is healthy) | Graceful degradation |
| 17 | **P3** | Provision rpi3-dns hardware + flash NixOS image | DNS failover foundation |
| 18 | **P3** | Enable DNS failover (Keepalived VRRP) with rpi3-dns | High-availability DNS |
| 19 | **P3** | Add automated backup rotation for databases + photos | Data safety |
| 20 | **P4** | Set up CI/CD pipeline (GitHub Actions) for flake checks | Prevent broken deploys |
| 21 | **P4** | Add offsite backup strategy (S3/B2/Restic) | Disaster recovery |
| 22 | **P4** | WireGuard/Tailscale VPN for remote access | Remote management |
| 23 | **P4** | Build multi-arch binary cache (aarch64-linux) | Faster Pi builds |
| 24 | **P4** | Security audit: port scan, vulnerability scan, firewall review | Security posture |
| 25 | **P4** | Formalize log retention and cleanup policy | Operational hygiene |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why did `just switch` at 23:16 NOT fix the sops problem?**

The fix (`owner = "root"` for gatus-env) was committed in `d663dc2e` and generation 316 was built. The booted system IS generation 316. But `sops-install-secrets` still fails with `failed to lookup user 'gatus'`. This suggests either:

1. The `just switch --test` mode was used (which doesn't update the initrd/bootspec, so the OLD sops manifest from initrd is still used on next boot), OR
2. The sops manifest in the initrd is baked at `nixos-install` / `boot` time and `switch-to-configuration test` doesn't regenerate it, OR
3. The generation 316 store path was built BEFORE the sops fix was applied (race between commit and build).

The sops manifest runs from initrd (`initrd-nixos-activation-start`), so a `switch-to-configuration test` would NOT update the initrd — it only updates the running system. A `switch-to-configuration boot` or `switch-to-configuration switch` is needed to bake the new sops manifest into the initrd for the next boot.

**I need confirmation:** Was the `just switch` at 23:16 done with `test` mode (no reboot) or `boot/switch` mode? And should we run `just switch` right now with a reboot to finally fix this?

---

## Service Status Matrix

| Service | Status | Uptime | Issues |
|---------|--------|--------|--------|
| Niri (compositor) | **RUNNING** | 47 min | DeviceMissing spam (non-critical) |
| Waybar | **RUNNING** | 47 min | OK |
| Docker daemon | **RUNNING** | 47 min | OK |
| Unbound DNS | **RUNNING** | 47 min | OK |
| node_exporter | **RUNNING** | 47 min | OK |
| cAdvisor | **RUNNING** | 47 min | OK |
| amdgpu-metrics | **RUNNING** | 47 min | OK |
| Gitea | **RUNNING** | 47 min | OK (no sops deps) |
| Twenty (Docker) | **RUNNING** | 47 min | Unreachable (Caddy down) |
| Manifest (Docker) | **RUNNING** | 3 min | Unreachable (Caddy down) |
| OpenSEO (Docker) | **RUNNING** | 4 min | Unreachable (Caddy down) |
| Whisper ASR (Docker) | **RUNNING** | 47 min | OK |
| Deer-flow (Docker) | **RUNNING** | 47 min | OK |
| Caddy | **CRASH LOOP** | — | Watchdog timeout + no secrets |
| ClickHouse | **CRASH LOOP** | — | Missing `/var/log/clickhouse-server` + no secrets |
| Authelia | **START-LIMIT** | — | No sops secrets |
| Immich | **CRASH LOOP** | — | No sops secrets (credentials) |
| LiveKit | **CRASH LOOP** | — | No sops secrets (credentials) |
| Gatus | **CRASH LOOP** | — | No sops env file |
| Hermes | **START-LIMIT** | — | No sops secrets |
| SigNoz (query) | **DOWN** | — | ClickHouse dependency |
| SigNoz (collector) | **TIMEOUT** | — | ClickHouse dependency |
| dnsblockd | **CRASH LOOP** | — | No sops secrets (waits 60s, then dies) |
| niri-health-metrics | **CRASH LOOP** | — | Permission denied on textfile |
| signoz-provision | **FAILED** | — | SigNoz dependency |

**Services running:** 12 | **Services broken:** 13 | **Recovery rate:** 48%

---

## Disk Space Concern

| Path | Used | Free | Total | Note |
|------|------|------|-------|------|
| `/` | 394G | 99G | 512G | 80% — needs Nix GC |
| `/data` | 819G | 206G | 1.0T | 80% — Docker heavy |
| `/nix/store` | 94G | — | — | 316 generations |
| Whisper Docker | 37.5G | — | — | Single image! |
| Docker images total | ~50G | — | — | Major consumer |

---

## Git Status

**Branch:** master
**Latest commit:** `d663dc2e` — fix(sops): use root owner for gatus-env template + update flake.lock
**Uncommitted changes:** `flake.lock` (staged), `modules/nixos/services/sops.nix` (modified)

The sops.nix in the working tree has the fix applied (owner = "root"), matching commit `d663dc2e`. The flake.lock has updates.

---

*Report generated by Crush AI — Session 76*
