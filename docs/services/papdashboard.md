# PapDashboard — dash.home.lan Services Surface Runbook

The alert hub (`https://dash.home.lan`, internal `http://localhost:8088`) serves the
dashboard UI, the alert/question/notification aggregates, and — since the 2026-09-18
homepage merge — a **Services tab**: service tiles with live up/down dots, a host-vitals
strip, bookmarks, and search. It replaced the retired homepage-dashboard (Node/Next.js).
This runbook covers the services surface: config anatomy, dot semantics, deploy probes,
and the rollback path. Product docs: the PapDashboard repo `README.md` (§Services surface).

## Surface map

| Surface | Where | Auth |
| --- | --- | --- |
| Dashboard UI (tabs: Services first when enabled) | `GET /` via templ | public (assets public by design) |
| Tiles + live status JSON | `GET /api/services` | API key (401 without) |
| Server-rendered tiles fragment | `GET /api/fragments/services` | public (same class as `/dashboard.js`) |
| Host vitals JSON (CPU/MEM/TEMP/UPTIME/net/disks) | `GET /api/system` | public (`/metrics` exposure class) |
| Status flips | SSE `service.status` events on `/api/events/stream` | public stream |

## services.json anatomy (where each field comes from)

The file the server reads is **rendered by SystemNix**, never hand-edited:

```
options services.papdashboard.dashboard.*   (module defaults: groups, tiles, search, disks)
  + services.papdashboard.extraTiles        (per-module seam: dashboardTile in integration.nix)
  + services.integration.* fan-out          (every registry module contributes its tile)
  → tileJson/addTile fold → pkgs.formats.json → render
  → environment.etc."papdashboard/services.json"
  → unit env PAP_SERVICES_CONFIG (+ restartTriggers = [servicesConfig])
```

- `title` — defaults to `hostName`.
- `search` — SearXNG-gated (`services.searxng.enable` → `https://search.${domain}/search?q=`), else DuckDuckGo.
- `system.disks` — stat-strip disk list (default `/`, `/data`, `/mnt/pool`), temp warn range 30–95 °C.
- `groups[].tiles[]` — `name`, `description`, `url` (also the default probe target), optional `checkUrl`
  for metrics-only tiles, optional `icon` (accepted, ignored).
- `bookmarks[]` — link groups, no status.
- The registry key for the module itself is still `homepage` (historical name kept to avoid a
  ~20-module rename; the value's `subdomain` is `dash`). A rename is planned as registry cleanup.

Invalid config = **startup fails loudly** (unit won't start) — there is no silent-degrade mode.

## Tile dot semantics (read before "fixing" a wrong-looking dot)

- The PapDashboard server probes every tile's `checkUrl` (default `url`) **server-side every 30s**.
- **up** = the route answered < 500 **through the Caddy vhost, including an SSO redirect**. A
  login page (302 → Pocket ID) is `up` — that is by design: it proves the route is alive.
- **down** = HTTP ≥ 500, TLS failure, or timeout (e.g. caddy answers 502 because the backend is dead).
- **none** = decorative tile (no URL) — never probed, renders without a dot.
- `service.status` flips are **bus-only SSE**: they are never persisted, and restarts start at
  unknown → first probe resolves. Gatus owns actual uptime history (`status.home.lan`).
- Latency shown in the dot tooltip is the server-side probe round trip.

## Deploy verification (built into post-deploy-check)

`scripts/post-deploy-check.sh` probes the surface on every deploy (all no-key, status-code +
public-fragment based): `/api/services` must 401 (route + auth gate), `/api/system` must 200
with nonzero `memTotalBytes`, `/api/fragments/services` must render group headings + tiles
with zero inline `onclick`, plus the existing `/api/health`, ingest-route, and gatus-ingest-
in-journal checks. Manual deep-dive:

```bash
journalctl -u papdashboard -n 50          # boot order: listener bind BEFORE first probe cycle
journalctl -u papdashboard --grep 'path=/api/ingest status=200' --since -30min --no-pager
curl -s localhost:8088/api/system | jq '.memTotalBytes'
```

## Rollback (restore homepage-dashboard)

The retirement is three logical changes, all inside the 2026-09-18 merge wave
(`13107a2e` deleted `modules/nixos/services/homepage.nix`; the same wave flipped
`subdomain = "alerts"` → `"dash"` in `papdashboard.nix`, dropped the Gatus "Homepage"
check, and removed `homepage = 8082` from `lib/ports.nix`):

1. Confirm you really want this — it un-deploys the tiles surface AND the alert-hub vhost
   rename. The services surface itself can be disabled per-host by setting
   `services.papdashboard.enable = false;` instead.
2. `git revert 13107a2e` (or `git checkout <pre-merge-rev> -- modules/nixos/services/homepage.nix lib/ports.nix modules/nixos/services/gatus-config.nix`) — restores the module, port, and Gatus check.
3. In `modules/nixos/services/papdashboard.nix`, flip the registry entry's `subdomain` back to
   `"alerts"` (or remove the module's vhost claim entirely).
4. Re-enable in `platforms/nixos/system/configuration.nix` (`homepage.enable = true;`).
5. Deploy (`scripts/deploy.sh`) and verify: `dash.home.lan` serves homepage again,
   `alerts.home.lan` serves PapDashboard, `systemctl status homepage-dashboard`.

Nix-level instant fallback (before any git action): `nixos-rebuild switch --rollback` to the
pre-merge generation — the homepage retirement and the merge ship in the same generation, so
rollback restores BOTH at once.

## Deploy evidence (2026-09-18 merge went live)

- Running system: configuration revision `7f4c78d2`, services.json activated 2026-09-18 ~16:32
  (store path `71wzqgbgpdcwm1diifp70vn44sqjjk32-services.json`; re-eval of the config at
  `01eac4ae` produced the identical path — live == current config, no drift).
- Post-deploy-check: all 8 PapDashboard checks green (incl. the 5 new services probes);
  gatus → `/api/ingest` 200s visible in the journal.
- Tile census at validation: 25 up, 2 down (`mr-sync`, `tq` — both verified genuine 502
  backends, truthful dots), 10 decorative.
- `alerts.home.lan` → 301 → `https://dash.home.lan` via the catch-all vhost.
- homepage-dashboard unit absent, port 8082 free.
