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
| Monitoring | Gatus "mr-sync Dashboard" (`/` renders HTML, 5m interval — rides the data cache); `mr-sync-dashboard` in system-health `extraMonitoredServices` |
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

- **Gatus interval is 5m on purpose** — a cold collect du-walks every repo in
  `~/projects` + `~/forks` (QLC). The 60s cache means probes usually ride
  data warmed by the user's own browsing; `[RESPONSE_TIME] < 15000` + client
  `timeout 20s` absorb cold walks without flapping.
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
