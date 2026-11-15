# media-atlas triple break: diagnosis + upstream fix + live verification

**Session:** 2026-11-15 ~08:00 → 12:3x · **Question:** "why is media atlas broken?"
**Answer:** three independent breakages, all fixed upstream (`LarsArtmann/media-atlas` `3e3c3ea`), all LIVE on evo-x2 via gen 1012 and verified end-to-end on the real prod state.

## a) What was actually broken

| # | Symptom | Root cause | State |
| --- | --- | --- | --- |
| 1 | Nightly UMAP refit crash-looped **8 nights** (2026-11-08..15, last success Nov 07) — `media-atlas-umap` died every night at `pickle.load`, `AttributeError: 'NNDescent' object has no attribute 'search_tree_leaf_budget'` | Pickle-schema drift: a nixpkgs float moved the python env to the 3.14.10-era pins; the new pynndescent renamed the NNDescent attr (`search_tree_leaf_size` → `search_tree_leaf_budget`), and the persisted `umap/model/model.pkl` predates the bump. `umap_fit.py --mode auto` decided fit-vs-transform by FILE EXISTENCE, so every night picked transform → died at load. Map coordinates never refreshed | FIXED + self-healing |
| 2 | Map plate never showed data in ANY browser: `/api/assets` → HTTP 401 (zero 200s on the endpoint since the OQ-5 key gate landed) | Design gap: the hub gates `/api`, `/events`, `/thumb` behind its single API key while `map.js` fetched headerless; no caddy injection (deliberate: "the key stays out of caddy config") and no UI key path — the product shipped broken-by-construction | FIXED (paste-once key path) |
| 3 | `media-atlas.service` "Failed to start" ×3 (2026-11-12 20:50, 11-13 11:32, 11-14 09:24) — `start operation timed out` → SIGKILL → `result 'timeout'` | NOT the watchdog: the hub needs >90 s to reach READY on cold boots / IO storms (journal replay over the big atlas.db under load); systemd's 90 s default `TimeoutStartSec` killed it mid-start; every restart succeeded once IO calmed | FIXED (`TimeoutStartSec=5min`, live) |

## b) The fix (upstream `media-atlas` `3e3c3ea`, pushed 2026-11-15 ~08:4x)

One commit, five files, A/B-verified before push (repo gates green: `go build/vet/test`, `e2e` check, `docs-check` 0 findings):

- `scripts/umap_fit.py` — `auto` mode probe-loads the model (`model_loadable`) and falls back to a FULL REFIT on any unpickle failure; the refit re-persists the model under the current library versions, so the fallback is self-healing across future schema bumps. Explicit `--mode transform` on an unreadable model exits 1 with an actionable message. Verified against the deployed `python3-3.14.10-env` with a fabricated old-schema pickle (stripped `search_tree_leaf_budget` from a live `NNDescent`) — unfixed script reproduced the prod frames EXACTLY (`pynndescent_.py:1365 __setstate__`); fixed script refit + transform + straggler paths all green (T1-T4, exit codes verified without pipe-swallowing).
- `internal/ui/map.js` + `map_js_test.go` — the plate carries the key itself: paste-once into localStorage (`atlas-api-key`), `X-Api-Key` header on the inventory fetch, `?key=` on the EventSource and thumbnail URLs (headerless surfaces; the query form is the documented SSE tradeoff). A 401 mounts the paste-once gate and reloads on save. Source-pinned by `TestMapJSAuthWiring`.
- `nix/nixos-module.nix` — `TimeoutStartSec = "5min"` on `media-atlas.service`.
- `CHANGELOG.md` — three entries (two Fixed, one Added per the docs-gate taxonomy).

## c) Deployment path (shared tree, parallel sessions)

