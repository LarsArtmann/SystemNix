# Task-Queue Window Closeout — 2026-11-14 09:23 skeleton, filled at 09:40 (4th fire, CANONICAL)

Task-Queue-ID of this closeout: `000001a1d8cbc3ff68f9d852788500000000`. Window: 5 completed tasks spanning 2026-11-10 → 2026-11-14.

**Fire chain (why this file is the 4th artifact for one window):** the 08:42 instance landed a full report (`19cce5de3`, file `2026-11-14_08-42_task-queue-closeout-window.md`) + CHANGELOG entry + 5 TODO_LIST rows but died before the tq verdict write; the queue re-fired. The 09:14 fire minted a skeleton + the verdict-loss row (TODO_LIST 3606, commit `c3832bb77`) and died. The 09:23 fire minted a second skeleton (commit `d425c69f9`) and died. THIS fire adopted the 09:23 skeleton, filled it, and records the verdict immediately post-commit (row 1469's rule, finally applied). The two predecessor files are annotated as folded into this one; their verified claims are re-stated here, re-checked at HEAD `d425c69f9` — they were not silently dropped.

Verification method: all four task closeout reports read in full (`docs/status/tasks/2026-11-10_01-44`, `02-23`, `2026-11-13_17-18`, `2026-11-14_07-04`); window commits inspected via `git show --stat` (`377a242f7`, `64c124592`, `316362190`, `d7963ea17`, `8b5acf49c`, `042f1044be`, `42fb02c17`/`fd42bde67`/`070eb35cf`/`889ee2b84`/`754320dce`/`4bb4a39e0`); cited TODO_LIST rows verified live at their line numbers (383/390/394/413/414 ticked; 2533, 3460–3465, 3565–3566, 3584–3595, 3597–3601 present and open); tree claims grepped at HEAD (llama-rag.nix:94–95 + nsfw-classifier.nix:172–173 RestartSteps=5/15min; cvagent.nix:205 `MemoryMax = mkForce "1G"` + :186 scan oneshot stays 512M; forgejo.nix:553 1G); band drift via `tq facts --type task.reprioritized` (0 facts) at 09:3x.

## a) FULLY DONE

1. **Task `…c14f087910` — time_series_v2 library-row tick drift fixed** (`377a242f7`, 1 file +1/−1): the reviewer's exact finding (queue `[x]`, library `[ ]`) repaired with a full-line-match edit guarded by an exactly-once anchor; batch parity asserted (all five items of parent batch `000001a1bdadc729` now `[x]` in docs/todo/monitoring.md); the gate gap (pairing_check reads only OPEN rows; "same report" citations unresolvable) source-read and minted as TODO_LIST 3460–3462.
2. **Task `…c14f087b6ab` — gatus endpoint-count drift fixed** (`64c124592`, README.md + TODO_LIST.md): README prose stamped to the live-eval truth (286 at that tree, deliberately overriding the reviewer's literal 285 to avoid minting a THIRD inconsistent count); the close-out kept the batch-final 285 with scope; repo sweep left zero stale hits outside docs/status/; the doc-counts gate RUN green post-fix (closing an argued-vs-ran gap); residue surfaces minted as 3463–3465.
3. **Task `…c7a258eff` — adb mDNS listener on 0.0.0.0:5353 verified intentional** (`316362190`, 2026-11-11): live fork-server for webphone-android (Pixel6 tooling), intent documented at the android-tools package site with the `ADB_MDNS=0` off-switch and loopback-only 5037 control socket; TODO_LIST:383 ticked with the verdict; no firewall change needed (eno1 firewall-trusted). Security question closed.
4. **Task `…d23e580d67` — the two §17 undersized budgets bumped** (code in daemon commit `d7963ea17` — content verified as exactly cvagent.nix + forgejo.nix; attribution commit `042f1044be`): cvagent serve unit `MemoryMax` 512M → 1G `mkForce` (the scan oneshot stays 512M — no throttle evidence), forgejo main unit → 1G (derives its 819M high at 80%); both verified in the tree at HEAD. Same session also landed: SigNoz v3 API cheat-sheet + Delta-temporality restoral docs, PSI emitter fail-visible + freshness canary, and `scripts/test-psi-percent-semantics.sh` grown 24 → 38 green legs (io-boundary-40/-401 both sides of the >40 storm bar, corroborated-storm full alert path, mutation negative control; `psi-percent-semantics-selftest` flake check green) — TODO_LIST:390/394 ticked.
5. **Task `…d5d871644a` — ai-stack 5-item batch** (5 footer-bearing commits + closeout `4bb4a39e0`):
   - pid churn verdict: restart cadence (`Restart=on-failure` loop), NOT ensure-convergence — the converger structurally cannot cycle an active pid; probe pattern (resolve MainPID at start + post-assert liveness) documented in docs/agents/monitoring.md (`42fb02c17`).
   - restart backoff: `RestartSteps=5` + `RestartMaxDelaySec=15min` on llama-embeddings/llama-reranker (shared commonServiceConfig) + nsfw-classifier; systemd 262 ≥ 254 eval-verified; full `nix flake check --no-build --all-systems` green at commit (`fd42bde67`); both settings grepped in-tree this pass.
   - re-embed calm-window batch DESIGN: docs/planning/2026-11-14_06-15_re-embed-calm-window-batch-design.md (`070eb35cf`).
   - demand profile measured from ClickHouse (samples_v4 ⋈ time_series_v4, ai_meter_requests_total), per-day + per-hour shape (`889ee2b84`).
   - write attribution pinned to unit cgroup + device magnitude: last invocation wrote **645.2 GB / read 8.5 GB**; /data wrote 0 since boot → the HDD pool; two new findings queued (Samsung 16.6 TiB/7d write rate; paperless-slice counter-evidence) (`754320dce`).

## b) PARTIALLY DONE

1. **Budget-fix verification half**: code landed but the `memory.events` counter re-read that PROVES throttling stopped needs the tree deployed + units restarted; honestly queued (3565), not faked. The deploy itself is currently BLOCKED by three foreign input breakages (row 3596: cv FOD guard, signoz FOD, invoices — first-hand evidence 2026-11-14 keep-going), so this half waits on the whole fleet deploy path.
2. **Re-embed work is design-only**: the timer oneshot + psi-wait-gate + content-hash cache + checkpointed consumer has no implementation; its implementation row (3586) was minted retroactively in the 11-14 closeout because the design tick could have read as done.
3. **Write attribution, inner mechanism unpinned**: unit cgroup + pool level proven; which file/syscall dirties 645 GB is unknown (per-device io.stat dies with the cgroup at stop) — instrumentation row 3584.
4. **pid-churn evidence base is mechanism-level**: the 2026-10-29 journal is vacuumed (oldest retained boot 2026-11-06); the verdict comes from the ensure script's code path, not that night's logs.
5. **Restart backoff spec deviation**: the ask said `RestartSteps=4` + 10min + jitter at systemd ≥262; shipped 5/15min, NO jitter (repo flm/vlm canon, deterministic timing for probes). Deviations argued in the commit but decided unilaterally — owner ruling queued (3600, blocked:user). nsfw-classifier's setting is eval-verified only (unit disabled on evo-x2 — unverified-on-target).
6. **Count-consistency class survives the fix**: FEATURES L97 ("133") + L635 ("100" + stale recipe) and monitoring.md L52 are queued (3463) not fixed; AND this pass found a FRESH instance — README:18 services-table says **298** while the doc-counts-anchored README:82 prose was re-stamped to **302** by the audiblesync wave (2026-11-14). The re-stamp discipline updates the anchored line; the table row rots.
7. **Shellcheck residue**: the 11-13 daemon commit bypassed the staged-path shellcheck leg and standalone shellcheck was unavailable in the agent shell; test-psi-percent-semantics.sh verified by `bash -n` + 38-leg execution only (row 3598).
8. **The closeout loop itself is the window's biggest partial**: one done prompt, four fires, zero recorded verdicts until this one, and three report files for one analysis. Fixed in this fire (adopt + fill + amend; verdict immediately post-commit); the process rows are 3606 (verdict ordering, minted by the 09:14 fire) and this report's §f.2 (artifact dedup).

## c) NOT STARTED (verified present, unchecked, at HEAD)

- Gate legs for the tick-drift class: tick-state parity in pairing_check (3460), same-report Source resolution (3461), `check-todo-system.sh --selftest` → flake check + CI (3462).
- Count consistency: FEATURES re-stamp + doc-counts anchor extension (3463), SigNoz 52/10 vs 54 `mkRule` reconciliation (3464), AGENTS.md batch-final count-citation rule (3465), README:18 re-stamp + anchor widening (NEW this pass, §f.1).
- Deploy-gated verification: post-restart cvagent/forgejo counter re-read (3565; behind the row-3596 foreign-breakage deploy block).
- PSI/selftest hardening: io_warning 10.00-exact boundary legs (3566), mutation-leg audit across other fixture selftests (3567).
- ai-stack/storage follow-ups: re-embed implementation (3586), llama-chat backoff (3587), fixed-RestartSec fleet sweep (3588), backoff regression test (3589), trickle consumer (3590), clickhouse→pool 70.8 GB attribution (3591), nsfw metering (3592), IO-counters evidence pattern into docs/agents/systemd.md (3593/3597 — duplicate pair, dedupe at dispatch), ClickHouse day-filter root-cause (3594), **gated-fleet DARK streak — llama-embeddings dependency-failed since 11-08 while the owner may assume it serves (3595, plausibly the highest-value item in the queue)**, Samsung 16.6 TiB write-rate attribution (3585).
- Window periphery (parallel sessions, correctly not this window's work but landlocked on the same deploy): CI red cluster 3574–3579, tryEval sweep 3579, audiblesync rows 3596/3598–3605.

## d) TOTALLY FUCKED UP

1. **The closeout dispatch chain: four fires for one done prompt.** The 08:42 instance finished a full, correct report and died at the last step (verdict write); two skeleton fires repeated the crash-checkpoint without finishing. The failure mode was already codified (row 1469, 2026-10-15: "write `$TQ_RESULT_FILE` immediately after the report commit, before end-of-session verification"; row 1762 documents a 7-refire instance of the same class) and was still not applied by any of the three prior fires. Paid waste: ~3× re-reading four closeout reports + re-verifying nine commits. This fire applies the rule; row 3606 owns the pool-contract half.
2. **Artifact duplication from the same chain**: three files now describe one window (08-42 filled, 09-14 skeleton, 09-23 canonical). Each re-fire minted a fresh skeleton instead of adopting the existing report at HEAD. Annotated this pass (both predecessors point here); the process fix is new row §f.2.
3. **The window's real code rides footless daemon commits**: `d7963ea17` (the budget bumps) and `4b60131a1` (psi script + selftests.nix, which also swept a parallel session's check-contact-registry-drift.sh + pre-deploy-check.sh changes). Attribution commits landed on top and name the ridden hashes (correct per policy — no amend, foreign files would be absorbed), but `git log --grep Task-Queue-ID` will not surface the hunks themselves. Known daemon-race cost, handled, not lost.
4. **ClickHouse day-filter silently no-oped** (11-14 session §d.1, self-reported): `unix_milli > now64(3) - INTERVAL 8 DAY` matched ALL history; the session noticed rows outside the window and sailed past, and the final query dropped the filter — the report's range is what the data HAPPENED to cover. Direct quote-scrutiny violation; conclusions survive (shape-based classification); root-cause row 3594.
5. **The parent batch `000001a1bdadc729` shipped reviewer-findable drift through every gate** — three inconsistent gatus counts and the queue↔library tick drift; two of this window's five tasks are its repair dispatches. The repo's own gate structurally cannot catch either class (open-rows-only pairing, no same-report resolution, .md-only commits skipping eval — a fresh reproducer: `64c124592` touched a readFile'd README while the hook printed the eval-skip line). Fixes queued (3460–3462, 743), not built.
6. **Tick co-ride**: the 11-14 session staged TODO_LIST.md wholesale for the item-3 commit, so that diff carries items 4/5's queue state — per-commit narratives lie; tq derives completion from footers, so nothing is lost.
7. **Tick-time follow-through gap**: the design row was ticked without a co-committed implementation row; caught retroactively in the 11-14 closeout (3586 minted there).
8. **Fresh drift instance found by this pass**: README:18 (298) vs README:82 (302) — the exact prose-vs-table duality row 742 polices, reopened by the audiblesync wave's re-stamp. Minted as §f.1, not fixed here (the compliant fix extends doc-counts anchors = flake check edit, outside this task's docs-only scope).

## e) WHAT WE SHOULD IMPROVE

1. **Verdict immediately post-commit** — row 1469's rule, applied by this fire for the first time in four. The verify/polish work that preceded the verdict write in every prior fire is exactly what killed them.
2. **Re-fired closeouts adopt the existing artifact** — fill + amend the skeleton commit at HEAD; never mint a second skeleton for the same window (§f.2).
3. **Widen doc-counts coverage to every README count surface** — the anchored line-82 discipline works; the unanchored line-18 table rotted within four days of the last fix (§f.1; sibling of row 742).
4. **Batch-closeout hygiene stays the top pipeline priority** — all three 2026-11-10 repair dispatches trace to one missing parity grep; rows 3460–3462 make it mechanical, 3599 makes it ritual (owner decision pending).
5. **Query-premise discipline** — a result contradicting its own filter gets root-caused before quoting, even when the accident is "more data" (row 3594).
6. **Tick-time follow-through** — a `[x]` on a design row co-commits its implementation row (doctrine exists; enforcement was retroactive here).
7. **Spec deviations flagged AT COMMIT TIME** ("asked X, shipped Y because…") + explicit unverified-on-target notes for settings landed on disabled units.
8. **Eval-relevant predicate vs readFile'd docs** (row 743): a staged README edit should run the cheap targeted `doc-counts` eval instead of skipping eval entirely.
9. **Daemon-swept scripts get no shellcheck until next staged touch** — the execute-instead fallback (bash -n + fixture run) held; row 3598 tracks the re-run, a CI shellcheck leg would close it structurally.

## f) NEXT THINGS (up to 50 — the queue already holds the deep backlog; existing rows cited, not re-minted)

**NEW this pass (appended to TODO_LIST, 2):**
1. Re-stamp README:18 services-table Gatus count (298 → live 302) + widen doc-counts anchor coverage to that row; audit ALL embedded README count surfaces in the same pass (row-742 sibling; Source: this report §d.8).
2. Re-fire closeout protocol: adopt the existing skeleton/filled report at HEAD (fill + amend that commit) instead of minting a fresh skeleton per fire — artifact-dedup sibling of rows 1469/3606 (Source: this report §d.1–§d.2).

**Already queued — highest value (verified open at HEAD):**
3. 3595 gated-fleet DARK streak (llama-embeddings dependency-failed since 11-08; is the calm gate refusing at its PSI cap or erroring?).
4. 3565 post-restart cvagent/forgejo counter re-read (behind the 3596 deploy block).
5. 3586 implement the calm-window re-embed batch job per the landed design.
6. 3460/3461 tick-state parity + same-report resolution in pairing_check (kills the class behind two of this window's five tasks).
7. 3462 wire check-todo-system --selftest into flake check + CI.
8. 743 pre-commit doc-counts leg when README/FEATURES staged (fresh reproducer `64c124592`).
9. 3463 FEATURES re-stamp + doc-counts anchors.
10. 3464 SigNoz 52/10 vs 54 mkRule reconciliation.
11. 3587 llama-chat crash-loop backoff (two-line pattern, documented OOM loop).
12. 3585 Samsung 16.6 TiB/7d write-rate attribution (wear-rate alarm on the hot-tier disk).
13. 3584 per-device io.stat instrumentation of llama-embeddings' next serving window.
14. 3589 VM/negative test asserting the backoff settings on the four units.
15. 3594 ClickHouse day-filter no-op root-cause + monitoring.md trap bullet.
16. 3566 io_warning 10.00-exact boundary legs; 3567 mutation-leg audit across fixture selftests.
17. 3597/3593 duplicate IO-counters-pattern rows — dedupe at dispatch (one row should be ticked as the twin).
18. 3598 shellcheck re-run on test-psi-percent-semantics.sh at next staged touch.
19. 3588 fixed-RestartSec fleet sweep (whisper workers, immich-ML, signoz stack, forgejo runner).
20. 3590 identify the 8-11 req/h embeddings trickle consumer; 3591 clickhouse→pool 70.8 GB attribution; 3592 nsfw metering route.
21. 3574–3579 CI red cluster (go-deps-audit runner, secret-history-scan fixture, negative-tests, nix-check + VM legs, checks-never-built hole) — parallel-session work, landlocked on the same tree.
22. 3596/3602–3605 audiblesync deploy path + runbook hardening rows (foreign-breakage triage playbook, preflight keep-going rule).

## g) QUESTIONS FOR THE OWNER (all already dispatched as blocked rows — cited, not re-minted)

1. **Gate hardness**: once 3460/3461 land, should `CHECK_TODO_PAIRING=strict` become the blocking pre-commit default, or stay WARN? The window's repair cycle (2 of 5 tasks were repairs of one batch) strengthens the strict case — tracked as decision row 2533.
2. **Restart backoff spec deviation ruling**: accept 5/15min no-jitter (repo canon + deterministic probe timing), or overrule to the literal ask (4/10min + jitter)? — row 3600 (blocked:user).
3. **Drop ruling for the dead-legacy `time_series_v2` ClickHouse table**: 0 rows, nothing writes it, blocklist entry landed `0bb953d24`; parked on your ruling since 2026-11-09 — row 3601 (blocked:user). (The verdict-loss pool-contract decision is row 3606.)

## h) BAND DRIFT

`tq facts --type task.reprioritized` → **(0 facts)** — verified live at 2026-11-14 09:3x for the window's timespan and overall: **none recorded**. No priority band moved this window; the dispatch sequence is fully explained by the queue's harvest order (plus the done-prompt re-fire chain, which is a lease/verdict mechanics fact, not a reprioritization — covered in §d.1).

## Docs-health pass notes (2026-11-14 09:4x, this fire)

- TODO_LIST: the window's rows verified at their line numbers (383/390/394/413/414 `[x]`; 2533, 3460–3465, 3565–3567, 3584–3595, 3597–3601 open); the window's own harvest legs all landed (3597–3601 by prior fires; 3606 by the 09:14 fire); dedup check run before this fire's 2 appends — no duplicates minted.
- CHANGELOG: the window's user-visible entry landed in `19cce5de3` (AI-stack resilience wave: backoff + budgets + adb mDNS + demand profile + write attribution) — verified present, nothing further to append from this docs-only pass.
- README: line-82 prose current at 302 (2026-11-14 re-derive); line-18 table stale at 298 — minted as §f.1, not fixed here (compliant fix needs a doc-counts anchor extension = flake edit, outside the docs-only scope rule).
- FEATURES: the two grossly stale gatus counts (L97 "133", L635 "100") stay owned by row 3463 — same anchor-coupling reason; not touched.
- Reports under docs/status/ dated 2026-11: the four window closeouts + the Nov-13/14 live pool (audiblesync triage, llama-cpp spin, opencloud web apps, superb contacts, w3b-resume, resume-session) checked for harvest state — every checked report's follow-ups are present as queue rows; no report re-derivation needed beyond this window's own.
- Archive: no moves this pass — every recent report carries open items and is cited by live queue rows (the archived/ convention requires every item resolved; none of the 2026-11 reports qualify).
- Annotations: the two predecessor closeout files (08-42 filled, 09-14 skeleton) now carry inline fold-into pointers to this file; history otherwise untouched.
- docs/status/README.md: live-pool addendum appended at top for this closeout, following the window-closeout precedent entries (2026-10-15 03:40, 2026-10-17 00:40).
