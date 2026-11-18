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
SSE stream. Loopback ONLY: the page exposes project paths and daemon
metrics without authentication.

- Endpoints: `GET /` (dashboard), `GET /api/health` (one-shot health
  envelope), `GET /api/metrics`, `GET /api/events` (SSE).
- `Type=exec`, NO `WatchdogSec` (the bridge has no sd_notify sender —
  WatchdogSec without one is a guaranteed watchdog kill). It **wants**
  (not requires) the daemon: while the daemon is down it serves explicit
  `{"reachable":false}` envelopes — a degraded dashboard beats a stopped
  one.
- Light 2s poller over the unix socket: `MemoryMax=512M`, no ioTier.

## Monitoring

Gatus could never dial the unix socket directly; the bridge is the
sanctioned HTTP window (registry entry `project-discovery-admin`,
`vHost.layer="none"`, loopback):

1. `project-discovery dashboard` — `GET /` 200 + <500ms (bridge liveness).
2. `project-discovery daemon` — `GET /api/health` 200 AND body
   `pat(*"reachable":true*)` — the FIRST functional daemon check (200
   alone only proves the bridge; `reachable:true` proves the daemon
   answered on the socket). Degraded daemon health still answers
   `reachable:true` with a worse `status` field — liveness vs health is
   the daemon's own truth-chain contract (`/v1/health` answers 200 when
   degraded).

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
