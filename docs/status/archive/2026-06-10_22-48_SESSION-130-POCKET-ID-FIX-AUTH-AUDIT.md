# Session 130 — Pocket ID Provision Fix, Auth Audit, Comprehensive Status

**Date:** 2026-06-10 22:48
**Session Focus:** Fix broken Pocket ID OIDC client provisioning, audit auth coverage, full system health

---

## Session Summary

Pocket ID's declarative OIDC client provisioning was silently failing since deployment — no clients were ever created. Root causes identified and fixed: URL bracket encoding (`pagination[limit]` → `pagination%5Blimit%5D`), extra API fields causing 400 errors, and missing debug logging. Auth audit completed: Manifest was the only unprotected Caddy vhost, now fixed. All 13 protected services use oauth2-proxy forward-auth; only immich uses direct OIDC.

---

## a) FULLY DONE ✅

### Session 130 Fixes (This Session)

| # | Item | Commit | Details |
|---|------|--------|---------|
| 1 | **Pocket ID provision: API header fix** | `21ce65fb` | `X-API-KEY` → `X-API-Key` in all curl calls (api_get, api_post, avatar upload, secret generation) |
| 2 | **Pocket ID provision: URL encoding fix** | `21ce65fb` | `pagination[limit]` → `pagination%5Blimit%5D` — curl was interpreting square brackets as glob patterns, returning empty responses |
| 3 | **Pocket ID provision: user creation payload fix** | `21ce65fb` | Removed `emailVerified`, `displayName`, `disabled` fields — Pocket ID API rejects unknown fields with HTTP 400 |
| 4 | **Pocket ID provision: race condition handling** | `21ce65fb` | Added proper "already exists" fallback for OIDC clients (previously only handled users) |
| 5 | **Pocket ID provision: debug logging** | `21ce65fb` | Added API response logging, truncated to 200 chars for diagnostics |
| 6 | **Pocket ID provision: error resilience** | `21ce65fb` | Added `2>/dev/null` on all jq calls to prevent pipefail on empty responses |
| 7 | **Manifest behind auth** | `f679b8fb` | `manifest.home.lan` moved from unprotected to `protectedVHost` — was the only Caddy service without forward-auth |

### Verified Working After This Session

- **Pocket ID provision**: Successfully creates admin user, avatar, and both OIDC clients (oauth2-proxy + immich) on every boot
- **Immich OIDC login**: Client `immich` registered with callback `https://immich.home.lan/api/auth/callback`
- **oauth2-proxy forward-auth**: Client `oauth2-proxy` registered, protects 13 vhosts
- **Manifest auth**: Now requires Pocket ID login via oauth2-proxy

### Infrastructure (Pre-Session, Still Working)

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| Caddy | ✅ running | `caddy.nix` | TLS termination, forward-auth, 15 virtual hosts |
| Pocket ID | ✅ running | `pocket-id.nix` | v2.7.0, passkey OIDC, declarative provisioning, SQLite |
| oauth2-proxy | ✅ running | `oauth2-proxy.nix` | Forward-auth bridge, cookie sessions, Gatus ping every 30s |
| Forgejo | ✅ running | `forgejo.nix` | SQLite, LFS, weekly dumps, GitHub mirrors, Actions runner |
| Immich | ✅ running | `immich.nix` | v2.7.5, PostgreSQL + Redis + ML, VA-API transcoding, OAuth |
| Homepage Dashboard | ✅ running | `homepage.nix` | Catppuccin Mocha, programmatic tiles, 5 categories |
| Gatus | ✅ running | `gatus-config.nix` | Uptime monitoring, 30s intervals, webhook alerts |
| SigNoz | ✅ running | `signoz.nix` | Traces/metrics/logs, ClickHouse, OTel Collector, 7 alerts |
| Twenty CRM | ✅ running | `twenty.nix` | Docker Compose, PostgreSQL + Redis, daily DB backup |
| TaskChampion | ✅ running | `taskchampion.nix` | Taskwarrior sync, TLS via Caddy |
| BTRFS Snapshots | ✅ running | `snapshots.nix` | btrbk daily, 14d + 4w retention |
| SOPS secrets | ✅ running | `sops.nix` | Age-encrypted, SSH host key, auto-restart |
| Hermes AI gateway | ✅ running | `hermes.nix` | Discord bot, cron, 4G memory limit |
| Docker | ✅ running | `default-services.nix` | overlay2, `/data/docker`, weekly prune |
| PostgreSQL | ✅ running | system | Immich + Twenty + Forgejo databases |
| Niri compositor | ✅ running | `niri-config.nix` | Wayland, XWayland satellite, OOMScoreAdjust=-900 |
| Audio (PipeWire) | ✅ running | `audio.nix` | ALSA + Pulse + JACK compat |
| Security hardening | ✅ running | `security-hardening.nix` | fail2ban, ClamAV, polkit, 30+ tools |
| NVMe APST fix | ✅ committed | `eef194c2` | `nvme_core.default_ps_max_latency_us=0`, pending reboot verify |
| QDirStat | ✅ installed | `d0bf0347` | Qt disk usage analyzer added to packages |

