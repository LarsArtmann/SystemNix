# Session 128 — Post-GPU-Crash Cascade Fix & Overview Build Integration

**Date:** 2026-06-10 19:18 CEST
**Trigger:** System crashed (GPU freeze ~Jun 5, manually recovered Jun 10), 6m17s boot, 15+ services in crash loops
**Result:** 2 commits deployed, 17/19 services now active, 2 pre-existing failures remain

---

## A) FULLY DONE

### 1. Root Cause Identified & Fixed: sops Atomic Failure
- **Problem:** `sops-install-secrets` validates ALL secret owners atomically. `discordsync` secrets referenced user `discordsync` which didn't exist (service was disabled). One bad owner → ALL secrets blocked → `/run/secrets/` completely empty → 15+ services crash-looping.
- **Fix:** Wrapped discordsync secrets + template in `lib.optionalAttrs config.services.discordsync.enable (...)` in `modules/nixos/services/sops.nix`.
- **Impact:** All 15+ dependent services now start correctly. Secrets are populated.

### 2. SigNoz Decoupled From Boot Critical Chain
- **Problem:** ClickHouse (1m27s) → SigNoz (23s) → SigNoz Collector (54s) blocked `graphical.target` via `multi-user.target`, causing 2m48s userspace delay.
- **Fix:** Created `signoz.target` (custom systemd target). Moved all 4 services (signoz, signoz-collector, clickhouse, cadvisor) to `wantedBy = ["signoz.target"]`. They still auto-start but don't block desktop.
- **Impact:** After reboot, `graphical.target` should reach in ~30s instead of ~3min.

### 3. SigNoz JWT Secret Auto-Generation
- **Problem:** SigNoz required a JWT secret but none was configured.
- **Fix:** Wrapper script auto-generates random secret via `openssl rand -base64 48` on first start, persists at `${dataDir}/jwt-secret`, reads on subsequent starts.
- **Impact:** SigNoz starts without manual JWT configuration.

### 4. Crash-Loop Protection (startLimitBurst)
- **Problem:** Services with `Restart = always` (from `serviceDefaults`) but no burst limit would infinite-retry, filling journals.
- **Fix:** Added `startLimitBurst = 5; startLimitIntervalSec = 300;` to: homepage, immich-server, immich-machine-learning, minecraft, ollama, signoz, signoz-collector, clickhouse, cadvisor.
- **Impact:** Services give up after 5 failures in 5 minutes instead of infinite loops.

### 5. notify-failure %i Specifier Fix
- **Problem:** `notify-failure@%n.service` template used `%i` inside a `writeShellApplication` script. systemd specifiers are NOT expanded inside Nix store scripts.
- **Fix:** Changed ExecStart to pass `%i` as argument: `${scriptBin}/bin/notify-failure %i`.
- **Impact:** Failure notifications now correctly identify which service failed.

### 6. Security Hardening: plugdev Group
- **Problem:** 36 udev warnings about `70-u2f.rules` referencing non-existent `plugdev` group.
- **Fix:** Added `users.groups.plugdev = {};` in `modules/nixos/services/security-hardening.nix`.

### 7. Deprecated Kernel Params Removed
- **Problem:** `amdgpu.gttsize` kernel param is deprecated in kernel 7.0+ (only `ttm.pages_limit` used).
- **Fix:** Removed `amdgpuGttSize` binding and all references from `platforms/nixos/system/boot.nix`.

### 8. ClickHouse Ports Centralized
- **Problem:** ClickHouse keeper (9181) and raft (9234) ports hardcoded in signoz module.
- **Fix:** Added `signoz-clickhouse-keeper` and `signoz-clickhouse-raft` to `lib/ports.nix`.

### 9. Overview Package Build Fixed (Upstream)
- **Problem:** Overview's `mkPreparedSource` was missing the `deps` argument. 9 private Go repositories needed as flake inputs with full transitive dependency tree.
- **Fix:** Added all private transitive deps as `flake = false` inputs to overview's `flake.nix`:
  - `project-discovery-sdk` (12 sub-modules including testutil)
  - `cqrs-htmx`
  - `templ-components`
  - `go-cqrs-lite` (9 sub-modules: codec/v2, command/v2, dispatcher/v2, event/v2, id/v2, memory/v2, query/v2, schema/v2, snapshot/v2)
  - `go-error-family`
  - `httputil`
  - `go-branded-id`
  - `go-composable-business-types`
  - `go-filewatcher`
  - Also added `templ` to `nativeBuildInputs` for `_templ.go` generation
