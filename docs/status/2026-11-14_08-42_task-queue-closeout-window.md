# Task-Queue Closeout Window Status Report — 2026-11-14 08:42

Window: 5 completed tasks spanning 2026-11-10 → 2026-11-14, verdict task `000001a1d8cbc3ff68f9d852788500000000`.
Tasks covered:

| # | Task | Subject | Evidence |
|---|------|---------|----------|
| 1 | `…c14f087910…` | Review-finding fix: time_series_v2 library-row tick drift | closeout docs/status/tasks/2026-11-10_01-44_task-000001a1c14f087910352e55c18500000000.md, commit `377a242f7` |
| 2 | `…c14f087b6ab…` | Review-finding fix: gatus endpoint-count drift (283/284/285) | closeout docs/status/tasks/2026-11-10_02-23_task-000001a1c14f087b6ab9efa0bed500000000.md, commit `64c124592` |
| 3 | `…c7a258eff…` | Verify adb mDNS listener on 0.0.0.0:5353 is intentional | TODO_LIST.md:383 ticked `[x]` — "VERIFIED INTENTIONAL 2026-11-11 (live fork-server for webphone-android; documented at the android-tools package site, ADB_MDNS=0 off-switch)" |
| 4 | `…d23e580d67…` | Fix the two NEW undersized budgets (cvagent 1.38M throttle events, forgejo 95%-of-high graze) | closeout docs/status/tasks/2026-11-13_17-18_task-000001a1d23e580d6791e931f37e00000000.md, code in daemon commit `d7963ea17` (content = exactly the 2 files, verified per report) |
| 5 | `…d5d871644a…` | ai-stack 5-item batch (pid churn, restart backoff, re-embed design, demand profile, write attribution) | closeout docs/status/tasks/2026-11-14_07-04_task-000001a1d5d871644a2dac5d586a00000000.md, commits `42fb02c17`/`fd42bde67`/`070eb35cf`/`889ee2b84`/`754320dce` |

Verification method: the four closeout reports read in full; the ticked TODO_LIST rows (390, 383, 413, 414, 3565, 3584–3594) grep-verified live at HEAD `4f1dff9e9`; window commits confirmed via `git log --since 2026-11-09`. The two reviewer-finding tasks (1, 2) both report first-attempt single-commit fixes with footer-verified trailers and pre-commit batteries green — accepted as verified per their own command-level evidence tables.

## a) FULLY DONE

