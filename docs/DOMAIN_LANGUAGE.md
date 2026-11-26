# SystemNix Domain Language

Ubiquitous language for the SystemNix infrastructure domain. Terms used consistently across code, docs, and conversations.

---

## Infrastructure Core

| Term                 | Definition                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------- |
| **SystemNix**        | Cross-platform Nix flake managing macOS (nix-darwin) + NixOS configurations declaratively                   |
| **evo-x2**           | NixOS host — AMD Ryzen AI Max+ 395 (Strix Halo), 128 GB RAM, x86_64-linux                                   |
| **Lars-MacBook-Air** | macOS host — Apple Silicon, aarch64-darwin                                                                  |
| **primaryUser**      | The main user account: `lars` on NixOS, `larsartmann` on macOS. Referenced via `config.users.primaryUser`   |
| **domain**           | The local DNS domain: `home.lan`. All services are subdomains (`immich.home.lan`, `forgejo.home.lan`, etc.) |
| **LAN**              | The local network (`192.168.1.0/24`). Trusted by the firewall — all services accessible from LAN            |
| **WAN**              | External network. Firewall denies by default — only ports 22/53/80/443 open                                 |

## DNS

| Term                | Definition                                                                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **dnsblockd**       | Custom Go DNS resolver replacing Unbound. Embeds sdns: DNSSEC, DoT, DoH, caching, local zones, blocklists                                           |
| **sdns**            | Stubby-derived DNS stub resolver library. dnsblockd wraps it with Go bindings                                                                       |
| **Blocklist**       | A curated list of domains to block (ads, trackers, malware). ~4M+ entries across 23 lists (realized mapping 4,296,867 domains, verified 2026-10-01) |
| **Local zone**      | DNS entries for `*.home.lan` — resolved locally by dnsblockd, not forwarded upstream                                                                |
| **Local subdomain** | An explicitly listed hostname in `dnsLocal.localSubdomains`. Required because dnsblockd's sdns resolver does NOT support wildcard records           |

## SSO / Authentication

| Term                                      | Definition                                                                                                                   |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Pocket ID**                             | Passkey-only OIDC Identity Provider at `auth.home.lan`. Sole IdP for the system                                              |
| **Layer 1 (Native OIDC)**                 | App integrates directly with Pocket ID via OIDC. Caddy uses plain `reverse_proxy` (no forward-auth)                          |
| **Layer 2 (Forward Auth)**                | App has no native auth. Caddy `protectedVHost` gates external access behind oauth2-proxy. LAN bypass open                    |
| **Layer 2+ (Unconditional Forward Auth)** | App internal auth disabled (impersonation mode). Caddy applies forward-auth to ALL requests — no LAN bypass                  |
| **oauth2-proxy**                          | OAuth2 proxy that mediates between Caddy and Pocket ID for Layer 2/Layer 2+ services                                         |
| **OIDC client**                           | An application registered in Pocket ID with a `clientId` and client secret                                                   |
| **Client secret provisioning**            | The process of creating an OIDC client in Pocket ID and writing its secret to `/var/lib/pocket-id/client-secrets/<clientId>` |
| **Double-auth conflict**                  | When a Layer 1 service (native OIDC) is placed behind `protectedVHost` (Layer 2), causing an infinite redirect loop          |

## Caddy

| Term               | Definition                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **protectedVHost** | Caddy vHost helper that applies oauth2-proxy forward-auth for external clients with LAN bypass                                           |
| **proxyTo**        | Canonical reverse_proxy wrapper that adds `header_up X-Real-IP {remote_host}`. ALL reverse_proxy directives must use this                |
| **commonConfig**   | Caddy snippet providing security headers (HSTS, nosniff), compression (zstd/gzip), and `-Server` suppression. All vHosts MUST include it |

## Storage

| Term          | Definition                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **BTRFS**     | Copy-on-Write filesystem used on evo-x2. Root (`@`) and data (`/data`) are separate partitions                                     |
| **btrbk**     | Automated BTRFS snapshot tool. Daily snapshots at 23:00, 14-day + 4-week retention                                                 |
| **Subvolume** | BTRFS named subdivision. `@` is root, `/data` is toplevel (subvolid=5)                                                             |
| **Scrub**     | BTRFS integrity check that verifies checksums across all data/metadata. Monthly via `autoScrub`                                    |
| **ZRAM swap** | Compressed swap in RAM (62 GiB, `/dev/zram0`; live `/proc/swaps` 2026-11-14 — was ~16 GiB in early docs). Replaces disk-based swap |
| **GPUActive** | TTM buffer objects consuming system RAM. The #1 memory consumer on Strix Halo (51+ GiB). Only visible in `/proc/meminfo`           |

## Desktop

| Term                        | Definition                                                                                    |
| --------------------------- | --------------------------------------------------------------------------------------------- |
| **DankMaterialShell (DMS)** | Quickshell-based desktop shell. Replaces Waybar, Dunst, wlogout, swaylock, and rofi           |
| **Quickshell**              | QtQuick desktop shell framework. DMS is built on it                                           |
| **niri**                    | Scrollable-tiling Wayland compositor. Primary WM on evo-x2                                    |
| **Helium**                  | Ungoogled Chromium fork (Chromium 150). Primary browser. NOT Electron — a full Chromium build |

