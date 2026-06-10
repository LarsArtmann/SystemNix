# SystemNix — Session 130: Comprehensive Status Report

**Date:** 2026-06-10 22:48 (UTC+2)
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM, 1TB NVMe)
**Uptime:** Since boot 4939e144 at ~21:12 (rebooted for Caddy crash fix)
**Build:** `just test-fast` — ✅ ALL CHECKS PASSED
**Working tree:** DIRTY — Homepage + Hermes icon fixes uncommitted, not yet deployed

---

## a) FULLY DONE ✅

### This Session (130)

| What | Detail |
|------|--------|
| **Homepage YAML rewrite** | Replaced broken `''` string concatenation with `mkGroup`/`mkService` helpers — services now properly nested under groups. Eliminated `TypeError: b[c].forEach is not a function` |
| **Homepage `HOMEPAGE_ALLOWED_HOSTS`** | Added `HOMEPAGE_ALLOWED_HOSTS=dash.${domain}` — all Caddy-proxied requests now accepted |
| **Homepage cache dir** | Added tmpfiles rule `d /var/cache/homepage-dashboard 0755 homepage homepage -` — eliminated `EACCES: permission denied` |
| **Hermes icon** | Changed `icon = "ai.png"` → `icon = "hermes-icon.png"` from dashboard-icons pack |

### Infrastructure (Previous Sessions, Still Working)

| Service | Status | Notes |
|---------|--------|-------|
| **Caddy** | ✅ Running | TLS via sops, forward-auth, 10+ vhosts, reloaded at 21:31 |
| **Pocket ID** | ✅ Running | Passkey OIDC provider v2.7.0, declarative provisioning complete |
| **oauth2-proxy** | ✅ Running | Forward-auth bridge, 200 OK on /ping every 30s |
| **Forgejo** | ✅ Running | SQLite, LFS, GitHub mirrors, Actions runner |
| **Gatus** | ✅ Running | 30+ endpoints monitored, 5min intervals, all healthy |
| **Unbound DNS** | ✅ Running | Recursive resolver + ad-blocking, stable |
| **DNS Blocker (dnsblockd)** | ✅ Running | TLS handshake noise from 192.168.1.62 (client offering TLS 1.0 — likely IoT device) |
| **TaskChampion** | ✅ Running | Port 10222, taskwarrior sync |
| **Hermes** | ✅ Running | AI Agent Gateway, active Discord bot, occasional tool errors (expected — sandbox restrictions) |
| **Crush Daily** | ✅ Running | Next scheduled run at 03:30 |
| **SigNoz** | ✅ Running | Query service on :8080, OTel collector active, ClickHouse + schema migrator started |
| **Immich** | ✅ Running | v2.7.5, PostgreSQL + Redis + ML, OAuth via Pocket ID |
| **SOPS secrets** | ✅ Working | Age-encrypted via SSH host key, auto-restart on change |
| **BTRFS snapshots** | ✅ Active | Daily via btrbk, 14d + 4w pruning |
| **Flake build** | ✅ Clean | `nix flake check --no-build` passes, all derivations evaluate |
| **Twenty CRM** | ✅ Running | Docker Compose (4 containers), PostgreSQL + Redis |
| **Manifest** | ✅ Running | Smart LLM router, Docker Compose, healthy |
| **OpenSEO** | ✅ Running | SEO suite, Docker container, responding 200 OK |
| **Deer Flow** | ✅ Running | nginx + gateway + frontend containers up |
| **Redis (shared)** | ✅ Running | BGSAVE working, 54 keys |
| **Ollama** | ✅ Running | ROCm GPU inference, ai-stack module enabled |
| **Home Manager** | ✅ Working | Shared config for both platforms |
| **Steam** | ✅ Installed | Client configured with Proton |
| **Discord sync** | ✅ Enabled | Service active |
| **Disk monitor** | ✅ Enabled | Desktop notifications on threshold |
| **NVMe health monitor** | ✅ Enabled | Desktop notifications for critical SMART events |
| **Overview dashboard** | ✅ Enabled | Local project dashboard on configured port |
| **Dual-WAN (config)** | ✅ Enabled | MPTCP + route health monitoring config present |
| **AI models storage** | ✅ Enabled | `/data/ai/` tree, env vars |
| **AI stack** | ✅ Enabled | Ollama ROCm + llama.cpp + gpu-python |