1. **Task 1 — time_series_v2 drift fixed** (`377a242f7`): the reviewer's exact finding (queue row `[x]`, library row `[ ]`) repaired with a full-line-match edit guarded by an exactly-once anchor check; batch parity asserted (all five items of batch `000001a1bdadc729` now `[x]` in docs/todo/monitoring.md); the gate-gap root cause (pairing_check reads only OPEN rows; "same report" citations unresolvable) source-read and minted as three queue rows (now TODO_LIST:3460–3462).
2. **Task 2 — gatus count drift fixed** (`64c124592`): README prose → 286 (live `nix eval` truth at HEAD, deliberately overriding the reviewer's literal 285 to avoid minting a THIRD count), TODO_LIST close-out kept at the batch-final 285 with scope; repo sweep leaves zero stale hits outside docs/status/; the doc-counts gate RUN green post-fix (closing an argued-vs-ran gap); residual stale surfaces (FEATURES L97/L635, monitoring.md L52) minted as TODO_LIST:3463–3465 rather than silently dropped.
3. **Task 3 — adb mDNS verified intentional**: TODO_LIST.md:383 ticked with the verdict (live fork-server for webphone-android; documented at the android-tools package site; `ADB_MDNS=0` off-switch noted). Security question closed — no firewall change needed (eno1 is firewall-trusted).
4. **Task 4 — undersized memory budgets bumped** (daemon commit `d7963ea17`, content verified as exactly cvagent.nix + forgejo.nix): cvagent serve unit `MemoryMax` → 1G (`mkForce`, ~line 205; the scan oneshot stays 512M with no throttle evidence), forgejo main unit → 1G (~line 553, derives the 819M high); eval green (toplevel drv); rides the next deploy. The same session (2026-11-13 closeout) also landed SigNoz v3 API cheat-sheet + Delta-temporality restoral docs, the PSI emitter fail-visible + freshness canary (twin-session), and grew `scripts/test-psi-percent-semantics.sh` 24 → 38 green legs (io-boundary-40/-401, corroborated-storm, mutation leg; flake check `psi-percent-semantics-selftest` green) — TODO_LIST:394 ticked with full post-state.
5. **Task 5 — ai-stack 5-item batch** (5 footer-bearing commits):
   - pid churn verdict: restart cadence (`Restart=on-failure` loop), NOT ensure-convergence — the converger structurally cannot cycle an active pid; probe pattern documented in docs/agents/monitoring.md (`42fb02c17`).
   - restart backoff: `RestartSteps=5` + `RestartMaxDelaySec=15min` on llama-embeddings/llama-reranker (shared commonServiceConfig) + nsfw-classifier; systemd 262 ≥ 254 eval-verified; full `nix flake check --no-build --all-systems` green (`fd42bde67`).
   - demand profile measured from ClickHouse (samples_v4 ⋈ time_series_v4, ai_meter_requests_total), per-day + per-hour shape (`889ee2b84`).
   - write attribution pinned to unit cgroup + device magnitude: last invocation wrote **645.2 GB / read 8.5 GB**; /data wrote 0 since boot → the HDD pool; two new findings (Samsung 16.6 TiB/7d write rate; paperless-slice counter-evidence) queued (`754320dce`).
   - re-embed batch design: docs/planning/2026-11-14_06-15_re-embed-calm-window-batch-design.md (`070eb35cf`).

## b) PARTIALLY DONE

1. **cvagent/forgejo budget fix verification half**: the code landed but the counter re-read that PROVES throttling stopped needs the tree deployed + units restarted (counters reset). TODO_LIST:3565 owns it; honestly not faked.
2. **Re-embed work: design only** — implementation (timer oneshot + psi-wait-gate + content-hash cache + checkpointed consumer) never had a queue row until the 11-14 closeout minted TODO_LIST:3586; the `[design landed]` tick could have read as done.
3. **Write attribution, inner mechanism**: pinned to unit-cgroup + pool level; which file/syscall dirties 645 GB is unpinned (per-device io.stat dies with the cgroup at stop) — TODO_LIST:3584 instruments the next serving window.
4. **Task 5 item 1 evidence base**: the 2026-10-29 journal is vacuumed (oldest retained boot 2026-11-06), so the pid-churn verdict is mechanism-level (code path), not journal forensics of that night.
5. **Task 2's count-consistency class**: the finding is dead but the class survives in FEATURES L97/L635 + monitoring.md L52 (queued, not fixed — scope discipline).
6. **Restart backoff spec fidelity**: the ask said `RestartSteps=4` + 10min + jitter if ≥262; shipped 5/15min, no jitter (repo canon, flm/vlm precedent, deterministic timing for probes). Deviations argued in the commit but decided unilaterally — owner can overrule in one line (see §g.2).
7. **Shellcheck residue (11-13 session)**: the daemon commit bypassed the staged-path shellcheck leg and standalone shellcheck was unavailable in the agent shell; test-psi-percent-semantics.sh verified by `bash -n` + execution only.

## c) NOT STARTED

The window's own follow-up rows are all correctly minted but unimplemented (verified present, unchecked):

- Gate legs: tick-state parity in pairing_check (3460), same-report citation resolution (3461), check-todo-system --selftest → flake check + CI (3462).
- Count-consistency: FEATURES re-stamp + doc-counts anchors (3463), SigNoz 52/10 vs 54 mkRule reconciliation (3464), AGENTS.md batch-final count-citation rule (3465).
- io_warning 10.00-exact boundary legs (3566); post-restart cvagent/forgejo counter re-read (3565).
- ai-stack: re-embed implementation (3586), llama-chat backoff (3587), RestartSteps regression test (3589), per-device io.stat sampling (3584), Samsung 16.6 TiB write-rate attribution (3585), nsfw-classifier metering (3592), ClickHouse day-filter no-op root-cause bullet (3594).

## d) TOTALLY FUCKED UP

1. **Daemon footless commits carry the window's real work**: `d7963ea17` (the budget fix, heuristic message) and `4b60131a1` (psi script + selftests.nix, which ALSO swept a parallel session's check-contact-registry-drift.sh + pre-deploy-check.sh changes). Attribution commits landed on top, but `git log --grep Task-Queue-ID` will not surface the script hunks — the known daemon-race cost, handled per policy (no amend; foreign files would have been absorbed).
2. **Item-4/-5 TODO ticks rode the item-3 commit** (11-14 session): staged TODO_LIST.md wholesale, so the item-3 diff contains the other items' queue state — per-commit narrative lies; tq derives completion from footers, so nothing lost.
3. **ClickHouse day-filter silently no-oped** (11-14 session §d.1): `unix_milli > now64(3) - INTERVAL 8 DAY` matched ALL history; the session noticed and sailed past, and the final query dropped the filter entirely — the report's range is what the data HAPPENED to cover. Conclusions survive (shape-based classification), but the method note overstates rigor. Root-cause row queued (3594). Direct violation of the quote-scrutiny rule, self-reported.
4. **Reviewer-found drift is the systemic miss of the window's parent batch** (`000001a1bdadc729`): three inconsistent gatus counts and the queue↔library tick drift shipped through every gate — two of the window's five tasks are repair dispatches for ONE batch, and the repo's own gate structurally cannot catch either class (open-rows-only pairing + no same-report resolution + .md-only commits skipping eval). Fixes are queued (3460–3462), not built.
5. **Follow-through gap at tick time** (11-14 session §d.3): the design row was ticked without a co-committed implementation row; fixed retroactively in the closeout.
6. Nothing deployed in this window broke the live host: all changes are docs/config riding the next deploy; no gate went red at HEAD (toplevel eval green per the 11-13/11-14 sessions).

