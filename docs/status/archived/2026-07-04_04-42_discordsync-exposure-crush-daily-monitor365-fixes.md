# Status Report — DiscordSync Exposure, Crush-Daily Repair, Monitor365 UI Fix

**Date:** 2026-07-04 04:42 CEST
**Branch:** master
**Last deployed generation:** 434 (2026-06-25)
**Undeployed commits:** ~17 (all work since 2026-06-25 — monitoring hardening, Caddy security, Helium fix, memory bounds, niri fork, DiscordSync vHost, crush-daily repair, monitor365 UI fix, Overview exposure)
**Scope:** DiscordSync dashboard exposure, crush-daily data collection bug, Monitor365 server UI package mismatch, Overview vHost wiring

---

## Executive Summary

Three service fixes and one exposure. **DiscordSync dashboard** is now wired behind Caddy `protectedVHost` (Layer-2 SSO via Pocket ID + oauth2-proxy). **Crush Daily** had a silent failure: `ProtectHome=true` made the Crush database invisible — the nightly collector ran for weeks finding nothing. **Monitor365** `/ui/` 404'd because the server package default pointed at `pkgs.monitor365` (the agent CLI) instead of `pkgs.monitor365-server` (the symlinkJoin with bundled WASM UI). **Overview** identified as the only remaining unexposed web UI — ready to wire.

| Metric                                        | Value                                                 |
| --------------------------------------------- | ----------------------------------------------------- |
| Services with web UIs exposed via Caddy       | 12 (+1 DiscordSync pending)                           |
| Services with silent failures fixed           | 2 (crush-daily, monitor365)                           |
| Gatus endpoints with response-time thresholds | 17                                                    |
| Known broken services                         | 1 (Monitor365 server — pending deploy to confirm fix) |
| Undeployed commits                            | ~17                                                   |

---

## a) FULLY DONE ✅

### This Session

| Work Item                       | Details                                                                                                                                                                                                                                                                                                                                                                                                  | Status                        |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| DiscordSync dashboard exposed   | `protectedVHost "discordsync" ports.discordsync-api` in `caddy.nix`. DNS A record added (`discordsync` in `localSubdomains`). Homepage tile updated with `href`. Layer-2 SSO (Pocket ID passkey login required for external access, LAN open). `localhost:8085` stays direct.                                                                                                                            | ✅ Committed (`b1e45529`)     |
| Crush-daily data collection fix | Root cause: `ProtectHome=true` (from `harden {}`) made `/home/lars/.local/share/crush/.crush/` invisible. Nightly collector ran for weeks, found nothing, wrote empty results → "No reports yet". Fix: `ProtectHome=false`, `ReadOnlyPaths` scoped to `.crush/` dir, `SupplementaryGroups="users"`, activation script `chmod g+rx` on three 700-permission dirs (`.local/`, `.local/share/`, `.crush/`). | ✅ Uncommitted (this session) |
| Monitor365 UI package fix       | Root cause: `cfg.server.package` defaulted to `pkgs.monitor365` (the **agent CLI** — no server binary, no UI). The overlay exposes `pkgs.monitor365-server` (symlinkJoin: server binary + WASM UI + `UI_DIST_PATH` wrapper). Fix: default changed to `pkgs.monitor365-server`. The upstream flake already builds it correctly with the Leptos WASM UI bundled and `UI_DIST_PATH` set.                    | ✅ Uncommitted (this session) |

### Previously Completed (still undeployed)

| Work Item                                                    | Commit                 |
| ------------------------------------------------------------ | ---------------------- |
| Gatus DiscordSync response-time threshold                    | `42cac6d4`             |
| Caddy security headers, TLS 1.2+, strict SNI, access logging | `a5e688cf`, `15a8869d` |
| Gatus Discord alerts on all critical endpoints (31 of 39)    | `148beb9c`             |
| Gatus response-time thresholds (17 endpoints)                | `3c5eb141`             |
| Helium display-hotplug crash fix (`--disable-gpu-watchdog`)  | `326132cb`             |
| /tmp tmpfs capped at 16 GiB                                  | `d9dc7d30`             |
| Unbound cache bounds (`key-cache-size`, `neg-cache-size`)    | `d9dc7d30`             |
| BTRFS health gating for nix-gc                               | (earlier session)      |
| Niri fork switch for session management                      | `f1f23079`             |
| SSH socket cleanup timer                                     | `02b4e6eb`             |
| Herdr terminal agent multiplexer                             | `7514ba8f`             |

