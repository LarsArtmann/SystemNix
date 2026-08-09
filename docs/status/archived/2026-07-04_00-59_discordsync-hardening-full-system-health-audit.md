# Status Report — DiscordSync Hardening & Full SystemNix Health Audit

**Date:** 2026-07-04 00:59 CEST
**Branch:** master
**Last deployed generation:** 434 (2026-06-25)
**Undeployed commits:** ~14 (all work since 2026-06-25 — monitoring/Caddy hardening, Helium hotplug fix, /tmp cap, niri fork, discordsync Gatus fix)
**Scope:** Full project — every service, module, and infrastructure concern

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## Executive Summary

SystemNix is a **mature, production-grade cross-platform Nix configuration** running 39 auto-discovered service modules across two active systems (NixOS `evo-x2` desktop, macOS `Lars-MacBook-Air`). This session audited the `discordsync.nix` module against the DiscordSync Go source (verdict: well-configured, one monitoring convention gap fixed), then compiled a full-system status snapshot.

**The single biggest risk:** **~14 commits are undeployed** since generation 434 (2026-06-25). Everything passes `nix flake check --no-build`, but none of the monitoring hardening, Caddy security headers, Helium crash fix, or BTRFS/memory safety work is live on evo-x2.

| Metric                                  | Value                                               |
| --------------------------------------- | --------------------------------------------------- |
| NixOS service modules                   | 39 (auto-discovered)                                |
| Gatus monitored endpoints               | 39                                                  |
| Endpoints with Discord alerts           | 31                                                  |
| Endpoints with response-time thresholds | 17 (was 16 — DiscordSync fixed this session)        |
| SSO-protected services                  | 12 (3 Layer-1 native OIDC + 9 Layer-2 forward-auth) |
| Documented gotchas in AGENTS.md         | 55+                                                 |
| Known broken services                   | 1 (Monitor365 — upstream Rust panic)                |
| Disabled services                       | 4 (photomap, voice-agents, minecraft, dual-wan)     |

---

## a) FULLY DONE ✅

### This Session

| Work Item                           | Details                                                                                                                                                                                                                                                                                                                                                                                                                            | Status      |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| DiscordSync NixOS module audit      | Cross-checked all 9 env vars in `internal/config/config.go` against module `Environment`/`EnvironmentFile` — all correctly mapped. Secrets cleanly separated (token/turso in sops template; GCS creds in conditional secret). Systemd hardening textbook-correct (`harden` + `serviceDefaults` via `//`, no `ExecStart` trapped in `harden`, graceful shutdown windowed 10s < 30s). Port from `lib/ports.nix`. GCS opt-in guarded. | ✅ Verified |
| Gatus DiscordSync response-time fix | The DiscordSync `/healthz` check was the **only** HTTP endpoint in the entire monitoring config missing a `[RESPONSE_TIME]` condition (all 16 others had one). Added `conditions = ["[STATUS] == 200" "[RESPONSE_TIME] < 500"]`.                                                                                                                                                                                                   | ✅ Fixed    |

### Core Infrastructure

| Feature                             | Details                                                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Cross-platform flake                | Single flake, two active systems (Darwin + NixOS), 80% shared via `platforms/common/`                          |
| flake-parts module auto-discovery   | 39 modules in `modules/nixos/{services,desktop}/`, filename = module name                                      |
| SOPS secrets (age via SSH host key) | 4 sops files, ALL service-specific secrets guarded with `lib.optionalAttrs` (atomic-failure-proofed)           |
| Deploy pipeline                     | `nix run .#deploy` → pre-deploy-check (catches boot-breakers) → `nh os switch` with `reset-failed` → new shell |
| BTRFS snapshot protection           | Root (`@`) daily via btrbk, 14d+4w retention; `btrfs-health.nix` gates `nix-gc` when device-unallocated < 10%  |

### SSO / OIDC Architecture (Pocket ID)

| Layer                               | Services                                                                                   | Status                                             |
| ----------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| Layer 1 — Native OIDC               | Forgejo, Immich, Gatus                                                                     | ✅ All working (direct TLS proxy, no double-auth)  |
| Layer 2 — oauth2-proxy forward-auth | Homepage, SigNoz, Twenty, Taskchampion, Manifest, OpenSEO, Crush Daily, Dozzle, Monitor365 | ✅ All working (cookie-based `.${domain}` session) |

