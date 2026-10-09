# overview (project discovery dashboard)

**Service:** `services.overview` — `modules/nixos/services/overview.nix` wrapping `inputs.overview.nixosModules.default` (upstream owns every option). Port 8083 (`lib/ports.nix`), loopback. URL: `overview.<domain>` (**Layer 2 protected** via the registry — no native auth). DNS `overview`.

Web dashboard over the project fleet (repos, stats, activity), fed by the **project-discovery daemon** — the standalone `project-discovery-daemon.service` owns the unix socket at `/run/project-discovery/daemon.sock` (2026-09-07 flip out of PMA; the flip's leftovers — overview's deps still pointing at PMA, PMA still co-declaring the socket's RuntimeDirectory — were completed 2026-10-08).

## What it serves

| Route | Auth                    | What              |
| ----- | ----------------------- | ----------------- |
| `/`   | forward-auth / open LAN | Project dashboard |

## Ops

- **Daemon coupling (rewired 2026-10-08)** — `after`/`wants`/`partOf` `project-discovery-daemon.service` (the socket OWNER): daemon restarts bounce Overview and it re-discovers on start; PMA restarts no longer touch it (previously `partOf` PMA — an incomplete-2026-09-07-flip leftover that bounced overview on every PMA deploy/restart). The daemon socket mode is 0666 via `socketMode` in configuration.nix (a locked rev once ignored it — the readiness-gate lesson below).
- **Ghost-socket incident (2026-10-07 16:28 → 2026-10-08 ~19:40, ~26h crash-loop)** — PMA's upstream module still declared `RuntimeDirectory=project-discovery` (pre-flip leftover); PMA's deploy-stop flushed `/run/project-discovery/`, unlinking the LIVE daemon's socket, and PMA's restart recreated the dir empty. The daemon stayed `active` but unreachable → the (correct) 60s daemon-gate exit-1'd → restart loop to start-limit. Fix triple: PMA `RuntimeDirectory = lib.mkForce []` (exactly one dir owner), daemon `ExecStartPost` socket-existence start-contract, and systemd-shape-audit class 6 (eval-fails any RuntimeDirectory declared by more than one unit).
- **`overview-discovery-watchdog`** — periodic guard: Overview 503 + daemon `/v1/health` HEALTHY ⇒ restart overview (stale 503 discovery failure class). Both-unhealthy = wait (restart wouldn't help).
- **Readiness gates must probe AS THE SERVICE USER** — the `+`-privileged gate once passed green as root while the overview process got EACCES dialing the 0600 socket (the 2026-09-09 start-limit incident; now 0666 + daemon honors `PROJECT_DISCOVERY_SOCKET_MODE`).
- **OTel** — `OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318` (mkDefault; upstream initializes the tracer from it — historically with zero span sites, so it sits in signoz-coverage as a known upstream gap).
- **Monitoring** — Gatus via the registry check + Homepage tile; partOf-chain restarts are expected churn, not incidents.

## Related

- [projects-management-automation.md](./projects-management-automation.md) — the discovery daemon + its watchdog/memory shape
- [papdashboard.md](./papdashboard.md) — the alerting hub (not the project view)
