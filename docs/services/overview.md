# overview (project discovery dashboard)

**Service:** `services.overview` — `modules/nixos/services/overview.nix` wrapping `inputs.overview.nixosModules.default` (upstream owns every option). Port 8083 (`lib/ports.nix`), loopback. URL: `overview.<domain>` (**Layer 2 protected** via the registry — no native auth). DNS `overview`.

Web dashboard over the project fleet (repos, stats, activity), fed by the **project-discovery daemon** — the unix socket at `/run/project-discovery/daemon.sock` is provided by PMA (`services.projects-management-automation`; an eval assertion rejects enabling daemon mode without PMA).

## What it serves

| Route | Auth                        | What                                    |
| ----- | --------------------------- | --------------------------------------- |
| `/`   | forward-auth / open LAN     | Project dashboard                       |

## Ops

- **Hard PMA coupling** — `after`/`wants`/`partOf` PMA: every PMA restart (e.g. its watchdog) bounces Overview; it re-discovers on start. The daemon socket mode is 0666 via `socketMode` in configuration.nix (a locked rev once ignored it — the readiness-gate lesson below).
- **`overview-discovery-watchdog`** — periodic guard: Overview 503 + daemon `/v1/health` HEALTHY ⇒ restart overview (stale 503 discovery failure class). Both-unhealthy = wait (restart wouldn't help).
- **Readiness gates must probe AS THE SERVICE USER** — the `+`-privileged gate once passed green as root while the overview process got EACCES dialing the 0600 socket (the 2026-09-09 start-limit incident; now 0666 + daemon honors `PROJECT_DISCOVERY_SOCKET_MODE`).
- **OTel** — `OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318` (mkDefault; upstream initializes the tracer from it — historically with zero span sites, so it sits in signoz-coverage as a known upstream gap).
- **Monitoring** — Gatus via the registry check + Homepage tile; partOf-chain restarts are expected churn, not incidents.

## Related

- [projects-management-automation.md](./projects-management-automation.md) — the discovery daemon + its watchdog/memory shape
- [papdashboard.md](./papdashboard.md) — the alerting hub (not the project view)