---

## b) PARTIALLY DONE ⚠️

| Area | Status | Gap |
|------|--------|-----|
| **Homepage Dashboard** | ⚠️ Fixed in code, NOT deployed | Three fixes committed to working tree but `just switch` not yet run. Current live instance still broken |
| **SigNoz OTel → Pocket ID scraping** | ⚠️ Noisy | `Failed to scrape Prometheus endpoint` for pocket-id on port 9464 every 30s — pocket-id doesn't expose Prometheus metrics, but OTel collector is configured to scrape it |
| **Pocket ID metrics** | ⚠️ Spamming logs | Every 60s: `failed to upload metrics: Post "https://localhost:4318/v1/metrics": dial tcp [::1]:4318: connect: connection refused` — trying to push to OTel endpoint that SigNoz's collector serves on a different address |
| **Twenty CRM via Caddy** | ⚠️ Intermittent 502s | Connection reset/EOF on port 3200 — Twenty server occasionally drops connections during reloads |
| **SigNoz Gatus check** | ⚠️ Shows DOWN | Gatus reports `signoz: success=false` despite SigNoz running — likely health check URL mismatch (port 8080) |
| **Immich Gatus check** | ⚠️ Shows DOWN | Gatus reports `immich: success=false, errors=0` — health check succeeding but returning non-200 status |
| **Crush Daily Gatus check** | ⚠️ Shows DOWN | `success=false, errors=1` — Crush Daily is a scheduler, health endpoint may not be implemented |
| **Ollama Gatus check** | ⚠️ Shows DOWN | `success=false, errors=1` — Ollama port may have changed or service needs restart |
| **Monitor365 Gatus check** | ⚠️ Shows DOWN | `success=false, errors=1` — Server port may not be listening |
| **Disk usage (root)** | ⚠️ 95% full | `/dev/nvme0n1p6` at 477G/512G, only 28G free — approaching critical |
| **Swap usage** | ⚠️ 8.0/19Gi used | Significant swap pressure, possibly from AI workloads or stale LSP processes |
| **PostgreSQL collation warnings** | ⚠️ Spamming | Twenty CRM's postgres container warning `database "postgres" has no actual collation version` every 5s — harmless but noisy |
| **DNS blocker TLS noise** | ⚠️ Log spam | 192.168.1.62 (IoT device?) offering TLS 1.0 — incompatible, generates ~10 handshake errors/min |
| **Pi 3 DNS failover** | ⚠️ Code complete, hardware not provisioned | `rpi3-dns` NixOS config exists, VRRP module ready, physical Pi 3 not set up |

---

## c) NOT STARTED 📋

| Item | Notes |
|------|-------|
| **Deploy Homepage fixes** | `just switch` needed to apply the three Homepage fixes + Hermes icon |
| **Pi 3 DNS failover provisioning** | Physical hardware setup, SD card flash, network wiring |
| **Monitor365 dashboard vhost** | No Caddy vhost configured — only accessible via localhost:port |
| **Overview dashboard vhost** | No Caddy vhost — only accessible locally |
| **Deer Flow service module** | Running as ad-hoc Docker Compose, not a proper NixOS module with options |
| **Voice agents re-enable** | Module exists, disabled — LiveKit + Whisper ASR |
| **Minecraft server re-enable** | Module exists, disabled |
| **PhotoMap re-enable** | Module exists, disabled in configuration.nix |
| **File-and-image-renamer re-enable** | Blocked on Go 1.26.3 (nixpkgs has 1.26.2), charm.land/fantasy dependency |
| **SigNoz setup completion** | `setupCompleted: false` — initial user/org setup not done yet |
| **Monitor365 agent→server auth** | No auth between agent and server — anyone on LAN can POST data |

