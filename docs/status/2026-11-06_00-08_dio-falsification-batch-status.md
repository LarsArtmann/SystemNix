# Dio-Falsification Batch (3-item storage queue) — Full Status + Self-Review — 2026-11-06 00:0x

**Task queue:** `000001a1a97a363c7e386f5b55f700000000` (storage batch: dio repro / modelPath guard / ctx parity). **Instance:** tq re-dispatch continuation — items 2+3 were pre-landed by the earlier "dio-repro session" (commits `983f17fca`, `94f1c35b4`, both ticked); THIS session worked item 1 to resolution and self-reviewed everything. **Verdict channel:** `tq verdict` recorded (996 bytes) before this report.

**Scope line — what this report VERIFIED (all from commands run in THIS session):** coredumpctl two-core evidence; the KEEP_RAW=1 crash reproduction with captured abort text; both green exoneration runs (JSONL lines quoted); the item-2 derivation snippet echoed live; the item-3 decision text located in the design doc; shellcheck standalone green; git trailer parsing green; all three footer commits grepped; zero-content-loss split proof (empty `git diff`). **What it did NOT verify:** the A1 23.4G baseline number (untouched — different row), the upstream-master state of the assert (queued in the upstream row), and the at-crash memory-PSI state (see §b.1 — evidence gap, honestly flagged).

## Headline

The batch's central premise — "llama.cpp 0.6.0 LM=dio SIGABRTs mid-load under memory pressure, file upstream if reproduced" — was **REPRODUCED then FALSIFIED**. The crash is the **missing-`--embedding` GGML_ASSERT** (`llama-context.cpp:2275: GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max) failed` during the init warmup encode), it fires in **both** load-modes, it does **not** need memory pressure, and dio + `--embedding` loads green through the harness's own PSI gate. verify-before-filing gate fails (root cause is the caller's missing flag, not upstream's dio path) → **NO upstream report filed**. Three evidence legs, each independently sufficient: (1) the second coredump ran `--load-mode none`; (2) the rerun aborted deterministically at zero memory pressure with the assert captured; (3) dio+EMBED green twice (strict-gate entry + accepted-noisy).

## §a FULLY DONE

