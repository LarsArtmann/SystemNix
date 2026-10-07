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

| Piece        | Value                                                                                                                                    |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| UI           | `https://catalog.home.lan` — Layer 2 `protected` STATIC vHost (oauth2-proxy for external, LAN bypass, `file_server`; no port, no daemon) |
| Serving root | `/var/lib/architecture-catalog/current` — RELATIVE symlink into `generations/<timestamp>` (keep 3), all files `a+rX` for Caddy           |
| Sync         | `architecture-catalog-sync.service` (oneshot) + hourly `Persistent` timer — depth-1 clone of the hub's `dist` branch                     |
| Freshness    | `architecture-catalog-metrics` (5-min textfile collector) → `architecture_catalog_*` gauges                                              |
| Monitoring   | Gatus "Architecture Catalog" (+ llms.txt, silent) + "Architecture Catalog Freshness"; `architecture-catalog-sync` in system-health       |
| Backup       | none — fully rebuildable from the `dist` branch                                                                                          |
| AI surface   | `/llms.txt` + `/schemas.txt` (MCP server is Scale-license gated — deliberately not wired)                                                |

Data flow: each source repo's Go binary exports an EventCatalog tree
(bank-sync: `bank-sync catalog --format eventcatalog`; cqrs-htmx:
`examples/catalog-demo -eventcatalog … -export-only`) → hub CI (Forgejo
Actions, nightly 03:23 + push-triggered) union-merges sources, lints, builds
`dist/`, pushes the `dist` branch → the sync unit pulls it hourly, gates on
`index.html`, atomically swaps `current`, prunes to 3 generations.

## Go-live checklist (owner steps, in order)

0. Deploy the SystemNix generation carrying the runner PATH fix (nix, jq,
   python3 on `gitea-runner-evo-x2` — forgejo.nix). The hub workflow parses
   sources.json with `jq`, runs `merge.py` with `python3`, and shells go via
   `nix shell nixpkgs#go_1_27`; without the PATH fix the first CI run fails
   at `jq` (command not found).
1. forgejo must be UP first (2026-10-07 live-verified prereq): the
   Samsung-subvol G1 finalize must have landed — until it does,
   `forgejo.service` (and the whole family) condition-skips on the missing
   `.subvol-migrated` marker and everything 502s. Owner:
   `sudo ./scripts/migrate-forgejo-subvol.sh finalize` (+ `nix run .#deploy`),
   then probe `https://forgejo.home.lan` answers. Open rows:
   `docs/todo/services.md` G1 entries.
2. `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` — mints
   the read-scoped `GIT_CLONE_TOKEN`, creates the hub pull mirror, enables
   Actions, mirror-syncs source repos, dispatches the first run, and stores
   the SERVING-side sync token at
   `/var/lib/forgejo/.eventcatalog-hub-setup/sync-token` (root-only 0600).
   Re-runnable: it rotates the CI + sync tokens instead of failing on the
   unique token-name constraint.
3. Watch `https://forgejo.home.lan/lars/eventcatalog-hub/actions` — expect
   green + a `dist` branch. First-run watch-list: nix-daemon reachability
   for the DynamicUser runner, `npm` resolving inside the runner PATH
   (nodejs rides it), job-token git-push (PUSH_TOKEN fallback documented in
   the workflow).
4. Paste the sync token (read from the root-only file, never printed):
   ```
   SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/architecture-catalog.yaml
   ```
   — keep the env-file format `ARCHITECTURE_CATALOG_SYNC_TOKEN=<token>`,
   reading the token via `sudo cat /var/lib/forgejo/.eventcatalog-hub-setup/sync-token`.
5. `nix run .#deploy` (the module + DNS + smoke §15 are already in-tree),
   then `nix run .#post-deploy-check` — §15 stops warning once
   `/var/lib/architecture-catalog/current/index.html` exists.
6. Converge immediately instead of waiting for the timer:
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
repos' PR pipelines — it fails on message removal (events/commands/queries,
incl. a whole kind tree vanishing), service removal, same-version
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
- Host-mode CI jobs inherit the runner UNIT's PATH — the nixpkgs module's
  default set lacks `nix`/`jq`/`python3`; forgejo.nix's runner override adds
  them. New workflow tooling must either ride those or extend that list.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Architecture Catalog (federated EventCatalog hub, 2026-09-23, deploy owner-gated)

