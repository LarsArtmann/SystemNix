# PapDashboard — dash.home.lan Services Surface Runbook

The alert hub (`https://dash.home.lan`, internal `http://localhost:8088`) serves the
dashboard UI, the alert/question/notification aggregates, and — since the 2026-09-18
homepage merge — a **Services tab**: service tiles with live up/down dots, a host-vitals
strip, bookmarks, and search. It replaced the retired homepage-dashboard (Node/Next.js).
This runbook covers the services surface: config anatomy, dot semantics, deploy probes,
and the rollback path. Product docs: the PapDashboard repo `README.md` (§Services surface).

## Surface map

| Surface                                          | Where                                               | Auth                                                                         |
| ------------------------------------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------- |
| Dashboard UI (tabs: Services first when enabled) | `GET /` via templ                                   | public at the app; auth = Caddy vHost (Layer 2 protected)                    |
| Tiles + live status JSON                         | `GET /api/services`                                 | public at the app (upstream `publicPaths` contract)                          |
| Server-rendered tiles fragment                   | `GET /api/fragments/services`                       | public (same class as `/dashboard.js`)                                       |
| Host vitals JSON (CPU/MEM/TEMP/UPTIME/net/disks) | `GET /api/system`                                   | public (`/metrics` exposure class)                                           |
| Status flips                                     | SSE `service.status` events on `/api/events/stream` | public at the app (SSE can't send headers — why the gate lives at the proxy) |

Auth model note (upstream re-pin 2026-10-08, flake bump `f12d5604` → rev `81201c88`):
the whole browser read surface above is public AT THE APP by pinned upstream contract
(`middleware/auth.go` `publicPaths`, enforced by `cmd/server/auth_invariants_integration_test.go`)
— EventSource cannot attach Authorization headers, so an in-app key gate can never cover the
stream. Access control for the UI is the Caddy `protected` vHost (Pocket ID SSO off-LAN;
`*.home.lan` from the LAN is direct). The app-level `PAP_API_KEY` gate covers the MACHINE
surface only (ingest, forwarder, dead-letter, batch/export); an empty key disables it, hence
the module's `mkSecretCheck` ExecStartPre. This replaced the 2026-09-18 login-overlay
(`pap_session` cookie) model.

## services.json anatomy (where each field comes from)

The file the server reads is **rendered by SystemNix**, never hand-edited:

```
options services.papdashboard.dashboard.*   (module defaults: groups, tiles, search, disks)
  + services.papdashboard.extraTiles        (per-module seam: dashboardTile in integration.nix)
  + services.integration.* fan-out          (every registry module contributes its tile)
  → tileJson/addTile fold → pkgs.formats.json → render
  → environment.etc."papdashboard/services.json"
  → unit env PAP_SERVICES_CONFIG (+ restartTriggers = [servicesConfig])
  + PAP_ICONS_DIR = dashboardIcons          (the icon subset the tiles ask for)
```

- `title` — defaults to `hostName`.
- `search` — SearXNG-gated (`services.searxng.enable` → `https://search.${domain}/search?q=`), else DuckDuckGo.
- `system.disks` — stat-strip disk list (default `/`, `/data`, `/mnt/pool`), temp warn range 30–95 °C.
- `groups[].tiles[]` — `name`, `description`, `href` (also the default probe target), optional `checkUrl`
  for metrics-only tiles, optional `icon` (tile logo — see below).
- **Coverage is enforced (2026-10-25):** every `services.integration` entry with a `subdomain`
  MUST carry a `homepage` tile — an eval-time assertion in `integration.nix` (fails `nix flake
  check`), so a new web-facing service cannot silently miss the Services tab. Registry tiles with
  `icon = null` WARN at eval (owner directive: cosmetic gap, warn don't fail — the tile renders
  its monogram fallback; the §16 pre-deploy gate remains the hard monogram block). Tile
  authoring defaults: `name` derives from the subdomain, `group` defaults to `"Services"`,
  `href` derives `https://<subdomain>.<domain>` — a minimal tile is `homepage = { icon = "x.png"; }`.
  Opt-out for genuinely tile-less web services: `noDashboardTile = true;` + justification comment
  (papdashboard itself and tq-serve are the two live exemptions).
- `bookmarks[]` — link groups, no status.
- The registry key for the module itself is still `homepage` (historical name kept to avoid a
  ~20-module rename; the value's `subdomain` is `dash`). A rename is planned as registry cleanup.

Invalid config = **startup fails loudly** (unit won't start) — there is no silent-degrade mode
(since 2026-10-17 that includes tile icons: a name that is neither a pack file nor an http(s)
URL aborts startup, so `mdi-*`/`si-*` homepage-era names can never come back silently).

## Tile logos (icon pack)

Every tile renders a logo. `icon` is either a file name from the bundled
`homarr-labs/dashboard-icons` pack or an absolute image URL:

```
icon = "<pack file>.png"      →  /icons/<pack file>.png  (served by PapDashboard)
icon = "https://cdn/…/x.svg"  →  used verbatim
icon = null                   →  monogram fallback (registry tiles: eval WARNING since 2026-10-25;
                                the §16 pre-deploy gate blocks monograms for hand-written tiles)
```

- The pack is a **fixed pin in this module** (`iconPackSrc`: homarr-labs/dashboard-icons
  rev + `nix-prefetch-url --unpack` hash) — not a flake input, so the flake-input pin audit
  does not cover it; bump the rev and hash together deliberately.
- **Metric-name naming rule for any SigNoz query you add near this service:** the suffix
  form (dotted vs underscore) is decided by the exporter's TYPE declaration — see
  [docs/agents/monitoring.md](../agents/monitoring.md) "Exporter names vs store names"
  (the 2026-10-17 dotted-query regression was exactly a wrong assumption here; the
  `papdashboard_services_json_*` gauges are plain gauges stored verbatim).
- **Pack bump procedure (executable without re-deriving anything):**
  1. Pick the new upstream rev (the pack moves slowly; no cadence watcher exists — bump
     when a needed icon is missing from the pinned rev, or quarterly at most).
  2. `nix-prefetch-url --unpack https://github.com/homarr-labs/dashboard-icons/archive/<rev>.tar.gz`
     → SRI-encode: `nix hash to-sri --type sha256 <hash-from-stdout>`.
  3. Update BOTH `rev` and `hash` in `iconPackSrc` (modules/nixos/services/papdashboard.nix)
     in one commit — a half-bump fails the FOD with a hash mismatch by design.
  4. `nix build .#nixosConfigurations.evo-x2.config.services.papdashboard.package` — the
     `dashboardIcons` subset build re-runs and IS the existence gate for every icon the
     config references.
  5. Deploy; the post-deploy icon probes (fragment `src="/icons/` + route 200 + immutable)
     verify the new pack serves.
- **No generic fallback glyph in the subset — deliberate (2026-10-17):** the monogram is
  the fallback layer (kept in the DOM, promoted client-side when an `<img>` fails), so a
  missing icon degrades to the monogram everywhere, deterministically. Authoring a cyan
  neutral set remains the owner's open question (docs/todo/services.md).
- `dashboardIcons` copies **only the icons the rendered config asks for** (~40 files, ~1.2 MB
  instead of the full 85 MB pack) and is exported as `PAP_ICONS_DIR`. Referencing it in the
  unit env is what makes it part of the system closure, so the copy IS the missing-icon gate:
  a typo fails the toplevel build with the name and the pack path.
- Two gates, both fail before a deploy can land a logo-less tab: eval-time (**icon FORM**;
  `config.assertions` on `invalidIconTiles`) and build-time (**icon EXISTS** in the pack,
  `dashboardIcons`).
- Upstream PapDashboard mounts `GET /icons/` only when `PAP_ICONS_DIR` is set, serves it
  public + immutable-cached, and keeps the monogram in the DOM as the fallback layer — a lost
  image is dropped client-side by `dashboard.js`, never shown as a broken-image glyph.
- Registry tiles set their icon in the service module's
  `services.integration.<name>.homepage.icon` (bundled pack name); the built-in groups'
  icons live in this module's `dashboard.groups` defaults.
- **Off-LAN determination (2026-10-17, no bypass needed):** `dash.home.lan` is a Layer-2
  **protected** vHost whose template applies `forward_auth` to EVERY path — there is no
  path matcher, so `/icons/*` is intercepted off-LAN like everything else (live-rendered
  Caddyfile verified: `@external not remote_ip 127.0.0.1/8 192.168.1.0/24` → forward_auth
  arm; `handle` arm = direct proxy). Consequences: **on-LAN, no auth anywhere** — tile
  logos load with no cookie (live-probed: `GET /icons/caddy.png` through the vHost → 200 +
  immutable, no auth header). **Off-LAN, an authenticated browser's session cookie rides
  the `<img>` subresource requests** (same-origin, domain-scoped), so logos still load; an
  unauthenticated client never sees the dashboard at all (the page itself redirects to
  SSO). The only degraded shape is a session expiring mid-view → icon requests 302 →
  `dashboard.js` drops the failed `<img>`s → monogram fallback, the designed degradation.
  A `handle_path /icons/*` bypass would make tile artwork world-readable to unauthenticated
  off-LAN clients for zero functional gain — do not add one.

## Tile dot semantics (read before "fixing" a wrong-looking dot)

- The PapDashboard server probes every tile's `checkUrl` (default `href`) **server-side every 30s**.
- **up** = the route answered < 500 **through the Caddy vhost, including an SSO redirect**. A
  login page (302 → Pocket ID) is `up` — that is by design: it proves the route is alive.
- **down** = HTTP ≥ 500, TLS failure, or timeout (e.g. caddy answers 502 because the backend is dead).
- **none** = decorative tile (no URL) — never probed, renders without a dot.
- `service.status` flips are **bus-only SSE**: they are never persisted, and restarts start at
  unknown → first probe resolves. Gatus owns actual uptime history (`status.home.lan`).
- Latency shown in the dot tooltip is the server-side probe round trip.

## Deploy verification (built into post-deploy-check)

`scripts/post-deploy-check.sh` probes the surface on every deploy (all no-key, status-code +
public-fragment based): `/api/services` must 200 with the enabled payload (route + surface
on; 404 = stale flake pin), unauthenticated `GET /api/ingest` must 401 (machine-surface key
gate armed; the auth middleware runs before routing), `/api/system` must 200
with nonzero `memTotalBytes`, `/api/fragments/services` must render group headings + tiles
with zero inline `onclick`, plus the existing `/api/health`, ingest-route, and gatus-ingest-
in-journal checks. **Tile-icon probes (2026-10-17 icon-pack go-live, both fail CLOSED):**
the fragment must carry `src="/icons/` tile imgs (zero = the capability dropped — stale
flake pin or `PAP_ICONS_DIR` unset), the route must serve a fragment-derived icon file with
`Cache-Control: public, max-age=604800, immutable` (the probed file is taken from the
fragment itself, so the probe tracks the config with no hardcoded name). The pre-deploy
counterpart is **§16 of `scripts/pre-deploy-check.sh`**: every pack-relative icon in the
to-be-deployed rendered config must exist in the pinned pack subset (eval of
`dashboard.groups` + `extraTiles` vs `PAP_ICONS_DIR`), zero pack icons fails too, and
since 2026-10-18 COVERAGE fails as well — icons < tiles (a monogram-falling tile) blocks
the deploy, mirroring the runtime `icons_ok` gauge; `--section-16-only` iterates the leg
cheaply. The leg follows the §13/§14 anti-blind-skip discipline (only the module-disabled
eval shape may SKIP). Manual deep-dive:

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

## Deploy evidence (2026-10-17 icon-pack go-live, live-verified)

- Running unit: `papdashboard-a1a505f5` (store path `276sx5y4…`), restarted with the
  2026-10-17 evening deploy wave; `/api/health` 200.
- Fragment probe: **39 `src="/icons/…"` `<img>`s** served by `/api/fragments/services`.
- Through the Caddy vHost, no cookie (protected-vHost LAN bypass):
  `GET /icons/{caddy,miniflux,open-webui}.png` → **200 + `Cache-Control: public,
  max-age=604800, immutable`** + `Content-Type: image/png`.
- Served service worker: `pap-v9` (the icon-era cache generation).
- Deploy-anchor: the wave's raw-stc activation had left `/run/current-system` unanchored
  (profile stuck on gen 926); repaired to gen 927 = the running toplevel, boot entry
  re-armed — a reboot boots the verified state.
- Regression protection live: post-deploy icon probes + pre-deploy §16 inventory
  (fail-closed, both negative-tested), negative-test harness legs `tileicons/*`.

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### PapDashboard (Smart Alerting Hub)

**Module:** `modules/nixos/services/papdashboard.nix` (`services.papdashboard`) — alert lifecycle hub + NPU insight enricher at `dash.home.lan` (Layer 2 `protectedVHost` via the registry, `subdomain = "dash"` — since the upstream auth re-pin (2026-10-08, rev `81201c88`) this is the ONLY auth layer on the browser surface: the app serves the UI + read APIs + SSE public by contract (`publicPaths`, pinned by upstream auth_invariants tests) because EventSource can't attach Authorization headers. The app-level key gate covers the machine surface (ingest etc.); the key is sops `papdashboard_api_key` — the SAME value gatus uses as `PAPDASHBOARD_INGEST_KEY` and tq as `TQ_PAP_API_KEY`). The old `alerts.home.lan` hostname redirects via the caddy catch-all (unknown `*.home.lan` → `dash`). Port 8088 in `lib/ports.nix`.

- **Services dashboard surface (2026-09-18 homepage-dashboard merge):** the module renders `/etc/papdashboard/services.json` (title, tiles/groups, bookmarks, search, host-vitals config) consumed via `PAP_SERVICES_CONFIG`; `restartTriggers` restarts the unit when the rendered file changes. Built-in groups/bookmarks live in the `dashboard` option defaults; every `services.integration.<name>.homepage` registry tile fans into `services.papdashboard.extraTiles` and folds into its named group. Tile status is probed SERVER-SIDE by PapDashboard (30s HTTP probes, bus-only `service.status` events — uptime history stays with Gatus). The dashboard carries NO self-tile (same doctrine as homepage before it). **Smoke follow-up: the post-deploy loopback `Homepage :8082` check was REMOVED with the merge** (the service no longer exists; the check false-FAILED the first post-merge deploy as a NEW-baseline regression). The external vHost check retargets `dash.$DOMAIN`. Rule: when a service is retired/merged, sweep `scripts/post-deploy-check.sh` for its probes in the SAME change.

- **`nixpkgs.follows` DROPPED from the input (2026-09-17, bank-sync/qmd vendorHash doctrine)**: upstream derives its `vendorHash` against ITS pinned buildGoModule — following our nixpkgs invalidated it on every bump (the 2026-09-17 evening wave hunted FOUR revs — bee108c7 stale, e448c8be go-floor, b62272b1 FOD, a3d61685 hash-mismatch `BRdf2HA vs 4VS4RCZ` — all failed under the b1b8759 buildGoModule). With follows dropped the lock subtree comes from upstream's own lock (whose pinned nixpkgs is coincidentally the SAME b1b8759 rev), `ea15eb7a` builds green, and the FOD is stable across OUR bumps. The papdashboard go-modules FOD is also flaky ONCE per fresh tree (a test-phase DI shutdown flake exit-1'd the first package build, passed clean on direct rebuild) — retry once before diagnosing.

- **Dual Discord paths (design):** Gatus keeps its raw fast-path to Discord untouched AND POSTs every trigger/resolve transition to PapDashboard `/api/ingest` via an `alerting.custom` provider (`gatus-config.nix`). PapDashboard's outbound Discord is filtered by `PAP_NOTIFY_SOURCE_APPS=insight`, so Discord receives raw+insight pairs, never duplicates. If PapDashboard dies, raw alerts still flow
- **Gatus custom-provider traps (verified against gatus 5.36.0 source):** (1) `default-alert` does NOT auto-apply — every endpoint must DECLARE an alert of the provider's type; `withPapIngest` maps a `{type="custom";}` entry onto ALL endpoints (wrap the WHOLE endpoints expression — appended `lib.optionals`/`map` segments count too). (2) `os.ExpandEnv` runs file-wide before YAML parse — `$PAPDASHBOARD_INGEST_KEY` in headers IS expanded. (3) `ALERT_TRIGGERED_OR_RESOLVED` remaps TRIGGERED/RESOLVED → `triggered`/`resolved` via the `placeholders` map, yielding PapDashboard's `alert.triggered`/`alert.resolved` event types. (4) OMIT `alerting.custom` when disabled — a present-but-empty provider fails gatus validation (ErrURLNotSet). (5) The alert YAML field is `description:`, NOT `desc:` (yaml.v3 silently dropped `desc:` — descriptions never reached Discord before 2026-08-18)
- **Ingest body contract (live-verified):** huma requires `aggregateId` AND `metadata.{correlationId,causationId}` — the full body shape lives in `gatus-config.nix` with a comment; resolve matches unresolved alerts by `(sourceApp, title)`. **TWO stacked bugs killed every ingest with 405 (2026-08-18, 1076×):** (1) the flake input sat at `e93d2b15`, which PREDATES the `POST /api/ingest` huma registration (`internal/api/api.go`) — the bring-up session "verified" against a LOCAL `-dirty` build and never re-pinned; fixed by `nix flake lock --update-input papdashboard` → `ebbc6fa`. (2) `gatus-config.nix` had `method = "post"` — lowercase. Go's ServeMux matches method tokens CASE-SENSITIVELY (RFC 9110); gatus passes the string through verbatim, so lowercase `post` 405s against a POST-registered route (reproduced on a scratch instance: `post`→405, `POST`→422-validation). `method = "POST"` fixed it — first journal `method=POST status=200` within one gatus cycle. **Verification trap:** an unauthenticated POST probe returning 401 (`missing API key`) proves the ROUTE exists but NOT the method token — the auth middleware runs before routing and masks method mismatch; the only trustworthy signal is the server journal showing `status=200` from gatus itself
- **Insight enricher:** DynamicUser + `SupplementaryGroups = ["systemd-journal"]` (journalctl evidence reads), LLM = FastFlowLM `http://127.0.0.1:52625/v1` (`qwen3.6-moe:35b-a3b`; socket activation wakes the NPU, cold load 1-3 min, LLM timeout 300s default). Best-effort: enricher failures log and drop, never fatal. Insights publish as ordinary notifications (sourceApp `insight`) — free lifecycle/UI/SSE
- **Secrets:** sops `papdashboard.yaml` `papdashboard_api_key` (root-owned; DynamicUser reads via EnvironmentFile template `papdashboard-env`), same key rendered into `gatus-env` as `PAPDASHBOARD_INGEST_KEY`. Outbound insights webhook = dedicated sops `papdashboard-discord.yaml` `papdashboard_insights_webhook_url` (channel 1539383848549486632) since 2026-08-18 — raw Gatus alerts (shared `discord_alert_webhook_url`, signoz.yaml) and LLM insights land in TWO separate Discord channels; switch channels by updating the sops key and re-deploying
- **Evidence sources (module options):** `journalUnits` (gatus/caddy/**dnsblockd** — fixed 2026-08-18: the default said `dns-blocker.service`, a unit that never existed, silently blinding DNS evidence; pointless 2min TimeoutStartSec dropped same day) + `evidenceURLs` (node exporter). Caddy admin :2019 metrics is NOT usable as evidence (bare-localhost Host gets 403). Deploy smoke (post-deploy-check): `/api/health` 200, unauthenticated `/api/ingest` → 401 = route exists (404 = stale flake pin, 405 = method-case bug), gatus ingest 200s in the journal (`path=/api/ingest status=200`) — 401-only probes can never catch method/body bugs
- Session narrative + smoke-test evidence: `docs/status/archived/2026-08-18_14-51_smart-alerting-round3-lint-specs-systemnix-wiring.md`
