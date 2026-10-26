# Caddy (reverse proxy, TLS termination, forward auth)

**Module:** `modules/nixos/services/caddy.nix` — the single web entrypoint for
every `*.home.lan` service and its split-horizon mirror zone
`*.larsartmann.cloud`. TLS-terminating reverse proxy with Layer-2 oauth2-proxy
forward auth, Layer-1 native-OIDC pass-through, and static `file_server`
vHosts.

---

## vHost map + layer doctrine

Every vHost is rendered through ONE of three helpers (single source of truth —
registry fan-out and hand-written entries share them):

| Helper                      | Shape                                                                            | Used by                                                                                                                     |
| --------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `plainVHost`                | TLS + `reverse_proxy` — no auth here (native OIDC or LAN-only)                   | forgejo, paperless, rss, geo, health, auth, cache, dnsblock pair, cv, index, nsfw, graph, timers(static)                    |
| `protectedVHost`            | `@external not remote_ip <lan>` → forward-auth + proxy; LAN bypasses auth        | dash, signoz, seo (hand-rolled GSC-callback exemption), tasks, banksync, tq, and every registry `layer = "protected"` entry |
| `renderVHost`/`staticVHost` | registry entries with `vHost.root` → `file_server` (layer semantics still apply) | architecture-catalog (`catalog`), systemd-timer-monitor (`timers`)                                                          |

Hand-written vHosts still live in `homeLanVHosts` (caddy.nix): `:80` redirect,
catch-alls (unknown `*.home.lan` / `*.larsartmann.cloud` → branded 404 page), `auth`
(pocket-id + oauth2-proxy split), `paperless` (with the `/admin/*` 403
hard-block), `tasks`, `seo` (GSC callback exempt from forward-auth), the
`dnsblock`/`dnsblockd` pair, `monitor` (enable-gated), `voice`/`whisper`
(enable-gated, deliberately NOT in dns-local). Everything else comes from the
`services.integration` registry via `extraVHosts`.

**Layer rules (SSO architecture):**

- Native-OIDC services MUST be `plain` — forward-auth would double-auth
  (forgejo, immich, paperless, cv, rss, geo, health...).
- Apps without their own auth are `protected` (oauth2-proxy forward-auth).
- `layer = "none"` = no vHost; DNS + tile derivation only.
- Registry entries need **EXACTLY ONE** of `port` / `vHost.root`
  (eval-asserted, XOR since 2026-09-30 — both set would silently serve the
  static root).

**DNS coupling (eval-asserted):** every vHost subdomain must exist in
`platforms/common/dns-local.nix` — the assertion in caddy.nix fails eval on a
typo'd hand-written vHost, and an eval WARNING names dns-local entries that
nothing serves (`alerts` is the allowlisted legacy alias — an explicit vHost
redirects it to `dash`). Registry entries carry the same assertion in
integration.nix.

**Registry-blind vHost gate (2026-10-25):** every named vHost must ALSO map to
a `services.integration` entry (or sit on the justified
`registryBlindSubdomains` table in caddy.nix) — a hand-rolled vHost with no
registry entry is invisible to the tile/gatus/OIDC fan-outs (the pocket-id /
openseo / taskchampion / dnsblockd blind-spot class). New vHost = register the
service (preferred) or extend the table with a justification. Negative-tested
(`vhostregistry/blind-vhost`). All four original blind services registered
2026-10-25 (§g.2/§g.3 owner answers): entries carry `vHost.layer = "none"` so
the hand-written vHosts (GSC callback exemption, auth oauth2/pocket-id split,
dns redirect pair) stay canonical while tile/gatus/monitored fan out from the
registry; the blind table is down to alerts/logs/dnsblockd/paperless.

## Unknown-host 404 page

