# PapDashboard — dash.home.lan Services Surface Runbook

The alert hub (`https://dash.home.lan`, internal `http://localhost:8088`) serves the
dashboard UI, the alert/question/notification aggregates, and — since the 2026-09-18
homepage merge — a **Services tab**: service tiles with live up/down dots, a host-vitals
strip, bookmarks, and search. It replaced the retired homepage-dashboard (Node/Next.js).
This runbook covers the services surface: config anatomy, dot semantics, deploy probes,
and the rollback path. Product docs: the PapDashboard repo `README.md` (§Services surface).

## Surface map

| Surface                                          | Where                                               | Auth                                   |
| ------------------------------------------------ | --------------------------------------------------- | -------------------------------------- |
| Dashboard UI (tabs: Services first when enabled) | `GET /` via templ                                   | public (assets public by design)       |
| Tiles + live status JSON                         | `GET /api/services`                                 | API key (401 without)                  |
| Server-rendered tiles fragment                   | `GET /api/fragments/services`                       | public (same class as `/dashboard.js`) |
| Host vitals JSON (CPU/MEM/TEMP/UPTIME/net/disks) | `GET /api/system`                                   | public (`/metrics` exposure class)     |
| Status flips                                     | SSE `service.status` events on `/api/events/stream` | public stream                          |

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

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### PapDashboard (Smart Alerting Hub)

**Module:** `modules/nixos/services/papdashboard.nix` (`services.papdashboard`) — alert lifecycle hub + NPU insight enricher at `dash.home.lan` (Layer 2 `protectedVHost` via the registry, `subdomain = "dash"`; the UI has no built-in auth, only the ingest API is key-gated). The old `alerts.home.lan` hostname redirects via the caddy catch-all (unknown `*.home.lan` → `dash`). Port 8088 in `lib/ports.nix`.

- **Services dashboard surface (2026-09-18 homepage-dashboard merge):** the module renders `/etc/papdashboard/services.json` (title, tiles/groups, bookmarks, search, host-vitals config) consumed via `PAP_SERVICES_CONFIG`; `restartTriggers` restarts the unit when the rendered file changes. Built-in groups/bookmarks live in the `dashboard` option defaults; every `services.integration.<name>.homepage` registry tile fans into `services.papdashboard.extraTiles` and folds into its named group. Tile status is probed SERVER-SIDE by PapDashboard (30s HTTP probes, bus-only `service.status` events — uptime history stays with Gatus). The dashboard carries NO self-tile (same doctrine as homepage before it). **Smoke follow-up: the post-deploy loopback `Homepage :8082` check was REMOVED with the merge** (the service no longer exists; the check false-FAILED the first post-merge deploy as a NEW-baseline regression). The external vHost check retargets `dash.$DOMAIN`. Rule: when a service is retired/merged, sweep `scripts/post-deploy-check.sh` for its probes in the SAME change.

- **`nixpkgs.follows` DROPPED from the input (2026-09-17, bank-sync/qmd vendorHash doctrine)**: upstream derives its `vendorHash` against ITS pinned buildGoModule — following our nixpkgs invalidated it on every bump (the 2026-09-17 evening wave hunted FOUR revs — bee108c7 stale, e448c8be go-floor, b62272b1 FOD, a3d61685 hash-mismatch `BRdf2HA vs 4VS4RCZ` — all failed under the b1b8759 buildGoModule). With follows dropped the lock subtree comes from upstream's own lock (whose pinned nixpkgs is coincidentally the SAME b1b8759 rev), `ea15eb7a` builds green, and the FOD is stable across OUR bumps. The papdashboard go-modules FOD is also flaky ONCE per fresh tree (a test-phase DI shutdown flake exit-1'd the first package build, passed clean on direct rebuild) — retry once before diagnosing.

