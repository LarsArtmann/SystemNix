# mr-sync (Repo Portfolio Dashboard)

`mr-sync.home.lan` — read-only web dashboard for the `mr-sync` CLI
(github:LarsArtmann/mr-sync): repo portfolio, disk status of local clones,
recommended sync actions, live SSE updates. Module:
`modules/nixos/services/mr-sync.nix` (`services.mr-sync-dashboard`).

## Architecture

| Piece      | Value                                                                                                                                           |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| UI/API     | `https://mr-sync.home.lan` — Layer 2 `protectedVHost` (oauth2-proxy for external, LAN bypass)                                                   |
| Listen     | `127.0.0.1:7331` (`lib/ports.nix` `mr-sync` — the tool's own default port)                                                                      |
| Runs as    | `lars` (primaryUser), `ProtectHome = read-only` — the dashboard is read-only by design                                                          |
| Config     | The user's LIVE `~/.config/mr-sync/config.json` (mrconfig_path, scan_dirs, exclude_repos)                                                       |
| Data       | `~/.mrconfig` + full `computeDirSize` walk of `~/projects` + `~/forks`, cached 60s (5s on fetch errors, single-flight)                          |
| GitHub     | `GITHUB_TOKEN` from sops (`mr_sync_github_token`, env-file format `GITHUB_TOKEN=…`)                                                             |
| Monitoring | Gatus "mr-sync Dashboard" (liveness on `/favicon.ico`, 5m interval; the only route off the data collector); `mr-sync-dashboard` in system-health `extraMonitoredServices` |
| Backup     | none — read-only, no state                                                                                                                      |

## WHY it runs as the primary user

`/home/lars` is mode 0700 and the dashboard reads `~/.mrconfig`,
`~/.config/mr-sync/config.json`, and walks `~/projects`/`~/forks` for per-repo
disk sizes. Any other user (incl. DynamicUser) cannot traverse
(browser-history-agent / tq-serve precedent). `ProtectHome = read-only` keeps
that access one-way; upstream documents the dashboard as read-only ("To
execute actions, use the CLI commands").

## WHY no bearer token

Upstream REQUIRES `--token` only for non-localhost binds
(`dashboard.token_required` rejection). The service binds loopback behind
Caddy, and the protected vHost layer owns external auth via Pocket ID —
same posture as tq-serve / Homepage. Adding `--token` would also put the
secret on the process command line (`/proc/<pid>/cmdline`).

## GitHub token (go-live)

Until a real PAT is pasted, the GitHub fetch fails and the dashboard degrades
gracefully: FetchError banner + data filled from `.mrconfig` and the local
scan only (verified in `dashboard_data.go` `fillFromMrconfig`).

Paste a fine-grained PAT (Contents: read-only) into the placeholder:

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops platforms/nixos/secrets/mr-sync.yaml
# replace the PLACEHOLDER value of mr_sync_github_token with: GITHUB_TOKEN=github_pat_…
```

`sops` rotation restarts `mr-sync-dashboard.service` automatically
(`restartUnits`). With a working token the portfolio gains fork/push status
and the data cache sits at the 60s TTL instead of re-fetching every 5s.

## Gotchas

- **Gatus probes `/favicon.ico`, never `/` (since 2026-11-25)** — every page
  and API route rebuilds the portfolio synchronously on a cache miss (60s
  TTL, single-flight; disk scan + git subprocesses across `~/projects` +
  `~/forks` on the QLC). A cold rebuild took ≈25s on a calm box
  (2026-11-17) and 15.4s / 53s in two replays under io PSI ~45%
  (2026-11-25); the 53s one outran the server's own 30s `WriteTimeout`
  and came back empty. No probe budget absorbs that: the former `/` probe
  (`[RESPONSE_TIME] < 15000`, client `timeout 20s`) paged "down" 12x
  between 2026-11-17 and 2026-11-24 while the process was healthy.
  `/favicon.ico` serves the embedded SVG without touching the collector
  (4ms under that same storm): `[STATUS] == 200`, `[BODY] ==
  pat(*<svg*)`, `[RESPONSE_TIME] < 2000`, client `timeout 5s`. The 5m
  interval stays because a deploy can stop the unit for minutes and a
  faster cadence would read that gap as an outage. The slow rebuild itself
  is upstream work (serve stale + background rebuild,
  `docs/todo/services.md`).
- **`mr-sync` the CLI vs the dashboard** — the CLI rides PATH via
  `mkLarsPackages`; this module only deploys the `dashboard` subcommand. The
  upstream `nixosModules.default` (autonomous sync TIMER) is a separate
  module (`services.mr-sync`) that runs `reconcile` as a real user with `gh`
  CLI auth — deliberately NOT enabled here; enabling it later must not
  collide with this unit name.
- **Config auto-save edge** — if `~/.config/mr-sync/config.json` is ever
  deleted, upstream tries to re-create it under `ProtectHome = read-only`
  and the unit fails loudly into start-limit + onFailure. Restore the file
  (or run `mr-sync sync` once as lars) to clear.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### mr-sync (Repo Portfolio Dashboard, 2026-09-16)

**Module:** `modules/nixos/services/mr-sync.nix` (`services.mr-sync-dashboard`) — the `mr-sync dashboard` web surface of the mr-sync CLI at `mr-sync.home.lan` (Layer 2 `protectedVHost`), port 7331 (`mr-sync`, the tool's default), DNS `mr-sync`. Runbook: `docs/services/mr-sync.md`. The CLI itself stays PATH-only via `mkLarsPackages`; the upstream `nixosModules.default` (autonomous sync timer, `services.mr-sync`) is deliberately NOT enabled — no name collision, but enabling it later means two `mr-sync*` units.

- **Runs as `primaryUser` with `ProtectHome = read-only`** — the dashboard reads the LIVE `~/.mrconfig` + `~/.config/mr-sync/config.json` and du-walks `~/projects` + `~/forks`; `/home/lars` is 0700 so no other user can traverse (browser-history-agent/tq precedent). Upstream documents the dashboard read-only; if the user config is ever DELETED, upstream tries to auto-save it and the unit fails loudly under read-only home (restore the file to clear).
- **No bearer token by design**: upstream demands `--token` only for non-localhost binds; loopback + protected layer owns external auth (tq-serve posture), and a token would sit on `/proc/<pid>/cmdline`. GITHUB_TOKEN comes from sops `mr-sync.yaml` `mr_sync_github_token` (env-file format, root-owned, PID1-read) — ships as PLACEHOLDER, dashboard degrades gracefully (FetchError banner + `.mrconfig`/local-scan data only, verified in `fillFromMrconfig`); paste a fine-grained PAT per the runbook, rotation restarts the unit.
- **Gatus liveness rides `/favicon.ico` (since 2026-11-25)**: data collection is cached 60s (5s on fetch errors) and rebuilt synchronously by any page or API route on a cache miss (a cold rebuild runs the disk scan + git across every repo on the QLC NVMe: ≈25s calm, 15.4s / 53s in two replays under io PSI ~45%), so the old `/` probe with `[RESPONSE_TIME] < 15000` + client `timeout = 20s` straddled the rebuild time and paged "down" 12x between 2026-11-17 and 2026-11-24 while the process was healthy. Conditions are now `[STATUS] == 200`, `[BODY] == pat(*<svg*)`, `[RESPONSE_TIME] < 2000`, client `timeout = 5s`; the 5m interval is kept so a deploy's multi-minute unit stop cannot read as three consecutive failures.
- **OUTAGE + FIX (2026-10-01): the unit NEVER STARTED between 2026-09-16 and 2026-10-01** — the module shipped without `wantedBy`, so nothing ever pulled it into a boot transaction: no boot start, no `stc` start at deploys (units outside the transaction are not started), no deploy.sh entry (Type=simple, not a converger oneshot). Evidence: zero `mr-sync-dashboard.service` journal entries across ALL boots since 2026-09-15, `system_service_active{service="mr-sync-dashboard"} 0`, port 7331 refused, Gatus red since the check shipped. The Gatus/DNS/Caddy/sops surfaces were all present and green-by-config — only the daemon was absent (health-dashboard 2026-09-22 lesson class: "defined, monitored, smoke-checked, but NEVER started"). Fix: `wantedBy = [ "multi-user.target" ]` on the unit; deploys start newly-enabled units at activation, so the next `nix run .#deploy` (or any reboot) brings it up.
- **DEPLOYED + LIVE-VERIFIED (2026-10-01 ~19:00, agent session):** the `wantedBy` fix is live — the unit starts at boot (journal: started on all three 10-01 boots, latest 18:57), `127.0.0.1:7331` answers, and `/` + `/api/data` serve the full portfolio through the Caddy LAN bypass at `https://mr-sync.home.lan/` (425 repos). **GitHub auth verdict:** the live process env carries `GITHUB_TOKEN=PLACEHOLDER-…` (the sops placeholder) → the REST fetcher 401s on every call (`[rejection:github.http.failed] GitHub API returned HTTP 401`) → the dashboard runs the DESIGNED degraded mode: FetchError banner + `github_tracked: 0` + `.mrconfig`/disk-scan data only. This is expected until the go-live paste above happens; nothing else is pending on the deployment side.
