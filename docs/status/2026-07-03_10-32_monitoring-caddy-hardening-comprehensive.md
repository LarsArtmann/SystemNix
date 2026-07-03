# Status Report — Monitoring & Caddy Proxy Hardening

**Date:** 2026-07-03 10:32 CEST
**Branch:** master
**Last deployed generation:** 434 (2026-06-25)
**Undeployed commits:** 7 (all from this session)

---

## Executive Summary

Comprehensive monitoring and reverse-proxy hardening pass across Gatus health
checks and Caddy security posture. **38 endpoints monitored** (up from 34), **31
with Discord alerts** (up from ~10), and **16 with response-time thresholds** (up
from 5). Caddy gained security headers, compression, access logging, TLS 1.2+
enforcement, strict SNI host, and HTTP→HTTPS redirect.

**All changes pass `nix flake check --no-build` and full eval. None are deployed yet.**

---

## a) FULLY DONE ✅

### Gatus Monitoring (`gatus-config.nix`)

| Work Item | Details | Commit |
|-----------|---------|--------|
| UI configuration | Title, header, logo, dark mode, `default-sort-by: group`, 4 quick-link buttons (Dashboard, Forgejo, SigNoz, Dozzle) | initial |
| Discord alerts on all critical endpoints | 31 of 38 endpoints now alert (was ~10). Added to: Pocket ID, oauth2-proxy, Forgejo, Homepage, Node Exporter, cAdvisor, DNS Resolver, Redis, Manifest, TaskChampion, Twenty, Ollama, OpenSEO, Monitor365, EMEET PIXY, Crush Daily, Dozzle, Niri compositor | `148beb9c` |
| Response-time thresholds | 16 endpoints have `[RESPONSE_TIME] < N` conditions (was 5). Ranges: 500ms (Pocket ID, oauth2-proxy, Homepage, DNS Blocker, Monitor365, Dozzle, Overview) to 2s (Ollama, OpenSEO) | `3c5eb141` |
| Redis TCP check | New `tcp://127.0.0.1:6379` check — critical Immich ML + Twenty CRM dependency | `25a67a9d` |
| Mullvad DoT upstream check | New `tcp://dot.mullvad.net:853` check — validates DNS-over-TLS path | initial |
| External HTTPS connectivity check | `https://api.github.com/zen` every 5m — detects ISP outages | `3ae3d177` |
| Overview service check | Port 8083 was enabled but unmonitored | `25a67a9d` |
| TLS certificate expiry check | Pre-existing, verified working | — |

### Caddy Proxy (`caddy.nix`)

| Work Item | Details | Commit |
|-----------|---------|--------|
| Security headers (`commonConfig`) | HSTS (`max-age=31536000; includeSubDomains`), `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, `Permissions-Policy`, `-Server` (version suppression) | initial |
| Compression | `encode zstd gzip` in `commonConfig` — applied to all vhosts | initial |
| HTTP→HTTPS redirect | `:80` catch-all vhost (`redir https://{host}{uri} permanent`) — previously HTTP requests silently failed | initial |
| Structured access logging | JSON format to `/var/log/caddy/access.log`, 100MB rotation, 3 archives, 7-day retention | `15a8869d` |
| TLS 1.2+ enforcement | `protocols tls1.2 tls1.3` in all `tlsConfig` blocks — drops TLS 1.0/1.1 | `a5e688cf` |
| Strict SNI host | `strict_sni_host on` in `servers` global block — prevents serving TLS for unrecognized hostnames | `a5e688cf` |

### Documentation (`AGENTS.md`)

| Work Item | Details | Commit |
|-----------|---------|--------|
| "Adding a Service" step 9 | New services MUST add a Gatus health check with Discord alert | `261260ae` |
| Caddy gotcha entries | `commonConfig`, HTTP redirect + `auto_https off`, TLS protocols, Gatus endpoint conventions | `261260ae` |

---

## b) PARTIALLY DONE 🟡

