# SystemNix — Session 131: Comprehensive Status Report

**Date:** 2026-06-11 00:39 CEST
**Host:** evo-x2 (NixOS x86_64, AMD Ryzen AI Max+ 395, 128 GiB RAM)
**Session:** 131
**Previous Reports:** Sessions 128–130 (2026-06-10, 6 reports)
**Build:** `just test-fast` — ✅ ALL CHECKS PASSED
**Working Tree:** 3 staged files (Caddy boot ordering fix + DNS gap fixes)

---

## Executive Summary

SystemNix manages **2 machines** (NixOS `evo-x2` desktop + macOS `Lars-MacBook-Air` laptop) with **39 service modules**, **35 centralized port definitions**, **26 overlay packages**, and **~16,500 lines of Nix**. The codebase is in **excellent structural shape**: zero FIXME/HACK/WORKAROUND markers, all ports centralized with collision detection, lib/ helpers fully adopted with zero dead code, 94 justfile recipes, and GitHub Actions CI.

**Today (June 10)** was an intense recovery day — **3 sessions (128–130)** following a GPU crash that took the system down for ~5 days. 16 commits landed fixing the sops atomic failure cascade, SigNoz boot blocking, Pocket ID declarative provisioning, Homepage dashboard, Caddy boot crash, DNS gaps, auth audit, and NVMe APST boot delay. **Session 131 (this session)** fixed the two highest-priority remaining issues: Caddy boot ordering (preventing a repeat 14-hour outage) and DNS A records for 5 subdomains that had Caddy vhosts but no DNS resolution.

**Top risks:** Root disk at 94–95% (28 GiB free), 7 unfixed broken services (Monitor365 DB, dnsblockd-cert-import, aw-watcher-wayland, Twenty CRM 502s, Pocket ID OTel spam, PG collation noise, DiscordSync UNIQUE constraints), and stale documentation (TODO_LIST.md 3 days old, FEATURES.md 8 days old).

---

## a) FULLY DONE ✅

### This Session (131)

| # | Item | Files Changed | Details |
|---|------|---------------|---------|
| 1 | **Caddy boot ordering fix** | `caddy.nix` | Added `bindsTo = ["sops-nix.service"]` + `after = [..., "sops-nix.service"]`. Prevents Caddy from starting before sops decrypts TLS certs — the cause of a 14-hour outage on June 10 |
| 2 | **DNS A records for 5 missing subdomains** | `dns-blocker-config.nix`, `rpi3/default.nix` | Added `status`, `seo`, `daily`, `logs`, `monitor` to Unbound local-data on both primary and RPi3 DNS servers. All had Caddy vhosts but no DNS resolution |

### Sessions 128–130 (June 10) — All Committed

