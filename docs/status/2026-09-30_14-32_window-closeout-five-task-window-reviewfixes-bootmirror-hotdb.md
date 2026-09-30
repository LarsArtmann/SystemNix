# Window Closeout — five-task window: two self-harvest review-fixes + boot-mirror activation dispatch + two hot-db re-dispatch verifications

**Date:** 2026-09-30 14:32 CEST (`date` measured at authoring)
**Window tasks:**

| Task ID | What it was | Landing commits (current history) | Close-out report |
| --- | --- | --- | --- |
| `000001a0ef696bd6beb80100b7f100000000` | Review fix: the 00-42 scrub report shipped without its self-harvest accounting (6 §f items would have died unharvested) | `dd249cc2` (work) + `b81f7a10` (report) | `docs/status/2026-09-30_08-46_task-000001a0ef696bd6beb80100b7f100000000.md` |
| `000001a0f137c3365d8dabb0782000000000` | Review fix: the 08-46 review-fix report repeated the same violation with its own two post-authoring §f items | `f07c727a` (work) + `d466e427` (report) | `docs/status/2026-09-30_09-46_task-000001a0f137c3365d8dabb0782000000000.md` |
| `000001a0f1aa342a1f2cec4fb02d00000000` | Boot-mirror activation + reboot — honestly closed BLOCKED (agent sandbox forbids sudo) | `1c89e6c6` (work) + `dc4dca0e` (report) | `docs/status/2026-09-30_11-39_task-000001a0f1aa342a1f2cec4fb02d00000000.md` |
| `000001a0f1b7efd7de7037442bee00000000` | T14 hot-db tier monitoring — RE-FIRE verification (work pre-landed) + dangling closure-pointer repair | `3db0dfeb` (footer) + `8a2d0be2` (report) | `docs/status/2026-09-30_12-34_task-000001a0f1b7efd7de7037442bee00000000.md` |
| `000001a0f1ea4ac4421df201faa700000000` | `migrate-hot-db.sh` stub-fixture test — RE-FIRE verification (test pre-landed) + count-claim reconciliation | `0fa21cf6` (footer) + `8d74db5b` (report) | `docs/status/2026-09-30_12-54_task-000001a0f1ea4ac4421df201faa700000000.md` |

