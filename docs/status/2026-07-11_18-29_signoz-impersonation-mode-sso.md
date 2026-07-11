# SigNoz Impersonation Mode + Pocket ID SSO

**Date:** 2026-07-11 18:29
**Session scope:** Investigate SigNoz SSO options, implement passwordless auth via Pocket ID
**Status:** PARTIALLY DONE — working concept with TWO CRITICAL BUGS in implementation

---

## What Was Done

### Research (COMPLETE)

1. **Confirmed ClickHouse is mandatory** — SigNoz's sole telemetry datastore. No pluggable backend exists. Cannot swap for PostgreSQL, InfluxDB, TimescaleDB, or anything else.
2. **Confirmed ClickHouse tuning options** — single-node already as light as possible (embedded Keeper, no ZooKeeper JVM). Could lower MemoryMax, shorten TTLs, disable log/trace ingestion.
3. **Confirmed SigNoz CE OIDC/SAML is Enterprise-only** — $4,000/month. Google OAuth2 is the only free SSO (v0.85.0+), hardcoded to Google, not repointable to Pocket ID.
4. **Investigated trusted-header auth** — DEAD END. SigNoz's `pkg/identn/` has three providers (tokenizer, apikey, impersonation). None read `X-Forwarded-User` or any proxy headers. Not an Enterprise feature either — it simply doesn't exist.
5. **Found impersonation mode** — Disables all internal auth; every request = root admin. Combined with Caddy forward-auth (Pocket ID), this becomes the sole auth boundary.

### Implementation (PARTIALLY DONE — HAS BUGS)

#### Change 1: SigNoz impersonation mode (`signoz.nix:316-333`)

Replaced the JWT secret wrapper with impersonation env vars:
```
SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true
SIGNOZ_IDENTN_TOKENIZER_ENABLED=false
SIGNOZ_IDENTN_APIKEY_ENABLED=false
SIGNOZ_USER_ROOT_ENABLED=true
SIGNOZ_USER_ROOT_EMAIL="admin@${domain}"
SIGNOZ_USER_ROOT_PASSWORD="$(openssl rand -base64 48)"
SIGNOZ_USER_ROOT_ORG_NAME="default"
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

#### Change 3: AGENTS.md updated

- New "Layer 2+" SSO tier in the architecture table
- SigNoz moved out of Layer 2 list, into Layer 2+
- New gotcha entry documenting impersonation mode
- Updated "Native OIDC != free" entry

---

## What Is FUCKED UP (CRITICAL BUGS)

### BUG 1: Root password regenerated on every restart

**File:** `signoz.nix:328`
**Code:** `export SIGNOZ_USER_ROOT_PASSWORD="$(openssl rand -base64 48)"`

This runs inside the wrapper script on EVERY `ExecStart` (every service start/restart). The root user provisioning runs at startup only (per docs). On the first boot, root user is created with password A. On restart, password B is generated — but root user already exists with password A. Behavior is undefined: SigNoz may fail to start, may ignore the new password, or may error out on conflicting credentials.

**Fix needed:** Use a persistent file (same pattern as the old JWT secret):
```bash
ROOT_PW_FILE="${dataDir}/root-password"
if [ ! -f "$ROOT_PW_FILE" ]; then
  openssl rand -base64 48 > "$ROOT_PW_FILE"
  chmod 400 "$ROOT_PW_FILE"
fi
export SIGNOZ_USER_ROOT_PASSWORD="$(cat "$ROOT_PW_FILE")"
```

### BUG 2: Homepage siteMonitor will report SigNoz as DOWN

**File:** `homepage.nix:259-267`

The Homepage tile has `siteMonitor = svcUrl "signoz"` which points to `https://signoz.${domain}`. With the new unconditional `forwardAuth`, ALL external requests to `signoz.${domain}` — including Homepage's siteMonitor probe — get a 302 redirect to Pocket ID login instead of a 200 OK. Homepage will show SigNoz as permanently down.

