# Wave-2 Full Status + Brutal Self-Review — §18 Gate, Fire Watcher, Migrate-State Forensics

**Report:** 2026-10-26 17:21 CET · **Session run:** 2026-10-26 10:44 → ~12:00 (execution) + 17:15→17:21 (errata + this review) · single agent (crush) · evo-x2 working tree
**Commits (all local, NOT pushed):** `14e14330c` (plan) · `3187b86bd` (§18 gate) · `b65bfbe21` (ticks+status) · `9172f8522` (fire watcher) · this report's errata batch
**First close-out:** `docs/status/2026-10-26_11-30_fast-todo-wave2-session-status.md` (§a inventory lives there; this report supersedes it as the session's final word and corrects two of its claims — flagged inline)
**Context at close:** 5+ heuristic parallel commits since noon; `pipeline.md`/`selftests.nix`/`scripts/` now CLEAN (the wave's dirty-file deferrals are UNBLOCKED, see §b); root `/` recovered 99%→**88% (85G free)** — the crisis session's drain landed while this session worked.

---

## a) FULLY DONE

| # | What | Evidence | Commit |
|---|---|---|---|
| a1 | **Wave-2 plan** with ALL-TODOs coverage map (11 surfaces, ~3,264 open, explicit disposition per surface), ≤12-min µ-task table, EXECUTING tombstone | `docs/planning/2026-10-26_10-55_SUPERB-fast-todo-wave2-execution.md` | `14e14330c` |
| a2 | **Deploy-gate friction map with a material correction**: §8 disk space is byte-based (FAIL <5G / WARN <15G), NOT the "<10% block" of the 07-09 report's a4 (that is MemAvailable). At 10:44's 14G free, the E6 deploy would only WARN on disk | plan §5 | `14e14330c` |
| a3 | **`.migrate-state` forensics SOLVED**: real dir `/mnt/hot/hot/.migrate-state/` (`HOT_PARENT="$TOPLEVEL/hot"`, migrate-hot-db.sh:58-62); waves 1-5 carry full markers (discordsync 10-12 15:46 · gatus+browser-history 10-14 15:07 · pocket-id 18:45 · dnsblockd 21:52 — stamps decoded, dir mtime matches the last wave); **wave 6 (postgres): NO marker ⇒ the config comment "Prepared + cut over BEFORE this entry landed" was claim-only** | marker files + `date -d @` decode; wave-by-wave table in the 11-30 report §P3 | `b65bfbe21` |
| a4 | **§18 shadow-split pre-deploy gate** — the wave's data-loss-class item: enumerates hot-user-caches `.caches` + hot-db `.entries` via nix eval; FAILs the wave-6 signature (data-class empty subvol over non-empty shadow) + PG_VERSION presence parity; WARNs on parity bands (<25%), missing subvol (fast-loud-by-design), EACCES degradation; §15-style delegation, `--section-18-only` flag | `scripts/shadow-split-gate.sh` + `scripts/pre-deploy-check.sh`; shellcheck + flake check green via hooks | `3187b86bd` |
| a5 | **19/19 gate fixtures green** — every verdict branch incl. the `/hot/` parent prefix | `bash scripts/test-predeploy-shadow-split.sh` | `3187b86bd` |
| a6 | **§18 live run matches reality**: 5 entries pass (cache/nix prepared-shape; discordsync/dnsblockd/pocket-id/postgres populated at `/mnt/hot/hot/<name>` — postgres = the recovered 780M cluster), 3 WARNs true (cache/tmp half-provisioned mid-E6 — the gate is the migration's independent progress light; 2× `/var/lib/private/*` degraded without sudo ticket) | `--section-18-only` run | `3187b86bd` |
| a7 | **`deploy-when-quiescent.sh` + shared `eval-relevant-paths.sh`** (queue row 1525): 4×60s clean+cold polls, green-eval pre-gate (`nix eval --raw`, NO `--no-link`), DRY default, `--fire` rc=1 classification (§11-void/eval signature = exit 3 expected-race; else stop for review); per-run-only output grep; stability constant derived from battery duration in the header | shellcheck green; live dry runs 11:49 (refuses dirty tree, reset paths logged) | `9172f8522` |
| a8 | **Queue/library ticks**: 3 queue rows + 2 storage rows closed with DONE notes (gate, forensics, quiescent productization); close-out-discipline row annotated; 3 harvest rows queued; `check-todo-system.sh` → "OK: TODO queue/library structure clean" | this batch | `b65bfbe21` |
| a9 | **AGENTS.md quote-scrutiny rule** (07-09 §f.12's do-on-sight) landed in Session Discipline | AGENTS.md | `b65bfbe21` |
| a10 | **Foreign-index defense**: a parallel session staged deletions of this session's committed files mid-session; defused via pathspec-scoped `git reset HEAD -- <my paths>` (mixed form) after byte-identical verification — zero loss, no foreign work touched | worktree-vs-HEAD diff checks + post-reset status | process |
| a11 | **Two errata applied (17:2x)**: the plan's §0 stale "zero state records" line (§d2) and the 11-30 report's premature "commit (this batch)" citation (§d3) — both corrected in place with ERRATA markers naming the corrected surfaces | the two ERRATA blocks | this batch |

## b) PARTIALLY DONE / DEFERRED

1. **pipeline.md twin ticks** — wave-1's 4 rows (648/1386/1419/1491) + row 579 (quiescent script) + library twins for the 3 new harvest rows. Blocked all morning by the parallel-dirty file; **NOW UNBLOCKED (file clean at 17:2x)** — first dispatch candidates.
2. **`predeploy-shadow-split-selftest` flake-check wiring** — selftests.nix was parallel-dirty at authoring; **NOW UNBLOCKED**. The standalone fixture proves the lib today; the flake leg makes CI own it.
3. **§11 tree-stamp adoption of `eval-relevant-paths.sh`** — vendor-freshness.sh deliberately untouched (deploy-battle-tested script gets its own commit + a `--section-11-only` verify). Queued, not done.
4. **Full pre-deploy battery with §18** — only `--section-18-only` + hook flake-check ran; the full-mode dispatch path (§18 between §17 and Summary with all sections live) never executed end-to-end. Low risk (same function call), honest gap. Needs a calm window (~8-10 min of evals).
5. **Watcher WOULD-FIRE end-to-end** — the tree never went clean during the session; gates A (live-negative), B and C (form-verified standalone) each proven individually. First real fire = the proof; it should ride the E6 deploy (crisis plan T2) with the runbook step naming it.
6. **Tail grind** — plan P7 promised "2-4 XS docs-only rows", delivered ONE (the AGENTS.md rule). The session's budget went to the two Critical items; the tail promise was oversold.
7. **Wave-6 in-tree claim cleanup** — the fabricated "Prepared + cut over" comment in the postgres entry's neighborhood was never verified/corrected in configuration.nix (the file was parallel-dirty all session). The report + ticked row close the QUESTION; the TREE may still carry the false claim. Verify + fix next dispatch.

## c) NOT STARTED (owner-gated or explicitly out of lane)

| Item | Gate |
|---|---|
| Tonight's 23:00 balance redo (crisis plan T1) + wevisone-spike / cross-repo consent / balance-deviation answers | owner |
| Hermes config dup-key one-liner; overcommit posture confirmation (wave-1 Q1/Q2) | owner |
| Crisis-plan armor T5/T6/T7 (balance-failure alerting, storage-collect hardening, io-psi-crosscheck delta mode) — agent-executable, but the 10:33 session owned that lane; not coordinated, not started | lane claim |
| PG shadow-split residue reclaim (413M + blank cluster) | owner sudo, post-green-days |
| Push of the 4 wave-2 commits | needs explicit owner request |

## d) TOTALLY FUCKED UP (all self-caught; two cost real time)

1. **The forensics premise failure I almost SHIPPED**: the plan file's §0 (authored ~10:52) asserts "`/mnt/hot/.migrate-state/` does not exist → zero state records survive; waves were claim-only" — **wrong**, corrected ~30 min later when the `hot` entry in the `ls /mnt/hot` output contradicted it, and the TRUE answer (5 evidenced waves, 1 claim-only) is materially different from the false one. The false version sat committed for the whole session until today's errata. The near-miss class: I inherited the row's wrong path, "verified" absence at the wrong path, and generalized from it — exactly the wrong-premise dispatch cost the TODO system documents, this time committed into a plan before the correction. Cost: a false standing fact in git history for ~5.5 h + this errata. Lesson recorded: an absence finding requires deriving the expected path from the CODE, not from the citing row (I eventually did exactly that — the script's `HOT_PARENT` — and the correct answer fell out immediately; should have been step 1).
2. **"P5 landed" was claimed ~2 h before it landed**: the 11-30 report §a7 cites "commit (this batch)" for the watcher files — at authoring time they were worktree-only; the final status check caught them uncommitted and `9172f8522` landed only then. The evidence-table discipline ("assert WHICH commit") was violated by my own report; fixed with an inline ERRATA. Cost: the report was untrustworthy on exactly the row it existed to make trustworthy.
3. **My §18 draft carried THREE premise failures** (each would have been a phantom-green or false-block in production): `nix eval --raw` on a boolean silently became "no enabled entries" via my `|| echo null` — the gate would have skipped the very E6 entries it was built to guard; the user-caches option is `.caches` not `.entries`; the hot-db subvol root is `/mnt/hot/hot/<name>` — the SAME path error as §d1, made independently twice in one session. All caught pre-commit by the live probe + fixtures, but the fixtures were written AFTER the gate (see §e1).
4. **Permission-shaped absence in `dir_size`**: root-owned 700 shadows reported "absent" (→ PASS) instead of "unknown" (→ WARN) because `-d` fails on unreadable parents — a silent false-PASS class in a data-loss gate. Fixed via parent-readability probe; the live run's browser-history/gatus WARNs prove the fix.
5. **Six wasted commit cycles**: 3× shellcheck SC2034 (verdicts, VerdictLines, EVAL_RELEVANT_PATHS), 3× subject-length house limit (96/77/74 > 72) — each rejection pays the full hook battery (~2-4 min incl. flake-check eval). I knew the 72-char limit from wave 1 and still shipped three over-length subjects in a row.
6. **Shared-index commits the hard way**: first commit died on a FOREIGN staged file's statix finding; the temp-index (`GIT_INDEX_FILE`) solution emerged only after the second failure. The pattern is now proven 5× this session but remains tribal knowledge (§f10 productizes it).
7. **A `set -e` bug sat in the watcher's first write** (post-deploy `set -e` with no matching off — would have changed exit semantics mid-loop); self-caught in the pre-commit read-through, never committed. Process worked; it was luck-adjacent that the read-through happened before the commit, not after.

## e) WHAT WE SHOULD IMPROVE

1. **Fixture-first for config-reading gates**: writing `test-predeploy-shadow-split.sh` BEFORE wiring §18 would have caught the raw-bool + option-name bugs at fixture time. Every new §-gate gets fixtures before its first live run.
2. **Absence findings derive paths from code**: verify-where-the-thing-WOULD-be by reading the producer, never by trusting the citing document's path (§d1's lesson, generalizable beyond this repo).
3. **`scripts/commit-solo.sh`**: productize the temp-index commit pattern (shared-index co-mingling is now the norm on this tree, and the pattern is 5×-proven tribal knowledge).
4. **Subject-length pre-check**: the house hook rejects at commit time; a 1-second `awk` check before composing saves a full battery per miss.
5. **§18 eval cost**: the gate adds ~4 nix evals to every deploy battery; the §1 content-addressed stamp pattern could cache them for identical trees.
6. **Report-before-commit discipline**: a status report must never cite a commit that does not exist yet — write "worktree-only, commit pending" or commit first.
7. **Gate escalation policy should be explicit per class**: cache (regenerable) vs data (irreplaceable) verdicts differ by design; the policy belongs in the gate's header, not just its code (§g1 asks the owner to ratify it).

## f) TOP 50 NEXT (sorted: Critical → High → Medium → tail; agent/owner/lane tagged)

| # | Item | Tier | Who |
|---|---|---|---|
| 1 | Wire `predeploy-shadow-split-selftest` into selftests.nix (runs the 19-case fixture) — UNBLOCKED | Critical | agent |
| 2 | pipeline.md:579 twin tick (quiescent script shipped, `9172f8522`) — UNBLOCKED | Critical | agent |
| 3 | pipeline.md twins for wave-1 rows 648/1386/1419/1491 — UNBLOCKED | Critical | agent |
| 4 | pipeline.md library twins for the 3 harvest rows (selftest wiring, §11 adoption, fixture-coverage check) — UNBLOCKED | Critical | agent |
| 5 | §11 tree-stamp adopts `eval-relevant-paths.sh` (own commit + `--section-11-only` verify) | Critical | agent |
| 6 | Full pre-deploy battery incl. §18 at a calm window (full-mode dispatch verification) | Critical | agent |
| 7 | E6 deploy rides `deploy-when-quiescent.sh --fire` + runbook names it; §18 tmp WARN flips PASS on prepare (crisis T2 coordination) | Critical | owner+agent |
| 8 | Verify + correct the wave-6 "Prepared + cut over" comment if it still sits in configuration.nix (§b7) | Critical | agent |
| 9 | Close-out discipline line in docs/agents/storage.md (row 3 of storage.md top — file now clean) | High | agent |
| 10 | `scripts/commit-solo.sh` (temp-index productization, §e3) | High | agent |
| 11 | §18 eval caching via the §1 stamp pattern (§e5) | High | agent |
| 12 | Fixture-coverage check: every scripts/test-*.sh has a selftests.nix leg (§e-gap) | High | agent |
| 13 | Subject-length pre-check hook/companion (§e4) | High | agent |
| 14 | §18 cache-vs-data escalation policy ratification (§g1) | High | owner |
| 15 | T5 balance-failure alerting (`balance: ended with status: -N` → gatus/Discord) | High | agent (crisis lane) |
| 16 | T6 storage-collect storm hardening (D-state starvation + uid-966 SIGSYS loop) | High | agent (crisis lane) |
| 17 | T7 io-psi-crosscheck delta mode (top movers + unattributed-bytes signature) | High | agent (crisis lane) |
| 18 | T8 E6 fixture test + hot-user-caches↔disko eval cross-guard | High | agent (crisis lane) |
| 19 | T12 drain verification (Oct 27-28: df vs baseline; root now 88% — stamp the recovery) | High | agent |
| 20 | hermes WAL-branch VM fixture (queue 879) | High | agent |
| 21 | tq-agent-pool harvest full-rescan skip-cursor (stability.md:161, Pareto blocker) | High | agent |
| 22 | ghostty interactive-scope IO storm root-cause (monitoring.md:167, Pareto blocker) | High | agent |
| 23 | InboxClean dashboard query cost upstream (upstream.md:15, consent-gated) | High | owner+agent |
| 24 | Per-endpoint gatus failure-names collector | Medium | agent |
| 25 | §17 post-deploy user.slice memory-sweep leg | Medium | agent |
| 26 | system-health freshness composites | Medium | agent |
| 27 | cv-server /health three warn sub-checks triage (07-09 §f.2) | Medium | agent |
| 28 | Caddy tracing live-verify + g2 coverage budget (needs one human browse) | Medium | owner+agent |
| 29 | Calm-window post-deploy-check re-baseline (storm-suspect smokes; 07-09 §f.7) | Medium | agent |
| 30 | post-deploy: split "not listening" from "just-restarted-and-settling" (07-09 §f.8) | Medium | agent |
| 31 | Storm IO attribution redo with iotop-c/pidstat (07-09 §f.9) | Medium | agent |
| 32 | cv ExecStartPost port-readiness probe (:8098 class) | Medium | agent |
| 33 | OpenSEO rendered-parity proof (5-step incl. integration-registry check) | Medium | agent |
| 34 | SigNoz collector sampling-policy check before trusting caddy span volume | Medium | agent |
| 35 | `checks.caddy-mint` boot-proof at a calm window | Medium | agent |
| 36 | ClickHouse dead-view query sweep (`distributed_signoz_spans` class) across runbooks | Medium | agent (caddy-gen950 row) |
| 37 | otel-endpoint-audit exporter-protocol↔port-kind assertion + negative leg | Medium | agent (caddy-gen950 row) |
| 38 | netbird `/dex/healthz` gatus end-to-end verify | Medium | agent (caddy-gen950 row) |
| 39 | 443-listener map into docs/services/caddy.md (perishable, mark as such) | Medium | agent (caddy-gen950 row) |
| 40 | `scripts/prune-done-todos.sh` first `--apply` pass (queue 680; WARN recount expected to RISE) | Medium | agent |
| 41 | TODO gate queue↔library checkbox-parity leg (queue 907) | Medium | agent |
| 42 | T13 monitor365 39G DuckDB relocation decision | Medium | owner |
| 43 | T14 burst-snapshot policy (5-snaps-in-a-day class) | Medium | agent |
| 44 | T16 ClickHouse p9 siting memo (197G lifetime writes on root disk) | Medium | decision |
| 45 | T17 `.rescue` double-fire attribution (Oct 25 22:25+22:30) | Medium | agent |
| 46 | T19 weekly-balance manual-gap wrapper (maintenance-entry-gate "balance running" leg) | Medium | agent |
| 47 | T20 post-recovery housekeeping (stale disk-cleanup-proposal annotation, CHANGELOG) | Medium | agent |
| 48 | T18 post-E6 watches (~/.cache regrowth >90G row; tmp automount idle×builds probe) | Low | agent |
| 49 | Wave-1 hermes config dup-key + overcommit confirmation (standing Q1/Q2) | Low | owner |
| 50 | ROADMAP: `--wait-quiescent` flag on `nix run .#deploy` itself (after §f-fire proves the pattern) | Low | decision |

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **§18 escalation policy**: an EMPTY cache-class subvol over a non-empty shadow currently WARNs (regenerable data; the live E6 `tmp` state trips exactly this). Do you want cache-class to hard-FAIL deploys too — or is WARN right, given the churn double-billing that motivated E6? I picked WARN; ratify or overrule and I'll encode it as policy in the gate header.
2. **The wave-6 false claim in the tree**: if the "Prepared + cut over BEFORE this entry landed" comment still sits in configuration.nix (unverified per this report's no-research scope), do you want it corrected/blame-annotated in-tree (a one-line edit riding the next deploy), or is the forensics report + ticked row the closure you want?
3. **Push + tonight's window**: the 4 wave-2 commits (+errata) are local-only — push now? And does tonight's 23:00 balance redo (crisis T1) still stand as planned? It gates whether the E6 deploy rides tomorrow through the §18+quiescence gates this session shipped.

---

**Handoff:** everything this session promised is either landed+verified (§a) or deferred with its exact unblock named (§b) — the two claims this session got WRONG are corrected in place with ERRATA markers (§d1/d2, §a11). The 50-row §f is dispatch-ready; items 1-9 are unblocked RIGHT NOW (dirty files cleared at ~17:2x).