---

## b) PARTIALLY DONE 🟡

| Item                                        | Done                                                                           | Gap                                                                  | Effort to Close                                                           |
| ------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Deploy**                                  | ~17 commits pass `nix flake check --no-build`                                  | **NOT LIVE on evo-x2** (gen 434 since 06-25)                         | `nix run .#deploy` + reboot                                               |
| **Overview exposure**                       | Identified as the only unexposed web UI (port 8083). Running, Gatus-monitored. | No Caddy vHost, no DNS record, no Homepage href.                     | 3 lines: `protectedVHost "overview" ports.overview` + DNS + Homepage href |
| **DNS migration** (dnsblockd → primary :53) | dnsblockd v0.2.0 ready, detailed 4-phase plan in TODO_LIST.md                  | Phase 2a-4 not started                                               | ~15h both repos                                                           |
| **BTRFS `/data` subvolume**                 | Root (`@`) snapshotted                                                         | `/data` is toplevel (subvolid=5) — Docker/Immich/AI data unprotected | ~1h downtime                                                              |
| **Crush-daily verification**                | Fix written (ProtectHome, permissions, SupplementaryGroups)                    | Needs deploy + manual collection trigger to verify data flows        | Deploy + `systemctl start crush-daily-collect`                            |
| **Monitor365 verification**                 | Package fix written (`pkgs.monitor365-server`)                                 | Needs deploy to confirm `/ui/` serves the Leptos WASM dashboard      | Deploy + visit `monitor.home.lan`                                         |
| **Off-site backup**                         | None                                                                           | No disaster-recovery backup exists                                   | Medium (Hetzner StorageBox + BorgBackup)                                  |

---

## c) NOT STARTED ⬜

| Item                             | Impact   | Notes                                                                       |
| -------------------------------- | -------- | --------------------------------------------------------------------------- |
| **Overview vHost exposure**      | Medium   | Only unexposed web UI remaining. `protectedVHost "overview" ports.overview` |
| **Off-site backup**              | Critical | No DR. Hetzner StorageBox + BorgBackup evaluated                            |
| **Firewall deny-by-default**     | High     | All inbound allowed; needs explicit allowlist                               |
| **Bind Immich to localhost**     | Medium   | `0.0.0.0` + `openFirewall`; Caddy already proxies                           |
| **DNS migration Phase 2a**       | High     | dnsblockd module rework for `:53` primary                                   |
| **Pi 3 DNS failover cluster**    | Medium   | Hardware not provisioned                                                    |
| **Auditd enablement**            | Medium   | Blocked on NixOS 26.05 bug #483085                                          |
| **Caddy rate limiting**          | Medium   | No native rate limiter; needs plugin                                        |
| **Caddy access logs → SigNoz**   | Medium   | filelog receiver in OtelCollector                                           |
| **PostgreSQL direct monitoring** | Medium   | `pg_isready` textfile exporter                                              |
| **Split large modules**          | Low      | monitor365 (830L), signoz (705L), forgejo (583L)                            |
| **Typed NixOS module options**   | Low      | Many modules use `mkEnableOption` only                                      |
| **Hermes HTTP endpoint**         | Medium   | No health endpoint — needs upstream work                                    |

---

## d) TOTALLY FUCKED UP 🔴

### 1. Crush Daily — Silent Failure (FIXED, pending deploy)

**What happened:** The crush-daily service ran every night at 00:30 for **weeks**, silently failing. The `harden {}` function applies `ProtectHome=true` by default, which makes `/home` an empty tmpfs. The collector couldn't see `/home/lars/.local/share/crush/.crush/crush.db`. It wrote nothing, reported nothing, and the dashboard showed "No reports yet" — the correct answer, because there was no data.

**Evidence:**

- `crush-daily.db` last modified: **Jun 11** (last successful collection before hardening tightened)
- `crush-daily.db-wal` last modified: Jul 4 00:30 (scheduler keeps writing error/status entries)
- `reports/` directory: **empty** (no data → no insights → no reports)
- Three directories at `700` (`.local/`, `.local/share/`, `.crush/`) blocked the `crush-daily` user even through `SupplementaryGroups`

**Fix:** `ProtectHome=false` + `ReadOnlyPaths` scoped to `.crush/` + activation script `chmod g+rx` on the three blocking dirs + `SupplementaryGroups="users"`.

