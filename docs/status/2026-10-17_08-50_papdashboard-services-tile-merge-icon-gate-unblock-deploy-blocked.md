# PapDashboard Services Tab — dnsblockd/EMEET PIXY Tile Merge, Icon-Gate Unblock, Deploy Blocked by I/O Storm

**Date:** 2026-10-17 08:50 CEST
**Session start:** ~08:05 CEST
**Repos touched:** SystemNix (all edits), PapDashboard (read-only diagnosis)
**Outcome in one line:** Root cause found and fixed in config; rendered `services.json` verified correct in the store; **deploy NOT executed** — the I/O-pressure entry gate blocked all 4 attempts (buildcache storm, separate origin), and my retry loop had a false-positive exit bug and stopped itself.

---

## The original user complaint (3 parts)

1. "Why does dnsblockd have no link on https://dash.home.lan/#services?"
2. "Same for emeet pixy!"
3. "You even have DNS block double why?"

## Root cause (verified, not theorized)

- PapDashboard renders a tile without `href` as a **decorative, non-clickable card** (`internal/servicestatus/config.go`: `Href` is the link target, empty = decorative). Not a PapDashboard bug — a config shape.
- The live config (`/etc/static/papdashboard/services.json`, rendered by SystemNix `modules/nixos/services/papdashboard.nix`) carried:
  - **Monitoring group**: `dnsblockd` tile with `checkUrl=http://127.0.0.1:9090/` only, no `href` → probe-only, dead card.
  - **Media group**: `DNS Blocker` tile with `href=https://dnsblock.home.lan` only → link-only half of the SAME daemon. Verified via `caddy.nix`: `dnsblock.home.lan` proxies to `config.services.dns-blocker.statsPort` (= `ports.dns-blocker-stats` = 9090) — the exact port the Monitoring tile probed. One service, two half-tiles, two groups.
  - **Monitoring group**: `EMEET PIXY` tile with NO href and NO checkUrl — pure decorative leftover. The real tile arrives via the `services.integration` registry fan-out (`emeet-pixyd.nix` `homepage` → Infrastructure, with href).

---

## a) FULLY DONE

1. **Diagnosis complete** — all three complaints root-caused to SystemNix `papdashboard.nix` hardcoded group defaults (lines ~507-543 pre-edit), not to PapDashboard code.
2. **Tile merge implemented** (`modules/nixos/services/papdashboard.nix`):
   - Media `DNS Blocker` tile REMOVED.
   - Monitoring `dnsblockd` tile REMOVED.
   - New single tile in **Infrastructure** (after Redis): `name = "DNS Blocker"`, `href = svcUrl "dnsblock"` (clickable stats UI), `checkUrl = http://127.0.0.1:9090/` (direct daemon probe — a dead daemon reds the dot even while Caddy still answers). Why-comment at site.
   - Monitoring `EMEET PIXY` decorative tile REMOVED (registry tile in Infrastructure owns it). Why-comment at site.
3. **Rendered output verified**: built `nixosConfigurations.evo-x2.config.environment.etc."papdashboard/services.json".source` → `/nix/store/xpyi6max...-services.json`. Dumped all 39 tiles: exactly ONE DNS Blocker (Infrastructure, href+checkUrl+icon=blocky.png), exactly ONE EMEET PIXY (Infrastructure, href, icon=camera-ui.png), no mdi-* icons, 8 groups preserved.
4. **Wire-format validation**: jq + regex sweep — every `icon` matches the Go-side pack-name pattern or is an http(s) URL; every `href`/`checkUrl` is http(s). (`ALL_ICONS_LEGAL`, `ALL_URLS_LEGAL`.)
5. **Parallel icon-wave unblocked**: discovered an active parallel session mid-flight on an icon-pack feature (dashboard-icons fetchFromGitHub, `tileJson` icon passthrough, build-time `dashboardIcons` gate, eval assertion, `PAP_ICONS_DIR` env). Its tree state transiently broke eval (`attribute 'icon' missing`) — resolved by the parallel session itself within minutes; I completed the remaining violations it had not converted: removed `icon = "mdi-timer-outline"` (systemd-timer-monitor.nix) and `icon = "mdi-graph-outline"` (systemd-graph.nix) — the pinned pack (rev `6d31345`, 15,348 files, verified via filtered clone) carries no systemd/timer/graph/webcam glyph, and the Go side rejects `mdi-*` at startup with `ErrIconUnsupported` (would crash-loop the whole dashboard). Monogram fallback chosen over misleading product logos. Why-comments at both sites.
6. **No test breakage**: SystemNix `tests/test-integration.nix` pins only a "Demo" tile fan-out — untouched. PapDashboard fixture test pins shape only (8 groups, 3 bookmarks) — unaffected.
7. **All edits committed** by the auto-commit daemon (verified via `git log -S`): tile merge in `6dface8d`, mdi removals in the `a8e50edd`/`bc578aa2` wave. Working tree clean.
8. **restartTriggers confirmed**: `systemd.services.papdashboard.restartTriggers = [ servicesConfig ]` — the unit auto-restarts when the rendered JSON changes; no manual restart needed post-deploy.

