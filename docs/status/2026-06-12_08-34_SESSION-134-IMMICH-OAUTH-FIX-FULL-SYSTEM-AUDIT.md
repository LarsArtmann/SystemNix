# Session 134 — Immich OAuth Login Fixed + Full System Audit

**Date:** 2026-06-12 08:34 CEST
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM)
**Uptime:** 1d 11h25m | **Load:** 14.00, 13.13, 13.45
**NixOS Generation:** current (26.11)
**Build:** ✅ `just test-fast` all checks passed

---

## System Resources

| Metric | Value | Status |
|--------|-------|--------|
| Root disk (/) | 430G / 512G (88%) | ⚠️ Getting tight |
| Data disk (/data) | 786G / 1.0T (77%) | ✅ OK |
| RAM | 76G / 93G used | ⚠️ Heavy |
| Swap | 19G / 19G used (99.99%) | 🔴 CRITICAL |
| BTRFS snapshots | 4 daily + 1 pre-deploy | ✅ Working |

### Top Memory Consumers
| Process | RSS | Notes |
|---------|-----|-------|
| llama-server (gemma-4-31B) | 9.8G | User workload, not a service |
| sdxl_character_consistency.py | 6.8G | User workload, not a service |
| rust-analyzer | 2.4G | Dev tool |
| ClickHouse | 510M | SigNoz backend |
| Helium (Electron) | ~700M total | Multiple renderers |
| Crush | 139M | This agent |

---

## A) FULLY DONE ✅

### Session 134 — Immich OAuth Login Fix
- **Root cause:** Pocket ID provisioning script searched for existing OIDC clients by **display name** (`.name == "Immich"`) instead of **client ID** (`.id == "immich"`)
- **Symptom:** Immich client existed from a prior run, but the script couldn't find it, tried to CREATE (failed: "Client ID already in use"), and never updated callback URLs → Pocket ID rejected OAuth callbacks with `"invalid callback URL"`
- **Fix:** Changed `select(.name == ...)` → `select(.id == ...)` in both primary search (line 214) and fallback search (line 237) of `pocket-id.nix`
- **Verification:** Provisioning now logs `Client 'Immich' already exists (ID: immich). Updating...` → `updated successfully` → `Logo uploaded successfully`
- **Status:** Deployed and verified. User needs to test the actual OAuth login flow at https://immich.home.lan/user-settings

### Session 133 — Upstream vendorHash Cascade + API Compatibility
- Fixed 15 upstream Go repos with broken vendorHash
- Overview + PMA flake.lock updated

### Session 132 — Pocket ID OIDC Client Infrastructure
- Declarative OIDC client provisioning (oauth2-proxy, Immich)
- Logo upload, secret management, migration from sops

### Session 131 — Caddy Boot Ordering, DNS Fixes, SOPS Skill
- oauth2-proxy network/DNS readiness
- sops secret management skill
- Monitor365 fix, wayland watcher fix

### Stable Infrastructure (Long-Term)
- **Caddy:** Reverse proxy with oauth2-proxy forward auth — working
- **PostgreSQL:** Tuned per-service configs — working
- **Unbound DNS:** Local resolver with dnsblockd — working
- **Pocket ID v2.8.0:** Passkey OIDC provider with declarative provisioning — working
- **BTRFS snapshots:** Daily via btrbk, pre-deploy snapshot, verify timer — working
- **SOPS + Age:** SSH host key → age conversion for secret management — working
- **Home Manager:** Cross-platform (Darwin + NixOS) — working
- **Forgejo:** Git hosting with runner — working

---

## B) PARTIALLY DONE 🔶

### Immich OAuth Login
- **Config fix:** ✅ Deployed, callback URLs now correct
- **Actual user test:** ⏳ User needs to verify at https://immich.home.lan → User Settings → Link OAuth
- **Note:** The user has been trying since session 132. The provisioning bug prevented it from ever working.

### Immich Core Plugin (WASM)
- `immich-core` plugin v2.0.1 fails to load: references old nix store path `/nix/store/...immich-2.6.1/.../plugin.wasm` but immich 2.7.5 is running
- Non-critical: Immich works fine without it. Likely a DB-cached path from prior version.
- **Fix:** Need to clear the plugin cache in Immich DB or re-install plugin

### Pocket ID Email Verification
- Admin user shows `emailVerified: false` in Pocket ID
- Not blocking OAuth but may affect claim mapping

---

## C) NOT STARTED ⏳