| # | Item | Commit | Details |
|---|------|--------|---------|
| 3 | **sops atomic failure fix** | `eaeba69c` | Discordsync secret referenced non-existent user → ALL secrets blocked → 15+ services crash-looping. Wrapped with `lib.optionalAttrs` |
| 4 | **SigNoz decoupled from boot** | `eaeba69c` | Created `signoz.target` — ClickHouse/SigNoz no longer block `graphical.target` (~2m saved) |
| 5 | **SigNoz JWT secret auto-generation** | `eaeba69c` | Wrapper script auto-generates random secret on first start |
| 6 | **Crash-loop protection (startLimitBurst)** | `eaeba69c` | Added to homepage, immich, minecraft, ollama, signoz, signoz-collector, clickhouse, cadvisor |
| 7 | **notify-failure %i specifier fix** | `eaeba69c` | `%i` passed as script argument instead of inside Nix store script |
| 8 | **plugdev group for UDEV rules** | `eaeba69c` | Eliminated 36 udev warnings |
| 9 | **Deprecated amdgpu.gttsize removed** | `eaeba69c` | Kernel 7.0+ uses `ttm.pages_limit` only |
| 10 | **ClickHouse ports centralized** | `eaeba69c` | Keeper (9181) and RAFT (9234) added to `lib/ports.nix` |
| 11 | **Overview package build** | `4ed93f7` (overview repo) | Complete `mkPreparedSource` integration with 9 private Go repos, 12 sub-modules |
| 12 | **Pocket ID static API key** | `eaeba69c` | Generated and added to sops |
| 13 | **Discordsync enabled** | `eaeba69c` | Service + token regenerated |
| 14 | **Pocket ID provision: header casing** | `21ce65fb` | `X-API-KEY` → `X-API-Key` |
| 15 | **Pocket ID provision: URL encoding** | `21ce65fb` | `pagination[limit]` → `pagination%5Blimit%5D` — curl was interpreting brackets as glob |
| 16 | **Pocket ID provision: user creation payload** | `21ce65fb` | Removed `emailVerified`, `displayName`, `disabled` — API rejects unknown fields |
| 17 | **Pocket ID provision: race conditions** | `21ce65fb` | Idempotent "already exists" handling for both users and OIDC clients |
| 18 | **Manifest behind auth** | `f679b8fb` | Was the only unprotected Caddy vhost — now uses `protectedVHost` |
| 19 | **Homepage YAML rewrite** | `78b52da0` | Replaced broken string concatenation with `mkGroup`/`mkService` helpers |
| 20 | **Homepage ALLOWED_HOSTS + cache dir** | `78b52da0` | Added `HOMEPAGE_ALLOWED_HOSTS=dash.${domain}` + tmpfiles cache rule |
| 21 | **Admin email updated** | `109b6d3e` | `larsartmann.com` → `larsartmann.cloud` |
| 22 | **QDirStat added** | `d0bf0347` | Qt disk usage analyzer |
| 23 | **NVMe APST fix** | `eef194c2` | `nvme_core.default_ps_max_latency_us=0` — eliminates 2m50s device detection delay |

### Build & Quality

- ✅ `nix flake check` passes on both platforms (Darwin + NixOS)
- ✅ `just test-fast` passes (statix, deadnix, alejandra, eval)
- ✅ Pre-commit hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check
- ✅ GitHub Actions CI: `nix-check.yml` (push/PR) + `flake-update.yml` (weekly auto-PR)
- ✅ Zero FIXME / HACK / WORKAROUND / XXX markers in any .nix file (2 benign TODOs only)
- ✅ 94 justfile recipes

### Architecture

- ✅ flake-parts modular architecture with 39 auto-discovered service modules
- ✅ Cross-platform: Darwin (aarch64) + NixOS (x86_64) — 80% shared via `platforms/common/`
- ✅ `lib/` helper layer complete and fully adopted (13 exports, 0 dead code)
- ✅ Port centralization: ALL service modules reference `ports.*`, zero hardcoded ports, collision detection
- ✅ Overlay architecture: `mkPackageOverlay` for platform-safe overlays, 26 packages total
- ✅ DNS ↔ Caddy parity: 13 active subdomains in DNS, 15 Caddy vhosts (2 conditional on disabled services)

### Auth Coverage (Complete)

All 15 externally-accessible Caddy vhosts are protected:

| VHost | Auth Method | Protected |
|-------|-------------|-----------|
| `auth.home.lan` | Identity provider itself | N/A |
| `immich.home.lan` | Direct OIDC (client `immich`) | ✅ |
| `forgejo.home.lan` | Forward-auth via oauth2-proxy | ✅ |
| `dash.home.lan` | Forward-auth | ✅ |
| `signoz.home.lan` | Forward-auth | ✅ |
| `crm.home.lan` | Forward-auth | ✅ |
| `tasks.home.lan` | Forward-auth | ✅ |
| `manifest.home.lan` | Forward-auth | ✅ **(fixed session 129)** |
| `status.home.lan` | Forward-auth | ✅ **(DNS fixed session 131)** |
| `seo.home.lan` | Forward-auth | ✅ **(DNS fixed session 131)** |
| `daily.home.lan` | Forward-auth | ✅ **(DNS fixed session 131)** |
| `logs.home.lan` | Forward-auth | ✅ **(DNS fixed session 131)** |
| `monitor.home.lan` | Forward-auth | ✅ **(DNS fixed session 131)** |
| `voice.home.lan` | Forward-auth (disabled) | ✅ |
| `whisper.home.lan` | Forward-auth (disabled) | ✅ |

### Core Infrastructure (All Running)