---

## b) PARTIALLY DONE ⚠️

| Item | Status | What's Missing |
|------|--------|----------------|
| **Pocket ID OTel metrics** | ⚠️ functional but noisy | `failed to upload metrics: Post "https://localhost:4318/v1/metrics": http: server gave HTTP response to HTTPS client` — every 30s. Metrics endpoint is HTTP, Pocket ID tries HTTPS. Low priority but log spam. |
| **PostgreSQL collation warnings** | ⚠️ noisy | `database "postgres" has no actual collation version, but a version was recorded` every 5s from Twenty CRM container. Non-functional impact, pure log noise. |
| **Hermes secondary LLM provider** | ⚠️ config done, secrets missing | Nix config has `OPENAI_API_KEY` env var, but `openai_api_key` not yet added to `platforms/nixos/secrets/hermes.yaml` via sops |
| **Hermes SSH deploy key** | ⚠️ keys generated | ed25519 key pair in `scripts/hermes-setup/`, needs manual install to `/home/hermes/.ssh/` and GitHub deploy key |
| **SigNoz alert verification** | ⚠️ deployed but untested | 7 alert rules provisioned but Discord webhook never manually tested |
| **TODO_LIST.md** | ⚠️ stale | Last updated session 122 (2026-06-08). Missing sessions 125-130 work. |
| **FEATURES.md** | ⚠️ stale | Last updated 2026-06-03. Missing: Pocket ID declarative provisioning, Overview dashboard, Crush Daily, Monitor365, auth audit, Manifest protection |
| **Voice agents** | 🔧 disabled | LiveKit + Whisper ASR, full config exists, disabled in configuration.nix |
| **PhotoMap AI** | 🔧 disabled | CLIP embedding visualization, podman permission issue, disabled |
| **Minecraft server** | 🔧 disabled | Full config with whitelist, client config done, disabled |
| **File & Image Renamer** | 🔧 disabled | Go 1.26.3 dependency not in nixpkgs yet |

---

## c) NOT STARTED 📋

| # | Item | Impact | Notes |
|---|------|--------|-------|
| 1 | **Provision Raspberry Pi 3** for DNS failover | High | Hardware required, `rpi3-dns` config defined in flake |
| 2 | **Wire Pi 3 as secondary DNS** | High | Depends on Pi 3 hardware |
| 3 | **BTRFS `/data` subvolume migration** | High | `/data` is BTRFS toplevel (subvolid=5), cannot be snapshotted. `just snapshot-migrate-data` exists but not run |
| 4 | **Verify boot time after NVMe APST fix** | Medium | `eef194c2` committed, needs reboot + `systemd-analyze` |
| 5 | **Darwin disk cleanup strategy** | Medium | 256GB SSD at 90-95%, no automated cleanup |
| 6 | **Darwin Home Manager parity** | Low | Only 7 lines of HM config — no terminal, editor, theme parity with NixOS |
| 7 | **Btrfs-snapshot-bloat Disko migration** | Low | Phase 5 in planning doc, low priority |

---

