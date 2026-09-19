# health-dashboard (Federated go-health Hub)

`health.home.lan` — one dashboard federating every service's existing
go-health endpoint (github:LarsArtmann/go-health-dashboard, `health-hub`
binary). Module: `modules/nixos/services/health-dashboard.nix`
(`services.health-dashboard`). The hub renders one card per remote with
`name/check` keys (worst-of status); a dark remote shows a
`name/reachable` FAIL row instead of silently freezing at its last state.

## Architecture

| Piece      | Value                                                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------------------------------------- |
| UI/API     | `https://health.home.lan` — Layer 2 `protected` vHost (oauth2-proxy for external, LAN bypass)                             |
| Listen     | `127.0.0.1:8103` (`lib/ports.nix` `health-dashboard`, via `HEALTH_HUB_ADDR`)                                              |
| Runs as    | DynamicUser — stateless: no home, no StateDirectory, no secrets                                                          |
| Remotes    | `services.health-dashboard.remotes` — `name=url` pairs fetched fresh on every read (merge-on-read, 5s per-fetch deadline) |
| Trend      | `HEALTH_HUB_TREND=1` (default) — in-memory ring, ~1h at the 2s push cadence, timeline card in the UI                       |
| Monitoring | Gatus "Health Hub" (`/healthz` liveness) + "Health Hub Federation" (`/readyz` — the aggregate pager); system-health       |
| Backup     | none — stateless                                                                                                         |

## Adding a remote

Any deployed go-health instance federates with zero changes: a bare probe's
readiness handler, or any go-health-dashboard route (the hub always sends
`Accept: application/json`, which triggers the dashboard's JSON
negotiation).

1. Add the pair to `services.health-dashboard.remotes` in
   `platforms/nixos/system/configuration.nix` (loopback URL when the
   service lives on this host, e.g. `cv=http://127.0.0.1:8098/health`).
2. Names namespace check keys — unique, non-empty, no `/`, no whitespace.
3. Deploy; the hub fails FAST at startup on a malformed pair (eval-time
   assertion also requires a non-empty list).
4. Pre-flight for manual bind tests: confirm the port is actually free
   first (`ss -tln | grep 8103`) — never assume from memory.

## Readiness semantics (why `/readyz` pages)

The hub's `/readyz` merges every remote: 200 pass/warn, 503 when any
federated service reports `fail` or is unreachable. That makes the
"Health Hub Federation" Gatus check an aggregate pager — a critical check
ANYWHERE pages here even when the owning service's own 200-liveness stays
green. Per-service specifics stay on the owning service's own checks;
the hub's dashboard names the culprit (`name/reachable` row).

## The endpoint-domain enforcement chain

This module is the worked example of the fleet rule the user asked for:
`services.integration.health-dashboard` declares `subdomain = "health"`,
and `integration.nix` asserts at eval time that the subdomain is in
`platforms/common/dns-local.nix` — a service cannot ship a web surface
without its DNS record. Both halves live in the same change; the
`dnsMissing` assertion fails `nix flake check` otherwise.

## Upstream

The binary comes from the go-health-dashboard flake
(`packages.health-hub` — buildGoModule on go_1_27 with
`GOEXPERIMENT=jsonv2` for go-sse's encoding/json/v2). go.mod pins
go-health master (federation) as a pseudo-version until v0.3.0 is
tagged; re-pin to the tag on the next input bump.