**Module:** `modules/nixos/services/architecture-catalog.nix` (`services.architecture-catalog`) — serves the STATIC `dist/` tree that the `eventcatalog-hub` CI (Forgejo runner, bare-host) publishes to the `dist` branch of `forgejo.home.lan/lars/eventcatalog-hub`, at `catalog.home.lan` (Layer 2 `protected` STATIC vHost — registry entry with `vHost.root`, NO port, NO daemon; caddy.nix gained the `root`-based `staticVHost` renderer and integration.nix the `vHost.root` option + relaxed `vhostIncomplete` for root-without-port). Plan: `docs/planning/2026-09-22_23-27_EVENTCATALOG-FEDERATION-HUB.md`; runbook (go-live checklist, ops, semantics): `docs/services/architecture-catalog.md`; execution record: `docs/status/2026-09-23_13-26_eventcatalog-hub-session3-t5-t13-executed.md`.

- **Zero runtime daemons by design (owner Option B, license-free):** the box only PULLS. `architecture-catalog-sync` (hourly Persistent oneshot, `mkDnsGate`-gated, token-REDACTED depth-1 clone of the `dist` branch) gates on `index.html`, `chmod -R a+rX`, atomically swaps the RELATIVE `current` symlink (`mv -T`, never `ln -sfn` — readers can catch the unlink gap), prunes to `maxGenerations` (3). EventCatalog's MCP server, federation, and Architecture Change Detection are ALL Scale-license gated — llms.txt/schemas.txt are the agent surface, and breaking-change gates are the hub's free diff recipe (`scripts/check-architecture-changes.sh`, mirrors the paid semantics: message removal across events/commands/queries incl. whole-kind-tree disappearance, service removal, same-version schema change, producer/consumer shrinkage → exit 1; fixture-tested 8 scenarios).
- **PLACEHOLDER-inert until go-live:** sops `architecture-catalog.yaml` (`ARCHITECTURE_CATALOG_SYNC_TOKEN`, root-owned env-file) ships PLACEHOLDER; the sync unit skips cleanly (exit 0 + WARN) and the 3 Gatus checks stay RED as the standing not-live-yet signal (discordsync-Turso doctrine). Go-live = `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` (idempotent — revoke-before-mint rotates both PATs; mints the serving-side sync token to root-only `/var/lib/forgejo/.eventcatalog-hub-setup/sync-token`, value never printed) → watch first CI run → sops-paste the sync token from that file → deploy → `sudo systemctl start architecture-catalog-sync`. Freshness: `architecture_catalog_fresh` from CI's `build-stamp.json` (`builtAt`), 36h budget (nightly 03:23 + push builds are <24h; one missed nightly tolerated), collector fail-closed (scrape error emits ONLY `scrape_errors 1`).
- **Runner-unit PATH is the host-mode CI job PATH contract (fixed 2026-09-30, landed `0751be6a`):** `gitea-runner-<host>` jobs run on the bare host and inherit the RUNNER UNIT's PATH — the nixpkgs forgejo-runner module's default set carries neither `nix`, `jq`, nor `python3`, so the hub workflow's first `build.yml` run would have died at the first `jq` call. forgejo.nix adds `path = [ pkgs.nix pkgs.jq pkgs.python3 ]` to the runner unit override; future workflow steps either ride this PATH or extend it. Deploy prerequisite: this generation must be live BEFORE the setup script's first dispatch (runbook step 0).
- **`wantedBy` lesson from health-dashboard was applied pre-emptively** but a different bug class shipped instead: the metrics collector's raw `script = ''''` string carried a doubled `then` (`]; then; then`) — a shell SYNTAX error invisible to `nix flake check` (only eval-checked) that would have killed the collector at first runtime; caught + fixed 2026-09-23 pre-deploy by `bash -n`-ing the extracted text (all 4 collector paths + all sync guards functionally fixture-tested). Rule: raw systemd `script` strings are NOT linted — `bash -n` the extracted text whenever touching them.
- **No deploy.sh entry (verified against `deploy-restart-audit`):** `architecture-catalog-sync` matches no converger pattern; the hourly Persistent timer converges after every boot/deploy. The `-metrics` collector rides its own 5-min timer (mktemp+CAP_FOWNER textfile pattern).
- **Sources live in the hub repo, not SystemNix:** `sources.json` (bank-sync + cqrs-htmx demo today) — adding a source is a hub-repo change picked up by the next CI run; new repos adopt the export convention first (go-cqrs-lite `catalog/README.md`, `catalog/cmd/catalog-export` template). Upstream exporter follow-ups (`catalog.index.json`, skip-bootstrap, versioned-dir ref format, message owners) are routed in go-cqrs-lite's TODO_LIST; hub-owned follow-ups in the hub's TODO_LIST; SystemNix-owned (VM test, SigNoz tile) in `docs/todo/services.md`.