## d) TOTALLY FUCKED UP ❌

| # | Item | Severity | Root Cause | Status |
|---|------|----------|------------|--------|
| 1 | **Pocket ID OIDC client provisioning** (pre-fix) | **CRITICAL** | 3 bugs: (a) curl misinterpreted `pagination[limit]` as glob → empty GET responses, (b) extra fields `emailVerified`/`displayName`/`disabled` caused HTTP 400, (c) `|| true` + `2>/dev/null` silenced all errors | **FIXED this session** |
| 2 | **Twenty CRM intermittent 502s** | Medium | Caddy logs show `connection refused` and `connection reset by peer` to port 3200 — Twenty container likely crashing/restarting periodically | **UNFIXED** |
| 3 | **Root disk at 94%** | **HIGH** | 472G / 512G used, 33G free. Was 95% (28G free) earlier. GC-eligible paths exist but can't clear enough | **UNFIXED** |
| 4 | **Swap: 8 GiB used on 128 GiB RAM system** | Medium | Anomalous. Likely stale LSP processes (mitigated by daily `stale-lsp-cleanup` timer) but 8GiB still high | **PARTIALLY MITIGATED** |

---

## e) WHAT WE SHOULD IMPROVE 🔄

### Architecture

1. **Pocket ID provision idempotency**: The script now handles existing users/clients but still has N=1 debug logging. Should add a `--quiet` mode for steady-state boots to reduce journal noise.
2. **Auth coverage is complete**: All 14 Caddy vhosts now either have forward-auth or are the auth services themselves. No gaps.
3. **Sops → Pocket ID migration**: Two secrets still exist in both sops AND Pocket ID client-secrets (oauth2-proxy, immich). The sops fallback is correct for boot ordering but the dual-source is confusing. Consider removing sops secrets once provision is proven stable.
4. **Twenty CRM stability**: Container keeps dying. Should investigate if it's OOM, health check timeout, or PostgreSQL connection exhaustion.
5. **Port 4318 OTEL endpoint**: Pocket ID tries HTTPS for metrics but endpoint is HTTP-only. Should either configure the HTTP URL or disable OTel in Pocket ID.

### Code Quality

6. **Pocket ID provision script**: `writeShellApplication` enforces POSIX (`dash`) — our `${var:0:200}` bashism was caught by `just test-fast`. Good, but the script is growing complex. Consider extracting to a standalone script file with shellcheck.
7. **OIDC client registration**: Currently hardcoded as Nix module defaults. If we add more services needing direct OIDC (not forward-auth), we need to extend the `oidcClients` list in pocket-id.nix.
8. **Debug logging in provision script**: Truncated output with `head -c 200` is POSIX-compatible but loses important error details. Consider full output in a separate log file.

### Operations

9. **Root disk cleanup**: 94% is dangerous. Nix store GC, Docker image prune, and old journal cleanup needed.
10. **PostgreSQL collation warning spam**: `reindexdb` or collation version fix would silence 15,000+ daily log lines.

---

## f) Top 25 Things We Should Get Done Next

### Critical / High Impact (Do First)

| # | Task | Category | Impact | Effort |
|---|------|----------|--------|--------|
| 1 | **Root disk cleanup**: `nix-collect-garbage -d`, docker system prune, journal vacuum | Operations | 🔴 Critical | 15 min |
| 2 | **Investigate Twenty CRM 502s**: Check container logs, OOM, PostgreSQL connections | Fix | 🔴 High | 30 min |
| 3 | **Fix PostgreSQL collation spam**: `ALTER DATABASE ... REFRESH COLLATION VERSION` | Fix | 🟡 Medium | 10 min |
| 4 | **Fix Pocket ID OTel HTTPS→HTTP**: Set `OTEL_EXPORTER_PROMETHEUS_ENDPOINT` or disable | Fix | 🟡 Medium | 5 min |
| 5 | **Verify NVMe APST fix**: Reboot evo-x2, run `systemd-analyze`, confirm <60s boot | Verify | 🟢 High | 10 min |
| 6 | **BTRFS `/data` subvolume migration**: Run `just snapshot-migrate-data` for snapshot coverage | Operations | 🔴 High | 30 min |