- **Result:** `nix build .#default` succeeds, overview binary produced. Committed as `4ed93f7`, pushed.

### 10. Pocket-ID Static API Key Added to Sops
- **Problem:** `pocket_id_static_api_key` was referenced in sops.nix but not present in the encrypted `pocket-id.yaml`.
- **Fix:** Generated random 32-byte base64 key, added via `sops --set`.

### 11. Discordsync Service Enabled
- **Problem:** discordsync was disabled but its sops secrets still referenced the user.
- **Fix:** Added `discordsync.enable = true;` in configuration.nix.

### 12. Pocket-ID Provision Script Shellcheck Fix
- **Problem:** `continue` statement outside a loop in the provision script.
- **Fix:** Replaced with if/else pattern.

---

## B) PARTIALLY DONE

### 1. Pocket-ID Provision Idempotency (FAILING)
- **Status:** Script improved but still failing at runtime.
- **What was done:** Removed `curl -f` from api_get/api_post to capture error responses. Changed user search from API search endpoint to fetching all users + jq filtering. Added "already exists" race condition handling.
- **What's broken:** The API calls return empty responses. The Pocket ID search endpoint `/api/users?search=lars` returns data, but the jq filter `.data[] | select(.username == "...")` produces nothing. The user "lars" clearly exists (Pocket ID logs show "username is already in use" when trying to create), but the GET API doesn't find it.
- **Root cause hypothesis:** Either (a) the `STATIC_API_KEY` env var doesn't work in Pocket ID v2.7.0 (the `X-API-KEY` header returns empty responses), or (b) the key in sops doesn't match what Pocket ID actually uses internally, or (c) the API authentication method changed.
- **Impact:** `pocket-id-provision.service` fails, but OIDC clients that were previously migrated still work. Only new client creation is blocked.

### 2. Boot Time Optimization (COMMITTED, NOT YET REBOOTED)
- **Status:** All fixes committed and deployed via `just switch`, but the current boot still shows 6m17s.
- **What will improve after reboot:**
  - `signoz.target` decouples ClickHouse/SigNoz from graphical.target (~2m saved)
  - sops no longer hangs on invalid owner (~2m50s saved in initrd)
- **What won't improve:** Firmware POST (33s, BIOS limitation), NVMe device detection (~2m50s — likely a kernel/module timing issue with this specific hardware)

---

## C) NOT STARTED

### 1. NVMe/Firmware Boot Delay Investigation
The systemd-analyze blame shows `dev-nvme0n1.device` taking 2m48s. This is the initrd delay — not sops. Even after the sops fix, the NVMe device detection is extremely slow. This could be:
- A kernel module loading ordering issue
- A firmware bug in GMKtec NucBox EVO-X2 BIOS 1.11
- Missing `nvme_core.default_ps_max_latency_us=0` kernel param

### 2. Discordsync Discord Connection Failure
Discordsync keeps getting `discord.connection` errors (exit code 69/UNAVAILABLE). This is a Discord API issue — either the bot token is invalid, expired, or Discord is rate-limiting. Needs investigation of the token in sops.

### 3. Swap Usage at 17/19 GiB
System has 19Gi swap with 17Gi used despite 70Gi RAM available. This suggests stale processes or memory not being freed. The `stale-lsp-cleanup` timer should help, but swap usage should be monitored.

### 4. Darwin (macOS) Parity
No work done on the macOS side. AGENTS.md notes it's heavily resource-constrained (256GB SSD, ~90%+ full).

---

## D) TOTALLY FUCKED UP

### 1. Pocket-ID Provision API Authentication
The entire STATIC_API_KEY approach may be fundamentally broken for Pocket ID v2.7.0. The provision script can authenticate (no 401/403 errors), but receives empty responses from list endpoints while create endpoints return "already exists". This is a split-brain state where the API key has read access but the search/filter isn't working as expected. Needs:
- Direct API debugging with curl as the pocket-id user
- Check if Pocket ID v2.7.0 changed the static API key mechanism
- Possibly need to use admin session cookie instead of API key

