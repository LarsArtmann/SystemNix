# Window Closeout (second dispatch) — Five Tasks: 2 Review-Fixes, Paperless PG Dump, Cache-Fallback Sweep, Restic Dedup Repo

**Date:** 2026-09-22 05:55 CEST
**Task-Queue-ID:** 000001a0c64b1fe5f9c93bb3f89ed87d8dd8
**Window:** 2026-09-21 ~09:40 → 2026-09-22 ~05:40 CEST
**Tasks closed:** `000001a0c10023cde007879240f2d8a3a5ae`, `000001a0c100232043f9f217095d7fe77d2d`, `000001a0c373465b2a59cd41196ec4d45014`, `000001a0c5fdb2dd3166a37c82d89dc5be6c`, `000001a0c618c3adc95abca642eadda2dd3c`
**Dispatch note:** this is the SECOND closeout dispatched over the same five tasks — the first ran ~45 min earlier (`docs/status/2026-09-22_05-07_window-closeout-five-tasks-reviewfix-paperless-pgdump-cache-sweep-restic.md`, its footer commit swept into daemon commit `2a818fe1`). This pass re-verifies that closeout's claims against the tree (one claim is FALSE — see d.1), covers the post-05:07 delta (the buildcache reap review-fix `d60d598c`/`a5377c94`, the 12-26 citation fix inside `2a818fe1`), and lands the docs the earlier pass claimed but never wrote.
**Method:** all five per-task closeout reports read first (per contract); every code claim re-verified via `git show --stat`/`git cat-file -e`/on-tree greps (module files, hook, tests, deploy.sh, home.nix); band drift via `tq facts --type task.reprioritized`; queue state via `tq show`/`tq tasks`.

---

## a) FULLY DONE