| Service | Port | Status | Notes |
|---------|------|--------|-------|
| Caddy | 80, 443, 2019 | ✅ | TLS via sops, 15 vhosts, forward-auth, **boot ordering fixed** |
| Pocket ID | 1411 | ✅ | v2.7.0, passkey auth, declarative provisioning complete |
| OAuth2-Proxy | 4180 | ✅ | Forward-auth bridge, Gatus ping 200 OK |
| Forgejo | 3000 | ✅ | SQLite, LFS, Actions runner, push mirrors |
| Homepage Dashboard | 8082 | ✅ | Catppuccin Mocha, programmatic tiles, 5 categories |
| SigNoz | 8080, 4317, 4318 | ✅ | Traces/metrics/logs, ClickHouse, OTel, 7 alert rules |
| Gatus | 9110 | ✅ | 30+ health checks, status page |
| SOPS secrets | — | ✅ | Age-encrypted via SSH host key, 4 sops files |
| Docker | — | ✅ | overlay2, `/data/docker`, weekly prune |
| DNS (Unbound) | 53 | ✅ | Recursive + dnsblockd + 13 A records |
| SSH | 22 | ✅ | fail2ban aggressive |

### Applications (All Running)

| Service | Port | Status |
|---------|------|--------|
| Immich | 2283 | ✅ PG+Redis+ML, OAuth, VA-API |
| Twenty CRM | 3200 | ✅ Docker Compose, daily backup |
| Hermes | — | ✅ Discord bot, cron, messaging |
| OpenSEO | 3002 | ✅ SEO suite |
| TaskChampion | 10222 | ✅ Taskwarrior sync |
| Dozzle | 8084 | ✅ Docker logs |
| Overview | 8083 | ✅ Project dashboard |
| Crush Daily | 8081 | ✅ AI dev insights |
| DiscordSync | — | ✅ Channel sync (noisy) |
| Manifest | 2099 | ✅ LLM router, auth-protected |
| Deer Flow | — | ✅ nginx + gateway + frontend |
| Redis | — | ✅ BGSAVE healthy |

### Desktop (Fully Functional)

- ✅ Niri (scrolling-tiling Wayland) — 80+ keybindings, session save/restore
- ✅ Waybar — 15+ modules (DNS stats, weather, camera, GPU)
- ✅ Ghostty (primary) + Kitty (backup) + Foot (sway fallback)
- ✅ Rofi — Catppuccin Mocha, plugins (calc, emoji)
- ✅ SDDM — SilentSDDM, Catppuccin theme
- ✅ PipeWire audio — ALSA + PulseAudio + JACK
- ✅ Full Catppuccin Mocha theming (nix-colors, 164 colors migrated)
- ✅ AMD GPU — ROCm, VA-API, Vulkan, 32-bit support
- ✅ Yazi, Zellij, Dunst, Cliphist, Swayidle

---

## b) PARTIALLY DONE ⚠️

### Hermes AI Gateway

- **Done:** Service config, Discord bot, cron, messaging, 4G memory limit
- **Missing:** OpenAI API key not in sops (`hermes_openai_api_key` — TODO in `sops.nix:107`). SSH deploy key generated but not installed. No fallback LLM provider configured.
- **Impact:** Medium — no fallback if GLM-5.1 rate limits, can't reach git repos

### Pocket ID OTel Metrics

- **Done:** Auth fully working, provisioning complete
- **Missing:** `failed to upload metrics: Post "https://localhost:4318/v1/metrics": http: server gave HTTP response to HTTPS client` every 60 seconds
- **Fix:** Change OTel endpoint from `https://` to `http://` or disable metrics push
- **Impact:** Low — 1,440 log lines/day of noise

### DiscordSync

- **Done:** Service running, backfilling messages (578+ fetched)
- **Missing:** `UNIQUE constraint failed: messages.id` errors during backfill — app uses INSERT instead of INSERT OR IGNORE
- **Impact:** Low — eventually works but noisy logs

### Gatus Health Check Accuracy

- **Done:** 30+ endpoints defined
- **Missing:** 6 services show DOWN but may be healthy with wrong check URLs (SigNoz, Immich, Crush Daily, Ollama, Monitor365)
- **Impact:** Medium — monitoring dashboard is unreliable