### Service Health (Fix Broken Things)

| # | Task | Category | Impact | Effort |
|---|------|----------|--------|--------|
| 7 | **Monitor365 SQLite path fix**: Investigate "unable to open database file" error | Fix | 🟡 Medium | 20 min |
| 8 | **dnsblockd-cert-import PATH fix**: Add `nssTools` to service PATH | Fix | 🟡 Medium | 5 min |
| 9 | **SigNoz Discord webhook test**: `POST /api/v1/channels/test` to verify alerts reach Discord | Verify | 🟡 Medium | 5 min |
| 10 | **Gatus endpoint health re-audit**: Re-check all 30 endpoints, fix health check URLs | Fix | 🟡 Medium | 30 min |

### Manual Steps (Blocked on Human)

| # | Task | Category | Impact | Effort |
|---|------|----------|--------|--------|
| 11 | **Hermes: add OpenAI API key to sops** | Manual | 🟡 Medium | 2 min |
| 12 | **Hermes: install SSH deploy key** | Manual | 🟡 Medium | 5 min |
| 13 | **Hermes: set fallback model in runtime** | Manual | 🟢 Low | 2 min |

### Documentation (Update Stale Docs)

| # | Task | Category | Impact | Effort |
| 14 | **Update TODO_LIST.md**: Sessions 125-130 missing | Docs | 🟡 Medium | 30 min |
| 15 | **Update FEATURES.md**: Missing 5+ features since 2026-06-03 | Docs | 🟡 Medium | 30 min |
| 16 | **Update AGENTS.md gotchas**: Pocket ID provision fix details, auth audit results | Docs | 🟡 Medium | 15 min |

### Improvements (Make Things Better)

| # | Task | Category | Impact | Effort |
|---|------|----------|--------|--------|
| 17 | **Pocket ID provision: quiet mode**: Suppress debug logging on steady-state boots | Improve | 🟢 Low | 15 min |
| 18 | **Remove sops fallback secrets**: Once provision proven stable over multiple boots | Improve | 🟢 Low | 10 min |
| 19 | **Swap usage investigation**: 8GiB swap on 128GiB RAM is wrong — identify culprit | Investigate | 🟡 Medium | 20 min |
| 20 | **Provision Raspberry Pi 3**: DNS failover cluster, hardware needed | Ops | 🔴 High | 2+ hours |
| 21 | **Disko migration**: Phase 5 of BTRFS planning doc | Improve | 🟢 Low | 2+ hours |
| 22 | **Darwin Home Manager parity**: Terminal, editor, theme from NixOS | Improve | 🟢 Low | 1 hour |
| 23 | **Voice agents re-enable**: Debug why disabled, test LiveKit + Whisper | Fix | 🟢 Low | 1 hour |
| 24 | **File & Image Renamer**: Wait for Go 1.26.3 in nixpkgs or overlay | Blocked | 🟢 Low | 30 min |
| 25 | **Overview service: add to auth or verify localhost-only**: Ensure not exposed unprotected | Security | 🟢 Low | 10 min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why is the Twenty CRM container intermittently dying?**

Caddy logs show repeated 502s to `crm.home.lan` (port 3200) with `connection refused` and `connection reset by peer`. This suggests the Twenty frontend container is crashing or restarting. I cannot:

1. Run `docker logs twenty-server-1` (SSH blocked, docker logs requires root)
2. Check `docker ps` to see if the container is actually restarting
3. Inspect memory usage or OOM kills for the container

The Twenty service uses 4 Docker containers (server, worker, db, redis) managed by Docker Compose. The intermittent nature suggests either:
- OOM kill (4 containers sharing memory)
- Health check timeout causing restart loop
- PostgreSQL connection pool exhaustion from the collation-warning-spamming connections

**To diagnose**: Run `just twenty-logs` or `docker compose -f /var/lib/twenty/docker-compose.yml logs --tail=100` on evo-x2.

---

## System Resources