**Fix needed:** Change the siteMonitor to point to localhost (bypass Caddy):
```nix
siteMonitor = "http://localhost:${toString config.services.signoz.settings.queryService.port}";
```

---

## What Is PARTIALLY DONE

| Item | Status | What remains |
|------|--------|-------------|
| Impersonation mode env vars | SET | Root password persistence bug (BUG 1) |
| Caddy unconditional forward-auth | SET | Homepage siteMonitor will break (BUG 2) |
| AGENTS.md documentation | DONE | No gotcha entry for the Homepage siteMonitor pattern |
| Syntax validation | PASSES | Both files parse cleanly via `nix-instantiate --parse` |
| `nix flake check --no-build` | BLOCKED | Pre-existing `snapshots.nix:98` syntax error blocks full check |
| `nix fmt` | NOT RUN | Should format changed files |

---

## What Was NOT STARTED

1. **Post-deploy impersonation verification** — No check that `identN.impersonation.enabled: true` is actually active after deploy. Should add to `post-deploy-check.sh`: `curl localhost:8080/api/v1/global/config | jq '.data.identN.impersonation.enabled'`
2. **`verify-deployment.sh` update** — Script uses hardcoded `localhost:8080` (works with impersonation) but doesn't verify impersonation mode is active
3. **Firewall hardening for localhost:8080** — With impersonation mode, ANY local process has full admin access to SigNoz on `localhost:8080` with zero auth. Previously needed a password. Should consider iptables/nftables rule restricting to Caddy + signoz-provision
4. **Defense-in-depth YAML config** — The impersonation settings are env vars only. If someone runs the binary directly (bypassing the wrapper), defaults apply (tokenizer=true, impersonation=false). Could set them in `signoz.yaml` too
5. **ClickHouse memory reduction** — Original question about making ClickHouse lighter was answered but not implemented. `MemoryMax=4G` unchanged
6. **Stale `/var/lib/signoz/jwt-secret` cleanup** — The old JWT secret file persists on disk, no longer used. Dead weight
7. **Stale `/var/lib/signoz/discord-webhook.url` in verify-deployment.sh** — Pre-existing bug: provisioning service doesn't create this file (reads from sops directly), but verify-deployment.sh checks for it (line 108). Always shows "missing" warning

---

## What We Should Improve

### Immediate (blocks deploy)

1. Fix root password persistence — generate once, store in file
2. Fix Homepage siteMonitor — point to localhost, not external URL
3. Run `nix fmt` on changed files

### Short-term (post-deploy)

4. Add impersonation mode verification to `post-deploy-check.sh`
5. Add Gatus alert for impersonation mode being disabled (regression detection)
6. Consider firewall rule restricting `localhost:8080` to Caddy + provisioning only
7. Set impersonation config in `signoz.yaml` as defense-in-depth
8. Clean up stale `/var/lib/signoz/jwt-secret` file
9. Fix pre-existing `snapshots.nix:98` syntax error (blocks `nix flake check`)
10. Fix pre-existing `verify-deployment.sh` hardcoded port 8080

### ClickHouse weight reduction (original concern, unaddressed)

11. Lower ClickHouse `MemoryMax` from 4G to 3G
12. Shorten traces/logs retention TTL to 3-7 days
13. Shorten metrics retention TTL to 15 days
14. Consider disabling log ingestion entirely if only metrics are needed
15. Consider disabling traces ingestion if not actively used
16. Review if journald receiver (logs to ClickHouse) is needed
17. Review ClickHouse merge tree settings for lower memory usage
18. Review if all 6 OTel scrape targets are necessary
19. Consider replacing cAdvisor with lighter alternative
20. Review if all 12 node-exporter collectors are needed
21. Consider reducing PSI metrics interval (15s → 60s)
22. Add monitoring for ClickHouse memory usage (Gatus/alert)
23. Add monitoring for ClickHouse disk usage
24. Review ClickHouse data directory BTRFS CoW impact

### Alternative observability stack evaluation

