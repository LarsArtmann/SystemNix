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
catch-alls (unknown `*.home.lan` / `*.larsartmann.cloud` → `dash`), `auth`
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
nothing serves (`alerts` is the allowlisted legacy alias — the catch-all
redirects it to `dash`). Registry entries carry the same assertion in
integration.nix.

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

- **Global** `/var/log/caddy/access.log` — the DEFAULT logger (runtime JSON +
  any site without its own log block). Roll 100MB × 3, 168h.
- **Per-vHost** `/var/log/caddy/access-<host>.log` — the nixpkgs per-host
  default (`log { output file ... }` in every site block). Caddy file-output
  defaults: roll 100MiB, keep 10 — bounded per file, aggregate grows with
  vHost count.
- **No double-logging** (verified against the rendered Caddyfile + live log
  dir 2026-09-30): each request lands in exactly ONE per-vHost file.
- geometrikks tails BOTH surfaces (its per-vhost path derivation matches the
  nixpkgs default) — see `modules/nixos/services/geometrikks.nix`.

## Cloud mirroring (split-horizon)

Every home.lan vHost is mirrored 1:1 under `larsartmann.cloud` by the
`mirrorCloud` filter at the end of `virtualHosts` — do NOT hand-write cloud
vHosts; new home.lan vHosts mirror automatically. The cloud catch-all
redirects to `dash.larsartmann.cloud`. Auth redirects deliberately stay on
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
- Post-deploy: auth-gateway 500/502 detection (above) + plain-vHost probe.

## HSTS

`Strict-Transport-Security max-age=31536000; includeSubDomains` is set on
every vHost via `commonConfig`. HSTS **preload is deliberately NOT
submitted** — home.lan is a private LAN zone (not a public TLD, unloadable
from the preload list if it ever breaks) and larsartmann.cloud serves only
LAN/VPN traffic; preloading would brick non-VPN external access patterns for
zero benefit.

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
