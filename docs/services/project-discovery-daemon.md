# project-discovery-daemon (+ admin WebUI bridge)

Standalone discovery daemon owning `/run/project-discovery/daemon.sock` for
ALL consumers (overview, PMA, editor tooling). It pays the ~7GB full-
discovery spike ONCE per refresh so consumers stay thin (overview runs
unprivileged at ~250MB). Upstream:
`github:LarsArtmann/project-discovery-daemon` (private, git+ssh input).

**Delegated 2026-11-08**: the deployment contract (options, unit shape,
socket-start contract, portable hardening) lives in the upstream
`nixosModules.default`; this repo layers only site specifics in
`modules/nixos/services/project-discovery-daemon.nix`.

## Daemon

- **Unit**: `project-discovery-daemon.service` — `Type=notify` with
  `WatchdogSec=30s` (the daemon is a VERIFIED `WATCHDOG=1` sd_notify sender
  at half-interval; the bridge is not — see below). "Started" means the
  SOCKET exists: the upstream `ExecStartPost` wait fails the unit if the
  socket never appears.
- **User**: the primary user (`lars`) — discovery runs git INSIDE the
  search-path repos and reads `~/.mrconfig`; a dedicated 0700-home service
  user cannot. Search path: `~/projects` (the Samsung subvol — the unit
  carries a `RequiresMountsFor` mount gate so it never indexes the stale
  `@` shadow).
- **Cache**: hot-cache TTL 24h (ceiling only — the file watcher + 60s
  background refresh keep entries fresh per-change).
- **Socket mode**: `0666` — preserves the PMA-era access model until
  consumer users are group-managed (then tighten to `0660` + a shared
  group).
- **Resources**: `MemoryMax=8G` / `MemoryHigh=7G` (the measured ~7GB
  full-discovery spike passes the high mark; 8G is the OOM bound),
  `CPUQuota=400%`, ioTier **BE/6 background** — this daemon is the top
  sustained root-NVMe reader on the host (discovery latency is invisible
  to consumers behind the 5m+ TTL cache, but its bursts starve the
  desktop if untiered).

## Admin WebUI bridge (`project-discovery-admin.service`)

Loopback dashboard for the daemon (added 2026-11-18): the bridge binary
(`packages.admin` from the same upstream flake) talks to the daemon socket
via the public `DaemonClient` and serves an embedded single-file dashboard
on **`127.0.0.1:8765`** (`ports.project-discovery-admin`) — metrics, cache,
refresh, consumers, providers, and a live watch feed over one multiplexed
SSE stream. Backend stays loopback-only; externally the page is published
as `discover.<domain>` behind forward-auth (protected layer, 2026-11-22) —
it exposes project paths and daemon metrics, so plain exposure was
rejected; LAN clients pass via the fleet-wide bypass.

- Endpoints: `GET /` (dashboard), `GET /api/health` (one-shot health
  envelope), `GET /api/metrics`, `GET /api/events` (SSE).
- Registry fan-out: `subdomain = "discover"` (also listed in
  `platforms/common/dns-local.nix`), `vHost.layer = "protected"`, and the
  PapDashboard tile **Project Discovery** (`folder.png` from the pinned
  dashboard-icons pack — build-gated, no URL icon because the bridge ships
  no favicon).
- `Type=exec`, NO `WatchdogSec` (the bridge has no sd_notify sender —
  WatchdogSec without one is a guaranteed watchdog kill). It **wants**
  (not requires) the daemon: while the daemon is down it serves explicit
  `{"reachable":false}` envelopes — a degraded dashboard beats a stopped
  one.
- Light 2s poller over the unix socket: `MemoryMax=512M`, ioTier **BE/6
  background** (uniform with the daemon — the io-tier-coverage audit
  requires every boot-gated unit to carry a tier).

## Monitoring