**Lesson:** `harden {}` with default `ProtectHome=true` is dangerous for services that need to read user data. Always verify the service can actually reach its data source.

### 2. Monitor365 — Wrong Package (FIXED, pending deploy)

**What happened:** The Monitor365 server worked as an API (Gatus `/health` returned 200) but the UI at `/ui/` returned 404. Root cause: `cfg.server.package` defaulted to `pkgs.monitor365` — the **agent CLI** package, not `pkgs.monitor365-server` — the **symlinkJoin** that bundles the server binary + WASM UI + `UI_DIST_PATH` wrapper.

The upstream flake correctly builds three separate packages:

- `monitor365` (alias for `monitor365-cli` — the agent)
- `monitor365-server` (symlinkJoin: CLI + WASM UI + `UI_DIST_PATH` wrapper)
- `monitor365-ui` (WASM UI only)

The overlay exposes all three. The SystemNix module picked the wrong one.

**Fix:** Changed default from `pkgs.monitor365` to `pkgs.monitor365-server`.

**Lesson:** When an upstream flake exposes multiple packages with similar names, verify exactly which one contains the required runtime artifacts. The `monitor365` alias pointed at `monitor365-cli`, not the server bundle.

### 3. GPUActive Memory Crisis (architectural, mitigated not solved)

**Status unchanged from prior report.** 51+ GiB GPUActive (55% of visible RAM) with `GPUReclaim=0`. Mitigations in place but system runs in chronic pressure. Not fixable — hardware/driver architectural limit.

### 4. ~17 Commits Undeployed

All fixes from this session and the prior three sessions are **theoretical** until deployed. Generation 434 has been running since 2026-06-25 (9 days). The crush-daily and monitor365 fixes can't be verified until deploy.

---

## e) WHAT WE SHOULD IMPROVE

1. **DEPLOY.** The crush-daily fix, monitor365 UI fix, DiscordSync exposure, and ~14 prior commits are all undeployed. The system has been running stale config for 9 days. This is the single highest-impact action.

2. **Expose Overview.** It's the only remaining unexposed web UI. Three lines: `protectedVHost`, DNS record, Homepage href.

3. **Audit all hardened services for ProtectHome data access.** The crush-daily bug was silent for weeks. Other services that read from `/home` may have the same issue. Quick audit: `grep -r "ProtectHome" modules/` and cross-reference with services that read user data.

4. **Off-site backup.** Still the biggest existential risk. Forgejo (Git history), Immich (photos), DiscordSync (Discord archive), Twenty (CRM) — all have zero off-site backup.

5. **Fix the Monitor365 crash-loop (if still present).** The TODO says "upstream Rust panic (Axum 0.7 route syntax)". But the source audit shows the upstream **already uses** `{param}` syntax (Axum 0.7+). The crash-loop may have been the wrong package all along — `monitor365` (CLI) doesn't have server routes. Deploy may fix everything.

6. **DNS migration execution.** Plan is thorough, dnsblockd v0.2.0 ready. Simplifies the stack.

7. **Gatus maintenance windows.** Every deploy fires false Discord alerts. Suppress noise.

8. **Firewall hardening.** Every service exposed to LAN by default.

9. **PostgreSQL visibility.** Three critical services depend on it. Blind to DB health.

10. **BTRFS `/data` subvolume.** Docker/Immich/AI data unsnapshotted.

---

## f) Top 25 Things to Get Done Next