### Self-Hosted Applications (production)

| Service                          | Status | Highlights                                                                                                           |
| -------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------- |
| Forgejo                          | ✅     | Native OIDC SSO, SSO-only login enforced, declarative repo mirroring + GitHub push mirrors, Actions runner           |
| Immich                           | ✅     | OAuth via Pocket ID, VA-API H.264/HEVC/AV1 transcoding, daily DB backup                                              |
| SigNoz                           | ✅     | Full-stack observability (traces/metrics/logs), 19 alert rules, custom `signoz.target`, migration-lock self-healing  |
| DiscordSync                      | ✅     | turso-sync backend, GCS attachment backup (`discordsync-backup` bucket), backfill resume, just hardened this session |
| Homepage                         | ✅     | Programmatic tiles, conditional per-service                                                                          |
| Hermes                           | ✅     | Discord bot, multi-provider LLM (GLM, MiniMax, Xiaomi, FAL, Firecrawl)                                               |
| Manifest                         | ✅     | LLM router for AI agents                                                                                             |
| Crush Daily / Overview / OpenSEO | ✅     | All behind forward-auth                                                                                              |
| TaskChampion                     | ✅     | TLS via Caddy                                                                                                        |
| Twenty CRM                       | ✅     | 4-container Docker Compose, daily DB backup                                                                          |
| Dozzle                           | ✅     | Docker log viewer                                                                                                    |
| Caddy                            | ✅     | 15 vhosts, security headers, TLS 1.2+, strict SNI, structured access logging, HTTP→HTTPS redirect                    |

### Desktop (evo-x2)

| Feature                                             | Status                                                                                                       |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| DankMaterialShell (DMS) v1.4.6 on Quickshell v0.2.1 | ✅ Replaces Waybar, Dunst, Wlogout, Swaylock, polkit-gnome, **and rofi** (OOM-killing root cause eliminated) |
| Niri (scrollable-tiling Wayland)                    | ✅ LarsArtmann fork for improved session management; session save/restore                                    |
| 13 SystemNix-native DMS plugins                     | ✅                                                                                                           |
| Catppuccin Mocha global theme                       | ✅                                                                                                           |
| Steam gaming (gamemode, gamescope, mangohud)        | ✅                                                                                                           |
| PipeWire audio                                      | ✅                                                                                                           |

### Reliability Hardening (recent, undeployed)

| Fix                              | Root Cause                                                                                                                       |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Helium display-hotplug crash     | `--disable-gpu-watchdog` — Chromium GPU watchdog kills process during slow DCN 3.5.1 surface recreation under GPUActive pressure |
| `/tmp` tmpfs capped at 16 GiB    | go-build caches filled 16+ GiB in 21h (was 50% RAM = 47 GiB)                                                                     |
| Unbound caches bounded           | `key-cache-size` + `neg-cache-size` = 16 MiB each (RSS was 8x cache size)                                                        |
| MGLRU thrash protection          | `min_ttl_ms=1000` via sysfs service                                                                                              |
| OOM tuning                       | `user-1000.slice` MemoryHigh=56G/MemoryMax=64G, oomd 50%/20s                                                                     |
| BTRFS metadata ENOSPC prevention | `btrfs-health.nix` gates GC, Gatus alerts on device-unallocated %, DMS widget                                                    |
| Network interface boot race      | `dnsblockd-attach-ip.service` (CAP_NET_ADMIN oneshot)                                                                            |
| `switch-to-configuration` exit 4 | `reset-failed` before `nh os switch`                                                                                             |
| Pre-deploy validation            | `pre-deploy-check` catches boot-breakers (ext4 `discard=async`, missing `nofail`)                                                |

---

## b) PARTIALLY DONE 🟡

