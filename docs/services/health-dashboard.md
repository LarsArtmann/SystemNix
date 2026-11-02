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
| Runs as    | DynamicUser — stateless: no home, no StateDirectory, no secrets                                                           |
| Remotes    | `services.health-dashboard.remotes` — `name=url` pairs fetched fresh on every read (merge-on-read, 5s per-fetch deadline) |
| Trend      | `HEALTH_HUB_TREND=1` (default) — in-memory ring, ~1h at the 2s push cadence, timeline card in the UI                      |
| Monitoring | Gatus "Health Hub" (`/healthz` liveness) + "Health Hub Federation" (`/readyz` — the aggregate pager); system-health       |
| Backup     | none — stateless                                                                                                          |

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

Usually you don't even get here manually: the `health-dashboard-rediscover`
timer (below) fails loudly with the exact line to add the day after a
service starts speaking go-health.

## Who federates today (full-registry sweep, 2026-11-02)

EIGHT remotes — every go-health speaker on the host, found by sweeping ALL
77 `lib/ports.nix` ports on `/health`, `/readyz`, `/healthz` with
`Accept: application/json` (a go-health document = status
pass/warn/fail/off AND a `checks` object):

| Remote | Port/Path | Notes |
| ------ | --------- | ----- |
| `cv` | 8098 `/health` | first remote (2026-09-19) |
| `discordsync` | 8085 `/health` | its `/readyz` is a custom OTel document — `/health` is the go-health one |
| `renamer` | 8086 `/health` | file-and-image-renamer main daemon |
| `renamer-watcher` | 8089 `/health` | the watcher's own healthd (port split 2026-10-29) |
| `tq` | 8100 `/health` | go-taskqueue serve dashboard |
| `pma` | 9420 `/readyz` | no `/health`; `/healthz` is a liveness-only empty-checks stub |
| `dnsblockd` | 9090 `/readyz` | the STATS port serves the canonical go-health document (blocklist-sources/database/dns checks), not just Prometheus |
| `nsfw` | 8104 `/health` | nsfw-classifier |

Still custom-JSON (NOT federatable without adopting go-health upstream):
monitor365 (`{"status":"ok",...}` + rate-limited `/healthz`), overview,
browser-history (`"ok"` + checks in its own shape), inboxclean, geometrikks
(HTML), gatus-alert-relay, bank-sync/papdashboard/media-atlas
(`{"status":"up"}`), miniflux (HTML/plain). Federation refuses any of
these as a permanent `name/reachable` FAIL row — a service joins by
adopting go-health, not by being added to `remotes`.

## The rediscover drift sweep (2026-11-02)

The list above was stale for five weeks — the 2026-09-22 inventory said
"only CV speaks go-health", four-plus services adopted go-health v0.8.x
silently, and nothing re-probed. `health-dashboard-rediscover.service`
(daily, 15m after boot, Persistent) re-runs the exact sweep minus the hub
itself (self-federation would recurse) and FAILS via `onFailure` with the
exact `remotes` line to add when a registry port serves a go-health
document that is not federated. Connection-refused, 4xx/5xx and
undecodable bodies are skipped — the only failure mode is positive
go-health evidence, so there is no false-positive class by construction
(validated live against all 77 registry ports: with the 8 federated the
sweep exits clean).

Why not DNS autodiscovery: `*.home.lan` records DERIVE from the platform
catalog (ADR-008), but the catalog carries no health-PROTOCOL marker and
the hub binary consumes a static `HEALTH_HUB_REMOTES` env — blind
derivation from `healthPath` would federate every custom-JSON service
into permanent FAIL rows. The runtime sweep is the honest equivalent of
autodiscovery for this fleet; true DNS/SRV discovery would be an upstream
health-hub feature.

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

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Health Hub (federated go-health dashboard, 2026-09-19, deploy pending)

**Module:** `modules/nixos/services/health-dashboard.nix` (`services.health-dashboard`) — runs the `health-hub` binary from the upstream `go-health-dashboard` flake input (`github:LarsArtmann/go-health-dashboard?ref=master`, package pinned by the input's lock rev, NEVER a `git+file:` pin). It federates N remote go-health documents into one dashboard at `health.home.lan` (Layer 2 `protectedVHost`, DNS `health`, port 8103, loopback bind `127.0.0.1`), one card per remote via `GroupBySource`. Runbook: `docs/services/health-dashboard.md`; upstream docs: go-health-dashboard README "Federation Hub Binary".

- **Remotes come from `services.health-dashboard.remotes`** as `name=url` strings rendered into `HEALTH_HUB_REMOTES` (comma-joined). Constraint: names/URLs must not contain spaces or commas — systemd splits `Environment=` values on whitespace and the binary splits entries on commas; the binary's `parseRemotes` rejects whitespace-in-name and non-http(s) URLs fail-fast at startup with the offending entry named.
- **The module shipped 2026-09-19 WITHOUT `wantedBy` — defined, monitored, smoke-checked, but NEVER started** (fixed 2026-09-22: `wantedBy = [ "multi-user.target" ]` added after the unit showed zero journal entries since creation and the vHost 502'd; the smoke's enable-gate tested the bare unit FILE instead of the `.wants` symlink and its HTTPS probe hit `/`, which the hub binary legitimately 404s — both gates now key on the symlink + `/healthz`). Bring-up checklist lesson: a new service needs wantedBy + one verified unit start + a correctly-gated smoke BEFORE the first deploy carries it.
- **Gatus semantics:** "Health Hub" watches `/healthz` (liveness = process up). "Health Hub Federation" watches `/readyz` — the AGGREGATE: `warn` from any remote does NOT trip it (go-health marks non-critical failing checks `warn`; only `fail` or a dark remote's `name/reachable` row does), `[RESPONSE_TIME] < 8000` because merge-on-read fetches every remote synchronously. Keep client timeout above the hub's per-fetch deadline.
- **Fetch load is a live decision:** merge-on-read at the default 2s push cadence ≈ 43k requests/remote/day per remote. First remote = CV (`127.0.0.1:${ports.cv}/health`); adding remotes is one `remotes = [ ... ]` line + re-deploy. Exposing cadence/timeout as module options is parked in TODO_LIST.
- **Homepage tile icon is an MDI string** (`mdi-heart-pulse`) like every other module — a guessed `*.png` filename silently renders a broken/blank tile (caught in the 2026-09-19 harvest).
- **Upstream coupling:** the hub binary needs go ≥ 1.27.1 (upstream floor) and its `federation` dependency is consumed from go-health master until v0.3.0 is tagged (re-pin parked in go-health-dashboard TODO_LIST). The deployed binary stamps its build rev on startup (`build <rev>` log line) — verify it matches the lock rev after deploy.