**Window character:** ALL five landings are documentation/queue-hygiene only — no code, config, or test change belongs to this window (verified per-commit `git show --stat`). The engineering underneath (hot-db vehicle wave + fixture test + T14 monitoring) landed in the overnight vehicle-wave window and was only verified here; the boot-mirror ACTIVATION happened mid-window by the OWNER (~12:50, a parallel session's forensics), superseding task 3's blocker hours after its report.

**SHA note for future readers:** the dispatch payloads and the window reports cite pre-amend SHAs (`b9df9b1e`/`6bc8447f`, `6be7b4b1`/`4e7217c0`) — all still resolvable objects (reflog), superseded in branch history by the amend-forward rewrites above. The findings' re-anchor protocol (verbatim anchor text) handled this by design; three SHA generations per fix is the citation-rot cost of the amend-forward daemon-race policy.

---

## a) FULLY DONE (verified this session)

1. **Review fix #1 — the 00-42 report's six un-queued §f items all have queue/library surfaces.** TODO_LIST one-liners + library pairs landed for §f.12/13/19 (stability.md: fleet-wide `SuccessExitStatus` sweep, btrfs-scrub exit contract, deploy.sh reset-failed template coverage) and §f.14/16/17 (pipeline.md: task-ID dedup gate, three-report consolidation, read-only systemctl sandbox allowlist). Verified this session: rows exist at TODO_LIST (stability + pipeline clusters) and `docs/todo/stability.md`/`pipeline.md` carry the `[ready]` entries citing `docs/status/2026-09-30_00-42_…md §f.N`. The 00-42 report itself gained a harvest log with a Deliberately-NOT-harvested list (mirroring the 00-31 shape the finding named). `scripts/check-todo-system.sh` green.
2. **Review fix #2 — the 08-46 report's own two §f items harvested + its finding repaired without content loss.** TODO rows + `docs/todo/pipeline.md` entries for the carried-radar spot-verify and the report→queue harvest-coverage lint (verified in-tree: pipeline.md rows citing the 08-46 filename, marked "HARVESTED by the 2026-09-30 review fix, post-authoring"). The finding's verbatim anchor text preserved byte-for-byte in the 08-46 report. Bonus: this run proved the **soft-reset split** daemon-race repair live (daemon batched the fix + a foreign 997-line HTML; `git reset --soft HEAD~1` → two pathspec commits; zero-loss proven by empty `git diff <batch> HEAD`) and harvested its CONTRIBUTING documentation row.
3. **Boot-mirror state verified live, then the blocker RESOLVED same-day by the owner.** The 11-39 dispatch verified: `/boot-mirror` mounted (nvme1n1p1), `boot-mirror-sync` green TODAY 10:31 (12 entries, 325M, diff-drift gate), EFI entry `Boot000C` exists but BootOrder still led with QLC — activation structurally impossible from the sandbox (sudo + no-new-privileges, empirically proven, not assumed). Closed BLOCKED with the reason in both surfaces. **~12:50 the owner ran `nix run .#boot-mirror-activate`** (parallel forensics session, `docs/status/2026-09-30_12-58_…md`): BootOrder now `000C,0001,…` (Samsung first), pre-reboot-check 22-pass/0-fail with §11 green AT FAIL grade. AGENTS.md Samsung section + storage.md row 33 + TODO row 21 updated by that session. Remaining: the owner reboot + read-only post-reboot verify.
4. **T14 hot-db monitoring re-verified first-hand on the rendered surface + closure pointer repaired.** `nix eval` of rendered `services.gatus-config.extraEndpoints` on evo-x2 → 112 endpoints with "Hot Tier Mounted" present and zero per-entry checks (correct for `entries = { }`). Module re-verified in-tree this session: `modules/nixos/services/hot-db.nix` carries the `hot-db-metrics` collector + timer + `hot_tier_mounted`/`hot_db_entry_mounted{name}`/`hot_db_scrape_errors` emissions + the anchored check. The prior dispatch's self-referential closure note ("this commit supplies the cross-reference" inside a footer-less daemon commit — false on arrival) repaired with an explicit footer-commit pointer (`3db0dfeb`).
5. **`migrate-hot-db.sh` fixture test re-verified end-to-end + queue drift closed.** Direct run green (re-run by THIS session: "ALL migrate-hot-db fixture tests passed"), flake check `checks.x86_64-linux.migrate-hot-db-fixture` wired (flake.nix:2124) and green. The drifted queue one-liner (library row already `[x]`, TODO row still open) closed under the task footer. Count-claim drift reconciled: the true count is **22 assertion call sites** (the authoring session wrote 21) — corrected on the live surfaces + era-annotated at both quotes in the 00-55 historical report, original text preserved. Stale adjacent row refreshed (Phase-2 T-task table parenthetical).
6. **Every task in the window carries footer-bearing commits** — `git log --grep=<task-id>` hits for all five IDs (the queue's footer-based completion derivation can see all five closures).

## b) PARTIALLY DONE

1. **The boot-mirror feature:** sync leg ✅ live since 09-19; activation ✅ done 09-30 ~12:50; **reboot + post-reboot proof remain** (owner-decided timing; then agent read-only verify: `LoaderDevicePartUUID` == `023f66c0-3677-4c15-9ce7-f9e1f1457edb`, `BootCurrent` == `000C`, §10 gcroot flip).
2. **T14 monitoring runtime legs:** the textfile half is LIVE-verified (storage.md row 161, closed 04:50: `hot-db.prom` emitting `hot_tier_mounted 1`, `hot_db_scrape_errors 0` on deployed system-804) — but the **live Gatus-check-green leg** (the check evaluating against the real gatus instance) was never probed (root-only gatus sqlite, OIDC-gated API; `systemctl` blocked in agent sandboxes). Config-side + rendered-side only.
3. **`discordsync-db-backup` first-nightly proof:** units + timer are in the deployed tree (row 161), but the day-1 `.sql.gz` landing in `/mnt/pool/backups/discordsync` + `backup_all_healthy 1` + restic pickup after a 02:30 window (Persistent catch-up) remains an open `[watch]` residual **with no queue surface** — harvested this pass (§f item 2).
4. **The review-fix habit's sibling sweep was skipped a second consecutive time** (09-46 report §b1, self-reported): the 01-15 §e3 habit row already covers it; this report is the evidence trail, no new row.

## c) NOT STARTED (skipped by the window; all already queued — listed for completeness)

- **The five hot-db migration windows** (gatus → dnsblockd → pocket-id → browser-history → discordsync) — `[blocked:user]` sudo maintenance windows, one per wave; wave 1 is now unblocked (its fixture-test gate is satisfied and re-verified).
- **The `/mnt/hot` scrub family** (`btrfs.autoScrub += /mnt/hot` + metrics-loop entry — 45 GiB of live DBs with zero scrub coverage since 09-18) and the other 11 row-39 storage items.
- **The `crush-hot-db` interim-module fold** into ratified `services.hot-db` (never run both).
- **The three rows this window's review-fixes queued but nobody executed:** carried-radar spot-verify (TODO 444), check-todo-system harvest-coverage lint (445), soft-reset-split CONTRIBUTING docs (446).
- **Post-reboot verify, hot-db VM-test rebuild (PSI-gated), offsite-borg go-live chain, /data EIO repair** — standing blocked/queued work untouched by this window.

## d) TOTALLY FUCKED UP (window-attributable; blunt)

1. **Two window reports assert a stale live-system state their own library file had already corrected.** Both the 12-34 and 12-54 reports say the vehicle batch is "armed but **undeployed** … the first deploy is user-run" — while `docs/todo/storage.md` row 161 (closed 04:50, daemon commit `3ce83f41`, hours before either report) records the batch **DEPLOYED in system-804 with live probes**: `hot-db.prom` emitting `hot_tier_mounted 1`, `discordsync-db-backup{,-dir}` units in the deployed tree, anchor verified. Neither re-dispatch session grepped the library it was writing into for fresher rows — the "queue intake freshness rule" (TODO row 266) violation at the REPORT level. Cost of not catching it: this closeout would have re-queued a runtime-verification item that is half-done (the textfile leg) and missed that the genuinely open piece is the first-nightly discordsync dump proof. Both reports annotated this pass.
2. **The 12-54 report's count reconciliation cites an evidence command whose real output is 23, not 22.** `grep -c 'ok "'` matches 23 lines (22 assertion call sites + the `ok()` helper's own body at line 31); the 22 figure is right, the command as written over-counts — a fresh mini-instance of the exact count-claim class that report was fixing, inside the fix. Era-annotated in the 12-54 report this pass; the fixture-coverage queue row (79) carries the same command citation and cannot be reworded, so a corrective row is queued (§f item 6).
3. **The 11-39 report went ~50% stale within ~70 minutes** (activation executed 12:50) and nobody annotated it — the superseding 12-58 session updated AGENTS/TODO/storage but left the earlier report's "activation NOT done" §a and its §g1 open question ("did activate ever run?") standing. A reader hitting the 11-39 report first gets the wrong state. Annotated inline this pass (evidence-cited, original text preserved).
4. **Carried (not introduced this window, visible throughout):** the auto-commit daemon swept window files into footer-less heuristic commits repeatedly (7+ instances today; two repair patterns exercised: amend-forward with exclusivity check, soft-reset split); the queue re-dispatched completed work twice in this window (T14, fixture test — both correctly handled by the re-dispatch protocol, but each cost a full dispatch); 448 open queue rows with known duplicate-pressure and no dispatcher-side dedup gate (row 435 queued, unlanded).

## e) WHAT WE SHOULD IMPROVE

1. **Report-time freshness gate (one line in the re-dispatch protocol):** before asserting deployed/runtime state, grep the linked library file for rows matching the subject and cite the FRESHEST row's state — row 161 sat in the very file both re-dispatch sessions edited. This is cheaper than the AGENTS.md-section reconcile the intake rule already prescribes and would have prevented both stale claims.
2. **Mechanical counts need the right command, recorded with its output.** The fixture's `ok()` helper defeats `grep -c 'ok "'`; either rename the helper (`_ok`), prefix assertion calls (`ok_check`), or count call sites — and paste the command + number together (the 21→22 reconciliation shipped a command citing the wrong number). Folded into the corrective row (§f item 6); the general rule (report-claim surface rule) is already in AGENTS.md.
3. **Same-day supersession must annotate the superseded report.** The 12:50 activation made the 11-39 report's headline false; the landing session updated every LIVE surface but the historical one. Habit: whichever session executes an owner-gated step updates the dispatch report that queued it (2-minute edit) — the ANNOTATE doctrine's "reader forms their impression from the opening" applied to same-day artifacts.
4. **Queue payloads freeze SHAs; amend-forward invalidates them.** Both review-fix dispatches anchored findings to pre-amend SHAs. The verbatim-anchor fallback worked, so no action needed beyond noting it in the dedup-gate design (row 435): the gate must not key on payload SHAs.
5. **Re-dispatch verification cost is real and should size the queue's patience:** three of five window tasks were re-fires against already-landed work (T14, fixture, plus the boot-mirror item whose remaining work was sudo-gated from birth). The 11-39 report's §e1 (sudo-gated work = `[blocked:user]` at authoring) remains the cheapest prevention and is already covered by the human-capability-tag row (337) — dispatch it rather than aging it.

## f) UP TO 50 NEXT THINGS (grounded ~20; "NEW" = appended to TODO_LIST this pass; the rest already queued — dedupe, don't duplicate)

1. **NEW — Verify the "Hot Tier Mounted" Gatus check green on the live gatus + `hot-db-metrics.timer` active** (sudo/OIDC-capable session, ~2 min; the textfile leg is already live-verified per storage.md row 161 — only the check-evaluates-green and timer-active legs remain). (Source: 12-34 §b1, scoped down by row 161)
2. **NEW — Prove the first `discordsync-db-backup` nightly dump:** after a 02:30 window (Persistent catch-up covers a miss), assert `discordsync-db-*.sql.gz` in `/mnt/pool/backups/discordsync`, `backup_all_healthy 1`, and restic-app-dumps pickup. Row 161's open `[watch]` residual had no queue surface. (Source: storage.md row 161 residual)
3. **NEW — Fold `hot_db_entry_mounted{name="gatus"}` presence into the wave-1 cutover smoke** (runbook step 6) so the first entry's check is proven green at cutover, not discovered red later. (Source: 12-34 §f.22)
4. **NEW — Document where `nix run .#boot-mirror-activate` logs its runs** (owner shell vs system journal) in the AGENTS boot-mirror section — post-activation audits currently have no canonical evidence path (the 11-39 run's journal grep dead-ended). (Source: 11-39 §f.4)
5. **NEW — Re-stamp stale BLOCKED reasons on every re-dispatch** (one sentence in CONTRIBUTING's re-dispatch protocol; the 11-39 run found row 33's BLOCKED reason describing pre-landing state a full day after the deploy). (Source: 11-39 §e2)
6. **NEW — Fix the fixture's mechanical assertion-count command** (`grep -c 'ok "'` = 23: it counts the `ok()` helper body; call sites = 22) — rename the helper or count call sites, and correct the command citation that row 79 and the 12-54 report carry. (Source: this closeout §d2)
7. Owner: run the reboot (gate green — pre-reboot-check 22/0, §11 FAIL-grade), then the read-only post-reboot verify (loader PARTUUID `023f66c0…`, `BootCurrent 000C`, §10 gcroot). Also clears the flm corpse classes + D-state piles. (TODO row 21)
8. Hot-db wave 1 (gatus) — now unblocked; then waves 2-5, one per maintenance window. (storage.md row 34)
9. `/mnt/hot` scrub family + metrics (45 GiB unscrubbed since 09-18). (storage.md row 39(1))
10. Fold `crush-hot-db` into `services.hot-db`. (AGENTS hot-db section)
11. Scrub timers `Persistent=false` + serialization (freeze-#7 remaining half). (stability rows)
12. Carried-radar spot-verify of the 00-42 §f.21–50 rows (named by two review rounds). (TODO 444)
13. `check-todo-system.sh` report→queue harvest coverage lint — the systemic fix for the unharvested-§f class (4 round-trips paid). (TODO 445)
14. Soft-reset-split daemon-race docs in CONTRIBUTING. (TODO 446)
15. Task-ID dedup gate in harvest/dispatch (row 435) — this window alone had 2 completed-work re-dispatches.
16. Read-only `systemctl`/gatus-probe sandbox allowlist (row 437) — would have closed the 12-34 §b1 residual without a sudo session.
17. Answer the NVRAM sub-question: why BootOrder never led with Samsung between 09-19 and 09-30 (firmware reset vs `-o` never run) — decides whether a persistence guard is worth building. (12-58 §b; owner memory)
18. InboxClean chain (not this window's scope, flagged by §9 in passing): pre-deploy unblock (`token.json` → `.expired-*`) + consent-screen "In production" flip + re-consent + upstream push → lock bump → deploy. (TODO row 214 + upstream row 253)
19. Hot-db + crush-hot-db VM-test rebuild on the current tree (PSI-gated). (TODO 20)
20. Retire the duplication this window's reports fed: consolidate the three 00-42-family reports (TODO 436) — every consolidation day-delayed adds one more stale-SHA surface.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER (appended as BLOCKED items)

1. **Sequencing: the owed reboot (boot-mirror boot-source flip + corpse/D-state cleanup) vs the five hot-db windows — which first?** Both orders are mechanically safe (staging survives reboots; stop window is cutover→switch only), but the answer changes queue pacing: reboot-first gives the waves a clean PSI baseline; windows-first avoids booting twice. (Restated from 12-54 §g2, still unanswered.)
2. **Must the `crush-hot-db` interim fold complete BEFORE hot-db wave 1, or can the interim mechanism and the first ratified entry coexist?** AGENTS.md says "do not run both"; whether the conflict is structural (both provision `/mnt/hot` subvols + monitoring) or only about eventual double-coverage could not be determined from the tree. (From 12-34 §g2.)
3. **Was the BootOrder flip lost to a firmware reset between 09-19 and 09-30, or did `-o` never run until 12:50 today?** Only the owner's memory (BIOS setup visits, CMOS resets) can answer; it decides whether the mirror needs a persistence guard beyond the existing §11 FAIL-grade gate. (From 12-58 §b, owned here because it gates the reboot.)

## h) BAND DRIFT (ADR-0015)

**None recorded.** `tq facts` over the journal (head seq 8257 at 14:22) returns **zero `task.reprioritized` facts** — for this window and for the journal's whole history. No marker/AI/unblock/importance moves to account for. (The standing observation from prior closeouts holds: go-taskqueue does not yet EMIT the fact type — row 271 queued upstream; until it ships, every closeout will honestly read "none recorded".)

---

*Point-in-time snapshot. §f "NEW" items are the only queue appendages this pass made (plus evidence-backed ticks); everything else was deduped against the 448 open rows. Committed with the window-closeout Task-Queue-ID footer; never pushed.*

_Arte in Aeternum_