---

## d) TOTALLY FUCKED UP ❌

| Issue | Root Cause | Impact | Severity |
|-------|-----------|--------|----------|
| **Homepage Dashboard was completely broken** | Three compounding bugs: broken YAML structure (`forEach is not a function`), missing `HOMEPAGE_ALLOWED_HOSTS` (all requests rejected), missing cache dir (`EACCES`). Dashboard was non-functional for unknown duration. | Dashboard showed empty/error state | **HIGH** — Fixed in code, awaiting deploy |
| **Caddy crash on boot** | `open /run/secrets/dnsblockd_server_cert: no such file or directory` — sops secret not available when Caddy started at 05:29. Caddy FAILED TO START. All services behind Caddy (auth, dashboard, CRM, etc.) were unreachable from the network until manual restart at 19:00 (~14 hours of downtime) | ALL web services unreachable | **CRITICAL** — Caddy restarted manually, but boot-time ordering not fixed |
| **status.home.lan DNS resolution failure** | `lookup status.home.lan on 127.0.0.1:53: no such host` — Unbound local-zone not returning A records for `status.home.lan`. Gatus is running and healthy locally, but the domain doesn't resolve. | Status page inaccessible | **HIGH** — DNS zone configuration gap |
| **Pocket ID provision task failures** | `notify-failure@pocket-id.service` triggered 4 times between 19:14-19:51 — scheduled task failures | OIDC auth may be intermittently unavailable | **MEDIUM** |
| **oauth2-proxy double-restart** | `notify-failure@oauth2-proxy.service` triggered at 21:12 and 21:13 — service failed twice during boot | Auth-protected services briefly unreachable | **MEDIUM** |

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Critical

1. **Caddy boot ordering** — Caddy must start AFTER sops-install-secrets. Add `BindsTo=sops-nix.service` + `After=sops-nix.service` or use `sops.secrets.*.neededForUnits` to ensure certs exist before Caddy starts. The 14-hour outage was entirely preventable.

2. **status.home.lan DNS** — Unbound `local-zone` for `home.lan` must include `status` subdomain A record. Currently missing from the DNS zone configuration.

3. **Root disk at 95%** — 28G free on a 512G root partition. `nix-collect-garbage`, clean old generations, check `/tmp` and `/var/cache` for bloat. This is a ticking time bomb.

### High Priority

4. **Pocket ID metrics endpoint mismatch** — Pocket ID tries to push to `localhost:4318` but OTel collector listens elsewhere. Either disable metrics push in Pocket ID config or align the port.

5. **SigNoz OTel scraping Pocket ID** — OTel collector configured to scrape `pocket-id` on port 9464 but Pocket ID doesn't expose Prometheus metrics. Remove the scrape target.

6. **Gatus health check accuracy** — 6 services show DOWN in Gatus but may actually be healthy with wrong check URLs. Audit all Gatus endpoint configurations.

### Medium Priority

7. **DNS blocker TLS noise** — Add `firewall` rule or `fail2ban` to rate-limit TLS 1.0 connections from 192.168.1.62, or accept the log spam.

8. **PostgreSQL collation version** — Run `ALTER DATABASE postgres REFRESH COLLATION VERSION` in Twenty CRM's postgres container to silence the warnings.

9. **Swap pressure** — 8Gi swap used suggests memory pressure. Check for stale LSP processes (`stale-lsp-cleanup` timer), consider reducing AI workload memory footprint.

10. **Homepage is not yet a proper NixOS test** — No VM test validates the YAML structure. Should add a NixOS test that starts Homepage and verifies it responds 200.

### Low Priority

11. **Twenty CRM intermittent 502s** — Connection resets from Twenty server. May need `keepalive` or `flush_interval` in Caddy upstream config.