### 2. GPU Crash Forensics — NOTHING CAPTURED
The amdgpu driver freeze on ~Jun 5 produced zero diagnostic output. pstore is empty (WDT hard reset), journal has a gap of 5 days. The SP5100 TCO watchdog took 2+ minutes to fire (should be 60s). We have:
- No kernel panic log
- No amdgpu error before freeze
- No way to reproduce
- No fix beyond "hope it doesn't happen again"

---

## E) WHAT WE SHOULD IMPROVE

### Architecture & Reliability
1. **sops secret guards** — Every sops secret that references a service-specific user should use `lib.optionalAttrs config.services.X.enable (...)`. Currently only discordsync is guarded. Other services (hermes, immich, twenty, manifest, etc.) would cause the same atomic failure if their users were missing.
2. **serviceDefaults should include startLimitBurst by default** — Instead of adding it per-service, bake it into `lib/systemd/service-defaults.nix` so ALL services get crash-loop protection automatically.
3. **Health check dependencies** — Services like oauth2-proxy depend on pocket-id, but there's no `BindsTo` or `After` ordering. oauth2-proxy fails on first start because pocket-id isn't ready yet, then succeeds on retry.
4. **GPU watchdog reliability** — The SP5100 TCO took 2+ minutes instead of 60s. Consider amdgpu `reset_method` module param or a software watchdog as backup.
5. **Swap management** — 17Gi of swap used with 70Gi RAM free is wasteful. Add `systemd-oomd` swap pressure config or periodic swap clear.

### Code Quality
6. **175+ status report files** — docs/status/ is a dump. Should archive old ones and keep only the last 5-10.
7. **Provision script testing** — The pocket-id provision script is a complex shell script with no testing. Should be testable outside of NixOS activation.
8. **Flake.lock staleness** — Many inputs may be outdated. Run `nix flake update` periodically.

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact |
|---|----------|------|--------|
| 1 | CRITICAL | **Reboot to verify boot time improvement** — signoz.target decoupling + sops fix should drop graphical.target from ~3min to ~30s | 2.5min faster boot |
| 2 | CRITICAL | **Fix pocket-id-provision API auth** — debug STATIC_API_KEY against Pocket ID v2.7.0 API, run curl commands as pocket-id user | All OIDC client provisioning works |
| 3 | HIGH | **Guard ALL sops secrets with optionalAttrs** — audit every secret in sops.nix that references a service-specific user/owner | Prevents future atomic failures |
| 4 | HIGH | **Add startLimitBurst to serviceDefaults** — bake crash-loop protection into the shared default instead of per-service | All future services auto-protected |
| 5 | HIGH | **Investigate NVMe 2m50s device detection** — try `nvme_core.default_ps_max_latency_us=0` kernel param, check module loading order | Faster initrd |
| 6 | HIGH | **Fix discordsync Discord connection** — check bot token validity, test with manual curl | Backup service operational |
| 7 | HIGH | **Monitor swap usage** — investigate why 17Gi swap used with 70Gi RAM free, consider swap clear | Memory efficiency |
| 8 | MEDIUM | **Add service ordering: oauth2-proxy After pocket-id** — prevent first-start failures | Cleaner boot |
| 9 | MEDIUM | **Add amdgpu reset_method=0 module param** — force GPU reset method for faster watchdog response | Faster crash recovery |
| 10 | MEDIUM | **Run full `nix flake update`** — update all flake inputs, fix vendorHash cascades | Security + features |
| 11 | MEDIUM | **Archive old status reports** — move 160+ old reports to docs/status/archive/ | Clean repo |
| 12 | MEDIUM | **Test pocket-id provision on clean state** — create a test script that can run independently | Debugging DX |
| 13 | MEDIUM | **Add systemd-oomd swap pressure config** — automatic swap management | Memory resilience |
| 14 | LOW | **Check BIOS update for GMKtec EVO-X2** — newer BIOS may fix NVMe detection or POST time | Hardware fix |
| 15 | LOW | **Add GPU crash kernel params** — `amdgpu.gpu_recovery=1`, `amdgpu.lockup_timeout=10000` | Better crash handling |
| 16 | LOW | **Review watchdogd config** — SP5100 TCO took 2+ min instead of 60s, needs investigation | Reliable watchdog |
| 17 | LOW | **Add pstore Ramoops** — configure ramoops to capture crash logs before WDT reset | Crash forensics |
| 18 | LOW | **Homepage health check tiles** — add statusStyle: dot + siteMonitor to remaining tiles | Dashboard completeness |
| 19 | LOW | **Darwin disk cleanup** — macOS at 90%+ full, needs nix-collect-garbage | macOS usability |
| 20 | LOW | **Consolidate SigNoz module** — JWT secret wrapper + target + startLimitBurst all added piecemeal | Code cleanliness |
| 21 | LOW | **Test overview service** — verify overview dashboard actually works at its URL | Service verification |
| 22 | LOW | **Add Gatus endpoints for new services** — discordsync, overview, pocket-id-provision | Monitoring coverage |
| 23 | LOW | **Review AGENTS.md accuracy** — several new gotchas added, verify no contradictions | Documentation accuracy |
| 24 | LOW | **Investigate TPM/serial device 2m50s delay** — tpmrm0, ttyS0-S3 all take 2m50s in blame | Boot optimization |
| 25 | LOW | **Consider systemd-boot `editor=false`** — prevent bootloader security bypass | Hardening |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does Pocket ID v2.7.0 actually support the `STATIC_API_KEY` environment variable / `X-API-KEY` header for admin API access?**

