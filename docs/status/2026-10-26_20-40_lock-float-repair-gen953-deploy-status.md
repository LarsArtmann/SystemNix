# Lock-Float Repair → gen-953 Deploy — Session Status

**Reported:** 2026-10-26 20:40 CET · **Instance:** crush session (fix task, owner paste at ~16:15)
**Scope:** THIS session only — the failed `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`, its diagnosis, repair, and the gen-953 deploy. No other project state was researched.
**HEAD at report time:** `6491fd32a` · **Deployed:** gen-953 (`/nix/store/8y5jiqlvlr4x5rl4b194wbpylm9sflpi-nixos-system-evo-x2-26.11.20261015.fe13242`, anchor verified `== system-953-link`)

## Timeline (compact)

| Time | Event |
| --- | --- |
| 16:10 | Owner's float+deploy → float-register proof RED (5 roots shown on console, log held 21); registry reverted; deploy aborted |
| 16:10–17:35 | (daemon + parallel session) lock+registry swept into commits MID-PROOF → tree left in the known "registered-but-unproven" state |
| 17:36–17:43 | Session starts. Diagnosis: 19 stale go-modules vendorHashes + 2 true builder failures (go-taskqueue, branching-flow). 13 hash edits + 6 shim conversions in `lib/lars-packages.nix`, 6 more edits across 8 other files. Pin-backs for both broken inputs. |
| 17:44 | float-register run: proof RED again — mr-sync + project-discovery-daemon MODULE-surface shims missed (sweep list had been built from the truncated console paste) |
| 17:45–17:52 | Fixed both module surfaces; full 19-hash sweep CLEAN |
| 17:54 | float-register proof **GREEN (rc=0)** — but the script died silently BEFORE committing (set -e + pipefail, diagnosed + A/B-verified) |
| 18:07 | Hand-committed lock+registry pair (`ad017c6f4`) mimicking the script's step 4a |
| 18:12 | Deploy attempt 1 → aborted at guard-trip gate (trips #4400/#4401). Waited, polling, 61 min. |
| 19:16 | Deploy attempt 2 → full battery 114/0, then aborted at the pressure gate (D-state phantom: btrfs-flush kworker + dead `home-lars-tmp` automount, PSI avg10 22.7%) |
| 19:28–19:53 | Investigated D-states (bounded jobs: discordsync `PRAGMA integrity_check`, jbd2); poll-looped for a real dip |
| 19:54 | Deploy attempt 3 on a verified dip with `DEPLOY_FORCE_PRESSURE=1` → **LANDED** (activation complete, anchor self-repaired) |
| 20:00–20:30 | Post-deploy verification: 9 services LoadUnit-probed running; smoke 24 PASS; monitor365 `/health` diagnosed as upstream 308-redirect; follow-up rows queued |

**Commits this session:** `ad017c6f4` (float: register branching-flow go-taskqueue, hand-commit after script death) · `847fd0388` (docs: float-register bug + sweep lesson) · `6491fd32a` (docs: upstream FOD-scope + monitor365 /health rows) — plus daemon batches that swept `docs/agents/go-ecosystem.md` and 9 of my shim-edit files (all 18 new hash fragments HEAD-verified via `git grep`).
**Logs:** `~/.cache/lockfloat/float-proof-20261026-{161006,174429,175455}.log` (RED, RED, GREEN).

---

## a) FULLY DONE

1. **19 stale go-modules vendorHashes fixed across 9 files / 7 surfaces** — `lib/lars-packages.nix` (7 value updates), `overlays/linux.nix` (crush-daily, overview, file-and-image-renamer), `modules/nixos/services/{cv,discordsync,health-dashboard}.nix`, `modules/nixos/services/projects-management-automation.nix` (module surface re-add), `modules/nixos/services/mr-sync.nix` + `project-discovery-daemon.nix` (second-round module surfaces), `platforms/nixos/system/configuration.nix` (buildflow PATH surface). Evidence: all 18 new hash fragments `git grep`-verified in HEAD; §11 "all deploy go-modules FODs cached — vendorHash proven" on the deploy; every affected FOD built green in the 17:54 proof.
2. **6 `flakePkg` → `flakePkgShim` conversions with evidence comments** (erraudit, go-auto-upgrade, go-humanize-linter, project-meta, projects-management-automation, samber-linter) — these tools' upstream-baked hashes staled under their own re-locked nixpkgs; got-hashes pasted from the 16:10 keep-going enumeration, never invented.
3. **go-taskqueue + branching-flow pinned back to last-known-good revs** (`f4ff9b1f` / `becd8a1a`) via `nix flake lock --override-input` — narHashes match the pre-float state; LIFT conditions recorded in `ad017c6f4`'s message; upstream fix queued (`6491fd32a`).
4. **Keep-going toplevel proof GREEN** — `float-proof-20261026-175455.log`, rc=0, zero errors, full toplevel realized.
5. **lock+registry committed together** (`ad017c6f4`, exactly 2 files) — the float audit-log doctrine held despite the script's death.
6. **Deployed gen-953 with anchor discipline** — `readlink /run/current-system` == `system-953-link` == the deployed toplevel store path; deploy.sh's own anchor self-repair ran and was re-verified by generation number (not mtime).
7. **9 services verified `active/running`** post-activation: cv-server, discordsync, mr-sync-dashboard, project-discovery-daemon, overview, projects-management-automation, tq-serve, tq-agent-pool, journal-serve (LoadUnit + ActiveState/SubState probes).
8. **Post-deploy smoke: 24 PASS / 1 diagnosed** (the 1 = monitor365 `/health`, see §b).
9. **Two lessons landed in the doc system**: float-register silent-death bug (pipeline.md row + TODO_LIST twin, `847fd0388`) and the log-first sweep rule (go-ecosystem.md, daemon-swept `bea100f94`, content HEAD-verified).
10. **Gate discipline held**: honored the 60-min guard-trip gate with a verified trip-free window instead of overriding; the eventual override fired only on a measured IO dip with the owner's same-day precedent.

## b) PARTIALLY DONE

1. **monitor365 `/health` triage** — Works: root-caused to an upstream route move (raw probe: `/health` → 308 Permanent Redirect while `/` serves 200 and the UI works); the agent-watchdog fired ONCE during activation settle (journal 20:01:39) and no flap since. Open: the NEW route (follow the 308 Location) not yet identified; `monitor365.nix` SERVER_HEALTH (~line 563) + any gatus pat not repointed. Blocker: none. Effort to finish: S.
2. **Tonight's IO-storm attribution** — Works: guard logged trips #4400/#4401/#4402 (17:47 / 18:08 / 19:22) with **+430 GB system.slice IO between trips, recurring ~every 30 min**; PSI verified calm between bursts; deploy timed into a dip. Open: the BURST SOURCE is unidentified (candidates: backup/scrub/btrbk-class job). Blocker: none, just not hunted (out of the fix task's scope). Effort: M.
3. **fastflowlm post-guard state** — Works: activation started fastflowlm.service + socket (+3 connection instances), superseding the guard's "restore capped, manual restart" note. Open: NOT verified actually serving a request ("started" ≠ "serving" — see §d.6). Effort: S.
4. **float-register automation** — Works end-to-end EXCEPT the silent green-proof death (diagnosed, A/B-verified, hand-commit closed the state); the proof-marker gap (registry==lock trusted as "proven") remains from the prior session's queued row. Effort: S (pipefail fix) / M (proof marker).
5. **The 17:44 stale-eval anomaly** — the proof eval produced drv paths IDENTICAL to the 16:10 run (old shim values) despite the file being edited minutes earlier; a live re-eval minutes later returned NEW drv paths. Worked around; ROOT CAUSE NOT DETERMINED (nix flake eval caching / git stat-cache?). Could bite future floats. Effort: M (forensics).
6. **18:04:05 mtime touch on flake.lock + expected-locks.nix** — content verified unchanged (pin-backs intact, registry==lock); the toucher unidentified (pre-commit hook treefmt? background nix process?). Cosmetic but unexplained. Effort: S.