- SystemNix lock floated `ad7dce0 → 3e3c3ea` (~08:53); eval probe green.
- My `nix run .#deploy` was flock-refused (a marathon session held the deploy lock) and later PSI-refused (io PSI 41% + sdb 87% util) — both refusals correct; no force override.
- **The parallel sessions' deploys carried the fix anyway** (shared tree): gen 1011 (09:01, night-deploy marathon) and gen 1012 (11:24, audiblesync extraction wave) — the LIVE system now runs `atlas-3e3c3ea` with `TimeoutStartSec` in the rendered unit (verified by store-path + unit grep, 12:1x).
- Tree drift remains: fresh toplevel drv ≠ gen-1012 deriver (post-11:24 commits from the extraction-wave session) — convergence deploy queued behind the monitor365 cargo storm (a parallel session's `libduckdb.a` archiving has io PSI at 46-76% at 12:26-12:30; boot id pinned `7096665b…`, no reboot).

## d) Live verification on REAL prod state (the assertions that matter)

1. **umap self-heal engaged on the real old-schema model** (manual trigger 12:13-12:22, exit 0):
   `umap_fit: persisted model at /var/lib/media-atlas/umap/model/model.pkl no longer unpickles (AttributeError: 'NNDescent' object has no attribute 'search_tree_leaf_budget'); refitting from scratch`
   `umap_fit: fitted 13897 x 512-dim in 145.7s` → `13897 coord(s) -> coords.json` → `project-coords: done applied=13897 skipped=0 run=2026-11-15`. Tonight's 03:00 run rides the fast path (new-schema model).
2. **`/health/timers` rollup `fresh`** (12:2x): poll 0.17 h, umap 0.013 h, lane-join 7.96 h — the gatus `MediaAtlas nightly stale` episode clears.
3. **Plate data path verified through the vHost** (12:1x, key handled inside the probe script, never in argv/history): served `map.js` carries the auth wiring (5 needle hits); `/api/assets` keyless → 401 (gate enforced); with `X-Api-Key` from the provisioned key file → **200**; `/health/ready` → 200. Owner action: paste the hub key once per browser (the plate prompts on 401).
4. **Backup chain legs verified** (stale-row evidence): `media-atlas-backup` natural dump 05:00:39 (`atlas-2026-11-15.db`); restic `restic-backups-app-dumps` 05:48 → snapshot `6b7657b8` (correct unit name — `restic-app-dumps` in the row text never existed as a unit); `monitor365-pool-copy` 03:34 (13.09 GB, fresh). `backups.prom`: `backup_healthy{backup="media-atlas"} 1`, age 7 h.

## e) Watchdog re-arm: condition MET, decision owner-gated (deliberately not taken)

The re-arm checklist precondition is now satisfied: upstream `3e3c3ea` wires `daemon.NotifyReady` + `daemon.Watchdog` (armed off `WATCHDOG_USEC`) and `TestServeBehavioralSpecs` is GREEN at that rev (ran it: `go test ./internal/cli/ -run TestServeBehavioralSpecs -count=1` → ok). Arming `WatchdogSec=30s` is safe per the checklist — but the runbook flags re-arm as owner-gated and this deploy already carried three behavior changes, so the re-arm + scaffold removal stays an owner decision. Full procedure documented in `docs/services/media-atlas.md` (WATCHDOG TRAP entry, updated today). Note: the live `/run` drop-in currently holds only `[Service]` (its `WatchdogSec=0` line was lost at a boot) — harmless either way since the live unit declares no WatchdogSec at all.

## f) Follow-ups (harvested at authoring time)

1. Convergence deploy (tree drift → gen 1013) — IN FLIGHT this session behind the monitor365 storm; if the PSI window never opens it becomes a `[ready]` row → `docs/todo/pipeline.md`. (Harvested: row landed.)
2. **Owner decision:** re-arm `WatchdogSec=30s` + remove the tmpfiles scaffold (procedure + evidence in the runbook) → `[blocked:user]` row → `docs/todo/services.md`. (Harvested: row landed.)
3. **Owner action (not a repo task):** paste the hub API key once per browser on `map.home.lan` (the plate prompts); key file `/var/lib/media-atlas/hub-api-key` (read interactively, never into shell history).
4. Stale-row corrections landed this session (see the TODO_LIST diff): the 2026-11-05 backup-verify row TICKED with today's evidence; the "All Backups Healthy … deploy pending" row TICKED (deployed since gen 979); the gen-983 scaffold row REWORDED to its remaining scope (scaffold removal, owner-gated).
5. umap `umap-fit` aarch64 gate lift row (pre-existing, `docs/todo/services.md`) untouched — no aarch64 builder on the fleet; unchanged.

## g) Attribution / shared-tree notes

- Parallel sessions were ACTIVE throughout: night-deploy marathon (gens 1008-1011, wrapped 11:51), extraction-wave + audiblesync sessions (12:17/12:20 reports, deployed gen 1012 at 11:24), and a monitor365 cargo build storming io PSI at 12:26+ (libduckdb.a archive). My flock+PSI deploy refusals were correct; gen 1012's deploy carried my fix via the shared tree before I could deploy.
- The auditablesync/extraction commits are NOT mine; the convergence deploy ships them plus my docs — that is the standing shared-tree contract.
