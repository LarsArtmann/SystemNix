# Window closeout re-run — IO-PSI guard tier, PSI/disk correlation, InvokeNamed sweep, two reviewer-fix loops (+ a history regression the first closeout missed)

**Date:** 2026-09-15 07:32 CEST
**Window:** 2026-09-14 00:37 → 03:11 (5 queue tasks, all `status=completed` in the tq journal)
**Queue task:** 000001a0a1f149f8469390a3b300fddf0914 — this is the SECOND run of this closeout. The first run (06:10 today) wrote `2026-09-15_06-10_window-closeout-io-psi-guard-invokenamed-sweep.md` and harvested TODO items, but its own commit failed (tq fact 3520, exit 1); the auto-commit daemon carried its deliverables at 06:14 (`47b0585e`). This re-run re-verified every claim against the CURRENT tree and reachable history — and found one regression the first run missed (§d.1).

**Method:** every claim below verified against `git show`/`git merge-base --is-ancestor`, the tq journal (`tq facts -db /mnt/pool/services/tq/tq.db`), the reflog, and the live code tree. No invented history.

## The window's tasks

| Task              | What it was                                                                                                                                                                                       | Cited commit (dangling) | Reachable counterpart                               | Verified outcome                                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 000001a09ceb…     | Reviewer finding: the gitleaks commit-message rewrite (`8e8be78c`) never landed on branch history; `120ada36` (fabricated gitleaks sentence) still reachable; the status report claimed otherwise | `695ffda8`              | `638b91a3` (on origin/master)                       | CORRECTION block landed in the 2026-09-13_04-22 report; rewrite re-performed at the time — **since REGRESSED, see §d.1**                           |
| 000001a09d06…     | Sweep ALL LarsArtmann Go repos for `InvokeNamed[interface]` on concrete `do` registrations                                                                                                        | `1483bde0`              | `75e76712`                                          | 17-repo sweep (cmdguard added by the follow-up finding), ZERO live traps; only historical instance (DiscordSync) already fixed upstream `085fa539` |
| 000001a09d2b…     | IO-PSI phantom-saturation by D-state tasks on dead automounts — deploy gate + gatus can lie (crash3)                                                                                              | `5daa85cc`              | `b34b5fc8` (TODO close) + `be2ead2a` (code, daemon) | Code verified in tree (see a.2); TODO item closed                                                                                                  |
| 000001a09d4250c0… | IO-PSI emergency guard tier (Zone 6) for the freeze #3/#4 class                                                                                                                                   | `bc2d399c`              | `a03143ef`                                          | Verification-only run: Zone 6 was already complete from a parallel queue run; zero code authored, correctly                                        |
| 000001a09d42534b… | Reviewer finding: sweep report omitted cmdguard; count 16 vs 17                                                                                                                                   | `449ef806`              | `b481c047`                                          | cmdguard row added (`pkg/cmdguard/v4/scope.go:194`, same-T provide/invoke passthrough); count corrected to 17                                      |

All five cited SHAs are UNREACHABLE from HEAD (verified `git merge-base --is-ancestor`): they are the abandoned post-rewrite-lineage copies. The content survives via the reachable counterparts above — most re-landed through the 2026-09-14 10:00:16 rebase onto origin/master (reflog) and daemon commits. Reports citing the dangling SHAs are annotated with the counterparts (docs pass, this run).

## a) FULLY DONE

1. **The `InvokeNamed[interface]` sweep is complete and honest: 17 repos, zero live traps.** Every call site cross-checked against its registration's type parameter (report: now at `docs/status/archived/2026-09-14_00-00_task-000001a09d06ce7945994b3bef63af3ff419.md`). DiscordSync remains the only historical instance, fixed upstream with a regression test. The reviewer's completeness finding (cmdguard) was cured in-window. Closure recorded in CHANGELOG ("Verification-culture closures batch 2026-09-14").
2. **The deploy pressure gate reads IO PSI and classifies phantoms — code verified in the current tree.** `scripts/deploy.sh:214-288`: gate on io PSI some avg10 ≥ 20% (exit 12, `DEPLOY_FORCE_PRESSURE` intact), per-disk `%util` via double io_ticks read 1 s apart; real storm vs D-state corpse-pile signature with the distinction printed. `modules/nixos/services/_signoz-metrics.nix:392-397`: `node_psi_io_phantom` + `node_disk_busy_percent_max` emitted. `modules/nixos/services/gatus-config.nix:895-900`: "I/O Stall Rate" asserts `node_psi_io_alert 0` with a phantom-filtered description — pages real saturation only. The crash3 deploy-gate/gatus-lie class is closed in code.
3. **Zone 6 exists and is correctly documented.** `modules/nixos/services/memory-emergency-guard.nix:340` (io PSI some avg60 ≥ threshold trip), :591-593 (`memory_emergency_guard_zone6_trips_total`), :670/:682 (`ioPsiSomeAvg60ThresholdPercent`, `ioChurnUnits` options), with io_ticks-delta corroboration and the never-restart churn stop-list. FEATURES.md:130 carries the row; CHANGELOG has the full entry; the 2026-09-14 freeze #4 postmortem independently confirmed the zone fired live and by design.
4. **The gitleaks report CORRECTION content is in reachable history** (via `638b91a3`, on origin/master): the 04-22 report's false "clean rebase landed" claim is inline-corrected. The commit-message purge it describes has since regressed — §d.1.
5. **Queue state:** all five tasks `task.completed` in the tq journal (00:52-03:11 window, worker-63716). TODO_LIST closures have since graduated to CHANGELOG per the docs-health lifecycle (the `[x]` rows were retired 2026-09-15 06:15 pass — no drift, correct lifecycle).