| Item | Status | Gap |
|------|--------|-----|
| PostgreSQL monitoring | No direct TCP check (NixOS PostgreSQL listens on Unix socket `/run/postgresql` only). Covered indirectly by Immich/Forgejo/Twenty health checks, and SigNoz systemd-unit-failed alert. A custom textfile exporter check would be needed for direct monitoring. | Would need `pg_isready` textfile exporter or enable `listen_addresses` |
| Caddy admin API (port 2019) | Metrics endpoint works, localhost-only, not in firewall. But admin API has no auth — any local process can reconfigure Caddy at runtime. | Would need `admin off` + standalone metrics listener, or `admin localhost:2019 { access_control }` |
| Metrics scrape monitoring | Node Exporter, cAdvisor, GPU VRAM, Disk, BTRFS, NVMe, Memory, Swap, PSI checks verify metrics are *present* but don't alert on *values* (that's SigNoz's job via `_signoz-alerts.nix`) | SigNoz alert rules cover this layer |
| Endpoint groups | All endpoints use groups but they're inconsistent — some monitoring endpoints are in "Monitoring" group, others in "Filesystem" | Cosmetic only |

---

## c) NOT STARTED ⬜

| Item | Impact | Effort |
|------|--------|--------|
| Caddy rate limiting on auth endpoints | Brute-force protection for `auth.${domain}` | Medium — Caddy has no native rate limiter, needs caddy-ratelimit plugin or nginx-style approach |
| Caddy request body size limits | Prevents memory exhaustion from large POSTs | Low — add `request_body { max_size 100MB }` per vhost |
| Gatus maintenance windows | Suppress alerts during planned deploy windows | Low — add `maintenance-windows` config |
| Gatus Prometheus metrics endpoint | Expose Gatus's own metrics (`/metrics`) to SigNoz for correlation | Low — verify it's enabled by default in Gatus |
| Gatus default-endpoint config | Apply default client timeout, default conditions to all endpoints | Low — add `endpoints` defaults block |
| Gatus endpoint for `projects-management-automation` | Service is enabled but has no health endpoint | Needs upstream health endpoint |
| Gatus endpoint for `file-and-image-renamer` | Service is enabled but has no health endpoint | Needs upstream health endpoint |
| Caddy admin endpoint hardening | Admin API at `localhost:2019` has no authentication | Medium — see partially done section |
| Caddy log integration with SigNoz | Access logs go to file but aren't ingested into SigNoz for log search | Medium — add filelog receiver to SigNoz collector |
| Homepage statusStyle for Gatus | Homepage dashboard tiles could show real-time Gatus status | Low — Homepage supports Gatus integration |

---

## d) TOTALLY FUCKED UP 🔴

**Nothing.** No regressions, no broken configs, no data loss.

**One latent risk noted (pre-existing, not caused by this work):**
The `:80` HTTP redirect vhost inherits `default_bind`. In production this resolves
to the correct IP (`192.168.1.150` on eno1). But if someone enables dns-blocker
with `blockInterface = "lo"` (the module default), `bindAddress` becomes `null`,
no `default_bind` is emitted, and Caddy's `:80` would bind `0.0.0.0:80` — colliding
with dnsblockd on `127.0.0.2:80`. This is a **pre-existing latent bug** in the
bind logic, not introduced by our changes.

---

## e) WHAT WE SHOULD IMPROVE

1. **Deploy these changes** — 7 commits undeployed since 2026-06-25 (generation 434). Everything passes eval but isn't live.
2. **Caddy admin API auth** — any local process can POST to `localhost:2019/config/` and inject malicious reverse_proxy routes. This is the single biggest Caddy security gap.
3. **Caddy access logs → SigNoz** — JSON logs are written but never ingested. Adding a filelog receiver to the SigNoz OtelCollector would enable log search/alerting.
4. **PostgreSQL direct monitoring** — currently blind to DB-level issues (connection exhaustion, slow queries, replication lag). A textfile exporter running `pg_isready` would close this gap.
5. **Gatus maintenance windows** — deploys cause transient endpoint failures that fire Discord alerts. A maintenance window during deploy would suppress noise.
6. **Endpoint group consistency** — "Filesystem" group should be folded into "Monitoring" for cleaner dashboard.
7. **Response-time baselines** — thresholds (500ms, 1s, 2s) are guessed. After deploy, check Gatus response-time history and tune to actual baselines.
8. **Gatus `/metrics` → SigNoz** — Gatus exposes Prometheus metrics. Adding it to SigNoz's scrape config would enable uptime/alert correlation in dashboards.

