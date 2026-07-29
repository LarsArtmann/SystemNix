# SystemNix Domain Language

Ubiquitous language for the SystemNix infrastructure domain. Terms used consistently across code, docs, and conversations.

---

## Infrastructure Core

| Term | Definition |
|------|-----------|
| **SystemNix** | Cross-platform Nix flake managing macOS (nix-darwin) + NixOS configurations declaratively |
| **evo-x2** | NixOS host — AMD Ryzen AI Max+ 395 (Strix Halo), 128 GB RAM, x86_64-linux |
| **Lars-MacBook-Air** | macOS host — Apple Silicon, aarch64-darwin |
| **primaryUser** | The main user account: `lars` on NixOS, `larsartmann` on macOS. Referenced via `config.users.primaryUser` |
| **domain** | The local DNS domain: `home.lan`. All services are subdomains (`immich.home.lan`, `forgejo.home.lan`, etc.) |
| **LAN** | The local network (`192.168.1.0/24`). Trusted by the firewall — all services accessible from LAN |
| **WAN** | External network. Firewall denies by default — only ports 22/53/80/443 open |

## DNS

| Term | Definition |
|------|-----------|
| **dnsblockd** | Custom Go DNS resolver replacing Unbound. Embeds sdns: DNSSEC, DoT, DoH, caching, local zones, blocklists |
| **sdns** | Stubby-derived DNS stub resolver library. dnsblockd wraps it with Go bindings |
| **Blocklist** | A curated list of domains to block (ads, trackers, malware). 2.5M+ entries across 23 lists |
| **Local zone** | DNS entries for `*.home.lan` — resolved locally by dnsblockd, not forwarded upstream |
| **Local subdomain** | An explicitly listed hostname in `dnsLocal.localSubdomains`. Required because dnsblockd's sdns resolver does NOT support wildcard records |

## SSO / Authentication

| Term | Definition |
|------|-----------|
| **Pocket ID** | Passkey-only OIDC Identity Provider at `auth.home.lan`. Sole IdP for the system |
| **Layer 1 (Native OIDC)** | App integrates directly with Pocket ID via OIDC. Caddy uses plain `reverse_proxy` (no forward-auth) |
| **Layer 2 (Forward Auth)** | App has no native auth. Caddy `protectedVHost` gates external access behind oauth2-proxy. LAN bypass open |
| **Layer 2+ (Unconditional Forward Auth)** | App internal auth disabled (impersonation mode). Caddy applies forward-auth to ALL requests — no LAN bypass |
| **oauth2-proxy** | OAuth2 proxy that mediates between Caddy and Pocket ID for Layer 2/Layer 2+ services |
| **OIDC client** | An application registered in Pocket ID with a `clientId` and client secret |
| **Client secret provisioning** | The process of creating an OIDC client in Pocket ID and writing its secret to `/var/lib/pocket-id/client-secrets/<clientId>` |
| **Double-auth conflict** | When a Layer 1 service (native OIDC) is placed behind `protectedVHost` (Layer 2), causing an infinite redirect loop |

## Caddy

| Term | Definition |
|------|-----------|
| **protectedVHost** | Caddy vHost helper that applies oauth2-proxy forward-auth for external clients with LAN bypass |
| **proxyTo** | Canonical reverse_proxy wrapper that adds `header_up X-Real-IP {remote_host}`. ALL reverse_proxy directives must use this |
| **commonConfig** | Caddy snippet providing security headers (HSTS, nosniff), compression (zstd/gzip), and `-Server` suppression. All vHosts MUST include it |

## Storage

| Term | Definition |
|------|-----------|
| **BTRFS** | Copy-on-Write filesystem used on evo-x2. Root (`@`) and data (`/data`) are separate partitions |
| **btrbk** | Automated BTRFS snapshot tool. Daily snapshots at 23:00, 14-day + 4-week retention |
| **Subvolume** | BTRFS named subdivision. `@` is root, `/data` is toplevel (subvolid=5) |
| **Scrub** | BTRFS integrity check that verifies checksums across all data/metadata. Monthly via `autoScrub` |
| **ZRAM swap** | Compressed swap in RAM (~16 GiB). Replaces disk-based swap |
| **GPUActive** | TTM buffer objects consuming system RAM. The #1 memory consumer on Strix Halo (51+ GiB). Only visible in `/proc/meminfo` |

## Desktop

| Term | Definition |
|------|-----------|
| **DankMaterialShell (DMS)** | Quickshell-based desktop shell. Replaces Waybar, Dunst, wlogout, swaylock, and rofi |
| **Quickshell** | QtQuick desktop shell framework. DMS is built on it |
| **niri** | Scrollable-tiling Wayland compositor. Primary WM on evo-x2 |
| **Helium** | Ungoogled Chromium fork (Chromium 150). Primary browser. NOT Electron — a full Chromium build |

## Observability

| Term | Definition |
|------|-----------|
| **SigNoz** | OpenTelemetry-native observability platform. Traces, metrics, logs |
| **Gatus** | Automated health check monitor. 67 endpoints, Discord alerts on failure |
| **system-health** | Prometheus textfile collector for systemd state, memory, GPUActive, DuckDB pressure |
| **Post-deploy check** | Functional smoke test that verifies services work (not just that they're alive) |

## Service Patterns

| Term | Definition |
|------|-----------|
| **harden** | Systemd serviceConfig helper that applies security hardening (NoNewPrivileges, ProtectSystem, etc.) |
| **hardenUser** | User-service variant of `harden` — omits ProtectHome/ProtectSystem (user namespace) |
| **serviceDefaults** | Systemd defaults for always-running services (Restart=always, start-limit hardening) |
| **serviceOneshotDefaults** | Systemd defaults for one-shot services (Restart=no) |
| **Provisioner** | A `Type=oneshot` + `RemainAfterExit=true` service that bootstraps resources (OIDC clients, alert rules, DB schemas) |
| **restartTriggers** | List of store paths that, when changed, trigger a service restart. Critical for provisioners and static-file-serving services |
| **onFailure** | Alert routing helper that sends a Discord notification when a service fails |
| **waitDnsReady** | DNS-gate dependency that blocks service start until dnsblockd is resolving |