## b) PARTIALLY DONE

1. **Deploy** — `nix run .#deploy` attempted 4× (08:15, 08:44, +loop). EVERY attempt aborted at the **I/O-pressure entry gate** (freeze-precursor class, 2026-08-22 stability plan): `sdb` (SanDisk QLC `/mnt/buildcache`) at 100-103% util, PSI some avg10 oscillating 21-86% for 35+ min. Gate threshold: <20% PSI WITH <20% disk busy. The storm originates in `user.slice/app.slice` (a second active `crush` session, PID 1230205, plus ghostty scopes) — not from this session's work (my sdb traffic sample: ~80 KB/s writes, trivial).
2. **Retry automation** — ran, but with a bug (see d); loop exited after 1 gated attempt printing a false `DEPLOY_OK`.

## c) NOT STARTED

1. **Live verification** of the deployed state: `/etc/static/papdashboard/services.json` symlink target, papdashboard restart, `/api/fragments/services` (one linked DNS Blocker, one EMEET PIXY), tile probe dots green.
2. **Post-deploy battery**: `nix run .#pre-deploy-check.sh` / `post-deploy-check.sh` equivalents that the deploy script itself would have run (the gate blocked BEFORE the validation battery — nothing has been validated past eval).
3. **PapDashboard fixture refresh**: `internal/servicestatus/testdata/systemnix-rendered.json` is now ≥2 renders stale (predates even the dnsblockd/EMEET Monitoring tiles). `golden_test.go` documents the deliberate refresh: `cp /etc/static/papdashboard/services.json internal/servicestatus/testdata/systemnix-rendered.json` — should happen AFTER the deploy lands, then `go test ./internal/servicestatus/`.
4. **Real-Go-parser check** of the new JSON (jq+regex done; `servicestatus.Parse` run via refreshed fixture not done — same item as above).
5. **Deploy-anchor discipline** (AGENTS: verify `readlink /run/current-system` = latest `system-N-link` after any switch) — moot until a switch happens.
6. **Cleanup**: `/tmp/dashboard-icons` filtered clone (15k filenames, small) still in tmpfs.

## d) TOTALLY FUCKED UP

1. **Retry loop false positive (my bug, worst one)**: `timeout 500 nix run .#deploy 2>&1 | tail -25; rc=$?` — `$?` captured **tail's** exit code, not nix's. Every gated attempt "succeeded"; the loop broke after attempt 1 printing `DEPLOY_OK` while the deploy had been REFUSED. Correct form: `set -o pipefail` or capture via a temp file. Consequence: ~5 min of false confidence; caught only when manually reviewing output for this report.
2. **`rg -rn` flag mistake — TWICE**: `-r` is the REPLACE flag; `rg -rn pat` replaces every match with a literal `n`, silently garbling my own research output (dnsblockd→"n", PAP_ICONS_DIR→"n"). Both times I re-ran correctly, but I initially reasoned over mangled evidence. Must stop typing `-rn` as if it meant "line numbers + no heading".
3. **Mid-flight collision with the parallel session (contained)**: I prepared icon edits for `emeet-pixyd.nix` from a grep view that was minutes stale; the parallel session fixed it differently (`camera-ui.png`) in between. The edit-tool's read-before-edit guard rejected my stale edit — no damage, but the correct protocol for a shared actively-edited file is: re-`git diff`/re-View immediately before each edit, expect the file to move under you.
4. **First `nix build` ran against a half-saved file**: the eval failure I chased (`attribute 'icon' missing`) was a transient mid-write state of the parallel session, not a stable tree defect. Cost: one extra build cycle + a wrong first hypothesis ("they forgot the option").

## e) WHAT WE SHOULD IMPROVE