25. Prototype VictoriaMetrics + Grafana as SigNoz replacement (~1.5 GB vs 6.5 GB RAM)
26. Research VictoriaMetrics + Grafana native OIDC integration with Pocket ID
27. Benchmark VictoriaMetrics single-binary memory footprint on evo-x2
28. Evaluate Grafana Loki for log aggregation (lighter than ClickHouse for logs)
29. Evaluate Grafana Alloy as OTel collector replacement
30. Consider if Gatus + Discord alerts already covers the monitoring need
31. Review which SigNoz features are actively used (dashboards? alerts? trace exploration?)
32. Cost-benefit analysis: 6.5 GB RAM for SigNoz vs 1.5 GB for VM+Grafana stack

### Auth/SSO architecture improvements

33. Consider per-user audit logging at Caddy layer (SigNoz impersonation loses per-user audit)
34. Review oauth2-proxy session timeout settings for SigNoz
35. Consider adding rate limiting on `signoz.${domain}` vHost
36. Review Pocket ID session timeout for observability access
37. Document the security model: localhost = admin, external = Pocket ID
38. Consider if any other Layer 2 services would benefit from impersonation + unconditional forward-auth
39. Review if any automation/API scripts access SigNoz programmatically (they'd need to go through Pocket ID now or use localhost)
40. Consider adding a read-only API key for external tools that need metrics data (but apikey is disabled in impersonation mode)

### Monitoring stack improvements

41. Add BTRFS scrub status to Prometheus metrics + Gatus Discord alert
42. Review if the 18 SigNoz alert rules are all correct and firing properly
43. Add alert for SigNoz collector being down (separate from query service)
44. Review if ClickHouse Keeper is needed on single-node (it is, for replicated table DDL)
45. Add dashboard for oauth2-proxy health/metrics
46. Add dashboard for Pocket ID auth events
47. Review Caddy metrics pipeline completeness
48. Consider adding process-level monitoring (OOM score, FD count) for SigNoz services
49. Review if the signoz schema migrator needs updates after version bumps
50. Consider end-to-end test: Pocket ID login → SigNoz dashboard → query data → alert fires

---

## Top 2 Questions I Cannot Answer Myself

### Q1: Does SigNoz impersonation mode re-provision the root user on every startup, or only on first boot?

The docs say "root user provisioning runs at startup only" but don't clarify what happens on restart with different credentials. If it tries to UPDATE the root user with a new password and fails, the service won't start. If it skips because the user exists, the random password doesn't matter (nobody logs in with it anyway). **This determines whether BUG 1 is a real crash or a non-issue.** Only way to know: deploy and observe, or read the SigNoz source code for `SIGNOZ_USER_ROOT_*` startup logic.

### Q2: Is the 6.5 GB SigNoz footprint actually causing problems on evo-x2?

evo-x2 has 128 GB physical RAM (94 GB visible). The chronic memory pressure documented in AGENTS.md is from GPUActive consuming 51+ GB, NOT from SigNoz. If SigNoz's 6.5 GB is well within headroom, the entire ClickHouse weight question may be academic — the real memory problem is the GPU driver, not the observability stack. **Only Lars can say whether SigNoz is actually the bottleneck or just "feels heavy."**

---

## Files Changed This Session

| File | Change |
|------|--------|
| `modules/nixos/services/signoz.nix` | Impersonation mode env vars (line 2-5 header, 316-333 ExecStart) |
| `modules/nixos/services/caddy.nix` | SigNoz vHost: unconditional forward-auth, no LAN bypass (line 135-144) |
| `AGENTS.md` | Layer 2+ SSO tier, impersonation mode gotcha, updated OIDC entries |

## Files NOT Changed But Should Be

| File | Issue |
|------|-------|
| `modules/nixos/services/homepage.nix:265` | siteMonitor points to external URL, will break with forward-auth |
| `scripts/verify-deployment.sh:101` | Hardcoded port 8080 (pre-existing, works but fragile) |
| `scripts/post-deploy-check.sh` | No SigNoz impersonation verification (pre-existing gap) |
| `platforms/nixos/system/snapshots.nix:98` | Pre-existing syntax error blocks `nix flake check` |