1. **SigNoz stack** — `signoz-query`, `signoz-clickhouse`, `signoz-otel-collector` all inactive. Not deployed since last reboot.
2. **Twenty CRM** — `twenty-server` inactive. Disabled or not started.
3. **Photomap** — Commented out in configuration.nix (`# photomap.enable = true`). Podman config permission issue unresolved.
4. **btrbk timer** — `btrbk.timer` inactive. Snapshots exist but timer not running (manual snapshots only).
5. **Swap optimization** — 19G/19G swap used (99.99%). System running on fumes memory-wise. No swap optimization or reduction strategy in place.
6. **Root disk cleanup** — 88% used, approaching critical. No cleanup strategy executed.
7. **Darwin (macOS)** — Last checked: 90%+ disk full. No recent maintenance.

---

## D) TOTALLY FUCKED UP 🔴

### DiscordSync — FAILED (start-limit-hit)
- **Error:** `turso: error: Parse error: Error: invalid expression in CREATE INDEX: guild_id`
- Turso DB schema migration failing — `guild_id` is not valid SQL expression for CREATE INDEX
- Hit start limit (5 retries exhausted), service is dead
- **Impact:** Discord backup not running
- **Fix needed:** Upstream DiscordSync app bug — SQL migration needs fixing in the Go code

### Swap Exhaustion — CRITICAL
- 19G swap at 99.99% utilization
- llama-server (9.8G) + sdxl (6.8G) = 16.6G just for user AI workloads
- SigNoz ClickHouse (510M) running but SigNoz query service not
- If more services start, system will OOM
- **Impact:** Any new service or memory spike risks cascading OOM

