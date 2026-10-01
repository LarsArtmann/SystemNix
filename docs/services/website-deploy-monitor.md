# website-deploy-monitor (larsartmann.com freshness)

**Service:** `services.website-deploy-monitor` — `modules/nixos/services/website-deploy-monitor.nix`. A user-level timer + desktop-notification service (via `mkDesktopNotifyService`): polls the production site's `/build-info.json` `builtAt` marker and notifies the desktop when it is older than `maxAgeDays`.

Why it exists: GitHub Actions scheduled jobs are billing-blocked (the 2026-08-14 class — the site's CI ran ~10h dead with zero jobs and no notification reached anyone), so the always-on NixOS box watches deploy freshness instead.

## Ops

- **Alert-once semantics** — a stale build alerts ONCE (state file `~/.local/state/website-deploy-monitor/last-alerted-built-at`), not on every tick; a fresh deploy clears the state. Uptime/availability of the site itself is NOT this check's job (fetch failure = log + exit 0 — deliberate degradation, every capture `|| true`'d so a network transient cannot fail the unit; that exact bug was the 2026-08-30 "long-failed units" root cause).
- **Fix action on alert** — the notification names it: CI is billing-blocked; run `pnpm run deploy` (in the website repo).
- **No vHost, no port, no Gatus check** — a desktop notification pipeline only; the unit timer is the cadence owner.

## Related

- [docs/agents/monitoring.md](../agents/monitoring.md) — why freshness markers (not liveness) catch dead-CI classes