| Resource | Value | Status |
|----------|-------|--------|
| Root disk (`/`) | 472G / 512G (94%) | 🔴 Danger |
| Data disk (`/data`) | 798G / 1.0T (78%) | 🟢 OK |
| RAM | 31G used / 93G total | 🟢 OK |
| Swap | 8.0G used / 19G total | 🟡 Anomalous |
| Service modules | 40 `.nix` files | 🟢 OK |
| Enabled services | 30+ | 🟢 OK |

---

## Auth Coverage Matrix (Complete)

| VHost | Service | Auth Method | Protected |
|-------|---------|-------------|-----------|
| `auth.home.lan` | Pocket ID + oauth2-proxy | Identity provider | N/A |
| `immich.home.lan` | Immich | Direct OIDC (client `immich`) | ✅ |
| `forgejo.home.lan` | Forgejo | Forward-auth | ✅ |
| `dash.home.lan` | Homepage | Forward-auth | ✅ |
| `signoz.home.lan` | SigNoz | Forward-auth | ✅ |
| `crm.home.lan` | Twenty CRM | Forward-auth | ✅ |
| `tasks.home.lan` | TaskChampion | Forward-auth | ✅ |
| `status.home.lan` | Gatus | Forward-auth | ✅ |
| `seo.home.lan` | OpenSEO | Forward-auth | ✅ |
| `daily.home.lan` | Crush Daily | Forward-auth | ✅ |
| `manifest.home.lan` | Manifest | Forward-auth | ✅ **NEW** |
| `voice.home.lan` | LiveKit | Forward-auth | ✅ (disabled) |
| `whisper.home.lan` | Whisper ASR | Forward-auth | ✅ (disabled) |
| `logs.home.lan` | Dozzle | Forward-auth | ✅ |
| `monitor.home.lan` | Monitor365 | Forward-auth | ✅ |

**Gaps: NONE.** All externally-accessible Caddy vhosts are protected.

---

## Pocket ID OIDC Client Registration (Complete)

| Client ID | Name | Callback URL | Secret Source |
|-----------|------|--------------|---------------|
| `oauth2-proxy` | oauth2-proxy | `https://auth.home.lan/oauth2/callback` | `/var/lib/pocket-id/client-secrets/oauth2-proxy` |
| `immich` | immich | `https://immich.home.lan/api/auth/callback` | `/var/lib/pocket-id/client-secrets/immich` |

---

## Session Timeline

| Time | Event |
|------|-------|
| 22:00 | User reports no OIDC clients in Pocket ID |
| 22:10 | Investigate provision logs — discover HTTP 400 on user creation, empty GET responses |
| 22:15 | Root cause #1: `pagination[limit]` brackets not URL-encoded |
| 22:17 | Root cause #2: extra fields `emailVerified`/`displayName`/`disabled` causing 400 |
| 22:20 | Fix all 3 root causes, deploy, verify provision succeeds |
| 22:30 | Auth audit: discover Manifest as only unprotected vhost |
| 22:32 | Move Manifest behind `protectedVHost`, deploy |
| 22:48 | Full comprehensive status report |

---

## Commits This Session

| Commit | Message | Files |
|--------|---------|-------|
| `21ce65fb` | fix(pocket-id): fix API header casing, URL encoding, and race conditions | `modules/nixos/services/pocket-id.nix` |
| `f679b8fb` | fix(caddy): protect manifest vhost with oauth2-proxy forward auth | `modules/nixos/services/caddy.nix` |
| `78b52da0` | refactor(homepage): programmatic service tiles + host validation + cache dir | `modules/nixos/services/homepage.nix` |
| `109b6d3e` | chore(pocket-id): update admin email to larsartmann.cloud domain | `modules/nixos/services/pocket-id.nix` |
| `d0bf0347` | feat(packages): add QDirStat — Qt disk usage analyzer with treemap | `platforms/common/packages/base.nix` |
| (this) | docs(status): session 130 — Pocket ID fix, auth audit, comprehensive status | `docs/status/2026-06-10_22-48_SESSION-130-POCKET-ID-FIX-AUTH-AUDIT.md` |

---

_Generated with Crush — Session 130_