Gatus could never dial the unix socket directly; the bridge is the
sanctioned HTTP window (registry entry `project-discovery-admin`,
`vHost.layer="protected"` — published as `discover.<domain>` behind
forward-auth since 2026-11-22; backend stays loopback — gatus probes
`127.0.0.1:8765` directly and never traverses oauth2-proxy):

1. `project-discovery dashboard` — `GET /` 200 + <500ms (bridge liveness).
2. `project-discovery daemon` — `GET /api/health` 200 AND body
   `pat(*"reachable":true*)` — the FIRST functional daemon check (200
   alone only proves the bridge; `reachable:true` proves the daemon
   answered on the socket). Degraded daemon health still answers
   `reachable:true` with a worse `status` field — liveness vs health is
   the daemon's own truth-chain contract (`/v1/health` answers 200 when
   degraded).

### SigNoz / OTEL posture (live-probed 2026-11-22)

- **Logs: flowing.** The fleet journald OTel receiver ingests
  `project-discovery-daemon.service` — 56 entries fresh to the minute in
  `signoz_logs.logs_v2`. This is the ONLY SigNoz plane the daemon touches.
- **Traces: none.** The daemon has NO OpenTelemetry SDK (zero
  `go.opentelemetry.io` deps in `go.mod`), neither unit sets
  `OTEL_EXPORTER_OTLP_ENDPOINT` (verified in rendered units), and
  `signoz_traces.distributed_signoz_index_v3` has zero spans for any
  discovery serviceName. It is NOT registered in
  `services.signoz-coverage.expected` (consistent — no OTLP env, so the
  eval gate does not fire; no spans → never on the Services page, which
  is trace-driven).
- **Metrics: exposed but unscraped.** The daemon serves a real Prometheus
  registry (`promhttp`, `project_discovery_*` + hot-cache families) on
  its unix-socket `/metrics`; the bridge re-serves it as **JSON**
  (`/api/metrics`, `application/json`) — not a Prometheus exposition
  format, so the signoz collector cannot scrape it, no collector job
  exists, and `signoz_metrics.time_series_v4` has zero daemon series.
  Gatus consumes only `/api/health` + the dashboard.
- **Full OTEL verdict: NO.** Wiring paths if ever wanted: (a) traces —
  OTel SDK + `OTEL_EXPORTER_OTLP_ENDPOINT` env on the unit + a
  `services.signoz-coverage.expected` row (`wiring = "env"`); (b)
  metrics — needs a Prometheus-TEXT surface first (e.g. bridge proxying
  the exposition format), then a `project-discovery` scrape job in
  `signoz.nix`. The daemon's `TraceHandler`/flightrecorder is a runtime
  debug capture, not distributed tracing.

## vendorHash shim — THREE surfaces

The upstream flake does not follow our input pins (its own lock governs
the FOD content), so lock floats go stale through our graph. When the FOD
fails, re-derive via `buildflow -s nix-hash-fix --fix` evidence and move
ALL THREE surfaces together (same value — identical `go.mod`):

1. `modules/nixos/services/project-discovery-daemon.nix` → daemon `package`
2. same module → `admin.package`
3. `lib/lars-packages.nix` → PATH surface

**Currently DROPPED (2026-11-18):** the 64f5f1b lock float refreshed
pdd's nested go-daemon/SDK inputs to match its flake.nix URL rev pins, so
both FODs produce the hash upstream itself bakes (`Nldg+4vI…`). Re-add
only when a future float re-drifts, with nix-hash-fix evidence.

## Ops

- Redeploy runbook (upstream): `deploy/README.md` in the project repo —
  `nix build .#default .#admin`, swap binaries, restart units, verify via
  `/v1/health` (socket) and `/api/health` (bridge).
- Lock float: probe-before-lock — build the target rev outside the lock
  first, then `nix flake update project-discovery-daemon`.
- Consumers: `overview` (`daemonSocket = unix:///run/project-discovery/
  daemon.sock`) and editor tooling; PMA's co-located daemon is OFF
  (`enableDiscoveryDaemon = false`, flipped 2026-09-07) — only ONE daemon
  may bind the socket.
