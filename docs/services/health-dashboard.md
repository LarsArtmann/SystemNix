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

**Why only CV federates today (fleet inventory, live-probed 2026-09-22):**
the remote URL must serve go-health `Response` JSON — the hub always sends
`Accept: application/json` and an undecodable body becomes a permanent
`name/reachable` FAIL row, never a skip. CV (:8098) is the only go-health
instance in the fleet: inboxclean/overview/browser-history/papdashboard/
geometrikks serve custom health JSON, file-and-image-renamer/
discordsync/tq serve HTML dashboards, llama-rag serves llama.cpp's
`{"status":"ok"}`, and monitor365-server/crush-daily/pma-health answer 404
or nothing on `/health`. A service joins the hub by adopting go-health (or
exposing a go-health-shaped probe), not by being added to `remotes`.

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