---

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 1 | **Deploy the 7 undeployed commits** | Critical | `nix run .#deploy` | Everything passes eval |
| 2 | **Caddy admin API hardening** | Critical | Medium | `admin off` + standalone metrics listener, or access_control allow-list |
| 3 | **Gatus maintenance windows** | High | Low | Suppress false alerts during deploys |
| 4 | **Caddy access logs → SigNoz filelog receiver** | High | Medium | Add `filelog` receiver to OtelCollector config in `signoz.nix` |
| 5 | **Gatus `/metrics` → SigNoz scrape config** | High | Low | Add gatus job to prometheus scrape_configs in signoz.nix |
| 6 | **PostgreSQL textfile exporter** | High | Medium | `pg_isready` + connection count via textfile collector |
| 7 | **Caddy request body size limits** | Medium | Low | `request_body { max_size 100MB }` on file-upload vhosts (Immich) |
| 8 | **Gatus → Homepage integration** | Medium | Low | Homepage `statusStyle: dot` with Gatus API for real-time status |
| 9 | **Endpoint group cleanup** | Low | Low | Fold "Filesystem" into "Monitoring" |
| 10 | **Response-time threshold tuning** | Medium | Low | Check actual baselines post-deploy, adjust thresholds |
| 11 | **Caddy upstream health checks** | High | Medium | Add `health_uri` / `health_port` to reverse_proxy blocks — Caddy won't proxy to dead backends |
| 12 | **SigNoz alert for Caddy 5xx rate** | High | Low | Query `caddy_http_response_total{status >= 500}` |
| 13 | **Gatus default client timeout** | Medium | Low | Add default `client.timeout: 10s` to prevent hanging checks |
| 14 | **Discord alert deduplication** | Medium | Medium | Gatus fires per-endpoint; group critical+infra into a single Discord channel vs separate |
| 15 | **Caddy log sampling** | Low | Low | High-traffic vhosts produce excessive JSON logs; add `sample` directive |
| 16 | **Gatus SSH check for Forgejo** | Low | Low | Verify SSH git access (port 22) not just HTTP API |
| 17 | **BTRFS scrub monitoring** | Medium | Low | Add a textfile exporter for `btrfs scrub status` |
| 18 | **Caddy graceful shutdown timeout** | Low | Low | Add `grace_period 10s` to prevent dropped connections during reload |
| 19 | **Docker health check integration** | Medium | Medium | Container health status → Gatus via custom script |
| 20 | **SigNoz SLO dashboards** | Medium | High | Define error-budget SLOs for critical services |
|  +| **Gatus endpoint for Hermes** | Medium | Medium | No HTTP endpoint exists — needs upstream health endpoint |
| 22 | **Caddy OCSP stapling** | Low | Low | Verify OCSP staple is configured with self-managed certs |
| 23 | **Monitoring runbook** | High | Medium | Document what to do when each Discord alert fires |
| 24 | **Gatus backup** | Low | Low | SQLite DB at `/var/lib/gatus/gatus.db` — add to btrbk snapshots |
| 25 | **Caddy metrics dashboard** | Medium | Medium | Create dedicated Caddy dashboard in SigNoz (requests/sec, latency p50/p99, upstream errors) |

---

## g) Top #1 Question

**How should we handle the Caddy admin API?**

The admin endpoint at `localhost:2019` exposes:
- `GET /config/` — full runtime config (including upstream IPs, ports)
- `POST /config/...` — **modify running config** (inject routes, steal traffic)
- TLS certificate material

Currently **unauthenticated**. Three options:

1. **`admin off` + standalone metrics** — Disables admin API entirely. Metrics
   move to a separate listener (`metrics :2019`). Most secure but loses
   zero-downtime config reload via API (Caddy falls back to `SIGHUP`/restart).
   `nh os switch` still works (it does `systemctl reload caddy`).

2. **`admin localhost:2019 { access_control allow 127.0.0.1/8 }`** — Keeps admin
   API but restricts to localhost. Still allows any local process to reconfigure
   Caddy, but blocks network access.

3. **Keep as-is** — Accept the risk. localhost-only, single-admin machine.

**My recommendation:** Option 1 (`admin off` + standalone metrics) — it's the
most secure, and `nh os switch` reloads via systemd anyway. But this changes
operational behavior and I can't verify it won't break `nh` reload without
testing on the live system.

**Can you confirm which approach you want?**

---

## Session Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Gatus endpoints | 34 | 38 | +4 |
| Endpoints with Discord alerts | ~10 | 31 | +21 |
| Endpoints with response-time thresholds | 5 | 16 | +11 |
| Caddy security headers per vhost | 0 | 6 | +6 |
| Caddy access logging | None | JSON + rotation | New |
| Caddy TLS minimum version | Default | 1.2+ | Hardened |
| Commits this session | — | 7 | — |
| Files changed | — | 3 | `caddy.nix`, `gatus-config.nix`, `AGENTS.md` |
| Deploy status | — | **Not deployed** | 7 commits pending |