1. **Pipefail discipline in verification loops** — any "did it work" capture behind a pipe is a lie without `set -o pipefail` (see d.1). This class of bug makes unattended retry loops actively harmful.
2. **Deploy gate vs. unattended agents**: the pressure gate is correct, but an agent retrying deploys in a loop burns eval cycles; better pattern is a single queued attempt that waits on a PSI condition, then one deploy, then anchor-verify.
3. **The `mdi-*` icon class was a deploy-blocking landmine sitting in the tree**: the icon gate (assertion + `dashboardIcons` build gate + Go-side `ErrIconUnsupported`) is defense-in-depth NOW, but between the Go-side landing and the SystemNix gate landing, a deploy+restart would have crash-looped papdashboard. Keep multi-repo waves tightly coupled or feature-flag them.
4. **Tile inventory had no drift check**: two half-tiles for one daemon and a dead decorative duplicate survived multiple deploys because nothing asserts "one tile per service / tiles must be useful (href or checkUrl)". A cheap eval-time lint (duplicate-name check across groups; decorative-tile audit) in papdashboard.nix would have caught all three complaints at eval time.
5. **`sdb` buildcache QLC is a recurring freeze vector** (103% util at ~80 KB/s = random-4K thrash on slow QLC). The pressure gate protects the deploy, but the storm source (build caches on the slowest disk) is an open structural issue — owners' call.

## f) NEXT TASKS (prioritized)

1. Deploy when PSI drains: `cd ~/projects/SystemNix && nix run .#deploy` (or owner-decided `DEPLOY_FORCE_PRESSURE=1`).
2. Verify live: `readlink /etc/static/papdashboard/services.json` → new store path containing the merged tile.
3. Verify papdashboard restarted (restartTriggers) and answers: `/api/health` 200.
4. Fetch `https://dash.home.lan/api/fragments/services`: assert ONE "DNS Blocker" (linked), ONE "EMEET PIXY" (linked), zero "dnsblockd" Monitoring card, zero Media DNS card.
5. Check probe dots: DNS Blocker tile green via direct 127.0.0.1:9090 probe.
6. Refresh PapDashboard fixture: `cp /etc/static/papdashboard/services.json internal/servicestatus/testdata/systemnix-rendered.json`, then `nix develop -c go test ./internal/servicestatus/` (GOEXPERIMENT=jsonv2) — the round-trip test then covers the new icons on the real Go parser.
7. Run PapDashboard full battery per AGENTS after fixture change (`go test ./...`, lint if touched more than testdata).
8. Trash `/tmp/dashboard-icons`.
9. Deploy-anchor check: `readlink /run/current-system` equals latest system-N-link.
10. Consider an eval-time duplicate-tile/dead-tile lint in papdashboard.nix (e.4).
11. Consider assigning real pack icons to the monogram tiles (systemd-graph, systemd-timer-monitor, CV, Kith CRM, NSFW Filter, Browser History, Hermes, FastFlowLM, llama.cpp RAG) — owner taste, pack at pinned rev `6d31345`.
12. Watch the parallel icon-wave session to completion (it owns PAP_ICONS_DIR serving path verification: `GET /icons/<file>`).
13. After the icon wave lands end-to-end: re-run `scripts/smoke.sh` in PapDashboard (services step pins non-empty tiles).
14. If the I/O storm persists after the parallel session ends: diagnose sdb writer (`/proc/diskstats`, cgroup io.pressure) — possible QLC degradation signal (SanDisk SDSSDA240G is old).
15. Update SystemNix FEATURES.md services-tab row only if the tile semantics change further (not needed for this merge).

## g) QUESTIONS (cannot be figured out myself)

1. **Deploy under storm:** the pressure gate has blocked every attempt for 35+ min and the storm is another session's builds. Do you want me to (a) keep waiting for a quiet window, or (b) `DEPLOY_FORCE_PRESSURE=1` now — knowing the freeze-class history is exactly why the gate exists? (Risk decision is yours.)
2. **The second active `crush` session (PID 1230205) doing the icon wave:** should I treat its in-flight SystemNix edits as frozen (no further edits from me) and only deploy after it signals done, or is interleaving fine as long as eval stays green?
3. **Monogram vs. icon for the two Review Tools tiles** (systemd-graph, systemd-timer-monitor): I removed their illegal `mdi-*` icons rather than pick misleading product logos (pack has no systemd/timer/graph glyph at the pinned rev). Keep monograms, or do you want specific pack icons assigned (you know the pack; I verified only absence of obvious matches)?

---

*Report written from session memory + verified git/store state at 08:50 CEST. No new research performed beyond the deploy-loop status check.*