## b) PARTIALLY DONE

1. **Zone 6 verification gaps remain open by design (harvested, not lost):** isolated VM-test rebuild, liveness probe of the three new `memory_emergency_guard_*` metrics, and deployed-generation parity on evo-x2 are TODO_LIST items under "Added 2026-09-15 06:10" (sourced from the archived 02-48 report §b.1). "Fix exists in git" and "fix protects the machine" are still different done-states.
2. **Provenance is split-brained and the cited SHAs are dead.** The window's five commits are unreachable; content reached history via daemon/replayed counterparts with partial message fidelity (the PSI code landed under a "heuristic" daemon message in `be2ead2a`). `git log --grep Task-Queue-ID` cannot fully reconstruct this window. Annotated, not fixable retroactively.
3. **The first closeout run (06:10) delivered its artifacts only via the daemon.** Its tq lifecycle shows the agent failed exit 1 right after "Writing the status report" (fact 3520); the 06:14 daemon commit (`47b0585e`) is what actually committed the report + TODO appends. The closeout contract's "commit" step has no verification loop.

## c) NOT STARTED (skipped, still open)

1. **Repo-generic CI do-analyzer** (provide/invoke type-parameter pairing across all Go repos) — named future hardening in the sweep report; TODO_LIST item exists (branching-flow's `doanalyzerv2` is the seed).
2. **Zone 6 threshold recalibration**, `zone6_churn_units_stopped` forensics metric, SigNoz dashboard surfaces, trip-tier routing check, runbook entry, backup-staleness tripwire while btrbk is guard-stopped — all harvested as TODO items, none started.
3. **The still-owed evo-x2 reboot** (flm :52626 corpse) — untouched, correctly; no queue item owns it.
4. _In passing (adjacent, not this window's five):_ sibling batch task `000001a09d06cf0bc…` (enqueued 01:07:44) dead-lettered after 3 failed verify runs on go-taskqueue's own suite (`internal/session` package build failure) — flagged for the go-taskqueue owner.

## d) TOTALLY FUCKED UP

1. **The gitleaks message purge did not stick — the fabricated sentence is back in reachable history (the window's own fix, regressed).** Verified 2026-09-15 07:32: `git merge-base --is-ancestor 120ada36 HEAD` → **true** (commit message line 12: "a 40-char hex SHA trips gitleaks' built-in sourcegraph-access-token rule and would block every future repo commit" — a claim retracted 2026-09-15); `git merge-base --is-ancestor 0ae59e3b HEAD` → **false**. Root cause: the message-only rewrite lineage was never pushed; the 2026-09-14 10:00:16 rebase onto origin/master (which still carried the old history) abandoned it, and the 2026-09-15 04:11/05:08 rebases re-anchored HEAD on old history again. This is exactly the AGENTS.md purge doctrine's warning — local rewrites while the push is HELD are cosmetic; the durable fix is the push-time re-filter (runbook) plus key rotation making residues inert. The 04-22 report's CORRECTION ("no reachable commit on any local ref contains the claim") is FALSE as of today and is annotated inline (docs pass).
2. **The first closeout (06:10) re-asserted "0ae59e3b IS an ancestor of HEAD" without re-running the check** — after two rebases had already made it false. That is the precise verify-your-own-work anti-pattern its own §e.1 preaches ("a status report about git state MUST include the ancestry/verification transcript at write time"). Corrected inline this run.
3. **Five dangling SHA citations shipped in one window.** The window's reports, TODO appends, and the 06:10 closeout cite `695ffda8`/`1483bde0`/`5daa85cc`/`bc2d399c`/`449ef806` — all unreachable within 30 hours of being written, because the lineage they sat on was abandoned. Content survived; citations did not. Live citations annotated with counterparts this run.
4. **Queue availability: this docs-only closeout took 7.5 hours to get a slot.** ~20 claim→requeue cycles between 00:02 and 07:31, almost all `preflight: repo has uncommitted changes` rejections from PARALLEL sessions' dirty files (CHANGELOG.md, integration.nix, test-miniflux.nix, ucr-rag.py, attic.nix, .gitleaks.toml, nix-check.yml, backup-coordination.nix, crush-daily.nix), plus 2 rate-limit deferrals and 2 agent-run failures. On a box where concurrent agent sessions are the norm, `require_clean` preflight starves docs-only tasks.
5. **Carried context:** every window commit ran `--no-verify` citing the red `checks.x86_64-linux.cv`; the fixture fix landed 2026-09-14 (`tests/test-cv.nix:43` seeds `CV_OIDC_CLIENT_SECRET`), so that excuse is now stale for future commits — future docs commits should let the hook run unless a NEW red exists.

## e) WHAT WE SHOULD IMPROVE

1. **Git-state claims need at-write-time verification, and RE-verification after any intervening history operation.** The §d.1/§d.2 pair is the same lesson landing twice in 36 hours. Ancestry checks are one command; both failures were skip-able in 5 seconds.
2. **Citation durability:** cite reachable SHAs; when a lineage is abandoned, sweep citing reports and annotate counterparts (done here for the live reports). Prefer "message + date + reachable SHA" over bare SHAs in reports about recent, unpushed work.
3. **Stop attempting local history rewrites while the push is held.** The purge runbook already prescribes re-filter at push time; the 09-14 rewrite was duplicative work that could never survive an origin resync. AGENTS.md's history-rewrite checklist is extended this pass with the origin-resync resurrection case.
4. **Queue contract:** a dirty-tolerant lane (`require_clean=false`) for docs-only tasks, or a docs-only preflight; and closeout runs must verify the footer commit actually landed (`git log -1 --grep Task-Queue-ID`) before emitting TQ_RESULT.
5. **Provenance (standing):** the daemon footer convention item remains the systemic fix for "meaningful code in heuristic commits" (the PSI code in `be2ead2a`).

## f) NEXT THINGS

The first closeout's harvest (22 next-things + 3 owner questions) is already appended to TODO_LIST under "Added 2026-09-15 06:10" — not duplicated here. This re-run appends only NEW items its investigation surfaced (4 items + 1 blocked question, see TODO_LIST "Added 2026-09-15 07:32"): the gitleaks-saga closure decision, the reachable-SHA citation-hygiene rule, closeout footer-commit verification, and the dirty-tolerant queue lane (blocked on owner).

## g) QUESTIONS FOR THE OWNER

1. **(standing, already BLOCKED-listed 06:10)** Deploy Zone 6 + post-deploy metric probe now, or hold for the /nix soak window (~2026-09-17) alongside crush-hot-db?
2. **(standing, already BLOCKED-listed 06:10)** Contract for verification-only runs: mint an empty footer commit so the queue's commit_sha resolves, or accept "no commit + honest TQ_RESULT"? And should DONE stamps / daemon commits carry Task-Queue-IDs (upstream go-taskqueue change)?
3. **(new)** May docs-only queue tasks (status reporters, closeouts) run with `require_clean=false` (or a dedicated lane)? The current preflight starved this closeout for 7.5 hours on other sessions' dirty trees — but loosening it trades away write-safety for docs tasks. Owner call.

## h) BAND DRIFT

**None recorded.** `tq facts` over the entire journal contains **zero `task.reprioritized` facts** (verified by grep over the full fact list, superset of the window's timespan) — no priority was moved by marker, AI, unblock, or importance in this window or any other. The only in-window journal churn is task lifecycle traffic (claims, verify-failure retries, one sibling dead-letter, completions), which is not reprioritization.

## Docs-health pass (this run)

- Annotated `docs/status/2026-09-13_04-22_task-…8d.md` inline: REGRESSED note on the CORRECTION block (facts of §d.1).
- Annotated `docs/status/2026-09-15_06-10_window-closeout-…md` inline: table row + §a.1 corrected (dangling ancestor claim + counterpart SHAs).
- Archived (items fully resolved / harvested): `git mv` of `2026-09-14_00-00_task-…f419.md` (sweep verdict) and `2026-09-14_02-48_task-…9bf54.md` (Zone-6 verify) into `docs/status/archived/` — the latter makes the existing TODO citations resolve; the two archived reports' top-level citations to the sweep report were repointed.
- CHANGELOG/FEATURES/ROADMAP/README verified current against this window (Zone 6 row, deploy-gate row, sweep closure all present; README untouched — no user-facing surface changed). AGENTS.md: history-rewrite checklist extended with the origin-resync resurrection case.
- Not archived: the 04-22 gitleaks report (saga record, actively referenced) and the 06:10 closeout (today's record, cited here).

---

Task-Queue-ID: 000001a0a1f149f8469390a3b300fddf0914