| Item                                        | Done                                                                                       | Gap                                                                                                                       | Effort to Close                        |
| ------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **Deploy**                                  | ~14 commits pass eval                                                                      | **NOT LIVE on evo-x2** (gen 434 since 06-25)                                                                              | `nix run .#deploy` (1 command)         |
| **DNS migration** (dnsblockd → primary :53) | dnsblockd v0.2.0 has full resolver (sdns, DNSSEC, DoT, DoH); detailed plan in TODO_LIST.md | Phase 2a (module rework), 2b (config), 2c (deps), 3 (deploy+observe 24h), 4 (cleanup) — **not started**                   | ~15h both repos                        |
| **BTRFS `/data` subvolume**                 | Root (`@`) snapshotted                                                                     | `/data` is toplevel (subvolid=5) — Docker/Immich/AI data has NO snapshot protection                                       | ~1h downtime (USB rescue boot)         |
| **Gatus monitoring**                        | 39 endpoints, 31 alerting                                                                  | No maintenance windows (deploys fire false alerts); PostgreSQL blind (Unix socket only); no Gatus `/metrics` → SigNoz     | Low-Medium                             |
| **Caddy admin API**                         | localhost:2019, firewalled out                                                             | **Unauthenticated** — any local process can inject routes. Rationale documented (single-admin homelab) but latent risk    | Medium                                 |
| **Monitor365**                              | Agent + server deployed                                                                    | **Server crash-loops** — upstream Rust panic (Axum 0.7 `:param` → `{param}` route syntax). Nix-side workaround impossible | Fix in `github:LarsArtmann/monitor365` |
| **Cloud/offsite backup**                    | None                                                                                       | No disaster-recovery backup exists. Hetzner StorageBox + BorgBackup evaluated                                             | Medium                                 |
| **Firewall**                                | Docker punches its own holes                                                               | NixOS firewall allows all inbound — no deny-by-default allowlist                                                          | Medium                                 |
| **niri fork switch**                        | Config committed                                                                           | Improved session management — pending deploy                                                                              | Deploy                                 |
| **File & Image Renamer**                    | Re-enabled in config                                                                       | Pending deploy (Go 1.26.3 now available)                                                                                  | Deploy                                 |

---

## c) NOT STARTED ⬜

| Item                                                | Impact           | Notes                                                       |
| --------------------------------------------------- | ---------------- | ----------------------------------------------------------- |
| **Off-site backup** (BorgBase / Hetzner StorageBox) | Critical — no DR | Evaluated in `docs/research/`                               |
| **Firewall deny-by-default**                        | High             | Transition to explicit allowlist                            |
| **Bind Immich to localhost**                        | Medium           | Currently `0.0.0.0` + `openFirewall`; Caddy already proxies |
| **Pi 3 DNS failover cluster**                       | Medium           | VRRP module ready, hardware not provisioned                 |
| **Auditd enablement**                               | Medium           | Blocked on NixOS 26.05 bug #483085                          |
| **AppArmor**                                        | Medium           | `mkDefault false` in security-hardening.nix                 |
| **Darwin HM parity**                                | Low              | Blocked by 256GB disk (90%+ full)                           |
| **Caddy rate limiting on auth endpoints**           | Medium           | No native rate limiter; needs plugin                        |
| **Caddy request body size limits**                  | Medium           | `request_body { max_size }` on upload vhosts                |
| **Gatus → Homepage integration**                    | Low              | Real-time status dots                                       |
| **Caddy access logs → SigNoz**                      | Medium           | filelog receiver in OtelCollector                           |
| **PostgreSQL direct monitoring**                    | Medium           | `pg_isready` textfile exporter                              |
| **Split large modules**                             | Low              | monitor365 (716L), signoz (705L), forgejo (583L)            |
| **Typed NixOS module options**                      | Low              | Many modules use `mkEnableOption` only                      |

---

## d) TOTALLY FUCKED UP 🔴

### 1. Monitor365 — Crash-looping (upstream bug)

**Status:** Server crash-loops on every boot. Agent may run but has no server to report to.
**Root cause:** Upstream Rust panic — Axum 0.7 changed route syntax from `:param` to `{param}`. The monitor365 server binary uses the old syntax.
**Why Nix can't fix it:** The bug is in compiled Rust source at `github:LarsArtmann/monitor365`. No Nix-side patch can fix a route-syntax mismatch.
**Fix:** Update monitor365 source to Axum 0.7 route syntax, publish new tag, update flake input.
**Impact:** Device monitoring dashboard non-functional. ActivityWatch integration broken.

### 2. GPUActive Memory Crisis (architectural, mitigated not solved)