## c) NOT STARTED

(Discovered this session, untouched — with reason.)

1. **Upstream got-hash pastes for the shimmed tools** (drop-the-shim end-game: cv 5th value, health-hub 4th, crush-daily, file-and-image-renamer 4th, mr-sync, pdd, overview, library-policy ×2-in-a-day, buildflow, discordsync, + tonight's 6 new shims: erraudit, go-auto-upgrade, go-humanize-linter, project-meta, PMA, samber-linter) — not started: upstream repos were mid-churn tonight (the pinned-back tips ARE the unfixed tips); each paste needs its own upstream edit+push+re-lock cycle.
2. **Upstream FOD download-scope fix** (`go mod download` → `all`, or go.sum/go.sum alignment in go-taskqueue + branching-flow) — not started: that's the pin-back LIFT precondition; queued `6491fd32a`.
3. **float-register pipefail FIX** — only queued (row + twin); the script remains able to silently eat a green proof.
4. **media-atlas post-deploy verification** — the parallel session's module + `media-atlas-pg-ro` provisioner rode MY deploy (eval-clean, §11-stamped); its grant convergence / tiles were NOT verified by me — deliberately: another live session owns that work; co-verifying uninvited is the anti-pattern AGENTS.md warns about.
5. **Pre-existing failed units triage** — pocket-id-provision (exit 1 in 216 ms, OnFailure fired — pre-dates this deploy, was in §6 of BOTH batteries), buildcache-gc, service-health-check, ci-watchdog — not started: pre-existing, unrelated to the float repair.
6. **home-lars-tmp hot-subvol provisioning** (`/mnt/hot/users/lars/tmp` MISSING while the shadow dir holds ~493k files) — the §18 WARN, the dead automount, and the D-state phantom all point here; not started: needs a sudo-ticketed provision pass (the module's own fast+loud fail design is working as intended).
7. **Shim-drop bookkeeping automation** (a check that vendorHash literal changes carry evidence comments; a log→sweep-list generator) — not started: process tooling, queued as §f items.
8. **The prior session's queued pipeline rows** (proof-marker, deploy-when-quiescent productization, post-deploy-check not-listening split) — untouched this session; still open in docs/todo/pipeline.md.

## d) TOTALLY FUCKED UP

(Radical honesty — my mistakes this session.)

1. **The first sweep list was built from the truncated console paste, not the full proof log** — I enumerated 14 hashes from the paste's root display while the log held 19 + 2 builder failures. Result: missed mr-sync + project-discovery-daemon MODULE-surface shims (their 2026-10-19 values sat in `modules/nixos/services/*.nix`), one FULL wasted re-proof cycle (17:44 RED run, registry revert, ~15 min lost). Severity: cost, not correctness. Root cause: I under-executed a lesson the doc states verbatim ("the keep-going toplevel build … again the only oracle that works") and that `project-discovery-daemon.nix` itself documents ("The same BOTH-surfaces trap as PMA"). Mitigation: rule now written into go-ecosystem.md + the awk extraction command exists in this transcript; a script is queued (§f).
2. **The green proof sat uncommitted for ~13 minutes** — float-register died silently at 17:54; I only noticed when I finally polled the background shell, after writing todo updates. The commit-state check + hand-commit (`ad017c6f4`) closed it, but a daemon batch could have swept the pair mid-window into an unproven-state commit again (the exact 2026-10-25 race). Severity: near-miss. Root cause: I backgrounded a long task and did not watch its completion first. 
3. **Two false-alarm probes from my own methodology errors** — (a) busctl unit paths built with dash→underscore instead of the correct `_2d` escaping reported cv-server + PMA "inactive/dead" when they were running (caught on the empty-output smell, redone via LoadUnit); (b) an openssl-TLS probe against monitor365's PLAIN-HTTP :3001 returned empty and nearly read as "service dead" (the smoke harness's plain-HTTP UI probe was the tell). Severity: none shipped, but both are exactly the "unverified probe becomes a quoted finding" class this repo has been burned by (2026-10-26 quote-scrutiny rule exists for a reason).
4. **5 edit calls rejected** (read-via-bash `sed`/`grep` does not satisfy the edit tool's read-before-edit rule) — one wasted round trip; the Batch-View-then-edit pattern was in the workflow rules all along.
5. **3 failed attempts to commit the lesson docs** — TODO gate: title-identity drift, then the word "tonight" (wait-language list), then a date inside a cited filename. I wrote rows before reading `scripts/check-todo-system.sh`'s actual rules; the gate's selftest documents all three. ~10 min of churn.
6. **I asserted "fastflowlm resolved itself" in my final message without verifying it serves** — activation STARTED the unit, but I never probed an actual completion. That is the "a result observed once is 'happened', never 'can'" violation, one step from the 2026-09-18 close-out class. Corrected here: fastflowlm is STARTED, serving UNVERIFIED (§b.3).
7. **Post-deploy failed-set reconciliation incomplete** — pre-deploy battery: 7 failed units; post-activation: 3 (home-lars-tmp.mount, buildcache-gc, pocket-id-provision). I never produced the healed-vs-still-broken mapping (github-auto-assign, opencloud, inboxclean-sync apparently recovered via "Resetting failed units" + restarts — apparent, not verified). Severity: low (deploy.sh re-checks each run), but the close-out should have answered it.
8. **Unexplained anomalies left unexplained** — the 17:44 stale-eval (§b.5) and the 18:04 mtime touch (§b.6): I worked around both and moved on. Defensible under "fix the deploy", but both are potential future-trap signatures (an eval that reads stale shims WILL bite a future float) and I flagged rather than chased them.

## e) WHAT WE SHOULD IMPROVE

1. **Mechanize the sweep-list generation** — the awk extraction (`grep -A3 "hash mismatch" | awk` state machine) + the 19-hash `rg -F -e` sweep worked perfectly ONCE MANUALLY DONE. Script it: `scripts/vendor-sweep-list.sh <proof-log>` emitting the rg command; the six-surface sweep becomes one copy-paste. Impact: eliminates the §d.1 class entirely. (→ §f item)
2. **float-register robustness** — three concrete fixes: `|| true` the `drifted=` pipeline (or compute drift from grep's exit), print ALL roots (drop `head -20`), and the proof-marker stamp (prior queued row). Each is small; together they close tonight's entire failure surface inside the tool. 
3. **Probe patterns belong in the ops doc** — LoadUnit-first for unit state (raw escaped paths silently lie for dashed names), `/dev/tcp` for plain-HTTP ports (openssl s_client ONLY for TLS). The AGENTS.md live-probe set lists ss/pgrep/busctl but not these two; tonight both cost a false alarm.
4. **Read the gate before writing for the gate** — `check-todo-system.sh`'s three rules (queue↔library title identity, wait-word list including "tonight", date-regex on cited filenames) should be a 5-line cheat sheet in CONTRIBUTING.md. 
5. **The vendorHash treadmill needs its end-game systematized** — 15+ shims now exist, several re-staling weekly (cv: 4th value in 3 days). Each manual cycle costs a full proof build. The upstream-paste loop (edit upstream → push → re-lock → drop shim) is documented but never batched. A quarterly (or post-float) batch session would shrink the shim ledger permanently.
6. **Daemon-sweep attribution for lesson docs** — go-ecosystem.md's lesson line rode a heuristic daemon commit (gate-retry timing), splitting my doc trail across authors. The registry-history-as-audit-log doctrine wants properly-messaged commits; pathspec-commit FIRST, then iterate on gate fixes.
7. **Verify-before-assert on service recovery** — "the activation started it" must never again be phrased as "it works" (§d.6). The one-line probe (LoadUnit + an HTTP completion) belongs in the post-deploy checklist for any unit the guard shed.

## f) 50 THINGS WE SHOULD GET DONE NEXT

(Harvest status: items marked ✅ **already harvested at authoring time** — committed to TODO_LIST/domain libs in `847fd0388` + `6491fd32a` BEFORE this report, per the self-harvest rule. The rest are deliberately NOT harvested yet: this is a prioritization menu for the owner per the status-report skill's "larger N is a brainstorm" note — bulk-queueing 50 brainstorm rows would violate HARVEST routing rigor. Say the word and I harvest any subset.)

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Fix float-register's silent green-proof death (`drifted=` pipeline `\|\| true` + selftest leg) ✅ harvested | High | S | Bug |
| 2 | Upstream fix for go-taskqueue + branching-flow FOD download scope, then lift both pin-backs ✅ harvested | High | M | Bug |
| 3 | Repoint monitor365 agent-watchdog SERVER_HEALTH + gatus off the now-308 `/health` route ✅ harvested | High | S | Bug |
| 4 | Identify the ~430 GB/30-min system.slice IO burst source (guard trips #4400-#4402) | High | M | Bug |
| 5 | Root-cause the 17:44 stale-eval anomaly (drv paths identical despite edited shims — nix flake eval cache?) | High | M | Quality |
| 6 | Implement the float-register proof-marker (lock-fingerprint stamp; registry==lock ≠ proven) — prior queued row | High | M | Quality |
| 7 | Verify fastflowlm actually serves post-activation (guard restore-cap context; started ≠ serving) | Medium | S | Bug |
| 8 | Provision `/mnt/hot/users/lars/tmp` subvol (fixes home-lars-tmp.mount, the §18 WARN, the D-state phantom class) | Medium | M | Bug |
| 9 | Diagnose pocket-id-provision exit-1 (216 ms failure, pre-existing, OnFailure fired) | Medium | S | Bug |
| 10 | Diagnose buildcache-gc.service failure (pre-existing) | Medium | S | Bug |
| 11 | Script `scripts/vendor-sweep-list.sh <proof-log>` (mechanize the awk extraction + six-surface rg sweep) | High | S | Quality |
| 12 | float-register: print ALL roots (drop `head -20`) + print the sweep-list command | Medium | S | Quality |
| 13 | Upstream paste: cv got-hash `5Xjd8Czb…` (4th re-stale in 3 days — end the treadmill for this tool) | Medium | S | Cleanup |
| 14 | Upstream paste: health-hub got-hash `gytpnPbS…` | Low | S | Cleanup |
| 15 | Upstream paste: crush-daily got-hash `/sLqiHyQ…` (third re-stale class) | Low | S | Cleanup |
| 16 | Upstream paste: file-and-image-renamer got-hash `Uz4gaRoR…` (4th entry in its comment trail) | Low | S | Cleanup |
| 17 | Upstream paste: mr-sync got-hash `TENDT6NZ…` (note BOTH surfaces in the upstream comment) | Low | S | Cleanup |
| 18 | Upstream paste: project-discovery-daemon got-hash `XbZifGSt…` (both surfaces) | Low | S | Cleanup |
| 19 | Upstream paste: overview got-hash `QweKquKP…` | Low | S | Cleanup |
| 20 | Upstream paste: library-policy got-hash `OTLxExVE…` (+ watch the input's twice-in-one-day churn) | Low | S | Cleanup |
| 21 | Upstream paste: buildflow got-hash `ffjf0h53…` (upstream vendorHash.nix owns both our surfaces) | Low | S | Cleanup |
| 22 | Upstream paste: discordsync got-hash `gYJcV6Ol…` | Low | S | Cleanup |
| 23 | Upstream paste: erraudit got-hash `EiJnFbX3…` (follower-divergence class — note the FRAGILE watch) | Low | S | Cleanup |
| 24 | Upstream paste: go-auto-upgrade got-hash `pUk8kT+7…` | Low | S | Cleanup |
| 25 | Upstream paste: go-humanize-linter got-hash `k7GyCaMU…` | Low | S | Cleanup |
| 26 | Upstream paste: project-meta got-hash `+rbh2A6r…` | Low | S | Cleanup |
| 27 | Upstream paste: samber-linter got-hash `zrjjUEyK…` | Low | S | Cleanup |
| 28 | Upstream paste: PMA got-hash `fWJuASoh…` (one day after its 2026-10-25 green probe — its own lock moves fast) | Medium | S | Cleanup |
| 29 | go-nix-helpers audit: should the mkGoFlake FOD run `go mod download all` for ALL consumers (root fix for the tq/bf class — assess blast radius before bumping our follow) | High | L | Bug |
| 30 | Reconcile the pre-deploy vs post-activation failed-unit sets (7 → 3: which of github-auto-assign / opencloud / inboxclean-sync actually healed — verify, don't assume) | Low | S | Quality |
| 31 | Post-deploy media-atlas verification handoff (parallel session's feature rode gen-953: media-atlas-pg-ro grant convergence) — see §g Q2 | Medium | S | Bug |
| 32 | Confirm monitor365-agent didn't flap after the single watchdog restart (watch one watchdog cycle) | Medium | S | Bug |
| 33 | Add a CONTRIBUTING cheat sheet for the TODO gate (title-identity, wait-word list incl. "tonight", date-regex on filenames) | Low | S | Documentation |
| 34 | Pre-commit leg: vendorHash literal changes must carry a dated evidence comment (codifies "never by hand") | Medium | M | Quality |
| 35 | Extend the AGENTS.md live-probe set with LoadUnit-first unit probing + `/dev/tcp` plain-HTTP pattern | Low | S | Documentation |
| 36 | Forensics pass on the 18:04:05 flake.lock/expected-locks.nix mtime touch (content unchanged; toucher unknown) | Low | S | Quality |
| 37 | Next real `nix flake update && nix run .#deploy` must ride float-register end-to-end (its true acceptance test — the 16:10 run was wave 1's, this session was wave 2's) | Medium | S | Quality |
| 38 | Root-filesystem watch: 60 G → 50 G free across the evening (deploy + sandboxes); the 92-93% advisory will become a blocker | Medium | S | Cleanup |
| 39 | Verify the 4 stale build sandboxes advisory got cleared by nix-build-cleanup.service (its own timer; don't rm) | Low | S | Cleanup |
| 40 |inboxclean-sync + opencloud failed pre-deploy (guard-shed class): confirm they recovered with the post-activation restarts or re-queue | Medium | S | Bug |
| 41 | service-health-check + ci-watchdog failures (pre-existing): triage or they mask real outages (one IS the notifier) | Medium | S | Bug |
| 42 | home-lars-tmp.automount was STARTED by activation: confirm touching `/home/lars/tmp` fails fast-loud without a fresh corpse pile | Low | S | Bug |
| 43 | Consider a `DEPLOY_FORCE_PRESSURE` audit trail (the override fired 3× tonight across sessions; each justification should persist somewhere greppable) | Low | S | Quality |
| 44 | The erraudit FRAGILE follower note has now fired twice (2026-10-18, tonight): consider the nixpkgs-unstable follow pattern from the 2026-10-25 inboxclean lift as the systematic fix | Medium | M | Quality |
| 45 | Re-surface the prior session's queued idea: pre-commit hook requiring the float message when `flake/expected-locks.nix` is staged (registry-as-audit-log enforcement) | Low | S | Quality |
| 46 | Fold tonight's 430 GB bursts into the queued "junk IO attribution" row (docs/status/2026-10-25_17-45 §d) — fresh evidence, same instrument-class | Low | S | Documentation |
| 47 | Batch-analyze: how many of the 15+ shim entries could drop if ONE upstream sweep session pasted all got-hashes (effort vs the per-float re-stale tax) | Medium | S | Cleanup |
| 48 | The 2026-10-25 pipeline row "split not-listening from non-loopback in post-deploy-check" — tonight's monitor365 /health FAIL is a third instance of the smoke's stale-result class; bump its priority | Medium | S | Quality |
| 49 | Consider logging pressure-override + gate-abort events to a persistent file from deploy.sh itself (tonight's narrative lives only in this report + shell logs) | Low | S | Quality |
| 50 | Update the CHANGELOG with the gen-953 entry (19-hash repair wave, 2 pin-backs, float-register bug found) — CHANGELOG.md not touched this session | Medium | S | Documentation |

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Are tonight's ~430 GB / ~30-min system.slice IO bursts expected?** I verified they're real (guard trips #4400–#4402 at 17:47/18:08/19:22, PSI calm between) but could not attribute them within this task's scope. If a scheduled job (btrbk / scrub / backup export window) owns them, the deploy timing was fine and no hunt is needed; if NOT, this jumps to the top of the stability queue alongside the 2026-08-22 crash class.
2. **Does the media-atlas session own its own post-deploy verification, or do you want me to do it?** Their module + `media-atlas-pg-ro` provisioner rode MY gen-953 (eval-clean, battery-passed), their tree activity stopped ~17:35 with a wrap-up-style commit (`91aecdb55`), but I deliberately did not co-verify another live session's feature. If that session is gone, the grant convergence + tiles are unowned.
3. **Push the got-hashes upstream now, or let the shims ride?** The 15+ §f paste items are each a small upstream edit + push (your repos, your call). Tonight several upstream repos were mid-churn, so I shimmed consumer-side only. If you want, the next session can batch all pastes in one sweep — but I won't co-edit your repos without a go-ahead.

---

*Self-harvest record (AGENTS.md rule): §f items 1–3 were queued at authoring time, BEFORE this report (`847fd0388`, `6491fd32a` — pipeline.md + upstream.md + services.md + 4 TODO_LIST twins). Items 4–50 are deliberately not harvested: they are a brainstorm menu awaiting owner prioritization (user instruction: report then WAIT), several belong to other sessions/pre-existing queues (§c.4–c.8), and bulk-harvesting a 50-item brainstorm violates the docs-health HARVEST routing anti-pattern.*

*Format note: `.md` per the user's explicit path demand (status-report skill is HTML-canonical; override honored, not propagated).*