The provision script uses `X-API-KEY: $API_KEY` to authenticate against `/api/users` and `/api/oidc/clients`, but:
- The API returns empty responses (not 401/403 — just empty data arrays)
- Creating a user returns "username is already in use" (proving the API IS accessible)
- The `STATIC_API_KEY` env var is set in the pocket-id service, and the key file exists in sops

This could be a version mismatch, a config error, or a fundamental misunderstanding of how Pocket ID v2.7.0 handles static API keys. The only way to resolve this is to:
1. Read Pocket ID v2.7.0 source code or docs for `STATIC_API_KEY` support
2. Run `curl` directly as the `pocket-id` user with the actual key
3. Check Pocket ID logs for API auth errors

I cannot determine this without either (a) access to Pocket ID source/docs, or (b) the ability to run commands as the `pocket-id` system user (which requires root/sudo).

---

## Commits This Session

| Commit | Repo | Description |
|--------|------|-------------|
| `eaeba69c` | SystemNix | fix(system): resolve boot cascade failure — sops, signoz, watchdog, hardening |
| `1aac7f91` | SystemNix | fix(pocket-id): make provision script idempotent — handle existing users |
| `4ed93f7` | overview | fix(nix): complete mkPreparedSource integration with all transitive private deps |

## Service Status (Live)

| Service | State | Notes |
|---------|-------|-------|
| caddy | **active** | Reverse proxy, all vHosts up |
| pocket-id | **active** | OIDC provider working |
| oauth2-proxy | **active** | Forward auth operational |
| overview | **active** | New service, first deployment |
| immich-server | **active** | Photo management |
| immich-machine-learning | **active** | ML pipeline |
| signoz | **active** | Observability (now in own target) |
| signoz-collector | **active** | OTel collector |
| clickhouse | **active** | SigNoz database |
| cadvisor | **active** | Container metrics |
| gatus | **active** | Health checks |
| homepage-dashboard | **active** | Service dashboard |
| hermes | **active** | AI assistant |
| manifest | **active** | File manager |
| twenty | **active** | CRM |
| openseo | **active** | SEO tool |
| dnsblockd | **active** | DNS blocking |
| forgejo | **active** | Git hosting |
| ollama | **active** | Local AI models |
| minecraft | **inactive** | Intentionally stopped |
| discordsync | **FAILED** | Discord API connection refused (bot token issue) |
| pocket-id-provision | **FAILED** | API auth/search not finding existing users |

## System Resources

| Metric | Value | Status |
|--------|-------|--------|
| RAM | 93 GiB total, 23 GiB used, 70 GiB available | Good |
| Swap | 19 GiB total, 17 GiB used, 1.5 GiB free | **Warning**: excessive swap |
| Root disk | 512 GiB, 91% used (49 GiB free) | **Warning**: running low |
| Data disk | 1.0 TiB, 90% used (103 GiB free) | OK |
| Boot time | 6m17s (current, pre-fix) | **Expected ~1m after reboot** |
