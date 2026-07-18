# SigNoz Impersonation Mode + Pocket ID SSO

**Date:** 2026-07-11 18:29
**Session scope:** Investigate SigNoz SSO options, implement passwordless auth via Pocket ID
**Status:** IMPLEMENTATION COMPLETE — bugs fixed, syntax verified, formatted, post-deploy check added

---

## What Was Done

### Research (COMPLETE)

1. **Confirmed ClickHouse is mandatory** — SigNoz's sole telemetry datastore. No pluggable backend exists. Cannot swap for PostgreSQL, InfluxDB, TimescaleDB, or anything else.
2. **Confirmed ClickHouse tuning options** — single-node already as light as possible (embedded Keeper, no ZooKeeper JVM). Could lower MemoryMax, shorten TTLs, disable log/trace ingestion.
3. **Confirmed SigNoz CE OIDC/SAML is Enterprise-only** — $4,000/month. Google OAuth2 is the only free SSO (v0.85.0+), hardcoded to Google, not repointable to Pocket ID.
4. **Investigated trusted-header auth** — DEAD END. SigNoz's `pkg/identn/` has three providers (tokenizer, apikey, impersonation). None read `X-Forwarded-User` or any proxy headers. Not an Enterprise feature either — it simply doesn't exist.
5. **Found impersonation mode** — Disables all internal auth; every request = root admin. Combined with Caddy forward-auth (Pocket ID), this becomes the sole auth boundary.

### Implementation (COMPLETE)

#### Change 1: SigNoz impersonation mode (`signoz.nix:316-340`)

Replaced the JWT secret wrapper with impersonation env vars. Root password is persisted to a file (generated once on first boot, reused on restart):

```
SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true
SIGNOZ_IDENTN_TOKENIZER_ENABLED=false
SIGNOZ_IDENTN_APIKEY_ENABLED=false
SIGNOZ_USER_ROOT_ENABLED=true
SIGNOZ_USER_ROOT_EMAIL="admin@${domain}"
SIGNOZ_USER_ROOT_ORG_NAME="default"
# Password persisted to ${dataDir}/root-password (generated once, reused)
SIGNOZ_USER_ROOT_PASSWORD="$(cat $ROOT_PW_FILE)"
```

#### Change 2: Caddy unconditional forward-auth (`caddy.nix:135-144`)

Replaced `protectedVHost "signoz"` (which had LAN bypass) with custom vHost applying `forwardAuth` to ALL requests:

```nix
"signoz.${domain}" = {
  extraConfig = ''
    ${tlsConfig}
    ${commonConfig}
    ${forwardAuth}
    reverse_proxy localhost:${toString config.services.signoz.settings.queryService.port}
  '';
};
```

#### Change 3: Homepage siteMonitor fixed (`homepage.nix:268`)

Changed `siteMonitor` from `svcUrl "signoz"` (external URL, now 302-redirects to Pocket ID) to `http://localhost:${port}` (bypasses Caddy, probes SigNoz directly).

#### Change 4: Post-deploy impersonation check (`post-deploy-check.sh`)

Added functional check that verifies impersonation mode is active via `curl localhost:8080/api/v1/global/config`. FAILs if impersonation is not enabled, preventing silent auth-less exposure after deploy.

#### Change 5: AGENTS.md updated

- New "Layer 2+" SSO tier in the architecture table
- SigNoz moved out of Layer 2 list, into Layer 2+
- New gotcha entry documenting impersonation mode
- Updated "Native OIDC != free" entry

---

## Bugs Found and Fixed

### BUG 1 (FIXED): Root password regenerated on every restart

**File:** `signoz.nix:328` → **Fixed in:** `signoz.nix:330-336`

Was: `export SIGNOZ_USER_ROOT_PASSWORD="$(openssl rand -base64 48)"` ran on every `ExecStart`, generating a new password each restart. The root user provisioning runs at startup only; on restart the password would differ from the provisioned one.

**Fix applied:** Password now persisted to `${dataDir}/root-password` — generated once on first boot, reused on every restart:

```bash
ROOT_PW_FILE="${cfg.settings.queryService.dataDir}/root-password"
if [ ! -f "$ROOT_PW_FILE" ]; then
  openssl rand -base64 48 > "$ROOT_PW_FILE"
  chmod 400 "$ROOT_PW_FILE"
fi
export SIGNOZ_USER_ROOT_PASSWORD="$(cat "$ROOT_PW_FILE")"
```

### BUG 2 (FIXED): Homepage siteMonitor would report SigNoz as DOWN

**File:** `homepage.nix:268`

Was: `siteMonitor = svcUrl "signoz"` pointed to `https://signoz.${domain}`, which now returns a 302 redirect to Pocket ID instead of 200 OK (unconditional forward-auth has no LAN bypass).

**Fix applied:** Changed to `siteMonitor = "http://localhost:${toString config.services.signoz.settings.queryService.port}"` — probes SigNoz directly, bypassing Caddy.

---

## What Is DONE

| Item                             | Status  | Notes                                                         |
| -------------------------------- | ------- | ------------------------------------------------------------- |
| Impersonation mode env vars      | DONE    | Root password persisted to file (BUG 1 fixed)                 |
| Caddy unconditional forward-auth | DONE    | No LAN bypass — all traffic through Pocket ID                 |
| Homepage siteMonitor             | DONE    | Points to localhost (BUG 2 fixed)                             |
| Post-deploy impersonation check  | DONE    | Added to `post-deploy-check.sh`                               |
| AGENTS.md documentation          | DONE    | Layer 2+ tier, gotcha entries updated                         |
| `nix fmt`                        | DONE    | All changed files formatted cleanly                           |
| Syntax validation                | PASSES  | Both `.nix` files parse via `nix-instantiate --parse`         |
| `nix flake check --no-build`     | BLOCKED | Pre-existing `snapshots.nix:98` syntax error (not our change) |

---

## What Was NOT STARTED

1. **`verify-deployment.sh` update** — Script uses hardcoded `localhost:8080` (works with impersonation) but doesn't verify impersonation mode is active
2. **Firewall hardening for localhost:8080** — With impersonation mode, ANY local process has full admin access to SigNoz on `localhost:8080` with zero auth. Previously needed a password. Should consider iptables/nftables rule restricting to Caddy + signoz-provision
3. **Defense-in-depth YAML config** — The impersonation settings are env vars only. If someone runs the binary directly (bypassing the wrapper), defaults apply (tokenizer=true, impersonation=false). Could set them in `signoz.yaml` too
4. **ClickHouse memory reduction** — Original question about making ClickHouse lighter was answered but not implemented. `MemoryMax=4G` unchanged
5. **Stale `/var/lib/signoz/jwt-secret` cleanup** — The old JWT secret file persists on disk, no longer used. Dead weight
6. **Stale `/var/lib/signoz/discord-webhook.url` in verify-deployment.sh** — Pre-existing bug: provisioning service doesn't create this file (reads from sops directly), but verify-deployment.sh checks for it (line 108). Always shows "missing" warning

---

## What We Should Improve

### Short-term (post-deploy)

1. Add Gatus alert for impersonation mode being disabled (regression detection)
2. Consider firewall rule restricting `localhost:8080` to Caddy + provisioning only
3. Set impersonation config in `signoz.yaml` as defense-in-depth
4. Clean up stale `/var/lib/signoz/jwt-secret` file
5. Fix pre-existing `snapshots.nix:98` syntax error (blocks `nix flake check`)
6. Fix pre-existing `verify-deployment.sh` hardcoded port 8080

### ClickHouse weight reduction (original concern, unaddressed)

7. Lower ClickHouse `MemoryMax` from 4G to 3G
8. Shorten traces/logs retention TTL to 3-7 days
9. Shorten metrics retention TTL to 15 days
10. Consider disabling log ingestion entirely if only metrics are needed
11. Consider disabling traces ingestion if not actively used
12. Review if journald receiver (logs to ClickHouse) is needed
13. Review ClickHouse merge tree settings for lower memory usage
14. Review if all 6 OTel scrape targets are necessary
15. Consider replacing cAdvisor with lighter alternative
16. Review if all 12 node-exporter collectors are needed
17. Consider reducing PSI metrics interval (15s → 60s)
18. Add monitoring for ClickHouse memory usage (Gatus/alert)
19. Add monitoring for ClickHouse disk usage
20. Review ClickHouse data directory BTRFS CoW impact