## e) WHAT WE SHOULD IMPROVE

1. **Close-out hygiene is mechanical and still skipped**: all three repair dispatches against the parent batch trace to no final queue↔library parity grep at batch-close time. The gate legs (3460–3462) make it unskippable — they deserve priority over new feature work in the pipeline queue.
2. **Eval-relevant predicate vs readFile'd docs**: a README.md edit that touches the doc-counts anchors ships green locally (hook skips eval on docs-only diffs) and breaks CI — row 743's targeted `doc-counts` leg for staged README/FEATURES is the concrete fix; `64c124592` is a fresh reproducer.
3. **Query-premise discipline**: any result contradicting its own filter gets root-caused before quoting, even when the accident is "more data" (§d.3).
4. **Tick-time follow-through**: a `[x]` on a design row must co-commit its implementation row (doctrine exists; enforcement was retroactive in the 11-14 session).
5. **Per-item commit separation**: stage per-item paths; the TODO_LIST is a shared accumulating surface.
6. **Spec deviations get flagged AT COMMIT TIME** as deviations ("asked X, shipped Y because…"), not argued post-hoc; settings landed on disabled units (nsfw-classifier) get an explicit unverified-on-target note.
7. **Daemon-swept shellcheck bypass**: scripts committed by the daemon get no shellcheck until the next staged touch — the 11-13 session's execute-instead pattern (bash -n + fixture run) is the fallback; a CI shellcheck leg over scripts/ closes it structurally (row 938 owns the extension).
8. **Record tq verdicts once, at closeout, with the report path** (the 01-44 session recorded pre-report then re-recorded — harmless, wasteful).

## f) NEXT THINGS

Top value, dedup-checked against the 3,317 open rows — items 1–9 already exist as unchecked rows from the window's own harvests (listed with their row numbers, NOT re-minted); item 10+ are the genuinely new appends:

1. Tick-state parity leg in pairing_check (TODO_LIST:3460) — kills the class behind two of the window's five tasks.
2. Same-report Source resolution in pairing_check (3461).
3. check-todo-system --selftest → flake check + CI (3462).
4. FEATURES.md gatus re-stamp + doc-counts anchors (3463).
5. SigNoz 52/10 vs 54 mkRule count reconciliation (3464).
6. Deploy + post-restart re-read of cvagent/forgejo throttle counters (3565) — closes task 4's verification half.
7. Implement the calm-window re-embed batch job per the landed design (3586).
8. llama-chat crash-loop backoff, same two-line pattern (3587).
9. Samsung 16.6 TiB/7d write-rate attribution (3585) — wear-rate alarm on the hot-tier disk.
10. **NEW**: Write the proven last-invocation-IO-counters evidence pattern (systemd retains IO counters on stopped units — the 11-14 session's single best evidence source) into docs/agents/systemd.md (Source: docs/status/tasks/2026-11-14_07-04_…md §e.7).
11. **NEW**: Re-run shellcheck on scripts/test-psi-percent-semantics.sh at its next staged-path touch — the 2026-11-13 daemon commit bypassed the leg and standalone shellcheck was unavailable in the agent shell; verified by bash -n + 38-leg fixture run only (Source: same-window 11-13 closeout §d.3).
12. **NEW** [decision]: Codify the batch-closeout parity assertion (one closing grep across the batch's queue rows ↔ library rows + footer audit) into AGENTS.md's TODO System section — owner-weighted doc edit the 01-44 finding-fix session deliberately deferred; rows 3460–3462 make it mechanical, this makes it ritual (Source: docs/status/tasks/2026-11-10_01-44_…md §e.3).

Cap note: 3 new items appended (10–12); everything else in the window's reports was already harvested (verified by grep before writing — no duplicates minted).

## g) QUESTIONS FOR THE OWNER

1. Gate hardness: once the parity legs (3460/3461) land, should `CHECK_TODO_PAIRING=strict` become the blocking pre-commit default, or stay WARN? (Already tracked as decision row 2533; the window's repair cycle strengthens the case for strict.) — also appended below as a blocked item pointer? No: row 2533 exists, no duplicate minted.
2. **NEW — BLOCKED**: Restart backoff spec deviation ruling: item 2 asked `RestartSteps=4` + `RestartMaxDelaySec=10min` + `RestartRandomizedDelaySec` jitter; the session shipped 5/15min with NO jitter (repo canon, deterministic restart timing for probes). Accept, or overrule to the literal spec? (Source: docs/status/tasks/2026-11-14_07-04_…md §b.3.)
3. **NEW — BLOCKED**: Drop ruling for the dead-legacy `time_series_v2` ClickHouse table (0 rows, nothing writes it; blocklist entry landed `0bb953d24`) — the drop has been parked on your ruling since 2026-11-09; also COVERING the standing owner legs from the window's periphery: the quiet-window io-calm battery (row 197) and the InboxClean "In production" consent-screen flip (row 524) both still wait on you.

## h) BAND DRIFT

`tq facts --type task.reprioritized` → **(0 facts)** in the window's timespan (and overall): **none recorded**. No priority band moved this window; the queue's harvest order alone explains the dispatch sequence.

## Docs-health pass notes (2026-11-14 08:4x)

- TODO_LIST: the window's follow-up rows all verified present and correctly ticked/unticked (rows 383, 390, 394, 413, 414 ticked; 3460–3465, 3565, 3566, 3584–3594 open). Dedup check run BEFORE appends — no duplicates minted.
- CHANGELOG: appended one entry for the window's user-visible config changes (restart backoff + budget bumps ride the next deploy).
- FEATURES: the two stale gatus-endpoint claims are already row 3463 — not touched here (single-fix scope).
- Archive: no 2026-11 reports qualify (every recent report carries open items or is referenced by live queue rows); docs/status/archived/ untouched.
- Reports under docs/status/ dated 2026-11 read for this pass: the four closeouts in docs/status/tasks/ + docs/status/2026-11-14_06-15/07-10 work reports — all internally consistent with the tree at HEAD.