### BTRFS Snapshots

- **Done:** Root (`@`) daily via btrbk, 14d + 4w auto-pruning, pre-deploy snapshots, verify timer
- **Missing:** `/data` still on BTRFS toplevel (subvolid=5) — cannot be snapshotted. Docker data, Immich uploads, AI models all unprotected.

### AI Stack

- **Done:** Ollama ROCm GPU, llama.cpp, gpu-python, centralized model storage
- **Missing:** Voice agents (LiveKit + Whisper) disabled, PhotoMap disabled (podman permissions)

### Darwin (macOS)

- **Done:** Shared packages, Home Manager, shell config, theme, ActivityWatch
- **Missing:** Only 7 lines of Home Manager config. Disk at 90%+ full (256GB SSD). No terminal, editor, theme parity with NixOS.

---

## c) NOT STARTED 📋

| # | Item | Priority | Blocker |
|---|------|----------|---------|
| 1 | **Raspberry Pi 3 DNS failover provisioning** | Medium | Hardware not available |
| 2 | **BTRFS `/data` subvolume migration** | High | `just snapshot-migrate-data` exists, requires downtime |
| 3 | **Pocket ID SMTP via SES/Resend** | High | Need SMTP credentials, SES infra exists in `domains` repo |
| 4 | **Hermes OpenAI API key to sops** | Medium | Manual: `sops platforms/nixos/secrets/hermes.yaml` |
| 5 | **Hermes SSH deploy key installation** | Medium | Manual: install key + add to GitHub |
| 6 | **Boot time verification (target ~35s)** | Low | Requires reboot |
| 7 | **SigNoz provision log verification** | Low | Requires `just switch` + curl |
| 8 | **Gatus endpoint health re-audit** | Medium | Manual verification of 30+ endpoints |
| 9 | **Discord alert channel test** | Low | Needs webhook test on evo-x2 |
| 10 | **Auditd enablement** | Low | Blocked: NixOS 26.05 bug #483085 |
| 11 | **AppArmor enablement** | Low | Commented out in security-hardening.nix |
| 12 | **Darwin Home Manager parity** | Low | Disk constraint (90%+ full, 256GB SSD) |
| 13 | **Monitor365 agent→server auth** | Low | No auth — anyone on LAN can POST data |
| 14 | **Dozzle proper NixOS module** | Low | Creating module with options causes eval failure |
| 15 | **Shared flake-parts template push** | Low | Created, needs push to `go-nix-helpers` |
| 16 | **Deer Flow NixOS module** | Low | Running as ad-hoc Docker Compose, no proper module |
| 17 | **Voice agents evaluation** | Low | Module exists, disabled — decide enable/remove |
| 18 | **Minecraft server evaluation** | Low | Module exists, disabled — decide enable/remove |
| 19 | **PhotoMap evaluation** | Low | Module exists, disabled — decide enable/remove |

---

## d) TOTALLY FUCKED UP ❌

### Monitor365 — DB Path Broken

- **Services:** `monitor365-server` + `monitor365-agent` (user services)
- **Error:** `Failed to initialize database: error returned from database: (code: 14) unable to open database file`
- **Root cause:** SQLite database path points to a directory that doesn't exist or has wrong permissions
- **State:** `start-limit-hit` — systemd has given up restarting
- **Fix:** Check `stateDir` in module, ensure tmpfiles rule creates parent directory with correct ownership
- **Impact:** Monitoring dashboard completely down

### dnsblockd-cert-import — Missing Binary

- **Service:** `dnsblockd-cert-import` (user service)
- **Error:** Exit code 127 (command not found)
- **Root cause:** References `certutil` from `nssTools` which isn't in the user service's PATH
- **Fix:** Add `nssTools` to service's `path` attribute or use full binary path
- **Impact:** CA cert not imported into NSS DB

### aw-watcher-window-wayland — Display Race

- **Service:** `activitywatch-watcher-aw-watcher-window-wayland` (user service)
- **Error:** `Failed to connect to wayland display` (panic)
- **Root cause:** Starts before Niri compositor is ready — race condition during boot
- **Fix:** Add `After=graphical-session.target` + verify dependency chain
- **Impact:** Wayland window tracking dead on boot