Both catch-alls serve a branded 404 page instead of redirecting to `dash` (a
typo'd hostname used to masquerade as a dashboard bounce): `root *` points at
the self-contained `notFoundRoot` derivation (caddy.nix — inline CSS, one
inline JS echoing the requested host, Catppuccin Mocha, a `dash.home.lan`
link by auth-doctrine; zero external assets) and `error 404` +
`handle_errors { rewrite * /index.html; file_server }` returns a REAL 404
status with the page body on every path (sandbox-proven against the deployed
caddy 2.11.4). Live debugging: `rg 'root \*' /etc/caddy/caddy_config` names
the served store path. The legacy `alerts` alias keeps its documented dash redirect
via an explicit vHost that landed in the SAME change — no behavior gap
between deploys. Regression pins at three layers: `checks.cloud-domain`
asserts both catch-alls keep `error 404` + `handle_errors` and rejects any
dash `redir` returning to them; Gatus "Caddy Catch-All 404" probes
`catchall-probe.home.lan` expecting 404 (deliberately NOT in dns-local — no
ghost warning; KNOWN-FAILING since 2026-10-07: dnsblockd answers NXDOMAIN for
unknown `*.home.lan` names — its local-record store is exact-match only, so
the configured wildcard record never matches — and the probe dies on the DNS
shape before Caddy is reached; fix tracked in docs/todo/services.md);
`post-deploy-check.sh` smokes the same URL.

## TLS / cert flow

- `auto_https off` — no ACME, ever. Certificates are static or boot-minted.
- `dnsblockd-cert-mint.service` (every boot, `Before=caddy.service`,
  `After/wants sops-nix`): signs a 365d dual-zone leaf
  (`home.lan`, `*.home.lan`, `larsartmann.cloud`, `*.larsartmann.cloud`) from
  the sops'd dnsblockd CA into `/run/dnsblockd-certs/` (RuntimeDirectory,
  0444 cert / 0400 key, caddy:caddy). The unit SELF-ASSERTS the four SANs on
  the signed leaf before install — a broken extfile fails the MINT (OnFailure
  → Discord), not the first TLS handshake.
- `systemd.services.caddy.requires = dnsblockd-cert-mint.service` — the
  fail-closed mechanism is LITERAL: a dead mint blocks the caddy start
  (aligned 2026-09-30; before that the code only had `after`/`wants` and the
  claim in this file + AGENTS.md was false).
- Hosts without `networking.local.cloudDomain` (VM tests) fall back to the
  static sops cert (`dnsblockd_server_cert`/`_key`).
- Client trust: the dnsblockd CA (already distributed). SAN superset, so
  home.lan behavior is unchanged by the mint.

**Hardening (2026-09-30):** `harden {}` + `CAP_NET_BIND_SERVICE` ONLY (the
May-era `CAP_NET_ADMIN` came from a dead ACME-DNS-challenge rationale in
`da147df6`; `NoNewPrivileges = mkForce false` was removed — ambient caps work
under NNP by design, caddy never calls setuid/setgid). Proof gate:
`checks.caddy-mint` boots caddy and handshakes TLS on both zones.

## Ops

- **Restart after every deploy** — deploy.sh does this (`Restarting
  caddy.service (reload broken by PrivateTmp hardening)`): `harden {}` sets
  `PrivateTmp=true`, which blocks systemd's mount-namespace reload path;
  switch-to-configuration silently fails to reload (exit 4) and new vHosts
  stay unloaded. NEVER switch this to a reload.
- Manual: `sudo systemctl restart caddy.service` (mint re-runs at boot only;
  restart does NOT remint — the 365d leaf persists in /run until reboot).
- Validate config without restarting: `caddy validate --config
  /etc/caddy/caddy_config` (rendered Caddyfile is at `/etc/caddy/caddy_config`,
  a store-path symlink — the upstream `/etc/caddy/Caddyfile` path is NOT
  used).
- Bind posture: `default_bind <lan-ip>` — caddy listens ONLY on the LAN IP
  (never 0.0.0.0), so dnsblockd's block-page server on the blockIP
  (`:80`/`:443`) and caddy coexist. NetBird VPN needs no extra bind: the
  client routes the whole LAN subnet and traffic arrives AT the LAN IP.
- HTTP/3 is live: caddy serves h3 on UDP/443 (opened in the firewall
  2026-09-30; before that VPN/external clients chased Alt-Svc QUIC into a
  blackhole — LAN was unaffected, eno1 is a trusted interface).