1. **Review-fix `…cde007879240f2d8a3a5ae` — citation correction landed and re-verified.** The 09-46 report's line 31 credits the deploy-restart-audit config-layer fix to `50f73871` (verified on tree this pass: `git show --stat 50f73871` = `deploy-restart-audit.nix` +27/−20; the parenthetical that `82d4fa4a` carried only the commit MESSAGE is present). The second misattribution site this fix session left standing (the 12-26 deploy-chain-rescue report, line 17) was **fixed post-window at 05:10** inside daemon commit `2a818fe1` with a proper inline docs-health annotation (struck wrong SHA + corrected attribution + the note that the corpus-sweep's fix claim had been false). Both sites now agree; the follow-up is closed.
2. **Review-fix `…f9f217095d7fe77d2d` — finding correctly dispositioned ALREADY-RESOLVED.** `modules/nixos/services/hot-db.nix` groups consumer anti-shadow wiring PER UNIT via `lib.zipAttrsWith (_: lib.concatLists)` (landed in `9cce5bfd`, 09-21 11:17 — diff verified: hot-db.nix ±48, `tests/test-hot-db-assertions.nix` +27 carrying the `shared-unit-entries-wire-all-paths` case). The disposition report (`ca8ad35a`) verified both `hot-db` checks build green. Zero code changes were the correct outcome; the "verify content, not authorship" rule was applied correctly under the multi-agent discipline.
3. **Paperless PG-level dump (`…d45014`) — implemented, queue-closed, re-dispatch-verified.** Implementation `9546e7a1` (verified: `paperless.nix` +96 — `paperless-db-backup.timer` 02:00+10min jitter Persistent, `paperless-db-backup.service` User=postgres peer-auth `pg_dump --format=custom` 14d retention, mount-gated `paperless-db-backup-dir` oneshot at `modules/nixos/services/paperless.nix:1009-1082`) + docs `e9407432` + re-dispatch `35fafaec` which added the DISABLED-host shape (rpi3-dns renders none of the four artifacts — no auto-discovery leak). storage.md row 27 `[x]`; `paperless-db` registry entry + deploy.sh provisioner entry verified. The queued VM-test regression assertions subsequently landed (`tests/test-paperless.nix`, TODO rows 111/112 note "assertions landed 2026-09-22 (eval-verified)"; first green VM run PSI-gated).
4. **Cache-fallback sweep (`…2dd3c`) — three NVMe-writing stragglers converged, and the reviewer-caught convergence gap closed.** On tree, verified this pass: `platforms/nixos/users/home.nix:418-420` (HM out-of-store symlinks `~/.cache/pnpm`, `~/.local/state/pnpm`, `~/.cargo/registry`) + `:472-475` (`migrate-buildcache-fallback-caches` activation, mount-gated, `entryBefore ["checkLinkTargets"]`); `modules/nixos/services/buildcache.nix:341` (`pnpm` in the dead-mount reap loop) + `:348-356` (the two non-`.cache` names in the post-recovery reap); pre-commit GOTOOLCHAIN guard narrowed to nix-value assignments (`b4eda274`) after a live FP on home.nix's deliberate interactive fish override. **Post-window, a reviewer rejected the parent's convergence claim (deploy.sh pre-switch reap missing) and the fix landed at 05:28 (`d60d598c`: `scripts/deploy.sh` pre-switch reap loops extended, `buildcache-usb-recovery` mirrored; report `a5377c94` with functional sandbox verification that symlinks are kept and real dirs reaped).** The three-layer convergence is genuinely complete as of `d60d598c`. storage.md row 80 `[x]`.
5. **Restic app-dumps dedup repo (`…eadda2dd3c`) — module landed, eval-verified twice, VM test written and registered.** `modules/nixos/services/restic-app-dumps.nix` (daemon commit `49cfb914`, +144, with the configuration.nix opt-in and deploy.sh provisioner entry in the same batch — verified); docs `36a946d2`; re-dispatch verification `0c52b922` (repository option eval + `nix flake check --no-build` green). The VM test EXISTS and is registered: `tests/test-restic-app-dumps.nix` + `tests/default.nix:75` (`restic-app-dumps = makeTest …`) — real-btrfs-pool test asserting password-bootstrap idempotence, unit shape, init-on-missing, marker-only-on-success, and the backup-coordination fan-out (storage.md row 90 `[x]` DONE; first green VM RUN remains PSI-gated). The two duplicate TODO_LIST queue rows for it were still unchecked — ticked by this pass (evidence-backed).
6. **In-window adjacent work (not in this window's five; verified in passing):** the vendorHash wave repaired 7 LarsArtmann upstream repos with the switch refused by the IO storm (`docs/status/2026-09-22_01-21_…`); the own-tools NVMe→pool verification closed the discordsync-attachments + browser-history-dbBackup legs as eval-green/deploy-gated (`docs/status/2026-09-22_04-30_…`); FEATURES/ROADMAP/CHANGELOG updates rode `2a818fe1`/`06e01a1b`.

## b) PARTIALLY DONE

1. **Runtime is ZERO across the entire window.** The running generation (`system-792`, `dj5k7ykb`, nixpkgs-20260919 era) predates ALL of this window's work; the deploy was correctly refused by the pressure gate throughout (sustained 62→99% io-PSI storms, parallel monitor365 DuckDB build identified as one driver). Every "done" in (a) is one `nix run .#deploy` away from being real, and the batch keeps growing (restic, paperless-db, discordsync attachments, browser-history dbBackup, cache symlinks, hot-db shared-unit fix, scrub-mechanism fix, vendorHash wave, boot-mirror sync, crush-hot-db guards).
2. **The pool-quality pointer row stays open** (TODO_LIST row 21): the `hot-db`/`crush-hot-db` VM-test rebuild is PSI-gated (measured 68% avg10 at session time, gate <20%) and the mountPoint-vs-HM-symlink eval guard is deferred to its own run. Both are `[ready]` in the storage library.
3. **The restic dedup premise is unproven** — "forgejo zips share ~0 extents" motivates the repo, but the dedup ratio is unmeasurable until ≥3 nightly runs exist (deploy-gated). Eval-green is the weakest signal for a backup pipeline.
4. **Paperless DR chain is half-built:** the dump exists (eval), but no restore drill, no post-deploy smoke entry, no dump-size/pool-growth observation, and dump integrity is exit-0-trust-based (no `pg_restore --list` gate).
5. **AGENTS.md buildcache section was stale until THIS pass** — the 05:07 closeout claimed it updated the section and did not (see d.1). Fixed by this pass (docs-only): the Consumers bullet and the outage-displaced-symlink bullet now carry the three 2026-09-22 symlinks, the activation block, and the four reap surfaces incl. the `d60d598c` deploy.sh legs.

## c) NOT STARTED (deliberately out of the five tasks' scope, still open)

1. **The deploy itself** — the single gate everything in this window sits behind (authority question, g.1).
2. **Restore drills:** paperless `pg_restore` into a scratch cluster; restic one-file restore smoke; the older twenty/manifest drill.
3. **The mountPoint-vs-HM-symlink eval-time guard** (autofs-in-autofs at unit load — the hot-user-caches go-build class).
4. **The SHA-citation verifier** (`scripts/verify-status-citations.sh`) — now triply motivated (d.1, d.6, and the original review-fix finding).
5. **`~/.npm` convergence (103M stale fallback) and the `~/tmp/go-lint` (1.8G, live) reclamation path** — filed by the sweep, never built.
6. **buildcache-init does NOT provision the new targets** (`pnpm-cache`, `pnpm-state`, `cargo/registry` are absent from `buildcacheDirs`) — after a mount recovery the HM symlinks dangle ENOENT until the next deploy (found by the 05:31 review-fix report).
7. **Reap-list single-sourcing** — the name set now lives in FOUR hand-maintained places (deploy.sh `.cache` loop, deploy.sh non-`.cache` loop, usb-recovery step 2.5 both loops, home.nix activation); nothing enforces parity.
8. **Stub/fixture test for the destructive `discordsync-attachments-migrate` oneshot** before the deploy that triggers it.
9. **The wide storage backlog:** offsite Borg leg implementation, ClickHouse backup coverage, /data repair chain (scrub-mechanism fix must deploy first), SSD-2 tenant, boot-mirror reboot proof.

## d) TOTALLY FUCKED UP

1. **The 05:07 closeout made a FALSE claim in its own CHANGELOG entry — the same failure class it had just documented.** Its entry says the pass updated "AGENTS buildcache section (the three 2026-09-22 cache-fallback symlinks)". Verified false this pass: `git log -- AGENTS.md` shows no commit after 03:09 (pre-dating that pass) and zero grep hits for any of the new names. That is the second claim-without-post-edit-verification incident in 24h (after the corpus-sweep's phantom "misattribution fixed" claim the 05:07 pass itself exposed). CHANGELOG is append-only, so the false entry can only be counter-annotated — done via this pass's new entry — and the actual AGENTS.md fix is landed now.
2. **Duplicate dispatches burned paid runs all window:** review-fix 2 was dispatched against an already-fixed finding, the paperless task re-dispatched its own earlier run, and THIS closeout is the second over the same five tasks (its payload carries the identical five completions the 05:07 report closed). At least three same-day re-dispatches of closed work; the queue's done-filter/dedup gap is now the largest measured efficiency leak.
3. **A "CONVERGED" claim was premature and a reviewer caught it:** the sweep run marked storage row 80 converged while the deploy.sh pre-switch reap leg was missing — a deploy from that tree would have aborted at `checkLinkTargets` (the exact 2026-08-16 class). Fixed 5h later (`d60d598c`). Convergence claims need a layer inventory (deploy.sh + activation + recovery), not an assertion.
4. **Daemon-commit topology split EVERY substantive change from its footer:** `9546e7a1`, `49cfb914`, `f39e144b`/`87be97e5`, `9cce5bfd`, `2a818fe1` are heuristic daemon commits; footer commits carry docs-only diffs. The 05:07 closeout's own footer is nowhere visible (no footer line in its report; its commit rode `2a818fe1`). Two amend races were lost in-window; the 05:31 review-fix run lost one and recovered it with the house history-rewrite checklist.
5. **The 7.9 MB formatter-inflated HTML is STILL LIVE on the tree:** `docs/planning/2026-09-20_15-17_disk-layout-current-and-target.html` measures 7,887,869 bytes (the compact bundle is ~3.6 MB). The 2026-09-20 class re-landed in `9cce5bfd` (09-21 11:17, 201,638 insertions) and was never re-spliced — third occurrence, and `nix fmt`'s `docs/**/*.html` exclude did not prevent the daemon-era landing.
6. **The GOTOOLCHAIN guard FP fix is unpinned** — second FP incident on that hook (after the dead-guard-lint `$((` class), both fixed in the scanner with no negative-test case, violating the hook-guards-get-pinned doctrine.
7. **`nix fmt --no-update-lock-file -- --ci` is NOT a dry-run on this tree** — the 12:29 paperless session's `--ci` pass reformatted three foreign files (both never-format HTML bundles + a parallel session's script); caught and restored before commit, but the AGENTS.md bullet treats `--ci` as check-only.
8. **Deploy debt is compounding by the storm-day:** every `[x]`/eval-green mark in this window describes unbuilt state until the switch lands; each refused deploy grows the batch and its exit-4 surface (cv-perms, db-heal, hot-user-caches classes all expected).

## e) WHAT WE SHOULD IMPROVE

1. **Post-edit verification is a gate, not a courtesy** — any doc pass claiming a fix/update must run `git log -1 -- <file>` (or grep the landed content) before recording the claim. One command prevents the d.1 class; it fired twice in 24h.
2. **Ship the SHA-citation verifier** (`scripts/verify-status-citations.sh`): grep `docs/status/*.md` for bare 7/40-hex SHAs, `git show --stat` each, fail on missing SHAs, WARN on docs-only diffs cited as code fixes; CI WARN-grade first.
3. **Closeout/review-fix dispatch needs a preflight:** `tq show` the task, check whether a closeout over the same completions already exists in `docs/status/` (a filename glob on the task IDs would have caught this duplicate), and dispose "already closed" cheaply. Three paid duplicates in one day.
4. **VM test in the SAME run as the module:** restic, paperless-db, and hot-db all needed follow-up dispatches for tests the landing run could have written. House-default candidate: "new backup/backup-adjacent module ⇒ committed VM test in the same change."
5. **Batch-inventory line on every `[blocked:deploy]` row** ("rides the deploy with: X, Y, Z") — the pending batch now carries ~10 surfaces and the blast-radius knowledge is scattered across six reports.
6. **One quiet-IO window, one batched verification pass:** hot-db + crush-hot-db + restic + paperless VM tests are all eval-green/never-run; a single scheduled heavy-job window clears the whole backlog instead of each session re-gating.
7. **Reap-list single-sourcing:** one declarative `home file ↔ buildcache target` inventory generating symlinks, reap lists, and the activation migration — ends the four-hand-kept-lists drift the reviewer finding rode.
8. **Footer-commit discipline:** stage + amend in ONE pathspec command immediately after the last edit (the daemon commits every ~3 min); two races were lost again this window.

## f) NEXT THINGS (most valuable, concrete; 10 appended to TODO_LIST, marked ⭐)

1. ⭐ **Fire the batch deploy in the first calm window** (io avg10 <20%, no Zone-6 trip in 60 min) — carries restic-app-dumps, paperless-db-backup, discordsync attachments leg, browser-history dbBackup, the three cache symlinks, hot-db shared-unit fix, scrub-mechanism fix, vendorHash wave, boot-mirror sync, crush-hot-db guards; expect the known exit-4 classes, fix-forward.
2. ⭐ **buildcache-init provisioning gap:** add `pnpm-cache`/`pnpm-state`/`cargo/registry` to `buildcacheDirs` (or equivalent creator) so a mount recovery doesn't leave dangling HM symlinks until the next deploy.
3. ⭐ **Single-source the reap inventories** (deploy.sh ×2 + usb-recovery step 2.5 + home.nix activation) with a parity assertion.
4. ⭐ **Negative-test the pre-commit GOTOOLCHAIN guard** (pin the interactive-fish FP + both violation shapes).
5. ⭐ **`scripts/verify-status-citations.sh` + the post-edit verification gate** in the docs-health contract (CI WARN first).
6. ⭐ **Restic post-deploy proof chain:** first run, `restic check`, one-file restore smoke, dedup-ratio measurement, post-deploy smoke block.
7. ⭐ **Paperless DR completion:** `pg_restore` drill into a scratch cluster, `pg_restore --list` integrity gate, dump-size/pool-growth note after the first 02:00 run.
8. ⭐ **Stub/fixture test for `discordsync-attachments-migrate` BEFORE the deploy that triggers it** (stop → rsync → verify → `rm -rf` 40 GB → restart currently has zero automated coverage).
9. ⭐ **Converge `~/.npm` and give `~/tmp/go-lint` (1.8G, live) a reclamation path** (gc trim or tmpfs fallback — owner preference recorded as a question in the sweep report).
10. ⭐ **Re-splice the inflated disk-layout HTML** (7.9 MB on tree vs 3.6 MB bundle) and verify with `bash scripts/verify-html-diagrams.sh`.
11. Rebuild `hot-db` + `crush-hot-db` VM tests green on the current tree (PSI-gated, heavy-job) — the unrealized test drvs are the deploy-confidence gap (already a queue row).
12. Eval-time mountPoint-vs-HM-symlink guard (already a `[ready]` library row behind the pointer).
13. Post-deploy: verify the three new HM symlinks resolved and the migration activation journaled clean (storage.md `[watch]` row).
14. Root pool-receive freshness watch through storm lulls (2-day WARN live, 3-day FAIL at the 00:28 verify).
15. After the scrub fix deploys: /data scrub delta in a quiet window → unlock the /data repair decision chain (10 files, ~49G, all re-downloadable).
16. Offsite Borg leg (Hetzner StorageBox BX11) implementation — decided 2026-09-11, not built.
17. ClickHouse backup coverage (the XFS telemetry partition has no backup leg).
18. Fold `crush-hot-db` into the Phase-2 `services.hot-db` module once its first migration completes (delete the interim module + deploy.sh entry in the same change).
19. `/mnt/hot` free-space trend + alert threshold now that crush (45G) + forgejo subvol share the Samsung.
20. Post-migration PSI watch: `node_psi_io_some_avg60` 24h vs the 40-60% storm baseline.
21. Sweep remaining `~/.local/state/*` + `~/.local/share/*` for env-less NVMe-writing stragglers (mechanical churn probe instead of per-incident discovery).
22. Consider preemptive symlinks for `~/.cache/pip`/`~/.cache/sccache` (clean today because env-only; one env-less run re-creates them on the NVMe).
23. Gatus freshness for `buildcache.prom` during storm windows (verify the 5-min cadence held through this week's storms).
24. Verify fish `__go_cache_redirect` list and the HM symlink set enumerate the SAME variables (one audit script, fail on drift).
25. Document the pnpm/cargo fallback-symlink rationale in `docs/services/` or keep the (now-updated) AGENTS buildcache section as the single carrier.
26. Sweep AGENTS.md HDD-pool section after live restic validation to replace "deploy-pending" with measured facts (seed duration, repo size, dedup ratio).
27. Decide smoke-coverage ownership for the paperless dump freshness (post-deploy-check vs backup-coordination — one owner only).
28. Extend the postgres hot-db wave runbook to name the paperless dump as the DR path once the cluster leaves `@` snapshot coverage.
29. Audit ALL `createLocally` PG consumers vs pg_dump jobs (one enumeration so no DB silently lacks a dump).
30. `paperless-exporter` `RandomizedDelaySec` (open inside the storage library's pool-quality item; now interacts with the 02:00 slot).
31. Verify pre-deploy §10's new-metric auto-loan classifies the pnpm/cargo convergence correctly (no metric surface, but reap-list changes touch recovery output lines).
32. Check whether BuildFlow still emits its `gobuild/gocache/gomod` fallback names or whether those reap entries can be retired.
33. Re-verify `nix fmt -- --ci` stability after the home.nix restyle (a second formatter pass should be a no-op).
34. Sanity-probe env-less cargo create-dir behavior through the new `~/.cargo/registry` symlink (dangling-target edge).
35. Extend `buildcache-gc` coverage inventory: confirm every new SSD target dir is bounded by its tool or added to the gc unit.
36. Add `~/.cache/pnpm` + `~/.cargo/registry` to the post-deploy smoke's symlink sanity check (extend the go-build family check, don't duplicate).
37. Record the "finding already fixed by daemon commit" disposition pattern in the tq pool docs so future agents don't re-apply fixes.
38. Grep-reconcile the reviewer-finding backlog against this window's daemon batches (`9cce5bfd`/`c09d4867`/`6cc114df`/`2a818fe1`) — other findings may be silently already-fixed.
39. Re-view the 05-07 closeout's remaining open suggestions that this pass did not re-verify line-by-line (e.g. FEATURES row wording, ROADMAP restic idea placement) during the next docs-health pass.
40. Consider an eval-time assertion in hot-db.nix rejecting duplicate (unit,path) entries across entries (makes the keep-last class impossible rather than fixed).
41. Confirm the hot-db VM test boots a two-entries-one-unit config (assertions test covers eval; the VM fixture may still be single-entry).
42. Add the `mkAfter`-on-`ConditionPathIsMountPoint` intent comment in hot-db.nix (or drop it — one-line review).
43. `git log --grep "fix-review"` convention docs in CONTRIBUTING.md so reviewers can self-close findings by grep.
44. Extend `scripts/audit-textfile-tmp.sh`-style static audit: reject NEW `mkOutOfStoreSymlink` targets under `/mnt/buildcache` lacking a matching reap-list entry (the displacement class, mechanically enforced).
45. Verify daily fstrim covers the tlc mount (post-deploy watch row — actually execute it).
46. Verify `/mnt/hot` appears in disk-monitor.nix and the migrate timer on timers.home.lan (existing watch row — execute it).
47. Watch btrbk root snapshot deltas shrink as ~42G left `@` (existing watch row — execute it).
48. Ratify/revert the BuildFlow fallback-cache quarantine decision (~6.6G reap at next deploy).
49. btrbk-cache-buildcache-gc time-slice check on the one-USB-link topology — verify the Sunday 05:00 schedule still avoids collision now that storm profiles changed.
50. After 3+ green nights, prune the manual restic-verification checklist in storage.md into a one-line "verified" note.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy authority:** should the queue fire `nix run .#deploy` automatically in the next calm-IO window, or do you deploy manually? Everything since 2026-09-21 is runtime-zero behind this decision, and it has been asked unanswered by at least three closeouts (restic, paperless re-dispatch, pool-quality runs).
2. **Restic repo's offsite role:** is the restic app-dumps repo a local dedup layer only (with per-service dumps going offsite individually via the future Borg leg), or should it BE the offsite leg (replicated to Hetzner)? This decides whether `forgejo-subvol`/`github-voice-corpus`/`pixel6` join `paths` and how the Borg design interacts.
3. **Queue dedup preflight:** closeout and review-fix dispatches keep re-firing on already-closed work (3+ same-day duplicates on 09-21/22, including this second closeout). Should the harvester preflight items against storage.md `[x]` rows / existing closeout filenames before dispatch — and was this closeout's duplicate dispatch intentional (e.g. a deliberate second-opinion verification pass)?

## h) BAND DRIFT

**None recorded.** `tq facts --type task.reprioritized` over the journal (`/mnt/pool/services/tq/tq.db`) returns **0 facts** — no priority was moved by marker, AI, unblock, or importance in this window (or at all). This matches the 05:07 closeout's independent journal read. The only queue movement in the window was lifecycle churn (claims, verify retries, completions, and the duplicate dispatches noted in d.2), which is availability, not re-prioritization.

---

**Verification anchors:** footer commits `ce2f01da`, `ca8ad35a`, `35fafaec`, `b4eda274`, `0c52b922`; implementation commits `36a7160c`, `9546e7a1`, `e9407432`, `eae85c7b`, `f39e144b`, `87be97e5`, `49cfb914`, `36a946d2`, `9cce5bfd`, `2a818fe1`, `06e01a1b`, `d60d598c`; post-window review-fix report `docs/status/2026-09-22_05-31_task-000001a0c6bd8f713f14fea350dcfaf06434.md`; prior closeout `docs/status/2026-09-22_05-07_window-closeout-five-tasks-reviewfix-paperless-pgdump-cache-sweep-restic.md`; tree evidence: `modules/nixos/services/{paperless.nix:1009-1082, restic-app-dumps.nix, buildcache.nix:341,348-356, hot-db.nix:317-347}`, `platforms/nixos/users/home.nix:418-420,472-475`, `tests/test-restic-app-dumps.nix` + `tests/default.nix:75`, `tests/test-hot-db-assertions.nix` (shared-unit case), `scripts/deploy.sh` pre-switch reap loops; `tq facts --type task.reprioritized` → 0 facts; inflated-HTML measurement `ls -la docs/planning/2026-09-20_15-17_disk-layout-current-and-target.html` → 7,887,869 bytes. All commits unpushed per contract.