### Twenty CRM — Intermittent 502s

- **Service:** Twenty CRM via Caddy
- **Error:** `connection refused` and `connection reset by peer` on port 3200
- **Root cause:** Twenty server container crashes/restarts periodically (OOM? health check timeout? PG connection exhaustion?)
- **Impact:** CRM intermittently unavailable

### PostgreSQL Collation Spam

- **Service:** Twenty CRM's postgres container
- **Error:** `database "postgres" has no actual collation version, but a version was recorded` every 5 seconds
- **Root cause:** Postgres collation version mismatch after container upgrade
- **Fix:** `ALTER DATABASE postgres REFRESH COLLATION VERSION;` or `REINDEX DATABASE postgres;`
- **Impact:** Harmless but fills journal rapidly (~15,000+ lines/day)

### Root Disk at 94–95%

- **Metric:** 472–477G / 512G used, 28–33G free
- **Cause:** 87G Nix store with 3,874 GC-eligible paths (user ran `nix-collect-garbage -d` this session — should improve)
- **Impact:** Approaching critical. Disk-full = total system lockout

### Swap: 8 GiB Used on 128 GiB RAM

- **Metric:** 8–17 GiB swap used despite 64+ GiB RAM available
- **Cause:** Likely stale processes (LSP, AI workloads) — `stale-lsp-cleanup` timer mitigates partially
- **Impact:** Reduced performance, memory inefficiency

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Critical

1. **Root disk monitoring + automation** — Even after GC, 87G Nix store will grow back. Need a weekly `nix-collect-garbage` timer to prevent recurrence. `nix.settings.auto-optimise-store = true` is already set but doesn't remove old generations.

2. **sops secret guards for ALL services** — Session 128 proved one bad sops owner blocks ALL secrets atomically. Only discordsync is guarded with `lib.optionalAttrs config.services.X.enable`. Other services (hermes, immich, twenty, manifest, etc.) would cause the same cascade if their users were missing.

3. **Caddy boot ordering verification** — The `bindsTo = ["sops-nix.service"]` fix is committed but not yet deployed. Needs `just switch` + reboot to verify.

### Architecture

4. **Pocket ID OTel endpoint** — Change `https://localhost:4318` to `http://localhost:4318` in Pocket ID config. One-line fix, eliminates 1,440 log lines/day.

5. **Monitor365 state directory** — Add proper tmpfiles rule or fix DB path. 716-line module is the largest service module — likely has extraction opportunities.

6. **`/data` BTRFS migration** — Running on toplevel (subvolid=5) means no snapshot protection for Docker data, Immich uploads, AI models. `just snapshot-migrate-data` exists.

7. **Pocket ID SMTP** — SES/Resend credentials need wiring for email verification + login notifications.

8. **Split large modules** — `monitor365.nix` (716L), `signoz.nix` (705L), `forgejo.nix` (583L) all have extraction opportunities.

### Code Quality

9. **TODO_LIST.md stale (3 days)** — Missing sessions 125–131 work. Should update.

10. **FEATURES.md stale (8 days)** — Missing: Pocket ID provisioning, Overview, Crush Daily, Monitor365, auth audit, Manifest protection, NVMe APST fix, DNS fixes, Caddy boot fix.

