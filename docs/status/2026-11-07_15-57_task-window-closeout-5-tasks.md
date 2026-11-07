# 2026-11-07 Status Report: Task-Queue Window Close-Out (5 tasks)

**Window:** tasks completed 2026-11-05 → 2026-11-07 (closeout reports dated 11-05 02:28 and 11-07 13:48 / 14:34 / 15:10; the dio-repro task resolved same-day 11-05 with no dedicated report — its falsification is recorded in the storage-batch report §f.7 Correction).
**Report author:** autonomous docs-health close-out session, HEAD `ac319e455` at start.
**Method:** every verdict below is read from the tasks' own closeout reports (`docs/status/tasks/`) and spot-verified against the repo (git log footer greps, selftest wiring in `flake/parts/checks/selftests.nix`, TODO_LIST/library row states). No code was touched by this session.

## a) FULLY DONE

1. **Go-cache redirect (task …a7beb2a2, item 1)** — verified landed by the closeout's re-dispatch check (prior instance's commit `9bbbcafd3`; TODO_LIST + `docs/todo/storage.md` rows both [x]).
2. **compsize pass on /data/ai (item 2)** — measured ground truth: every slice compresses at ratio ≈ 1.000 (~0 of 515G saved despite `compress=zstd:3`), with A/B controls (270:1 calm, 1:1 under memory-PSI pressure-fallback, urandom heuristic-skip). Method correction recorded in `docs/agents/storage.md`: `btrfs filesystem du -s` + `filefrag -v` replace agent-unrunnable compsize.
3. **bench-cold-load harness (item 3)** — `scripts/bench-cold-load.sh` landed lint-clean with a full verification battery (PSI gate, cold-eviction via vmtouch, guard refusals); follow-up wave hardened it further 2026-11-07 (2-poll hysteresis, mem-PSI columns, `~/.cache` scratch, dead-server JSONL — all selftested).
4. **llama.cpp dio SIGABRT repro (task …a97a363c) — RESOLVED BY FALSIFICATION** — reproduced 2026-11-05 evening; the crash is the missing-`--embedding` GGML_ASSERT (`llama-context.cpp:2275`), load-mode-independent, zero memory pressure. dio exonerated; NO upstream filing for dio; the real upstream row (clean error for embedding-GGUF-without-`--embedding`) is queued (TODO_LIST:1813).
5. **monitor365-server storage-ledger capability (task …b5feb9f1, `[ready]` item)** — landed end-to-end in storage-collector `6a67056` (PSI-gated ledger refresh with fail-open, per-child + global budgets, `spawn_blocking`, skip gauge, 3 unit tests, NixOS module options + parity tests, green `nix run .#gate`), mirrored into SystemNix as `7395e1e8b`. Two pre-existing clippy failures fixed on sight.
6. **b0d70d73 later-window cascade fixture (task …b6159d8d, item 1)** — `tests/fixtures/boot-evidence-pull/b0d70d73-later-windows.dump` committed faithful to the surviving record; selftest pins 4 memcg invocations / 0 `Killed process` / join emits NOTHING, plus the cross-midnight join leg. (The row's literal "independent systemd line-ordering patterns" premise was NOT executable — see b.)
7. **Year-boundary join fix (item 3)** — bug live-proven (Dec 31→Jan 01 parsed as −31,535,965 s), fixed with leap-safe `bep_ts_delta` (min-abs over raw/±365d/±366d), pinned by three isolated Dec→Jan selftest legs + a 78 s known-value sanity.
8. **Session-74 spawn attribution (item 4)** — evidence-exhausted verdict recorded honestly: no lineage capture existed at trip time, so the spawner is unrecoverable for THAT cascade; the class is now fixable going forward (guard-trip lineage-capture row queued). Companion report `…_session74-attribution.md`.
9. **Re-arm/discriminator canonization (item 5)** — kill-pass discriminator (invocation count = distinct `invoked oom-killer` lines) into `docs/agents/stability.md`; stc socket re-arm class into `docs/agents/systemd.md`.
10. **PAUSE_FILE silent-cycle observability (task …b63ed071, item 1)** — skip path now journals "existing pause kept (epoch …), no action this cycle" (`memory-emergency-guard.nix`, commit `d86bcb392`); `checks.x86_64-linux.guard-pause-skip-observability-selftest` pins both elif legs, negative-tested, built green. NOTE: the queue row had drifted UNCHECKED despite the closeout claiming it closed — ticked [x] on BOTH surfaces by THIS session with the evidence appended.
11. **llama-stack MemoryMax floor verify (item 2)** — llama-chat disabled since 2026-11-03 (owner directive) so its 41.7 GiB OOM vector is structurally gone; llama-embeddings floor verified live at 2 GiB via busctl — but the unit is DEAD while hermes spawns hold its ports (see b/d).
12. **Deploy-anchor check (item 3)** — post-WDT boot 2026-11-07 01:06 verified ANCHORED (`readlink /run/current-system` == `system-985-link`, newest-by-number), no repair needed.
13. **Thermal re-open look (item 4)** — verdict negative on agent side: ZERO fan/pwm hwmon nodes on this board; fan curve is GMKtec firmware-owned, no ambient sensor. Sustained 95-98 °C Tctl stayed inside the guard's hi:95/lo:80 design. Physical half owner-gated.
14. **wtmp shutdown-record absence (item 5)** — verified structural: `/var/log/wtmp.1` holds ZERO shutdown entries, `systemd-update-utmp-shutdown.service` has no journal activity in 14 d while boot records ARE written — "still running" in `last` is NOT crash evidence on this host. Documented in `docs/agents/stability.md`.
15. **Follow-up harvesting discipline held across all three 11-07 sessions** — every report self-harvested its §f items into TODO_LIST + the matching domain library at authoring time (this session's dedup re-check found only ONE drift: the unticked PAUSE_FILE row, fixed above).

## b) PARTIALLY DONE

1. **Strict-gate cold-load baseline (23.4G Qwen3.6-35B) NOT taken** — the PSI_WAIT_S=7200 waiter never caught an io-quiet window and died with its shell registry (no JSONL, no leak, verified). The harness is the deliverable; the number is one calm-window rerun (TODO_LIST:128).
2. **monitor365-server containment `[decision]` (task …b5feb9f1, item 1)** — everything agent-side done (parked honestly with the BLOCKED marker after the `tq ask` channel refused the batch id, monitoring prerequisite landed); the decision itself is owner-only. Also un-diagnosed: WHY the batch id is not in the tq DB (TODO_LIST:148).
3. **Later-windows fixture premise** — the row promised four independent systemd line-ordering patterns the join must survive; the surviving record contains NO systemd OOM-unit lines for those windows (journal vacuumed pre-pull), so only the memcg-only/negative contract + cross-midnight could be pinned. The premise's §b.4 source is unfindable — row-scoping question queued to the owner (report §g.2).
4. **Forward-only backfill decision (item 2)** — recorded and evidence-backed for the FILE side, but with an unexamined overturn path: the ClickHouse copy (`signoz_logs.distributed_logs_v2` was streaming during b0d70d73). Probe queued (TODO_LIST) + owner finality question queued.
5. **llama-embeddings/reranker floor** — verification done, remediation NOT: the module units are inactive/dead while hermes-spawned llama-servers serve ports 8848/8849 unconstrained by the 2 GiB floor; the FOREIGN-rogue detector has emitted nothing since Nov 1. Routing-or-observability row queued (TODO_LIST:3327).
6. **Thermal look physical half** — agent-executable half done (prove no surface exists); the owner-gated firmware/physical look and the risk-acceptance call remain open.
7. **Storage-collector FEATURES/README inventory** — the three new flags + gauge landed in CHANGELOG + module but the collector's FEATURES.md capability table was not updated (its own docs-guard covers countables; this is drift by the minute).

## c) NOT STARTED

- Nothing owed by the dispatched batches beyond §b's carve-outs (per the closeouts: the 15-10 batch dispatched 5/5, the 14-34 batch 5/5, the 11-05 storage batch landed all three items).
- Deliberately not started (queued, owner-gated, or by-design follow-ups): A1 chattr +C (owner §6.1 gate), A2 XFS split (owner target gate), btrbk excludes, M12 GGUF→Samsung hot tier, gcs-staging + /data/docker reclaims, monitor365-server containment execution (blocked on the owner decision), SystemNix-side collector adoption (blocked:push row — push/tag `6a67056`, lock bump, `dirSizes` wiring, deploy, gauge verify).

## d) TOTALLY FUCKED UP

Nothing destroyed or data-lossy this window. Honest defects the closeouts self-reported (all caught in-session unless noted):

1. **Queue-row drift the closeouts missed** — the 15-10 closeout claimed item 1's row "closed by its code commit", but the TODO_LIST row was left UNCHECKED (only the library row was ticked-adjacent). Found and fixed by THIS session. The "edit both surfaces" rule failed silently on the code-commit-closes-row path — the closeout's claim did not match the queue state it asserted (the 2026-09-29 "assert WHICH surface" class, recurring).
2. **Broken liveness check cost ~20 min** (11-05 session) — v1 harness polled `/health` with `kill -0 $SRV`; a crashed child is a ZOMBIE until reaped, so `kill -0` succeeded forever. Shipped despite self-review. Fixed with /proc state=Z detection.
3. **Daemon races on effectively EVERY commit this window** — 5/5 (14-34 session) and 6/6 (15-10 session) commits lost the race to the auto-commit daemon and were recovered by amend-forward, bypassing the pre-commit filetype lint legs each time (shellcheck never ran on the staged .sh changes; compensated with standalone runs). The daemon interval (~10 min) is now shorter than per-item cycle time — this is structural, not occasional.
4. **Hardcoded-epoch false negative** (14-34 session) — first crush-DB scan used an epoch constant for the WRONG day; returned 0 and would have poisoned the session-74 verdict with a bogus premise. Caught only by re-deriving with `date -d` (known-value rule violated on the session's FIRST probe).
5. **Leaked full-FS `find /` background probe** (14-34 session) — auto-backgrounded, never killed until closeout; an IO-storm-class probe left unattended on the QLC by a session whose own AGENTS.md bans exactly that class.
6. **Mis-annotated rows by stale line number** (14-34 session) — BLOCKED text landed on the wrong item's rows; caught pre-commit by a targeted `sed -n` check.
7. **`tail -1` footer checks false-alarmed 5×** (15-10 session) — trailing blank lines read as FOOTER_MISSING; grep-the-trailer is the correct form, now queued for CONTRIBUTING.
8. **Two sudo cycles wasted** (11-05 session) — typed-sudo guard + NNP sandbox both hit despite AGENTS.md documenting both; the corrected mental model was recorded only near session end.
9. **PRE-EXISTING and still RED: the evo-x2 toplevel lock-float audit** — `flake.lock` (07:52 float commit `e6ed47b06`) vs `flake/expected-locks.nix` (15 inputs drifted) makes every `nixosConfigurations` eval RED (TODO_LIST last row). Two sessions this window hit it late and paid commit-archaeology to attribute it. NOT this window's damage, but it blocks the deploy that would carry this window's landed fixes (the guard journal note, the year-boundary join fix — none are live until a deploy).
10. **The window's landed code is NOT deployed** — guard skip-path journal note (d86bcb392), later-windows fixture + join fix (86ff3b416/8e467c193), collector ledger (blocked:push). Until the float audit is green and a deploy runs, runtime behavior is unchanged.

## e) WHAT WE SHOULD IMPROVE

1. **Code-commit-closes-row must tick the row in the SAME commit** — the PAUSE_FILE drift is the second occurrence of a closeout claiming a queue state the queue didn't hold. Make "grep the row state" the last step of every item close, not the closeout's memory.
2. **Stage + commit within the daemon window, or fix the daemon interval** — 11 consecutive daemon races across two sessions means every structural change ships lint-unverified through the hook. Either shorten the edit→commit latency norm, lengthen the daemon interval, or give the hook a post-amend lint sweep (owner decision — see the 14-34 report §g.3).
3. **Query the remote evidence copy BEFORE deciding "impossible"** — the forward-only backfill decision derived from local artifacts while the ClickHouse copy sat one query away; "journal vacuumed" ≠ "all copies gone" (M22 of the very pull read said so).
4. **Eval baseline (`nix eval …drvPath`) at dispatch start** — converts "is the RED mine?" from archaeology to a diff; two sessions this window paid for skipping it. Queued for CONTRIBUTING.
5. **Fake-server smoke before the first long run of any poller** — the 1200 s zombie-timeout waste was one 20-second test away.
6. **`bash -n` (and a smoke) between every structural edit and the next execution** — the glued-line unbound-variable and the silent no-op sed were both 1-second checks, skipped twice.
7. **Annotate rows by content assertion, never line number** — parallel sessions reshape TODO_LIST between read and write; a one-line `assert 'keyword' in line` discipline makes the mis-annotation class impossible.
8. **Kill what you background** — auto-backgrounded probes need a tracking note the moment they background; the full-FS `find /` walk is exactly the "your own background job is the other session" trap.
9. **Document semantics at ship time, not at review time** — the collector's abandon-not-cancel timeout semantics and the public unbounded `measure_dir` both shipped undocumented (both now queued as rows).
10. **Keep the tq ask channel diagnosable** — a `tq show` pre-flight before composing a question; the current channel is dead-letter for batch-parked decisions and nobody knows why.

## f) UP TO 50 NEXT THINGS (harvested — highest-value queued in TODO_LIST, capped 10; the rest is report/library fuel)

Already-standing rows this window re-confirmed as high-value (do NOT re-queue): strict-gate cold-load baseline; durable gate-number ledger; round-9 float-registration completion (eval RED, blocks deploy); hermes embeddings routing; ClickHouse probe; bep systemd-OOM-section + `.raw` companion + `oom-invocations` census; guard-trip lineage capture; collector textfile staleness gauges; MSRV 1.86 compile; monitor365-server containment (owner).

New this session (all appended to TODO_LIST below, dedup-checked):
1. Fix the pre-existing SC2016 in boot-evidence-pull.sh (standalone shellcheck exit 0).
2. bep selftest/check.nix fixture-existence gate lists BOTH cascade fixtures.
3. bep known-value unit leg for `bep_ts_delta` (78 s pair, helper-direct).
4. Later-windows fixture 19:15–19:38 SPAN leg (per-victim candidate-set isolation).
5. Negative-test leg for the year-boundary join fix (CASES convention).
6. Diagnose the FOREIGN-rogue journal leg's silence (distinct from the routing fix).
7. Diagnose why `systemd-update-utmp-shutdown.service` never runs (possible in-repo NixOS ordering fix).
8. Fan-surface-absence finding into the thermal-pstate-guard runbook.
9. Codify "grep the trailer, not `tail -1`" in CONTRIBUTING.
10. Codify the eval-baseline-at-dispatch-start convention in CONTRIBUTING.
11. Tick-drift hygiene: the code-commit-closes-row path must tick both queue surfaces in the same commit (process fix; fold into CONTRIBUTING close-out discipline).
12. Deploy the window's landed fixes once the float audit is green (guard note + join fix are inert until then).
13. Owner-session retry of the session-74 query via the SigNoz UI if the API path stays collector-dead.
14. Collector: re-probe ports 8848/8849 ownership after any hermes restart (foreign spawn may be transient).
15. SigNoz rule sanity: does the `llama-embeddings.service active` rule page on the unit's dead state? If it alerts, why is nobody paging?
16. check-todo-system WARN-90 drift count: a docs-health pairing pass to recount/reduce (expect post-prune rise; 60→74→90 across the last three passes).
17. bep: mark the two pre-2026-11-02 canonical pulls "join section absent by era — do not backfill" (only if forward-only is ratified).
18. Sweep `docs/todo/stability.md` rows citing the unfindable "same report §b.4" — fix provenance pointers.
19. Hermes interactive-state inventory (`~/.hermes/state.db` empty while the worker demonstrably runs) — closes the blind spot that made session-74 unanswerable.
20. bep `--year-boundary` calibration case in the queued `--calibrate` mode row.
21. (storage-collector) lib-move + unit-test the PSI gate and skip/republish paths — ALREADY QUEUED (TODO_LIST:143, verified this session).
22. (storage-collector) Gatus condition on the skip gauge sustained > N hours + surface `budget_exhausted` in the textfile — ALREADY QUEUED (TODO_LIST:142).
23. (storage-collector) negative-test leg for out-of-range module options (clap range guards the CLI only).
24. (storage-collector) first live `storage_collector_dir_bytes` reading for `/var/lib/monitor365-server` post-adoption — VERIFY the CAP_DAC_READ_SEARCH actually reaches the 0700 dir (agent du was blind 3.9G vs 145G).
25. Fleet compsize extension: /data/SteamLibrary + /data/models with the unprivileged method.
26. Check the pressure-fallback (encoded-1:1) signature against /nix (same zstd family; would revise the 1.89× durability story).
27. Fragmentation-writer attribution for image safetensors (131KB/extents shredding; download/merge flow suspected).
28. modelPath split-brain guard (bench-cold-load hardcodes llama-chat's default; brain-swap runbook sync note).
29. CTX-parity datapoint (32768 vs the fixed 4096 benchmark context) as A2-decision input.
30. Optional dio diagnostic datapoint on the 23.4G model — ALREADY QUEUED (TODO_LIST:132).
31. Changelog/FEATURES parity for the collector flags in the collector repo (its docs-guard covers countables).
32. Consider `node_hwmon_fan_absent`-style textfile metric or Gatus note so fan-absence is visible in monitoring.
33. Freeze-#38 cluster row split — four ANSWERED suffixes, ~700 words; prune answered halves to CHANGELOG per lifecycle.
34. k10temp calm datapoint (79.4 °C at load 8.3) into the thermal row as the storm-vs-calm contrast.
35. Vault the daemon-amend-per-session count (6 in one session); if every session amend-forwards 5-6×, the interval or a session-lock convention needs an owner decision.
36. Verify `guard-pause-skip-observability-selftest` is carried by the nightly negative-tests matrix or add it.
37. After the next deploy: journal-watch one ioPause trip cycle to see the new skip-path line fire live (runtime behavior of the fixture is unproven).
38. Count-vs-ledger cross-check: the §f.17 evidence-pull shows 4 throttle ENTER/EXIT pairs Nov 6 — do the freeze-ledger deep-throttle totals include them?
39. jq/DIRENV and `rg -r` classes aside: sweep `docs/todo/stability.md` "same report §b.4" citations (same as 18 — merged).
40. Split-brain sweep candidate: bench-cold-load's hardcoded llama-chat modelPath vs llama-chat.md — single-source it (same as 28).

**HARVESTED at authoring 2026-11-07 15:57: 10 new `[ready]` items + 3 `[decision]`/BLOCKED questions appended to TODO_LIST.md; 1 existing row ticked [x] on both surfaces (PAUSE_FILE observability) with evidence.**

## g) QUESTIONS FOR THE OWNER (≤3, queued as BLOCKED items)

1. **Are the 8848/8849 bge servers KEEP-SERVED from hermes.service** (intentional design — hermes owns the RAG stack now) **or is the 05:40 spawn the known rogue class to kill?** Decides the routing-row fix direction.
2. **ClickHouse retention vs the forward-only decision**: does retention hold b0d70d73's Oct-28 systemd OOM-unit lines, and if the probe finds them, do you want the backfill carve-out engineered — or does forward-only stay final and the probe row dies?
3. **Thermal risk acceptance on the EVO-X2**: is there ANY owner-accessible fan-control surface (GMKtec BIOS/fan app), or is sustained 95-98 °C Tctl under reclaim load accepted as the design envelope? Converts the re-open look into a closed risk decision.

## h) BAND DRIFT

**None recorded.** The queue journal (`tq facts` on both the default DB and `~/.local/state/tq/tasks.db`) holds ZERO facts of any type — including `task.reprioritized` — for this window or any other. No ADR-0015 accountability entries exist to explain; priority in this window was set entirely by the queue's harvest order, not by reprioritization moves. If the journal DB is expected to carry facts, the empty journal is itself worth a look (fact emission may be broken or pointed at a different store path).

## Surfaces updated by this close-out

- This report; TODO_LIST.md (13 appended items, 1 evidence tick); `docs/todo/stability.md` (the PAUSE_FILE library row ticked in lockstep); CHANGELOG.md (window's user-facing code landings).