**Status:** 51+ GiB (55% of visible RAM) consumed by GPUActive (GTT buffer objects) with only desktop workloads. `GPUReclaim=0` — these pages CANNOT be reclaimed under pressure.
**Root cause:** Strix Halo unified memory architecture. BIOS carves out 34 GiB VRAM → only ~94 GiB visible to Linux. TTM pool configured with `pages_limit = 112 GiB` (exceeds visible!).
**Why it's "fucked":** This is an architectural limit of the hardware + AMDGPU driver. Not a bug we can fix — only mitigate.
**Mitigations in place:** `MemoryHigh=56G/MemoryMax=64G` on user slice, oomd 50%/20s, Helium `--disable-gpu-watchdog`. But the system runs in **chronic memory pressure** with zram swap at 100%.
**Visibility:** `/proc/meminfo` `GPUActive` field is the ONLY way to see this — `free`/`htop` show it as generic "used".

### 3. Chronic Swap Pressure

**Status:** 8 GiB zram swap at 100% utilization on 128 GiB RAM system.
**Related to:** GPUActive consuming 51+ GiB forces everything else into 43 GiB, which fills zram.
**Impact:** Swap thrashing starves journald → sp5100-tco WDT hard reset (60s). This was the root cause of the historical OOM crash chain.

---

## e) WHAT WE SHOULD IMPROVE

1. **DEPLOY.** ~14 commits of hardening work (monitoring, Caddy security, Helium crash fix, memory bounds, BTRFS safety, niri fork) are sitting undeployed since 2026-06-25. This is the #1 priority — all this work is theoretical until it's live.

2. **Off-site backup.** The entire homelab — Forgejo (Git history), Immich (photos), DiscordSync (Discord archive), Twenty (CRM) — has zero off-site backup. A single BTRFS corruption or SSD failure = total data loss. This is existential.

3. **Fix Monitor365 upstream.** It's the only crash-looping service. The fix (Axum 0.7 route syntax) is mechanical.

4. **DNS migration execution.** The plan is thorough (4 phases), dnsblockd v0.2.0 is ready, but it's all unstarted. Eliminating unbound simplifies the stack and closes 3 gotchas.

5. **Firewall hardening.** Every service is exposed to the LAN by default. A deny-by-default firewall with explicit service allowlist is overdue for a system running Forgejo, Immich, and a CRM.

6. **Caddy admin API.** Even with the documented rationale, an unauthenticated config-injection endpoint on a system running a CRM and Git forge is a real risk. `admin off` + standalone metrics is the clean fix.

7. **Gatus maintenance windows.** Every deploy fires a wave of false Discord alerts. A maintenance window would suppress noise and make real alerts trustworthy.

8. **PostgreSQL visibility.** Three critical services (Immich, Forgejo, Twenty) depend on PostgreSQL. We're completely blind to DB-level health (connection exhaustion, slow queries). A `pg_isready` textfile exporter closes this.

9. **BTRFS `/data` subvolume.** Docker volumes, Immich ML models, and AI model storage sit on unsnapshotted BTRFS toplevel. One `rm -rf` mistake or corruption = unrecoverable.

10. **Module option typing.** Most modules use `mkEnableOption` only. Adding typed options (ports, paths, timeouts) enables compile-time validation and future testing.

---

## f) Top 25 Things to Get Done Next