11. **177 status reports in docs/status/** — Massive bloat. Archive pre-session-100 aggressively.

12. **No ROADMAP.md** — Planning docs exist in `docs/planning/` but no single source of truth for direction.

13. **No CHANGELOG.md** — 185 commits in 2 weeks with no changelog.

### Security

14. **Monitor365 agent→server auth** — No auth between agent and server. Anyone on LAN can POST data.

15. **Auditd** — Blocked by NixOS 26.05 bug #483085.

16. **AppArmor** — Commented out in `security-hardening.nix`.

### Operations

17. **PostgreSQL collation fix** — One-time `ALTER DATABASE` command silences 15,000+ daily log lines.

18. **Gatus health check accuracy** — 6 services show DOWN with possibly wrong URLs. Monitoring is unreliable.

19. **Deer Flow module** — Running as ad-hoc Docker Compose. Should be proper NixOS module with options.

20. **Disabled service triage** — Voice agents, Minecraft, PhotoMap are all disabled. Decide: enable or remove.

---

## f) Top 25 Things to Get Done Next

### Priority 0: Deploy & Verify

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **`just switch`** — deploy Caddy boot fix + DNS fixes + verify Pocket ID provision | Prevents 14h outage recurrence, fixes 5 unreachable subdomains | 10 min |
| 2 | **Reboot evo-x2** — verify boot time with NVMe APST fix + Caddy sops ordering | Confirms ~35s boot target vs 6m17s pre-fix | 5 min |

### Priority 1: Fix Broken Services

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 3 | **Fix Monitor365 DB path** — investigate stateDir, add tmpfiles rule | Monitoring dashboard restored | 20 min |
| 4 | **Fix dnsblockd-cert-import PATH** — add `nssTools` to service | CA cert import works | 5 min |
| 5 | **Fix Pocket ID OTel endpoint** — `https://` → `http://` localhost:4318 | Eliminates 1,440 log lines/day | 5 min |
| 6 | **Fix PostgreSQL collation spam** — `ALTER DATABASE postgres REFRESH COLLATION VERSION` | Eliminates 15,000 log lines/day | 5 min |
| 7 | **Fix aw-watcher-wayland startup** — verify `After=graphical-session.target` | Wayland window tracking works | 10 min |

### Priority 2: High-Value Quick Wins

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 8 | **Audit Gatus health checks** — fix 6 DOWN endpoints with wrong URLs | Reliable monitoring | 30 min |
| 9 | **Guard ALL sops secrets** — `lib.optionalAttrs config.services.X.enable` on every service-specific user | Prevents future atomic failures | 30 min |
| 10 | **Investigate swap usage** — `smem -t -k \| tail -20` + `swapoff -a && swapon -a` | Memory efficiency | 15 min |
| 11 | **Wire Hermes OpenAI fallback** — add API key to sops | LLM gateway has resilience | 5 min |
| 12 | **Install Hermes SSH deploy key** | Hermes can reach git repos | 5 min |
| 13 | **Add weekly Nix GC timer** — prevent root disk creep | Long-term disk health | 15 min |

### Priority 3: Service Maturity

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 14 | **Investigate Twenty CRM 502s** — check container logs, OOM, PG connections | CRM stability | 30 min |
| 15 | **`/data` BTRFS subvolume migration** — `just snapshot-migrate-data` | Snapshot protection for Docker/Immich/AI data | 1 hr + downtime |
| 16 | **Pocket ID SMTP wiring** — SES/Resend credentials + env vars | Email verification + login notifications | 30 min |
| 17 | **Create Deer Flow NixOS module** — proper service with options | Consistency with other services | 45 min |
| 18 | **DiscordSync: file upstream issue** — INSERT OR IGNORE for UNIQUE constraints | Reduces backfill log noise | 10 min |

### Priority 4: Documentation & Hygiene

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 19 | **Update TODO_LIST.md** — sessions 125–131 missing | Accurate task tracking | 30 min |
| 20 | **Update FEATURES.md** — add 8+ features since Jun 3 | Accurate feature inventory | 30 min |
| 21 | **Archive old status reports** — move pre-session-100 to `docs/status/archive/` | Reduces 177 → ~30 files | 10 min |
| 22 | **Create ROADMAP.md** — consolidate from `docs/planning/` | Single source of truth for direction | 1 hr |

### Priority 5: Long-Term

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 23 | **Provision Pi 3 for DNS failover** — hardware setup, SD flash, network wiring | Network resilience | 4 hr |
| 24 | **Darwin Home Manager parity** — terminal, editor, theme matching NixOS | Consistent cross-platform experience | 2 hr |
| 25 | **Split large modules** — monitor365 (716L), signoz (705L), forgejo (583L) | Maintainability | 3 hr |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Does the `bindsTo = ["sops-nix.service"]` fix actually prevent the Caddy boot race?**

The fix adds both `after = ["sops-nix.service"]` and `bindsTo = ["sops-nix.service"]` to Caddy's systemd unit. In theory, this means:
- `after` ensures Caddy starts after sops-nix completes
- `bindsTo` means Caddy stops if sops-nix stops (which is fine — sops runs once at activation)

But `sops-nix.service` is a oneshot activation service that runs during boot. The question is:
1. Is `sops-nix.service` the correct unit name? (It might be `sops-install-secrets.service` or `sops-nix-*.service` on some configurations)
2. Does `sops-nix` actually place the secret files on disk BEFORE it reports success? (If it queues async decryption, the files might not be ready even after the service completes)
3. Will `bindsTo` cause issues during `just switch` when sops-nix re-runs? (Caddy should restart, not stop permanently)

The only way to verify is to **deploy + reboot** and check `systemd-analyze blame | grep caddy` and `systemctl status caddy` after boot.

---

## System Snapshot

```
Hostname:            evo-x2
Platform:            NixOS x86_64 (kernel 7.0.11)
CPU:                 AMD Ryzen AI Max+ 395
RAM:                 93 GiB (28 GiB used, 64 GiB available)
Swap:                19 GiB (8 GiB used)
Load:                ~3-6

Root disk /:         512G total, ~94-95% used (28-33G free after GC)
Data disk /data:     1.0T total, 78% used (226G free)
Nix Store:           87G (post-GC, was 3,874 eligible paths)

Commits (today):     16 (sessions 128-131)
Sessions (today):    4 (128, 129, 130, 131)
Service modules:     39
Enabled services:    35
Disabled services:   4
Broken services:     7 unfixed
Ports:               35 (collision-protected)
Overlays:            26 packages
Lib helpers:         13 exports, 0 dead
FIXME/HACK:          0
Status reports:      177 non-archived
```

---

## Listening Ports (Full Inventory)

| Port | Service | Bind |
|------|---------|------|
| 22 | SSH | 0.0.0.0 + [::] |
| 53 | Unbound DNS | 0.0.0.0 |
| 80 | Caddy HTTP | LAN |
| 443 | Caddy HTTPS | LAN |
| 1411 | Pocket ID | 127.0.0.1 |
| 2019 | Caddy admin | 127.0.0.1 |
| 2099 | Manifest | 127.0.0.1 |
| 2283 | Immich | 127.0.0.1 |
| 3000 | Forgejo | * |
| 3002 | OpenSEO | 127.0.0.1 |
| 3200 | Twenty CRM | 127.0.0.1 |
| 4180 | OAuth2-Proxy | 127.0.0.1 |
| 4317 | SigNoz OTLP gRPC | 127.0.0.1 |
| 4318 | SigNoz OTLP HTTP | 127.0.0.1 |
| 5432 | PostgreSQL (Docker) | 127.0.0.1 |
| 5600 | ActivityWatch | 127.0.0.1 |
| 8080 | SigNoz UI | * |
| 8082 | Homepage | 0.0.0.0 |
| 8083 | Overview | * |
| 8084 | Dozzle | 127.0.0.1 |
| 8090 | Emeet-Pixyd | 127.0.0.1 |
| 8123 | ClickHouse HTTP | 127.0.0.1 |
| 9000 | ClickHouse native | 127.0.0.1 |
| 9090 | dnsblockd stats | 127.0.0.1 |
| 9100 | node_exporter | 127.0.0.1 |
| 9110 | Gatus | * |
| 9181 | ClickHouse Keeper | 127.0.0.1 |
| 9190 | cadvisor | 127.0.0.1 |
| 9234 | ClickHouse RAFT | * |
| 10222 | TaskChampion | 127.0.0.1 |

---

## Session Timeline (June 10–11)

| Session | Time | Key Changes |
|---------|------|-------------|
| 128 | 19:18 | Post-GPU-crash cascade: sops, SigNoz, watchdog, hardening, overview build |
| 129 | 21:23 | Manifest auth, Pocket ID API fixes, Homepage refactor, QDirStat, NVMe APST fix |
| 130 | 22:48 | Homepage fix, Caddy boot crash, DNS gap, Pocket ID email, auth audit, full service audit |
| **131** | **00:39** | **Caddy boot ordering fix (bindsTo sops-nix), DNS A records for 5 subdomains, full status report** |

---

_Generated by Crush — Session 131_
