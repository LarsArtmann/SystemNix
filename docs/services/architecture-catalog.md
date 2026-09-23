# architecture-catalog (Federated EventCatalog Hub)

`catalog.home.lan` — a license-free, zero-runtime-daemon EventCatalog of
every service's events/commands/services, built by CI and served as a static
tree. Upstream hub repo: `github.com/LarsArtmann/eventcatalog-hub` (mirrored
at `forgejo.home.lan/lars/eventcatalog-hub`). Module:
`modules/nixos/services/architecture-catalog.nix`
(`services.architecture-catalog`). Plan:
`docs/planning/2026-09-22_23-27_EVENTCATALOG-FEDERATION-HUB.md`; execution
record: `docs/status/2026-09-23_13-26_eventcatalog-hub-session3-t5-t13-executed.md`.

## Architecture (owner-decided Option B — license-free)

| Piece      | Value                                                                                                                            |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| UI         | `https://catalog.home.lan` — Layer 2 `protected` STATIC vHost (oauth2-proxy for external, LAN bypass, `file_server`; no port, no daemon) |
| Serving root | `/var/lib/architecture-catalog/current` — RELATIVE symlink into `generations/<timestamp>` (keep 3), all files `a+rX` for Caddy  |
| Sync       | `architecture-catalog-sync.service` (oneshot) + hourly `Persistent` timer — depth-1 clone of the hub's `dist` branch              |
| Freshness  | `architecture-catalog-metrics` (5-min textfile collector) → `architecture_catalog_*` gauges                                        |
| Monitoring | Gatus "Architecture Catalog" (+ llms.txt, silent) + "Architecture Catalog Freshness"; `architecture-catalog-sync` in system-health |
| Backup     | none — fully rebuildable from the `dist` branch                                                                                   |
| AI surface | `/llms.txt` + `/schemas.txt` (MCP server is Scale-license gated — deliberately not wired)                                          |

Data flow: each source repo's Go binary exports an EventCatalog tree
(bank-sync: `bank-sync catalog --format eventcatalog`; cqrs-htmx:
`examples/catalog-demo -eventcatalog … -export-only`) → hub CI (Forgejo
Actions, nightly 03:23 + push-triggered) union-merges sources, lints, builds
`dist/`, pushes the `dist` branch → the sync unit pulls it hourly, gates on
`index.html`, atomically swaps `current`, prunes to 3 generations.

## Go-live checklist (owner steps, in order)

1. `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` — mints
   the read-scoped `GIT_CLONE_TOKEN`, creates the hub pull mirror, enables
   Actions, mirror-syncs source repos, dispatches the first run.
2. Watch `https://forgejo.home.lan/lars/eventcatalog-hub/actions` — expect
   green + a `dist` branch. First-run watch-list: nix-shell for the runner
   user, `jq` on the runner, job-token git-push (PUSH_TOKEN fallback
   documented in the workflow).
3. Paste the minted token:
   `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/architecture-catalog.yaml`
   — keep the env-file format `ARCHITECTURE_CATALOG_SYNC_TOKEN=<token>`.
4. `nix run .#deploy` (the module + DNS + smoke §15 are already in-tree),
   then `nix run .#post-deploy-check` — §15 stops warning once
   `/var/lib/architecture-catalog/current/index.html` exists.
5. Converge immediately instead of waiting for the timer:
   `sudo systemctl start architecture-catalog-sync`, then watch Gatus.

## PLACEHOLDER-inert pre-go-live behavior (by design)

Until step 3 lands a real token, the sync unit exits 0 with a journal WARN
(skip, never a crash loop), `architecture_catalog_dist_present 0` /
`fresh 0` report honest absence, and the Gatus checks stay RED as the
standing not-live-yet signal (discordsync-Turso doctrine — do not silence
them). The vHost serves 404s meanwhile (no `current` symlink).

## Freshness semantics

The CI writes `build-stamp.json` (`builtAt`) into `dist/`. The collector
derives `architecture_catalog_stamp_age_seconds` and flips
`architecture_catalog_fresh` at `freshMaxAgeHours` (36h default: nightly
builds are <24h; 36h absorbs one missed nightly). Fail-closed: a scrape
failure emits ONLY `architecture_catalog_scrape_errors 1` so the anchored
Gatus pats go red instead of phantom-greening on a frozen textfile. Dist
present but stamp unreadable = scrape error (unexpected tree). "Freshness"
pages when EITHER the hub CI stopped building OR the sync stopped pulling
while the last-good generation keeps serving — the alert text names both
debug targets.

## Operations

- **Manual sync:** `sudo systemctl start architecture-catalog-sync` (idempotent;
  a fresh generation every run, pruned to `maxGenerations`).
- **Rollback:** `sudo ln -s generations/<older-stamp> /var/lib/architecture-catalog/.current.tmp && sudo mv -T /var/lib/architecture-catalog/.current.tmp /var/lib/architecture-catalog/current`
  — same atomic-rename shape the sync uses; `current` must stay a RELATIVE
  symlink (it is swapped via `mv -T`, never edited in place).
- **Token rotation:** mint a new read-scoped PAT in Forgejo, sops-paste it
  (step 3 shape). The sops secret's `restartUnits` restarts the sync unit, so
  a rotation converges within one tick.
- **Adding a source:** hub-repo change, not a deploy — add the entry to
  `sources.json` (build + export commands + tree path) per its README; CI
  picks it up on the next run. Onboarding a NEW repo means teaching it the
  export convention first (go-cqrs-lite `catalog/README.md`).
- **Nothing lands in deploy.sh:** the `-sync` unit matches no converger
  pattern and the hourly `Persistent` timer converges after every
  boot/deploy on its own.

## Breaking-change gates (governance)

EventCatalog's built-in Architecture Change Detection is Scale-license
gated; the license-free recipe lives in the hub repo
(`scripts/check-architecture-changes.sh` + README wiring) and runs in SOURCE
repos' PR pipelines — it fails on event/service removal, same-version
schema changes, and producer/consumer shrinkage. Structured diffs arrive
when go-cqrs-lite ships `catalog.index.json` (routed in its TODO_LIST).

## Linter posture

The hub lints the MERGED tree in CI (`@eventcatalog/linter` via
`.eventcatalogrc.js`); two rules ride at `warn` pending exporter upgrades
(`refs/resource-exists` — unversioned service dirs; `best-practices/owner-required`
— message owners). Strict `linkValidation` (broken links/anchors = error) is
always on. Re-arm triggers are documented in the hub TODO_LIST.

## Gotchas

- The Gatus title pattern `pat(*<title>EventCatalog*)` was verified against
  a REAL dist build — EventCatalog's config `title` does not reach the
  template. Do not "fix" it to a config-derived pattern.
- The metrics collector had a doubled-`then` syntax bug found and fixed
  2026-09-23 BEFORE first deploy (raw `script =` strings are NOT linted —
  only eval-checked; `bash -n` the extracted text when touching it).
- The sync needs DNS (dnsblockd answering `forgejo.home.lan`) — `mkDnsGate`
  budget 180s covers the boot blocklist load; gate-timeout floor enforced by
  `gate-timeout-audit.nix`.
- Clone failures journal with the token REDACTED (sed over the captured
  stderr) — never loosen that.