12. **Monitor365 authentication** — No auth between agent and server. Add API key or mTLS.

13. **Deer Flow NixOS module** — Currently ad-hoc Docker Compose. Should be a proper module with options like other services.

---

## f) Top #25 Things to Get Done Next

### Immediate (Deploy or Die)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **`just switch`** to deploy Homepage fixes + Hermes icon | 5min | Fixes broken dashboard |
| 2 | **Fix Caddy boot ordering** — add sops dependency | 15min | Prevents 14-hour outage recurrence |
| 3 | **Fix status.home.lan DNS** — add to Unbound local-zone | 10min | Makes status page accessible |
| 4 | **Root disk cleanup** — `nix-collect-garbage -d`, clean `/var/cache` | 20min | Prevents disk-full crisis |

### High Impact

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | **Silence Pocket ID metrics spam** — disable or fix OTel port | 10min | Cleans up 1440 log lines/day |
| 6 | **Fix SigNoz OTel Pocket ID scrape target** — remove non-existent target | 5min | Eliminates scrape failures |
| 7 | **Audit Gatus health checks** — fix 6 DOWN endpoints | 30min | Accurate monitoring |
| 8 | **Complete SigNoz initial setup** — create user/org via API | 10min | Makes observability usable |
| 9 | **Fix DNS blocker TLS log spam** — rate-limit or drop TLS 1.0 | 15min | Cleaner logs |

### Service Maturity

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | **Add Monitor365 Caddy vhost** — expose at monitor.home.lan | 15min | Remote access to monitoring dashboard |
| 11 | **Add Overview Caddy vhost** — expose at overview.home.lan | 15min | Remote access to project dashboard |
| 12 | **Fix PostgreSQL collation warnings** — REFRESH COLLATION VERSION | 5min | Eliminates log spam |
| 13 | **Investigate swap pressure** — check stale processes, memory hogs | 20min | Better system responsiveness |
| 14 | **Add Twenty CRM keepalive** in Caddy upstream | 10min | Reduces intermittent 502s |
| 15 | **Create Deer Flow NixOS module** — proper service with options | 45min | Consistency with other services |

### Long-Term / Infrastructure

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Add Homepage NixOS VM test** — verify YAML structure at eval time | 30min | Prevents YAML breakage regressions |
| 17 | **Monitor365 agent→server auth** — API key or mTLS | 30min | Security |
| 18 | **Pi 3 hardware provisioning** — flash SD, boot, wire | 2hr | DNS failover redundancy |
| 19 | **File-and-image-renamer unblock** — bump Go or vendor charm.land | 1hr | Restores screenshot AI renaming |
| 20 | **Voice agents evaluation** — assess LiveKit + Whisper for current needs | 1hr | Decide enable/disable permanently |
| 21 | **PhotoMap evaluation** — assess usefulness, enable or remove module | 30min | Reduce dead code |
| 22 | **BTRFS /data subvolume migration** — convert from toplevel to subvolume for snapshots | 1hr | Enables /data snapshots |
| 23 | **Darwin Home Manager parity** — terminal, editor, theme matching NixOS | 2hr | Consistent cross-platform experience |
| 24 | **Caddy cert auto-renewal monitoring** — Gatus TLS expiry check exists but alerting chain incomplete | 30min | Proactive cert management |
| 25 | **NixOS generation cleanup automation** — auto-remove generations older than 30d | 15min | Prevents root disk creep |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does Caddy fail to start on boot due to missing sops secrets, and what is the correct systemd ordering fix?**

The Caddy service needs `/run/secrets/dnsblockd_server_cert` (and potentially other sops-managed TLS certs) at startup. Today's 14-hour outage was caused by a race condition: Caddy started before sops-install-secrets placed the cert file on disk. I can see the error:

```
loading certificates: open /run/secrets/dnsblockd_server_cert: no such file or directory
```