| #   | Task                                                                                       | Impact   | Effort       | Dependency                             |
| --- | ------------------------------------------------------------------------------------------ | -------- | ------------ | -------------------------------------- |
| 1   | **Deploy the ~14 undeployed commits** (`nix run .#deploy`)                                 | Critical | 1 command    | Reboot after (verify boot time)        |
| 2   | **Off-site backup** (Hetzner StorageBox + BorgBackup / Restic)                             | Critical | Medium       | Evaluated, needs execution             |
| 3   | **Fix Monitor365 upstream** (Axum 0.7 `{param}` route syntax)                              | High     | Low          | Update flake input after               |
| 4   | **Gatus maintenance windows** (suppress deploy-time alerts)                                | High     | Low          | —                                      |
| 5   | **Caddy admin API hardening** (`admin off` + `:2019 { metrics }`)                          | High     | Medium       | Test `nh os switch` reload still works |
| 6   | **DNS migration Phase 2a** (dnsblockd module rework for `:53` primary)                     | High     | ~6h          | dnsblockd v0.2.0 pinned                |
| 7   | **Firewall deny-by-default** with explicit service allowlist                               | High     | Medium       | Test all services reachable            |
| 8   | **BTRFS `/data` → `@data` subvolume** migration                                            | High     | ~1h downtime | USB rescue boot                        |
| 9   | **PostgreSQL textfile exporter** (`pg_isready` + conn count)                               | Medium   | Medium       | —                                      |
| 10  | **Caddy access logs → SigNoz** (filelog receiver)                                          | Medium   | Medium       | —                                      |
| 11  | **Gatus `/metrics` → SigNoz** scrape config                                                | Medium   | Low          | —                                      |
| 12  | **Bind Immich to localhost** (remove `openFirewall`)                                       | Medium   | Low          | Caddy already proxies                  |
| 13  | **Caddy request body size limits** on upload vhosts                                        | Medium   | Low          | —                                      |
| 14  | **Caddy upstream health checks** (`health_uri` on reverse_proxy)                           | High     | Medium       | Per-backend health endpoints           |
| 15  | **Gatus → Homepage integration** (real-time status dots)                                   | Low      | Low          | —                                      |
| 16  | **DNS migration Phase 2b-2c** (config + dependency updates)                                | High     | ~4h          | Phase 2a done                          |
| 17  | **DNS migration Phase 3** (deploy + 24h observation)                                       | High     | 24h observe  | 2b-2c done                             |
| 18  | **DNS migration Phase 4** (remove unbound entirely)                                        | Medium   | Low          | 24h stable                             |
| 19  | **Cloud sync for DiscordSync attachments** verified (check GCS bucket has data)            | Medium   | Low          | `gsutil ls gs://discordsync-backup`    |
| 20  | **Split large modules** (monitor365 716L, signoz 705L, forgejo 583L)                       | Low      | Medium       | —                                      |
| 21  | **Hermes: install SSH deploy key + set fallback model** (manual steps)                     | Medium   | Low          | Blocked on human                       |
| 22  | **Typed NixOS module options** (ports, paths, timeouts)                                    | Low      | High         | Incremental                            |
| 23  | **Disabled service triage** — remove photomap (decided), decide voice-agents               | Low      | Low          | —                                      |
| 24  | **Upstream nixpkgs PRs** (aw-watcher-utilization, taskwarrior3 flags, KeePassXC manifests) | Low      | Medium       | Community benefit                      |
| 25  | **Monitoring runbook** (what to do when each Discord alert fires)                          | Medium   | Medium       | —                                      |

---

## g) Top #1 Question

**When can we schedule a deploy + reboot window for evo-x2?**

~14 commits of hardening work — monitoring alerts, Caddy security headers, the Helium display-hotplug crash fix, `/tmp` memory cap, unbound cache bounds, BTRFS-health GC gating, and the niri fork session-management improvements — are all evaluated and passing but **not live**. The system has been running generation 434 since 2026-06-25 (9 days).

The deploy itself is one command (`nix run .#deploy`), but:

1. The NVMe APST fix (`nvme_core.default_ps_max_latency_us=0` kernel param) needs a **reboot** to verify the boot-time improvement (target ~35s, was 6m17s).
2. Several services will restart (Caddy reload, Gatus restart, niri session changes) — brief user-facing disruption.
3. The `switch-to-configuration` exit-4 fix (`reset-failed` before `nh`) is itself undeployed — the first deploy may hit the start-limit issue it was designed to fix, requiring a manual `sudo systemctl reset-failed` first.

**I cannot self-resolve this because deploying requires the machine to be physically attended (reboot verification) and I don't know your availability window or whether now is a safe time for a 5-10 minute service disruption.**

---

## Session Metrics

| Metric                                        | Before This Session | After                         | Delta                           |
| --------------------------------------------- | ------------------- | ----------------------------- | ------------------------------- |
| DiscordSync module reviewed                   | No                  | Yes (verified against source) | —                               |
| Gatus endpoints with response-time thresholds | 16                  | 17                            | +1 (DiscordSync)                |
| Commits this session                          | —                   | 1 (Gatus fix) + this report   | —                               |
| Files changed                                 | —                   | 2                             | `gatus-config.nix`, this report |
| Deploy status                                 | gen 434 (06-25)     | **Still gen 434**             | ~14 commits pending             |

---

## Honesty Check

This is a **healthy project** with strong fundamentals: clean flake architecture, comprehensive monitoring, documented gotchas, SSO across all user-facing services, and a disciplined deploy pipeline. The DiscordSync module — the specific item audited this session — is genuinely well-configured.

The risks are **operational, not structural**: an undeployed backlog, a single crash-looping service (fixable upstream), no off-site backup, and an architectural memory limit that can only be mitigated. None of these are code-quality problems — they're "schedule the work" problems.