- **Dual Discord paths (design):** Gatus keeps its raw fast-path to Discord untouched AND POSTs every trigger/resolve transition to PapDashboard `/api/ingest` via an `alerting.custom` provider (`gatus-config.nix`). PapDashboard's outbound Discord is filtered by `PAP_NOTIFY_SOURCE_APPS=insight`, so Discord receives raw+insight pairs, never duplicates. If PapDashboard dies, raw alerts still flow
- **Gatus custom-provider traps (verified against gatus 5.36.0 source):** (1) `default-alert` does NOT auto-apply — every endpoint must DECLARE an alert of the provider's type; `withPapIngest` maps a `{type="custom";}` entry onto ALL endpoints (wrap the WHOLE endpoints expression — appended `lib.optionals`/`map` segments count too). (2) `os.ExpandEnv` runs file-wide before YAML parse — `$PAPDASHBOARD_INGEST_KEY` in headers IS expanded. (3) `ALERT_TRIGGERED_OR_RESOLVED` remaps TRIGGERED/RESOLVED → `triggered`/`resolved` via the `placeholders` map, yielding PapDashboard's `alert.triggered`/`alert.resolved` event types. (4) OMIT `alerting.custom` when disabled — a present-but-empty provider fails gatus validation (ErrURLNotSet). (5) The alert YAML field is `description:`, NOT `desc:` (yaml.v3 silently dropped `desc:` — descriptions never reached Discord before 2026-08-18)
- **Ingest body contract (live-verified):** huma requires `aggregateId` AND `metadata.{correlationId,causationId}` — the full body shape lives in `gatus-config.nix` with a comment; resolve matches unresolved alerts by `(sourceApp, title)`. **TWO stacked bugs killed every ingest with 405 (2026-08-18, 1076×):** (1) the flake input sat at `e93d2b15`, which PREDATES the `POST /api/ingest` huma registration (`internal/api/api.go`) — the bring-up session "verified" against a LOCAL `-dirty` build and never re-pinned; fixed by `nix flake lock --update-input papdashboard` → `ebbc6fa`. (2) `gatus-config.nix` had `method = "post"` — lowercase. Go's ServeMux matches method tokens CASE-SENSITIVELY (RFC 9110); gatus passes the string through verbatim, so lowercase `post` 405s against a POST-registered route (reproduced on a scratch instance: `post`→405, `POST`→422-validation). `method = "POST"` fixed it — first journal `method=POST status=200` within one gatus cycle. **Verification trap:** an unauthenticated POST probe returning 401 (`missing API key`) proves the ROUTE exists but NOT the method token — the auth middleware runs before routing and masks method mismatch; the only trustworthy signal is the server journal showing `status=200` from gatus itself
- **Insight enricher:** DynamicUser + `SupplementaryGroups = ["systemd-journal"]` (journalctl evidence reads), LLM = FastFlowLM `http://127.0.0.1:52625/v1` (`qwen3.6-moe:35b-a3b`; socket activation wakes the NPU, cold load 1-3 min, LLM timeout 300s default). Best-effort: enricher failures log and drop, never fatal. Insights publish as ordinary notifications (sourceApp `insight`) — free lifecycle/UI/SSE
- **Secrets:** sops `papdashboard.yaml` `papdashboard_api_key` (root-owned; DynamicUser reads via EnvironmentFile template `papdashboard-env`), same key rendered into `gatus-env` as `PAPDASHBOARD_INGEST_KEY`. Outbound insights webhook = dedicated sops `papdashboard-discord.yaml` `papdashboard_insights_webhook_url` (channel 1539383848549486632) since 2026-08-18 — raw Gatus alerts (shared `discord_alert_webhook_url`, signoz.yaml) and LLM insights land in TWO separate Discord channels; switch channels by updating the sops key and re-deploying
- **Evidence sources (module options):** `journalUnits` (gatus/caddy/**dnsblockd** — fixed 2026-08-18: the default said `dns-blocker.service`, a unit that never existed, silently blinding DNS evidence; pointless 2min TimeoutStartSec dropped same day) + `evidenceURLs` (node exporter). Caddy admin :2019 metrics is NOT usable as evidence (bare-localhost Host gets 403). Deploy smoke (post-deploy-check): `/api/health` 200, unauthenticated `/api/ingest` → 401 = route exists (404 = stale flake pin, 405 = method-case bug), gatus ingest 200s in the journal (`path=/api/ingest status=200`) — 401-only probes can never catch method/body bugs
- Session narrative + smoke-test evidence: `docs/status/archived/2026-08-18_14-51_smart-alerting-round3-lint-specs-systemnix-wiring.md`