## Observability

| Term                  | Definition                                                                          |
| --------------------- | ----------------------------------------------------------------------------------- |
| **SigNoz**            | OpenTelemetry-native observability platform. Traces, metrics, logs                  |
| **Gatus**             | Automated health check monitor. 320 endpoints (2026-11-25), Discord alerts on failure |
| **system-health**     | Prometheus textfile collector for systemd state, memory, GPUActive, DuckDB pressure |
| **Post-deploy check** | Functional smoke test that verifies services work (not just that they're alive)     |
| **Incident pipeline** | go-taskqueue ADR-0021 flow: error reports (`POST /api/v1/errors`, token-gated) become `error.observed` facts on `incident:<fingerprint>` streams; the pool's sweeper mints prio-120 (first) / prio-150 (regression) agent fix tasks |
| **Error beacon**      | `problems.home.lan/beacon.js` — embeddable script capturing web client errors (`onerror` + `unhandledrejection`), POSTing to `/report` where Caddy injects the tq-api Bearer token server-side (the token never reaches the browser) |
| **ai-meter** | Loopback metering proxy every OpenAI-compatible AI call routes through. Records token counts (facts) in a JSONL ledger and derives reference cost at the current price table |
| **Wait budget** | The longest one call may queue and retry at the gate before ai-meter answers it with a 429 of its own (`max_wait_seconds`; 270 s on this host). A retry enters with a whole new budget |
| **Kept place** | A call sent back at the end of its budget keeps its position in the queue as long as the client keeps sending it: the memory lasts five minutes from the latest arrival and ends with an answer no client retries |
| **Reference price** | The pay-as-you-go list price configured for a model in `services.ai-meter.costs`: what routed traffic WOULD cost, not what the coding plan bills (credits). Invented prices are banned; an unpriced model meters tokens exactly at $0 |
| **Restatement** | Re-pricing of every recorded call when a reference price lands, is corrected or is withdrawn. Automatic: the cost counter replays the ledger at each ai-meter start and the spend-rate panels derive cost from the token counters at query time. Never a manual backfill |
| **In flight** | A call inside ai-meter that is waiting on its provider, counted per client, provider and model by `ai_meter_active_requests`. It says that a client is waiting, not whether the provider is throttling |
| **Priced query** | A dashboard query the renderer derives from the token counters and the price table (`_ai-meter-dashboard.nix`): the spend rate in total, per model and per client, and the spend of the last 24 hours. Never read off the cost counter, whose steps are restatements |
| **Request outcome** | How a request through ai-meter ends: **served** (the provider answered 2xx), **not admitted** (ai-meter itself answered 429 because the call waited out its budget without a provider slot, or a usage window is spent) or **failed** (everything else). Success and failure figures count not-admitted requests as neither; they have their own panels. A call the client sends again after a retry answer is a new request |
| **Not admitted** | The proxy's own 429 answer to a client (`ai_meter_admission_outcomes_total` with outcome `timeout` or `circuit`). A delay, not a failure: the answer carries `Retry-After` and the call keeps its place in the queue. `gave_up` is not part of it: there the provider's own 429 is passed on, which is a failure |
| **Compliance evidence** | The frozen v1 JSON payload `buildflow compliance --json` emits (per-repo state, runs, step rows, failures, gate findings). Overview's `/compliance` heatmap consumes it as-is; absent evidence renders Unknown, never green. Produced by a timer, not in-service, because BuildFlow's state DB lives in the primary user's 0700 home |
| **Code risk hotspot** | A file ranked by `go-hotspot`'s churn × complexity score over a git window (machine-cadence commits filtered at the source). Overview's `/risk` matrix runs the CLI per discovered repo; a repo the CLI cannot analyze renders Unknown |

## Service Patterns

| Term                       | Definition                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **harden**                 | Systemd serviceConfig helper that applies security hardening (NoNewPrivileges, ProtectSystem, etc.)                           |
| **hardenUser**             | User-service variant of `harden` — omits ProtectHome/ProtectSystem (user namespace)                                           |
| **serviceDefaults**        | Systemd defaults for always-running services (Restart=always, start-limit hardening)                                          |
| **serviceOneshotDefaults** | Systemd defaults for one-shot services (Restart=no)                                                                           |
| **Provisioner**            | A `Type=oneshot` + `RemainAfterExit=true` service that bootstraps resources (OIDC clients, alert rules, DB schemas)           |
| **restartTriggers**        | List of store paths that, when changed, trigger a service restart. Critical for provisioners and static-file-serving services |
| **onFailure**              | Alert routing helper that sends a Discord notification when a service fails                                                   |
| **waitDnsReady**           | DNS-gate dependency that blocks service start until dnsblockd is resolving                                                    |