### Alternative observability stack evaluation

21. Prototype VictoriaMetrics + Grafana as SigNoz replacement (~1.5 GB vs 6.5 GB RAM)
22. Research VictoriaMetrics + Grafana native OIDC integration with Pocket ID
23. Benchmark VictoriaMetrics single-binary memory footprint on evo-x2
24. Evaluate Grafana Loki for log aggregation (lighter than ClickHouse for logs)
25. Evaluate Grafana Alloy as OTel collector replacement
26. Consider if Gatus + Discord alerts already covers the monitoring need
27. Review which SigNoz features are actively used (dashboards? alerts? trace exploration?)
28. Cost-benefit analysis: 6.5 GB RAM for SigNoz vs 1.5 GB for VM+Grafana stack

### Auth/SSO architecture improvements

29. Consider per-user audit logging at Caddy layer (SigNoz impersonation loses per-user audit)
30. Review oauth2-proxy session timeout settings for SigNoz
31. Consider adding rate limiting on `signoz.${domain}` vHost
32. Review Pocket ID session timeout for observability access
33. Document the security model: localhost = admin, external = Pocket ID
34. Consider if any other Layer 2 services would benefit from impersonation + unconditional forward-auth
35. Review if any automation/API scripts access SigNoz programmatically (they'd need to go through Pocket ID now or use localhost)
36. Consider adding a read-only API key for external tools that need metrics data (but apikey is disabled in impersonation mode)

### Monitoring stack improvements

37. Add BTRFS scrub status to Prometheus metrics + Gatus Discord alert
38. Review if the 18 SigNoz alert rules are all correct and firing properly
39. Add alert for SigNoz collector being down (separate from query service)
40. Review if ClickHouse Keeper is needed on single-node (it is, for replicated table DDL)
41. Add dashboard for oauth2-proxy health/metrics
42. Add dashboard for Pocket ID auth events
43. Review Caddy metrics pipeline completeness
44. Consider adding process-level monitoring (OOM score, FD count) for SigNoz services
45. Review if the signoz schema migrator needs updates after version bumps
46. Consider end-to-end test: Pocket ID login → SigNoz dashboard → query data → alert fires

---

## Top 2 Questions I Cannot Answer Myself

### Q1 (resolved by fix): Does SigNoz impersonation mode re-provision the root user on every startup, or only on first boot?

**Resolved by BUG 1 fix.** The root password is now persisted to a file and reused on every restart, so the re-provisioning question is moot — the password never changes after first boot. If re-provisioning attempts an UPDATE, it sets the same value. If it skips because the user exists, the file password matches the DB. Either path is safe.

### Q2: Is the 6.5 GB SigNoz footprint actually causing problems on evo-x2?

evo-x2 has 128 GB physical RAM (94 GB visible). The chronic memory pressure documented in AGENTS.md is from GPUActive consuming 51+ GB, NOT from SigNoz. If SigNoz's 6.5 GB is well within headroom, the entire ClickHouse weight question may be academic — the real memory problem is the GPU driver, not the observability stack. **Only Lars can say whether SigNoz is actually the bottleneck or just "feels heavy."**

---

## Files Changed This Session

| File                                  | Change                                                                                         |
| ------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `modules/nixos/services/signoz.nix`   | Impersonation mode env vars (header comment + ExecStart wrapper with persistent root password) |
| `modules/nixos/services/caddy.nix`    | SigNoz vHost: unconditional forward-auth, no LAN bypass (line 135-144)                         |
| `modules/nixos/services/homepage.nix` | siteMonitor changed to localhost:port (was external URL)                                       |
| `scripts/post-deploy-check.sh`        | Added SigNoz impersonation mode verification check                                             |
| `AGENTS.md`                           | Layer 2+ SSO tier, impersonation mode gotcha, updated OIDC entries                             |

## Files NOT Changed (Pre-existing Issues)

| File                                      | Issue                                                 |
| ----------------------------------------- | ----------------------------------------------------- |
| `scripts/verify-deployment.sh:101`        | Hardcoded port 8080 (pre-existing, works but fragile) |
| `platforms/nixos/system/snapshots.nix:98` | Pre-existing syntax error blocks `nix flake check`    |