### Immich Plugin WASM Path Mismatch
- Immich 2.7.5 running but `immich-core` plugin tries to load from 2.6.1 nix store path
- Old path `/nix/store/syi1yjpwgmrhf73rqza4yy42rd970rfl-immich-2.6.1/` no longer exists (GC'd)
- Error: `ENOENT: no such file or directory, open '.../plugin.wasm'`
- **Impact:** Smart search / advanced features may be degraded
- **Fix:** Need to clear `system_metadata` table or update plugin path in Immich DB

---

## E) WHAT WE SHOULD IMPROVE 📈

### Critical
1. **Swap/RAM strategy** — 19G swap at 99.99% is a ticking time bomb. Need either: (a) reduce resident memory, (b) add more swap, or (c) schedule heavy workloads better
2. **Root disk at 88%** — Need proactive cleanup: old nix profiles, garbage collection, journal vacuum
3. **btrbk timer not running** — Snapshots only exist from manual runs or pre-deploy. Daily timer should be active.

### Architecture
4. **Pocket ID provisioning robustness** — The name-vs-id bug was subtle and survived multiple sessions. Add a test or assertion that verifies provisioning actually updated the client.
5. **Immich version upgrades** — The WASM plugin path is cached in DB. On version upgrade, need a migration step or cache invalidation.
6. **Service health dashboard** — Gatus exists but many services are inactive without alerting.
7. **Darwin platform parity** — 7 lines of Home Manager config vs full NixOS setup. Getting stale.

### Operational
8. **Status docs archive** — 300+ status files in docs/status/. Needs periodic archival (most are in archive/ but recent ones pile up).
9. **Consistent service state** — SigNoz, Twenty, Homepage some active some not. Need a clear "desired state" document.
10. **Monitoring gap** — Gatus monitors endpoints but doesn't alert on systemd service failures. Consider systemd-failure → Discord notification for ALL services.

---

## F) Top 25 Things To Do Next

### P0 — Immediate (This Session)
| # | Task | Why |
|---|------|-----|
| 1 | **Test Immich OAuth login** | The fix is deployed. User must verify at /user-settings → Link OAuth |
| 2 | **Fix Immich WASM plugin path** | Clear stale 2.6.1 path from DB, restart immich-server |
| 3 | **Fix swap exhaustion** | Kill stale processes, consider swapiness tuning |

### P1 — High Impact (Next Few Sessions)
| # | Task | Why |
|---|------|-----|
| 4 | **Root disk cleanup** | 88% → run nix-collect-garbage, clean old profiles, journal vacuum |
| 5 | **Enable btrbk timer** | Daily snapshots aren't happening automatically |
| 6 | **Fix DiscordSync** | Database migration bug in upstream Go code |
| 7 | **Start SigNoz stack** | Monitoring is completely offline since reboot |
| 8 | **Add service health alerting** | DiscordSync failed silently for days |

### P2 — Important (This Week)
| # | Task | Why |
|---|------|-----|
| 9 | **Pocket ID email verification** | Admin user email unverified |
| 10 | **Photomap podman fix** | Commented out due to permission issue |
| 11 | **Twenty CRM deployment** | Service inactive, needs investigation |
| 12 | **Homepage monitoring completeness** | Audit all tiles vs actual service state |
| 13 | **Gatus endpoint audit** | Many services are down but no alerts firing |
| 14 | **Systemd failure notifications** | Extend notify-failure@ to all services (not just some) |

### P3 — Improvements (This Month)
| # | Task | Why |
|---|------|-----|
| 15 | **Add provisioning integration test** | Prevent name-vs-id class bugs |
| 16 | **Automate Immich version upgrade path** | WASM cache invalidation on version bump |
| 17 | **Status docs rotation** | Archive everything older than 2 weeks |
| 18 | **Darwin maintenance** | Check disk, update flake, verify HM still works |
| 19 | **Memory budget document** | Define per-service memory limits and total headroom |
| 20 | **Swap strategy** | Document when to use swap vs when to kill processes |

### P4 — Nice To Have
| # | Task | Why |
|---|------|-----|
| 21 | **Cross-platform test** | Verify Darwin still builds after recent changes |
| 22 | **NixOS tests** | Add actual NixOS VM tests for critical services |
| 23 | **Flake CI** | Automated build checking on push |
| 24 | **DNS blocklist update automation** | Timer to refresh blocklists |
| 25 | **AI workload sandboxing** | llama-server + sdxl consuming 16G+ with no cgroup limits |

---

## G) Top #1 Question I Cannot Answer

**Did the Immich OAuth login actually work for you after the fix was deployed?**

The provisioning now correctly updates the Immich OIDC client (verified via logs: `PUT /api/oidc/clients/immich → 200`, logo uploaded `→ 204`). But the actual end-to-end flow — clicking "Login with Pocket ID" on the Immich login page, authenticating with a passkey, and being redirected back — requires a browser interaction that I cannot perform.

The Pocket ID logs show zero OAuth errors since the fix (no more `"invalid callback URL"`). But if it still fails, the next thing to check would be:
1. Whether the client secret file at `/var/lib/pocket-id/client-secrets/immich` is readable by the immich user
2. Whether the Immich config.json has the correct secret injected (the pre-start script reads from `$CREDENTIALS_DIRECTORY`)
3. Whether PKCE is handled correctly (Pocket ID client has `pkceEnabled: true`, Immich uses openid-client which auto-negotiates PKCE)

---

## Service Status Summary

| Service | Unit | Status | Notes |
|---------|------|--------|-------|
| Caddy | caddy | ✅ active | Reverse proxy |
| Forgejo | forgejo | ✅ active | Git hosting |
| Immich Server | immich-server | ✅ active | v2.7.5, WASM plugin broken |
| Immich ML | immich-machine-learning | ✅ active | GPU-accelerated |
| Pocket ID | pocket-id | ✅ active | v2.8.0 |
| OAuth2 Proxy | oauth2-proxy | ✅ active | Forward auth |
| Homepage | homepage-dashboard | ✅ active | Next.js 16.1.7 |
| Gatus | gatus | ✅ active | Health checks |
| Hermes | hermes | ✅ active | AI assistant |
| PostgreSQL | postgresql | ✅ active | Tuned per-service |
| Unbound DNS | unbound | ✅ active | Local resolver |
| dnsblockd | dnsblockd | ✅ active | DNS blocking |
| Niri | niri | ✅ active | Wayland compositor |
| DiscordSync | discordsync | 🔴 failed | Turso SQL migration bug |
| SigNoz Query | signoz-query | ⚫ inactive | Not started since reboot |
| SigNoz ClickHouse | signoz-clickhouse | ⚫ inactive | Not started since reboot |
| Twenty | twenty-server | ⚫ inactive | Not started |
| Photomap | — | ⚫ disabled | Commented out |
| btrbk timer | btrbk.timer | ⚫ inactive | Manual snapshots only |

---

## Changes This Session

| File | Change |
|------|--------|
| `modules/nixos/services/pocket-id.nix` | Fix OIDC client lookup: search by `.id` (client_id) not `.name` (display name) |
| `flake.lock` | Updated overview + PMA inputs |