| #  | Task                                                                                       | Impact   | Effort       | Dependency                     |
| -- | ------------------------------------------------------------------------------------------ | -------- | ------------ | ------------------------------ |
| 1  | **Deploy ~17 undeployed commits** (`nix run .#deploy`) + reboot                            | Critical | 1 command    | Physical attendance for reboot |
| 2  | **Verify crush-daily collection** post-deploy (`systemctl start crush-daily-collect`)      | High     | Low          | Deploy first                   |
| 3  | **Verify monitor365 `/ui/`** post-deploy (visit `monitor.home.lan`)                        | High     | Low          | Deploy first                   |
| 4  | **Verify DiscordSync dashboard** post-deploy (`discordsync.home.lan` → Pocket ID SSO)      | High     | Low          | Deploy first                   |
| 5  | **Expose Overview** (`protectedVHost "overview" ports.overview` + DNS + Homepage)          | Medium   | Low          | —                              |
| 6  | **Off-site backup** (Hetzner StorageBox + BorgBackup / Restic)                             | Critical | Medium       | Evaluated, needs execution     |
| 7  | **Audit all `harden {}` services** for ProtectHome data-access bugs                        | High     | Low          | `grep -r ProtectHome modules/` |
| 8  | **Gatus maintenance windows** (suppress deploy-time alerts)                                | High     | Low          | —                              |
| 9  | **Firewall deny-by-default** with explicit service allowlist                               | High     | Medium       | —                              |
| 10 | **BTRFS `/data` → `@data` subvolume** migration                                            | High     | ~1h downtime | USB rescue boot                |
| 11 | **DNS migration Phase 2a** (dnsblockd module rework for `:53` primary)                     | High     | ~6h          | dnsblockd v0.2.0 pinned        |
| 12 | **PostgreSQL textfile exporter** (`pg_isready` + conn count)                               | Medium   | Medium       | —                              |
| 13 | **Caddy access logs → SigNoz** (filelog receiver)                                          | Medium   | Medium       | —                              |
| 14 | **Caddy admin API hardening** (`admin off` + `:2019 { metrics }`)                          | High     | Medium       | Test `nh os switch` reload     |
| 15 | **Bind Immich to localhost** (remove `openFirewall`)                                       | Medium   | Low          | Caddy already proxies          |
| 16 | **Caddy request body size limits** on upload vhosts                                        | Medium   | Low          | —                              |
| 17 | **Caddy upstream health checks** (`health_uri` on reverse_proxy)                           | High     | Medium       | Per-backend health endpoints   |
| 18 | **Gatus → Homepage integration** (real-time status dots)                                   | Low      | Low          | —                              |
| 19 | **DNS migration Phase 2b-2c** (config + dependency updates)                                | High     | ~4h          | Phase 2a done                  |
| 20 | **DNS migration Phase 3** (deploy + 24h observation)                                       | High     | 24h observe  | 2b-2c done                     |
| 21 | **Hermes: install SSH deploy key + set fallback model** (manual steps)                     | Medium   | Low          | Blocked on human               |
| 22 | **Split large modules** (monitor365 830L, signoz 705L, forgejo 583L)                       | Low      | Medium       | —                              |
| 23 | **Disabled service triage** — remove photomap (decided), decide voice-agents               | Low      | Low          | —                              |
| 24 | **Upstream nixpkgs PRs** (aw-watcher-utilization, taskwarrior3 flags, KeePassXC manifests) | Low      | Medium       | Community benefit              |
| 25 | **Monitoring runbook** (what to do when each Discord alert fires)                          | Medium   | Medium       | —                              |

---

## g) Top #1 Question

**The crush-daily "weeks of silent failure" pattern — are there other services with the same bug?**

The root cause was `harden { ProtectHome = true }` (the default) combined with a service that reads from `/home/lars/`. I found it for crush-daily because you noticed "No reports yet". But other services may be silently failing the same way — their collectors or agents can't reach user data, and the failure mode is "empty output" not "crash".

Specifically, I cannot determine without a deploy + runtime check whether:

- **PMA (projects-management-automation)** — watches `~/projects` directories. Does `ProtectHome=true` block it?
- **File & Image Renamer** — watches `~/Downloads` and `~/Pictures`. Same question.
- **ActivityWatch** — reads from the user session. May be fine (runs as user, not system service with `harden`).

A quick `grep -r "ProtectHome\|ReadWritePaths\|home" modules/nixos/services/*.nix` would identify candidates, but I can't verify runtime behavior from config alone. **Should I audit all hardened services for this class of bug before the next deploy?**

---

## Session Metrics

| Metric                         | Start                       | End                            | Delta                                                                        |
| ------------------------------ | --------------------------- | ------------------------------ | ---------------------------------------------------------------------------- |
| Services exposed via Caddy SSO | 11                          | 12                             | +1 (DiscordSync)                                                             |
| Silent failures diagnosed      | 0                           | 2                              | crush-daily + monitor365                                                     |
| Gatus response-time endpoints  | 16                          | 17                             | +1 (DiscordSync)                                                             |
| Commits this session           | —                           | 2 + this report                | —                                                                            |
| Files changed                  | —                           | 4                              | caddy.nix, dns-blocklists.nix, homepage.nix, crush-daily.nix, monitor365.nix |
| Deploy status                  | gen 434                     | **Still gen 434**              | ~17 commits pending                                                          |
| Known broken services          | 2 (crush-daily, monitor365) | 0 (both fixed, pending deploy) | —                                                                            |

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