1. **Re-dispatch protocol honored** — footer grep found items 2+3 pre-landed AND pre-ticked; skipped per the rules, then spot-verified live anyway: the modelPath derivation snippet echoed the correct 23.4G path (`/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf`), and the ctx-4096 OFFICIAL decision text is present in the design doc §5 LANDED bullet.
2. **Premise check at primary-evidence level (the session's pivotal move)** — `coredumpctl info` on the two llama-server SIGABRTs (PIDs 2304916 + 2367016) showed the second (02:05:15) ran `--load-mode none`: identical crash across load-modes kills the dio attribution BEFORE any rerun. Also corrected the source report's "one core-dump; not reproducible cleanly" — it was two cores, and it DID reproduce.
3. **Crash reproduction with abort-reason capture** — `LM=dio KEEP_RAW=1 PSI_ACCEPT=1` on bge-m3 without `--embedding` (exact 02:02:08 cmdline shape) → SIGABRT (core dumped, rc=1, zombie-safe death detection fired) with the reason in server.log: the GGML_ASSERT above, in `common_init_from_params → llama_context::encode`, preceded by "embeddings required but some input tokens were not marked as outputs -> overriding". Evidence copied durable: `~/.cache/data-ai-compsize/dio-sigabrt-repro-2026-11-05/` (log + psi.csv).
4. **Exoneration runs** — `LM=dio EMBED=1` green twice, both lines in `~/.cache/data-ai-compsize/dio-bge-m3.jsonl`: strict-gate entry (psi_pre 17.23 < 20, `psi_accepted:false`, 123.86s, mid-run storm cell honestly sampled psi_max_during 45.7) and accepted-noisy (psi_pre 39.12, storm 39-62% sustained, 149.24s). dio loads clean under exactly the pressure the original claim blamed.
5. **verify-before-filing applied, not just cited** — skill loaded; root-cause gate fails (caller's flag, not upstream); NOT-filed decision documented in the report Correction; upstream filing deliberately skipped (would have been the premise-error issue class the skill exists to prevent).
6. **Six surfaces corrected** — bench-cold-load.sh LM knob comment (misattribution → falsification story with the captured assert), docs/agents/storage.md harness paragraph, design doc §5 bracket, docs/todo/storage.md row 222, 02-18 source report (new Correction section), task-report follow-ups #7 (RESOLVED), #18 (MOOT), #28 (MOOT).
7. **TODO loop closed** — item 1 ticked with the full verdict (single physical line per house rule); two follow-ups queued in BOTH surfaces (queue one-liner + domain library): upstream clean-error-for-embedding row + optional dio 23.4G diagnostic row.
8. **Commit hygiene under an active daemon storm** — three daemon sweeps mixed my files with a parallel freeze-49 session's work; the sanctioned soft-reset split executed (my footer commit `96f570575` + foreign report byte-identical `69dddf00a`), zero-content-loss proven by an empty `git diff`; hook subject-length rejection (79 > 72) fixed; trailer verified parsing via `%(trailers:key=Task-Queue-ID)`.
9. **AGENTS.md lesson landed** (`813c0be8d`) — editing a script while a background instance of it runs kills the run with phantom bash syntax errors (see §d.1); generalizes the mid-session-modifications rule.
10. **Daemon-swept lint legs re-run standalone** — shellcheck `--severity=warning` on bench-cold-load.sh: clean (the .sh rode a daemon sweep whose hook skipped it).
11. **Strict-datapoint evidence completeness** (`dbc1a3f1f`) — the psi-wait twin found a window and landed the strict-gate line; the report Correction updated to cite both datapoints.
12. **Clean exit** — no leaked bench processes, no stray llama-servers, evidence durable, tree surface clean, `tq verdict` recorded.

## §b PARTIALLY DONE

1. **"Reproduced at zero memory pressure" is one sample short of airtight** — mem PSI (0.04%) was sampled BEFORE the crash run; the harness samples io-only during runs (psi.csv has no mem column), so the at-crash memory state is inferred (storm was io-class; no memory-guard trip attributed in-window). The verdict does not rest on this leg (load-mode-independence carries it), but the claim as worded slightly overreaches → mem-PSI sampler row queued (§f.4).
2. **Task-report #28 annotation wording** — first version said llama-vlm "runs chat/VL GGUFs with correct flags"; actually the module sets NEITHER flag (defaults only). The operative claim stands (VL GGUF is not an embedding GGUF, so the assert path cannot fire) and the wording was tightened this session.
3. **Upstream dupe/master check** — deliberately deferred INTO the queued upstream row (verify-before-filing first), not done now: the assert's state on llama.cpp master and any existing clean-error issues are unchecked.
4. **Concurrent-session surfaces observed, not touched** — freeze-49 session's reports and deploy.sh/test-deploy-pipeline.sh changes, the go-cache session's plan + EXECUTING tombstone, two untracked reports at session end: all foreign work, co-existed cleanly, none verified (their scope).

## §c NOT STARTED (deliberately out of this batch's scope)

1. **A1 strict-gate baseline on the 23.4G model** (existing row: "Take the strict-gate cold-load baseline") — THE before-number; this batch deliberately did NOT consume calm-window slots for it (the crash-repro ran accepted-noisy instead; the strict twin consumed one brief dip).
2. **dio diagnostic datapoint on 23.4G** — queued this session, not run.
3. **Upstream clean-error filing** — queued this session, not run.
4. **bench-cold-load selftest fixture** (existing row) — untouched.
5. **kill_pid cleanup-trap fixes** in bench-hot-file.sh / bench-samsung-livefs.sh (existing row) — untouched.
6. **All freeze-49 / go-cache / deploy-storm work** — other sessions' active scopes; this session only co-existed with them.

## §d TOTALLY FUCKED UP (honest list)

1. **I killed my own background run mid-flight.** Launched the strict-gate bench at ~20:52:30, then edited bench-cold-load.sh at 20:53:47 (the LM-knob comment correction) — the rewrite corrupted the live bash's read offsets and the run died RC=2 with a phantom `syntax error near unexpected token '('` at line 141. Cost: one harness run + ~10 minutes. Root cause: launching a background run BEFORE finishing the edit pass on the same file. Lesson landed in AGENTS.md; the run was relaunched and both successors landed green.
2. **Mid-hook commit race, live again** — first footer-commit attempt found "nothing to commit": the daemon swept my tick + reword into `0ec6b9cab` (mixed with the foreign freeze-49 report) while the hook ran on an empty index. Recovered exactly per the CONTRIBUTING soft-reset split (exclusivity check failed → amend forbidden → split + zero-loss proof).
3. **Hook rejection on subject length** — first attempt 79 chars vs the 72 house limit; chain aborted cleanly pre-commit; retried at 61 chars.
4. **Scattered attribution for one item's surfaces** — the corrections are spread across daemon sweeps `2f2922445` (6 surfaces + foreign deploy files) and `c17db2ccc` (my #28 annotation + 2 queue rows mixed with freeze-49 work), with `96f570575` carrying only tick + reword. Nothing lost (diffs are the record) but no single commit tells the whole story; the footer commit is intentionally the queue-visible anchor, not the whole payload.
5. **/tmp volatility nearly ate the only abort-text capture** — KEEP_RAW preserves into /tmp/bench-cold-load.XXXX; the hand-copy to ~/.cache happened ~4 minutes after the crash. Had the session stalled longer, the decisive evidence would have rotted (harness design flaw → queued row).
6. **I almost ran a mis-specified experiment** — the batch item's premise ("reproduce under memory pressure, file upstream") came from a prior session's VERIFIED report and I initially planned to rerun it as-written; only the coredumpctl pre-read revealed the premise itself was wrong. A calm-window rerun per the original spec would have "reproduced the dio bug" that isn't a dio bug and possibly filed a wrong upstream issue. The save was checking primary evidence (coredumpctl) instead of trusting the report's summary.

## §e WHAT WE SHOULD IMPROVE

1. **Primary-evidence premise check BEFORE any rerun** — one `coredumpctl info` overturned the batch's framing in minutes; make it step 1 of every reproduction task (this session's biggest positive).
2. **Never edit a file with a live background instance of it** — launch script-runs only after the edit pass is final (AGENTS.md lesson landed).
3. **Harness hardening (all queued):** auto-EMBED arch detect (prevents the entire misattribution class), crash-event JSONL lines, KEEP_RAW → ~/.cache, mem-PSI columns, PSI-gate hysteresis.
4. **Commit immediately after the last edit, pathspec-scoped** — the daemon's ~4-minute cycle ate my surfaces three times; the only clean landing was the pathspec footer commit that finally beat the clock.
5. **Hook whitespace pass should not touch content-identical files** — the 02-18 report's mtime changed at 21:24 with zero content delta, tripping edit-tool staleness and drift noise mid-session.
6. **Coredump evidence rots** — both original cores show "Storage: missing" within ~19h; extract abort reason + stack IMMEDIATELY (the calm-gate review's lesson, now re-confirmed at scale) or raise retention (§g Q3).
7. **Mega-ticks are getting heavy** — the item-1 tick is a ~2,000-char single line; consider capping tick verdicts at ~3 sentences + pointing at the report narrative (house style currently allows the long form; both items 2/3 from the prior session are equally long).
8. **Reproduction cmdlines should be lifted verbatim from coredumpctl `Command Line:`** — matching host/port/flags exactly (port 18849 for the repro) made the comparison airtight.

## §f NEXT (grounded in this session + its direct neighbors; ≤50)

Markers: **[Q]** queued this session (queue + library, both surfaces), **[X]** existing open row spotted while working, **[I]** idea from this session, not yet queued, **[O]** owner decision (see §g).

1. [X] Take the A1 strict-gate baseline (23.4G Qwen, LM=none, ctx 4096) — THE before-number every /data leg gates on; record load_s/mb_s into design doc §4.
2. [O] Calm-window slot priority: A1 baseline vs the dio-diagnostic datapoint (§g Q1) — both need io-quiet windows.
3. [O] Benchmark definition: keep official LM=none vs switch to dio before the baseline lands (§g Q2).
4. [Q] bench-cold-load: auto-detect embedding GGUFs (GGUF header `general.architecture`) → auto-`--embedding`/refuse — prevents the whole misattribution class.
5. [Q] bench-cold-load: dead-server crash events into OUT JSONL (failure line with reason excerpt).
6. [Q] bench-cold-load: KEEP_RAW artifacts under ~/.cache (durable), not /tmp.
7. [Q] bench-cold-load: mem PSI columns in psi.csv + JSONL.
8. [Q] bench-cold-load: PSI-gate hysteresis (2 consecutive calm polls or avg60).
9. [Q] Upstream ggml-org/llama.cpp clean-error row — verify-before-filing first (master assert state + dupe scan), then draft.
10. [X] bench-cold-load selftest fixture (guards: held port, unreadable model, bad COLD, gate refusal).
11. [X] kill_pid cleanup-trap fixes in bench-hot-file.sh:81 + bench-samsung-livefs.sh:146.
12. [I] Coredump retention on evo-x2: both 0.6.0 cores "Storage: missing" within ~19h — decide policy (§g Q3), then either extract-on-sight discipline or a retention bump.
13. [I] Confirm from the llama-vlm module/doc that the VL GGUF path can never hit the embedding assert (annotation hardened; a one-line doc note would pin it).
14. [I] Reconcile coredumpctl list-TIME (02:06:33) vs info Timestamp (02:05:15) semantics before either timestamp is cited as the death minute (SI_TKILL vs corefile write — cosmetic, only if cited again).
15. [I] The 02:12 green smoke (LM=none smoke, 157s) exists only as quoted text in the 02-18 report — its JSONL line was never appended (OUT unset); a one-time backfill note or accept-and-move-on.
16. [X] After the baseline lands: A1 chattr +C per-dir application wave (design doc sequencing, owner-gated).
17. [X] §6 owner decision asks in the design doc (A2 XFS trigger value etc.) — owner still owns the target VALUE.
18. [I] When dio datapoints accumulate: a dio-vs-none read-rate comparison line in the storage agent doc (pure-DirectIO vs buffered cold-load delta as an A2 diagnostic).
19. [I] bench-cold-load: optionally emit the derived-model echo into the JSONL (derived vs explicit MODEL=) so out-of-tree fallback runs are self-identifying.
20. [I] Consider a `--dry-run` flag printing the exact llama-server cmdline + flags without launching (verification affordance; pairs with the selftest row).
21. [X] Post-baseline: record numbers into the storage ledger row per design doc §4 contract.
22. [I] /tmp bench dirs from earlier runs still on disk (`/tmp/bench-cold-load.{PY1egy,ZWqIFI,BY4ZaI}`) — safe to trash once evidence copies are confirmed durable (PY1egy is; the other two hold no unique evidence).
23. [I] KEEP_RAW dirs accumulate in /tmp when runs fail before cleanup — the cleanup trap covers it, but a tmpfiles age-out rule for /tmp/bench-cold-load.* would bound the residue.
24. [X] The upstream flm-real SIGABRT row (freeze-#47 leg) is unrelated to this falsification — do NOT conflate the two SIGABRT families in future reads (flm = libgomp barrier; bge = GGML_ASSERT n_outputs_max).
25. [I] A one-line "SIGABRT families seen on this box" table in docs/agents/stability.md or the gotchas archive (flm/gomp vs bge/embedding-assert vs future) to stop cross-family misattribution at the source.

Items 26-50 deliberately not fabricated: this session's honest discovery set is the 25 above; padding the list with unrelated queue rows would violate the "report what you noticed" scope.

## §f self-audit (harvest table)

| Direct follow-up from THIS session | Surface |
| --- | --- |
| Upstream clean-error-for-embedding row | TODO_LIST.md + docs/todo/upstream.md (queued earlier this session) |
| Optional dio 23.4G diagnostic row | TODO_LIST.md + docs/todo/storage.md (queued earlier this session) |
| auto-EMBED detect / crash-event JSONL / KEEP_RAW durable / mem-PSI sampler / gate hysteresis | TODO_LIST.md + docs/todo/storage.md (queued at report time, this commit) |
| Coredump retention policy | Deliberately NOT harvested as a row: it is a pure owner disk-spend decision with no agent-executable step until answered (see §g Q3) |
| coredumpctl timestamp reconciliation; llama-vlm doc note; backfill of the 02:12 smoke JSONL; dry-run flag; derived-model JSONL echo; SIGABRT families table; /tmp residue trash | Deliberately NOT harvested: cosmetic/optional ideas listed in §f as [I]; harvesting all five would bloat the queue for marginal value — they live in this report's §f with full context |
| A1 baseline, selftest, kill_pid, §6 asks | Pre-existing rows (this session created none of them) |

## §g QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Calm-window slot priority:** the A1 baseline (row "Take the strict-gate cold-load baseline") and the queued dio-diagnostic datapoint both need io-quiet windows and this box's storms make those slots scarce — which takes the next calm window?
2. **Benchmark definition, while it is still free to change:** the official cold-load number is currently defined as LM=none (buffered reads + vmtouch eviction, whose re-fault caveat can flatter the number). Now that dio is exonerated, do you want the OFFICIAL A1/A2 gate switched to LM=dio (true DirectIO, page-cache bypass, pure storage read) BEFORE the baseline lands — accepting that it redefines what THE number means — or keep LM=none?
3. **Coredump retention:** both original 0.6.0 cores rotated to "Storage: missing" within ~19h, costing the original abort evidence (this session recovered only via a lucky reproduction). Raise systemd-coredump retention/disk budget on evo-x2 (QLC/Samsung space cost), or keep rotation and rely on extract-on-sight discipline?

## Verification matrix (commands run THIS session, results)

| check | result |
| --- | --- |
| `git log --grep Task-Queue-ID` (re-dispatch) | 2 pre-landed footer commits found (items 2+3), item 1 absent |
| coredumpctl info 2304916 / 2367016 | SIGABRT SI_TKILL; cmdlines dio vs **none**, both bge-m3, no `--embedding`; cores "missing" |
| journal `_PID=` for both PIDs | no entries (stderr went to the deleted temp-dir log) — evidence dead end, documented |
| crash repro run (dio, no EMBED, KEEP_RAW=1, port 18849) | RC=1, "(core dumped)", assert text captured: llama-context.cpp:2275 GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max), init warmup encode |
| exoneration run 1 (dio+EMBED, strict gate, port 18848) | GREEN: 123.86s, psi_pre 17.23, psi_accepted=false, psi_max_during 45.7 |
| exoneration run 2 (dio+EMBED, PSI_ACCEPT=1, port 18851) | GREEN: 149.24s, psi_pre 39.12, psi_accepted=true, storm 39-62% |
| shellcheck standalone (severity=warning) on bench-cold-load.sh | clean |
| bash -n on bench-cold-load.sh | clean |
| item-2 derivation snippet (sed/grep on llama-chat.nix) | echoes the correct 23.4G path |
| item-3 decision text grep | present in design doc §5 (ctx 4096 OFFICIAL) |
| git trailers on 96f570575 | `%(trailers:key=Task-Queue-ID,valueonly)` = the task ID |
| all-three-footers grep | 96f570575 + 94f1c35b4 + 983f17fca present |
| soft-reset split zero-loss proof | `git diff <pre-split-batch> HEAD` EMPTY |
| leaked-process sweep | none (pgrep clean; 8138 = the live vlm service, untouched) |
| tq verdict | recorded (996 bytes) |

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.3-5 f.7 f.10 f.11 f.24 · already-tracked f.6 f.8 f.9 f.17 · OBSOLETE f.14 f.15 · NEW rowed: 7 rows (merged f.1+2+16+21, f.19+20, f.22+23) → storage 4, stability 2, ai-stack 1