## encode / compression behavior (verified 2026-10-06, Caddy 2.11.4)

`commonConfig` sets `encode zstd gzip` on EVERY vHost, but Caddy's default
response matcher is a Content-Type **allowlist** (text/*, json/js/xml variants,
fonts, `image/svg+xml*`, `image/vnd.microsoft.icon*`, `image/x-icon*`,
application/x-protobuf, multipart/bag) + minimum 512 bytes. Empirically probed
on this host: html/json/svg → `Content-Encoding: zstd`; **png/jpeg/webp/mp4/
octet-stream → NOT encoded by Caddy**. Caddy also skips any response that
already has Content-Encoding (so app-compressed responses pass through
untouched) and disables encoding on 206 partial responses.

**Consequence:** if you observe `Content-Encoding: zstd/gzip` on image/* or
media responses, it came from the UPSTREAM app, not Caddy — `reverse_proxy`
forwards the client's `Accept-Encoding` unchanged, and browsers attach it to
every fetch including images, so backends with compression middleware
(Express/NestJS `compression`, Django GZipMiddleware, …) compress media
themselves. Distinguish by probing the backend port directly with
`Accept-Encoding` set; suppress app-side compression with
`header_up Accept-Encoding identity` on the relevant proxy block.

**Server-Timing:** no core support (no directive, no official plugin). Verified
recipe for a total-time metric (deferred set, milliseconds per RFC 9111 spec —
`{http.request.duration}` is a Go duration string, `duration_ms` is the ms
float):

```
header >Server-Timing "caddy;dur={http.request.duration_ms}"
```

Per-phase timings (proxy connect, app DB, …) must come from the apps — Caddy
passes backend-emitted Server-Timing headers through untouched. Total request
duration is also in every access-log line (`duration` field).

## Logs

- **Runtime** — the journal (M9, 2026-10-25): the default logger is
  `output stdout` + `format journald { wrap json }` (encoder needs 2.11.3+;
  syntax adapt-validated against 2.11.7), so caddy's own lines (reload/TLS/
  upstream-dial errors) land in the journal with priority prefixes and reach
  SigNoz through the journald receiver as service `caddy`. The global
  `/var/log/caddy/access.log` file is GONE — geometrikks no longer tails it
  (runtime lines only ever produced access_log_debug malformed rows there).
- **Per-vHost** `/var/log/caddy/access-<host>.log` — file output in every
  site block: mode 0640 (caddy rw + group r for crowdsec), roll 100MiB ×
  keep 3 / 168h, zstd-compressed on roll (M21; ~77 vHosts worst case ≈
  23 GiB uncompressed, far less compressed). A server RESTART (not reload)
  applies output-file option changes, and open(2) never re-modes existing
  files — the crowdsec re-chmod timer covers the transition.
- **Probe endpoints skip access logging** (M21): `/health /healthz /metrics
  /ping /up /api/healthz /api/server/ping /actuator/health` are `log_skip`ed
  in commonConfig — responses untouched, only the log row is dropped
  (gatus/post-deploy probes were ~80 req/min of noise into crowdsec +
  geometrikks).
- **No double-logging**: each request lands in exactly ONE per-vHost file;
  runtime lines land ONLY in the journal.
- crowdsec tails `/var/log/caddy/*.log` (glob; group-read re-asserted by its
  timer) — unaffected by the runtime-log switch.
- geometrikks tails the per-vHost files only (derivation matches the nixpkgs
  per-host default) — see `modules/nixos/services/geometrikks.nix`.
- **Access-log ingestion** (filelog receiver) now targets the per-vHost
  files — `docs/todo/monitoring.md`.

## Error pages

- **404** — branded page (notFoundRoot) served by both wildcard catch-alls
  WITH the 404 status (`error 404` + `handle_errors 404`).
- **502/503/504** — branded sibling pages (serverErrorRoot, one file per
  status) served by `handle_errors 502 503 504` in every upstream-bearing
  vHost (proxy helpers + hand-written proxy vHosts). file_server keeps the
  original error status. Static/redirect-only vHosts carry no such route
  (no upstream, no 5xx). Sandbox-proven 2026-10-25: dead backend → HTTP 502
  with the page naming 502.
- **Upstream 5xx RESPONSES** stay pass-through by decision (deep dive
  finding 2b): `handle_response` blocks that serve a page lose the upstream
  status (file_server answers 200), and replacing upstream 5xx bodies would
  break API clients. If ever needed, the opt-in pattern is a `status 5xx`
  response matcher + `handle_response` inside `proxyTo` (caddyserver/caddy
  #7283 context) — deliberately NOT wired.
- **10GB request bodies** — per-vHost `request_body { max_size 10GB }` in
  commonConfig is deliberate (Immich-class uploads); `read_body 15m` bounds
  slow-upload stalls (sized for 10GB at ~10Mbps with headroom).

## Cloud mirroring (split-horizon)

Every home.lan vHost is mirrored 1:1 under `larsartmann.cloud` by the
`mirrorCloud` filter at the end of `virtualHosts` — do NOT hand-write cloud
vHosts; new home.lan vHosts mirror automatically. The cloud catch-all serves
the same branded 404 page as home.lan (single page, `dash.home.lan` link).
Auth redirects deliberately stay on
`auth.home.lan` (VPN resolves both zones; oauth2-proxy whitelists the cloud
domain for post-login redirects only). NEVER publish cloud service names in
public DNS. Architecture: `docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md`.

## Post-deploy smoke coupling

`scripts/post-deploy-check.sh` reads `/etc/caddy/vhost-layers` (emitted by
caddy.nix at eval time: `layer sub port` per home.lan vHost) — the auth-gateway
block probes every rendered protected vHost (backend-down → SKIP; 5xx with a
listening backend → FAIL) and one plain vHost proves TLS + routing. The file
is derived from the RENDERED virtualHosts set, so a new vHost is smoke-covered
with zero script edits.

## Monitoring

- Gatus "Caddy" metrics check (`:2019` admin metrics, `Host: localhost:2019`).
- `caddy` in the integration registry (`monitored = true`, `vHost.layer =
  "none"` — Caddy OWNS the vHost/check surfaces; a self-referential vHost
  would be circular).
- SigNoz scrapes caddy :2019; `caddy_http_response_duration_seconds.sum`
  (dotted histogram suffix in SigNoz).
- **Per-host cardinality receipt (F12, live 2026-10-26 post-gen-949): 32
  distinct `host=` labels on the `caddy_http_*` families (~2.7k labelled
  series); 0 `_other` (no unmatched-Host traffic observed). Cardinality is
  bounded by the vHost set, not request paths.**
- Post-deploy: auth-gateway 500/502 detection (above) + plain-vHost probe.

## Edge tracing (OpenTelemetry spans, 2026-10-25)

Every vHost emits an OTel span per request via the `tracing` directive in
`commonConfig` (the single block shared by hand-written vHosts, the registry
fan-out, static roots, catch-alls and the cloud mirrors — 76 rendered site
blocks at the time of writing). Spans carry the OTel HTTP semantic attributes
(method, route, status, duration, client); the **span name is the requested
host** (`span {http.request.host}`), so SigNoz spanmetrics cardinality stays
bounded by the vHost count. Service name: `caddy` (`OTEL_SERVICE_NAME`).

- **Exporter**: OTLP over **HTTP** → the local SigNoz collector,
  `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` on the caddy unit
  (scheme REQUIRED — otel-go otlptracehttp is a URL parser; the 2026-08-14
  schemeless-endpoint hang class). Audited at eval time:
  `otel-endpoint-audit` expectation `caddy = "http-url"`.
  **PORT HISTORY (2026-10-26 battery catch):** the endpoint shipped pointed
  at the gRPC port :4317 (the audit expectation wrongly asserted
  otlptracegrpc) — the collector answered caddy's HTTP/1.1 POST with an
  h2c SETTINGS frame and EVERY export failed ("malformed HTTP response"),
  so spans were dark from gen-949 until the :4318 fix deploys. Lesson: the
  endpoint-audit checked URL shape, not protocol-port agreement.
- **Coverage rail**: `signoz-coverage.expected.caddy` — wiring `env`,
  26h **request-driven** budget (gatus checks hit the backends directly, NOT
  through Caddy, so spans flow on human browsing + deploy smokes; an
  overnight without requests is healthy, not dark — dnsblockd doctrine).
  Still accurate post-`per_host`: that knob multiplies metric series per
  vHost, never span volume (F78 re-check 2026-10-26).
- **What this is NOT**: Caddy cannot continue trace context INTO the
  backends (no client-side instrumentation anywhere), and Forgejo itself has
  no OTel support (upstream #3972 was merged + reverted over licensing;
  never shipped). These are edge spans only — per-request status/duration
  per vHost, which is exactly the KFears #7216 "basic insight" need.
- **Verify spans flowing live** (post-deploy): hit any vHost, wait ~10 s,
  then
  `clickhouse-client --query "SELECT count() FROM signoz_traces.distributed_signoz_index_v3 WHERE timestamp > now() - 300 AND serviceName = 'caddy'"`
  (same table the coverage collector sweeps). Or check
  `signoz_traces_reporting{service="caddy"}` on the next coverage scrape.
- Directive validated against the deployed caddy 2.11.7 binary; full
  rendered Caddyfile adapts cleanly (`caddy adapt`, 76 tracing blocks).

## HSTS

`Strict-Transport-Security max-age=31536000; includeSubDomains` is set on
every vHost via `commonConfig`. HSTS **preload is deliberately NOT
submitted** — home.lan is a private LAN zone (not a public TLD, unloadable
from the preload list if it ever breaks) and larsartmann.cloud serves only
LAN/VPN traffic; preloading would brick non-VPN external access patterns for
zero benefit.

## Header + privacy defaults (correct by default, M18 2026-10-26)

- **X-Forwarded-For is spoof-resistant**: `trusted_proxies` is unset, so
  Caddy IGNORES any client-supplied `X-Forwarded-For`/`X-Forwarded-Proto`
  and sets them from the immediate peer (2.5+ behavior). The LAN edge has
  no proxy in front — the value backends receive is the real client IP.
  Do not add `trusted_proxies` unless a real proxy lands in front.
- **Access-log identity**: per-vHost `access-*.log` lines carry client IPs
  (no auto-redaction — crowdsec + geometrikks need the real source); the
  8 probe paths (`log_skip @probe`) are the only suppression. Files are
  root/group-readable per the log roll defaults; journald runtime lines
  need systemd-journal membership to read.
- **Permissions-Policy** is the restrictive baseline
  `geolocation=(), microphone=(), camera=()` on every vHost (reviewed
  F70 2026-10-26: no vHost needs any of the three; add per-vHost only if a
  backend ever asks).
- **`hostOverride` users (F71 audit 2026-10-26): exactly one — bank-sync**
  (`Host: localhost`, because the daemon's DNS-rebinding guard 403s any
  non-localhost Host on its loopback bind). The integration-registry
  option defaults to `null` (no rewrite) everywhere else — audit again if
  a second user appears.
- **`enableReload` stays false** (rationale lives as a comment next to
  `services.caddy` in `caddy.nix`): restarts are the honest, cheap op on
  this edge.

## Caching

Caddy does no server-side caching. Its entire cache influence is header
policy in `commonConfig`: a **set-if-absent** `?Cache-Control "no-cache"`
default, so every vHost revalidates unless the backend sends its own
`Cache-Control` (apps owning content-addressed media, e.g. Immich's
`immutable`, are preserved; `file_server` vHosts get the default).

The hand-written `monitor` vHost additionally force-overrides
`no-cache, no-store, must-revalidate` on `/ui/index.html` + `/ui/bootstrap.js`
(`faae52ac`): a stale cached `bootstrap.js` requests old content hashes, the
SPA fallback masks the 404 as `text/html`, and the browser MIME-errors. The
monitor365 server now ships this policy itself (entry points `no-cache,
no-store, must-revalidate`, trunk-hashed assets `immutable`), so the Caddy
override is redundant once that upstream rev is locked + deployed — removal
is tracked in `docs/todo/services.md`; the global `?` default remains the
backstop for any backend that sends no cache headers.

Re-check note (F67, 2026-10-26): after the row-293 override removal lands,
re-verify WHICH surface owns the header live (`curl -sI` on
`/ui/bootstrap.js` → upstream `immutable` on assets, Caddy default only
where the backend is silent) — the `?` set-if-absent default must stay the
backstop, never fight a backend that already sets `Cache-Control`.

## Feature deep dive (2026-10-25)

Full adoption audit vs Caddy 2.11: `docs/research/2026-10-25_caddy-deep-dive.html`
— verdict **89/100 (very high)**: 24 of 27 applicable capabilities fully
leveraged, 0 anti-patterns, version-current (2.11.7 = upstream latest). Three
findings (Pareto-ranked, none urgent): (1) `metrics { per_host }` unused —
ADOPTED 2026-10-25 (globalConfig; per-vHost RED metrics live); (2) dead
backends serve plain-text 502 — ADOPTED 2026-10-25 (`handle_errors 502 503
504` + branded serverErrorRoot in every upstream-bearing vHost; upstream 5xx
responses stay pass-through by decision — see Error pages below); (3) caddy
runtime logs invisible to the journald→SigNoz pipeline — ADOPTED 2026-10-25
(`output stdout` + `format journald { wrap json }` on the default logger;
global access.log dropped, geometrikks tail removed, per-vHost files
unchanged). Refresh triggers: next caddy major bump, adoption of any remaining
finding, or a change to the helper/vHost architecture.

Post-adoption notes (2026-10-25, edge plan M22/M23): all three findings were
adopted and deployed the SAME day — the version-currency leg re-verified at
closeout (nixpkgs lock `fe13242` rev-pin, lastModified 2026-10-23, carries
caddy 2.11.7 = upstream latest; the pin audit trail lives in the flake-input
pin notice). Inventory granularity: audit rows 8 (request_body 10GB) and 9
(read_body timeout) were split — next refresh should keep them separate
(cap = size bound via commonConfig; timeout = servers.timeouts, different
surfaces, different owners).

## 2026-09-30 config review — verdict table

| #  | Finding                                         | Disposition                                                                  |
| -- | ----------------------------------------------- | ---------------------------------------------------------------------------- |
| 1  | HTTP/3 QUIC blackhole (UDP/443 dropped)         | FIXED — UDP/443 opened (`platforms/nixos/system/networking.nix`)             |
| 2  | After+Requires claim vs after+wants code        | FIXED — `requires` added; AGENTS.md anchor updated                           |
| 3  | Uncommented `NoNewPrivileges = mkForce false`   | FIXED — override REMOVED (rationale was stale lore, `da147df6`)              |
| 4  | `CAP_NET_ADMIN` with no live justification      | FIXED — dropped from bounding + ambient sets; `checks.caddy-mint` proves it  |
| 5  | `default_bind` uncommented                      | FIXED — comment documents syntax-fix origin + collision + NetBird routing    |
| 6  | port+root both set silently serves static       | FIXED — XOR assertion in integration.nix (negative-tested)                   |
| 7  | Vestigial `protectedVHost _subdomain` param     | FIXED — param removed, all call sites updated                                |
| 8  | `monitor365.enable` missing `or false` guard    | FIXED                                                                        |
| 9  | Per-vHost logs lack roll bounds                 | DOCUMENTED (Caddy defaults 100MiB×10/file; aggregate bounded by vHost count) |
| 10 | Mint installs whatever the extfile produced     | FIXED — SAN self-assert in the mint script                                   |
| 11 | Hand-written vHosts not DNS-asserted            | FIXED — eval assertion + ghost-entry warning (alerts allowlisted)            |
| 12 | No caddy runbook                                | FIXED — this document                                                        |
| 13 | Hand-maintained smoke AUTH_VHOSTS (drift class) | FIXED — derived from `/etc/caddy/vhost-layers`                               |
| 14 | Plain vHosts had zero deploy-smoke coverage     | FIXED — derived plain-vHost probe                                            |