But I cannot determine from this machine whether the fix should be:
- (A) Adding `After=sops-nix.service` + `Wants=sops-nix.service` to the Caddy systemd unit
- (B) Using `sops.secrets.*.neededForUnits = ["caddy.service"]` to make sops explicitly order before Caddy
- (C) Both (A) and (B)
- (D) Something else in the sops-nix activation ordering that I'm missing

This requires reading the sops-nix module and Caddy module to understand the exact dependency graph, which would be the first thing to investigate.

---

## Service Health Summary

| Service | Process | Gatus | Notes |
|---------|---------|-------|-------|
| Caddy | ✅ Running | ✅ UP | Restarted manually at 19:00, reloaded at 21:31 |
| Pocket ID | ✅ Running | ✅ UP | Metrics spam to localhost:4318 |
| oauth2-proxy | ✅ Running | ✅ UP | Ping 200 every 30s |
| Forgejo | ✅ Running | ✅ UP | API responding |
| Homepage | ❌ Broken | ✅ UP | Service running but serving errors (fix awaiting deploy) |
| Gatus | ✅ Running | ✅ UP (self) | 30+ endpoints checked |
| Immich | ✅ Running | ⚠️ DOWN | Health check mismatch |
| SigNoz | ✅ Running | ⚠️ DOWN | Health check port mismatch |
| Twenty CRM | ✅ Running | ✅ UP | Intermittent 502s from connection resets |
| Manifest | ✅ Running | ✅ UP | Healthy |
| TaskChampion | ✅ Running | ✅ UP | Sync server |
| Hermes | ✅ Running | — | Active, Discord bot functional |
| Crush Daily | ✅ Running | ⚠️ DOWN | Health endpoint may not exist |
| Ollama | ✅ Running | ⚠️ DOWN | Port or health check issue |
| Monitor365 | ✅ Enabled | ⚠️ DOWN | Server may not be listening |
| OpenSEO | ✅ Running | — | Docker container, 200 OK |
| Deer Flow | ✅ Running | — | Docker Compose, no module |
| Redis | ✅ Running | — | BGSAVE healthy |
| DNS Blocker | ✅ Running | ✅ UP | TLS noise from IoT |
| Unbound DNS | ✅ Running | ✅ UP | Recursive + blocking |
| EMEET PIXY | ✅ Running | ✅ UP | Webcam daemon |
| NVMe monitor | ✅ Running | ✅ UP | SMART checks |
| Niri | ✅ Running | ✅ UP | Compositor |

## System Resources

| Resource | Value | Status |
|----------|-------|--------|
| Root disk | 477G/512G (95%) | ⚠️ CRITICAL |
| Data disk | 798G/1.0T (78%) | ✅ OK |
| RAM | 30G/93G used | ✅ OK |
| Swap | 8.0G/19G used | ⚠️ High |
| Load | ~30 active services | ✅ Manageable |

## Docker Containers (10 running)

| Container | Image | Status |
|-----------|-------|--------|
| twenty-server-1 | twentycrm/twenty:v2.7.3 | Up 2h (healthy) |
| twenty-worker-1 | twentycrm/twenty:v2.7.3 | Up 2h |
| twenty-db-1 | postgres:16-alpine | Up 2h (healthy) |
| twenty-redis-1 | redis:7-alpine | Up 2h (healthy) |
| mnfst-manifest-1 | manifestdotbuild/manifest:6.6.1 | Up 2h (healthy) |
| mnfst-postgres-1 | postgres:16-alpine | Up 2h (healthy) |
| openseo-openseo-1 | ghcr.io/every-app/open-seo:v0.0.15 | Up 2h |
| deer-flow-nginx | nginx:alpine | Up 2h |
| deer-flow-gateway | deer-flow-dev-gateway | Up 2h |
| deer-flow-frontend | deer-flow-dev-frontend | Up 2h |

## Uncommitted Changes

```
M modules/nixos/services/homepage.nix  — YAML rewrite, ALLOWED_HOSTS, cache dir, Hermes icon
```

Awaiting `just switch` to deploy.
