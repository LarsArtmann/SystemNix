# quotaboard (AI coding-plan quota dashboard)

`quotaboard.home.lan` — live usage bars for the Z.ai GLM and Synthetic.new
coding plans (github:LarsArtmann/quotaboard): web UI, `/history` analytics,
`GET /api/quotas` JSON, and the DankMaterialShell bar widget that polls the
same API. LAN-exposed and always-on since 2026-11-25 (owner request); before
that it was a session-scoped loopback tool behind the bar widget only.

## Architecture

| Piece        | Value                                                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UI/API       | `https://quotaboard.home.lan` — Layer 2 `protectedVHost` (oauth2-proxy for external clients, LAN bypass)                                 |
| Listen       | `127.0.0.1:8791` (`lib/ports.nix` `quotaboard` — the app's own compiled-in default)                                                                      |
| Unit         | `quotaboard.service` — USER unit of the primary user, **always-on** (wanted by `default.target`; starts at boot through linger)                          |
| Server owner | upstream home-manager module `quotaboard.homeModules.quotaboard`, consumed in `platforms/nixos/desktop/quickshell.nix`                                  |
| Exposure     | `modules/nixos/services/quotaboard.nix` — the registry entry: vHost, Gatus checks, dashboard tile, tile icon                                            |
| Secrets      | `sops.templates."quotaboard-env"` (`ZAI_API_KEY` + `SYNTHETIC_API_KEY` — re-renders the existing crush / crush-daily subscription keys, `sops.nix`)     |
| Data         | `~/.local/state/quotaboard/quotaboard.db` (sqlite history, `StateDirectory=`) — lives under `/home`, so the `@` snapshots cover it; no backup registry entry |
| Monitoring   | Gatus "Quotaboard ready" (`/health/ready`, 30s) and "Quotaboard quotas API" (`/api/quotas` envelope, 60s), group `AI`                                  |
| Dashboard    | PapDashboard tile "Quotaboard" (group `AI`), icon = the product's own `static/favicon.svg` from the locked source rev                                   |

## Why the unit is always-on (2026-11-25)

Upstream's home module binds the unit to `graphical-session.target`
(`PartOf` / `After` / `WantedBy`) — the right default for a bar-widget-only
loopback tool. With a LAN vHost in front, session-scoping means a 502 tile
at the SDDM greeter, in SSH-only periods and after every crash reboot until
someone logs in. So `quickshell.nix` overrides exactly those three keys
(`PartOf = []`, `After = []`, `WantedBy = [ "default.target" ]`) and nothing
else: `ExecStart`, `Type=notify`, `StateDirectory` and hardening stay
upstream's single definition.

The contract is held by three rails:

- **Linger is declared and asserted.** `users.users.<primaryUser>.linger = true`
  (`platforms/nixos/system/configuration.nix`) pins what had been an
  imperative `loginctl enable-linger`; the exposure module fails eval when it
  is not set (without a boot-time user manager the unit only starts at first
  login).
- **`session-boot-audit.nix`** already polices every unit reachable from
  `default.target` — the override removes all references to
  `graphical-session.target`, so nothing pulls the session target into the
  boot transaction.
- **Both Gatus checks page unconditionally** — unlike emeet-pixyd (still
  session-scoped, silent endpoint checks + a session-aware meta check),
  expected-down no longer exists for this service.

Boot ordering needs no gate: sops renders
`/run/secrets/rendered/quotaboard-env` in the initrd stage, before the user
manager starts (journal 2026-11-25 11:06:54 vs 11:07:00), and the server
tolerates network/DNS arriving late — provider fetch failures are journaled
and retried on every refresh interval.

First activation: Home Manager's `sd-switch` starts an inactive unit that is
wanted by an active target, so the switch that lands this binding starts the
server by itself — no manual `systemctl --user start`.

## Operating

- State and logs: `systemctl --user status quotaboard`,
  `journalctl --user -u quotaboard -n 50` (failed fetches carry
  `consecutive_failures=N`, recovery has its own line).
- The env file is read at unit start: a rotated key reaches a running server
  on its next restart (a deploy that changes the unit, or a reboot).
- Deploy smoke: `scripts/post-deploy-check.sh` probes `/api/quotas` (envelope
  `"generatedAt"`) and `/health` on loopback, and the auth-gateway leg covers
  `https://quotaboard.home.lan` through the derived `/etc/caddy/vhost-layers`
  list. A refusal is a real regression; until 2026-11-25 it was the
  expected-down class that produced the 2026-11-23 NEW-failure exit 3.

## Gotchas

- **`monitored = false` is deliberate.** system-health's unit probes read the
  system bus and never see a user unit (emeet-pixyd precedent); a dead or
  crash-looping server trips the two Gatus checks instead.
- **One switch owns server and exposure.** The registry entry follows the
  home-manager `services.quotaboard.enable` of the primary user (read through
  `config.home-manager.users`), so "vHost without a backend" cannot be
  declared. Disabling the server in `quickshell.nix` removes the vHost, the
  checks and the tile with it.
- **No `hostOverride` on the vHost.** `POST /refresh` is same-origin only
  (the browser's `Origin` must equal the request host), so the original
  `Host` header must reach the backend; a cross-origin refresh answers 403
  (probed against the deployed binary 2026-11-25).
- **Two `X-Frame-Options` headers is expected.** appkit emits `DENY` and
  Caddy's `commonConfig` adds `SAMEORIGIN`; the stricter one wins, so the
  dashboard cannot be framed (no `frameAncestors` consumer).
- **Tile icon bytes come from the flake input source**, not from a running
  service or an absolute URL: `inputs.quotaboard + "/static/favicon.svg"` is
  the same locked rev the binary builds from (timesheets precedent).
