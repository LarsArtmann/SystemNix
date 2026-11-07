# Window Closeout — go-cache redirect / dio SIGABRT / monitor365 decision / stability batches — 2026-11-08 00:0x

**Task-Queue-ID:** 000001a1b65edd26df3e2ecc974b00000000 (closeout prompt; this is a RE-FIRE — a first instance of this same closeout already committed its report at 2026-11-07 16:06, `c4bbcd804`, report `docs/status/2026-11-07_15-57_task-window-closeout-5-tasks.md`)
**Window:** the five tasks listed in the dispatch (completed 2026-11-05 → 2026-11-07 15:10)

**Re-fire note (read first):** the 16:06 instance already (1) wrote a full status report for these exact five tasks, (2) harvested 10 `[ready]` items + 3 owner-blocked questions into TODO_LIST.md (now at TODO_LIST.md:3320–3345), (3) ticked the drifted PAUSE_FILE queue row on both surfaces, and (4) landed the CHANGELOG entry for the window's code-facing changes. This report is the queue-visible close of the re-fired dispatch; it re-verifies the claims independently, adds what the first instance's report did not cover (the subsequent 16:37 batch's aftermath is out of this window and NOT re-reported here), and appends only dedup-checked NEW queue items (2; the harvest space was already fully covered).

## a) FULLY DONE

Verified against the repo, not just the closeout reports' claims:

1. **Go-cache redirect to /mnt/buildcache (task …335067e9, item 1, prior fire)** — LANDED; TODO_LIST row ticked `[x]` (row 147 pre-prune, now in CHANGELOG's 2026-11-07 prune block) + `docs/todo/storage.md` row ticked; the direnv-guard coupling fix `ef6bf1b51` referenced in AGENTS.md is in history. Correctly skipped by the 11-05 re-dispatch (footer grep proof in the closeout §a.1).
2. **/data/ai at-rest compression verdict (compsize pass, item 2)** — measured ground truth: every /data/ai slice at ratio ≈ 1.000 (~0 of 515G saved despite compress=zstd:3); method correction (`btrfs filesystem du -s` + `filefrag -v` replace root-gated compsize, unprivileged) recorded in `docs/agents/storage.md`; A/B controls (270:1 calm / 1:1 under PSI / urandom skip) documented. Commit `7c6a22b32`.
3. **`scripts/bench-cold-load.sh` harness (item 3)** — landed, lint-clean, live-verified (PSI gate/abort, vmtouch eviction, fixed llama-server flags, JSONL output, zombie-safe death detection); verification battery incl. gate-refusal and green accepted-noisy smoke (bge-m3 → /health 200 at PSI 83–87%). Commit `ca08df2f9`. Since hardened by follow-up waves (PSI hysteresis, mem-PSI columns, durable scratch — CHANGELOG entry).
4. **dio SIGABRT reproduction → premise FALSIFIED (task …5b55f7)** — the report `docs/status/2026-11-06_00-08_dio-falsification-batch-status.md` proves with three independent legs (second coredump ran `--load-mode none`; deterministic rerun at zero memory pressure captured the `GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max)` at llama-context.cpp:2275; dio+`--embedding` green twice) that the crash is the missing-`--embedding` assert, load-mode-independent, NOT a dio defect. verify-before-filing gate failed → no upstream issue (correct). Six surfaces corrected.
5. **Storage-ledger capability in storage-collector (task …6653 00, `[ready]` item)** — landed in the sibling repo (`6a67056` there; `7395e1e8b` here): PSI-gated dir-size ledger (fail-open), per-root 60s budgets with flagged partials, global 300s timeout, spawn_blocking fold, module options + both-direction parity tests, 3 new unit tests, gate green, CHANGELOG entry. SystemNix adoption correctly queued `[blocked:push]` (TODO_LIST.md:151, 1558).
6. **Owner containment decision (monitor365-server 125G, the `[decision]` item)** — parked honestly, not fabricated: `tq ask` refused (batch id not in DB), TODO_LIST.md row + storage.md library row both carry the BLOCKED annotation. The monitoring prerequisite (ledger) is the enabler for the eventual decision.
7. **b0d70d73 later-window cascade fixture (task …d2f850, item 1)** — `tests/fixtures/boot-evidence-pull/b0d70d73-later-windows.dump` exists; selftest legs pin 4 memcg invocations / 4 `oom-kill:` lines / 0 `Killed process` / join emits NOTHING, cross-midnight +30s join pinned, census updated (11/7/3). Commit `86ff3b416`. (Premise partially executable — see b.)
8. **Year-boundary join fix (item 3)** — `bep_ts_delta` (min-abs over raw/±365d/±366d, leap-safe) in `scripts/boot-evidence-pull.sh` (3 refs verified); bug live-proven first (−31,535,965 s for a true +35 s Dec→Jan pair); three isolated Dec→Jan legs + 78 s known-value sanity. Commit `8e467c193`.
9. **Forward-only backfill decision (item 2)** — recorded `c1f31e6cd`, grep-verified (zero systemd OOM-unit lines across all 30 committed pulls); ClickHouse overturn-probe queued (TODO_LIST.md:3322).
10. **Session-74 attribution (item 4)** — evidence-exhausted verdict committed `528a5b2f0`; stc re-arm class + kill-pass discriminator canonized in `docs/agents/systemd.md` + `docs/agents/stability.md` (`d335012ca`).
11. **PAUSE_FILE silent-cycle observability (task …f753a 00, item 1)** — the skip path now journals "existing pause kept (epoch …), no action this cycle" (`modules/nixos/services/memory-emergency-guard.nix:848` verified live) and `checks.x86_64-linux.guard-pause-skip-observability-selftest` exists (`flake/parts/checks/selftests.nix:791`). Commit `d86bcb392`. NOT yet deployed (see b).
12. **Stability batch verifications (items 2–5)** — llama-stack MemoryMax floors (llama-chat disabled 11-03 → vector structurally gone; live servers ride hermes.service OUTSIDE the 2 GiB floor), post-crash deploy anchor ANCHORED (system-985-link), thermal re-open negative (zero fan/pwm hwmon nodes; GMKtec firmware-owned), wtmp never records shutdowns (structural, documented in stability.md ~line 126). Commits `d9cbe4b0a`/`4f5243374`/`425e79717`/`19ff9a513`; 5/5 rows ticked with per-item evidence; selftest + flake check gates green at each closeout.

## b) PARTIALLY DONE

1. **Strict-gate 23.4G cold-load baseline** — never taken (box never went calm in the window); harness works, the A1 before-number is one calm-window run (row TODO_LIST.md:128).
2. **Guard PAUSE_FILE fix not live** — selftest green, code landed (`d86bcb392`), but the next deploy is blocked by the standing lock-float audit RED (16 drifted inputs; proof row TODO_LIST tail). The journal line's runtime behavior is unproven until a deployed cycle fires it.
3. **storage-collector adoption** — capability local-only in the sibling repo until push/tag + flake.lock bump + `dirSizes` wiring + deploy (`blocked:push`, TODO_LIST.md:151). Also: the green gate predates the last commit content by ~2 min (CHANGELOG edit ordering, honestly flagged in the closeout §b.2); MSRV 1.86 two-sided compile never run (row TODO_LIST.md:145).
4. **Later-windows fixture premise** — the row's "independent systemd line-ordering patterns" could only be pinned as the memcg-only/negative contract; the actual systemd orderings died with the vacuumed journal (owner question queued by the 14:34 closeout §g.2).
5. **hermes/llama-embeddings routing** — the 8848/8849 foreign-hold fix direction is gated on the owner keep-vs-kill decision (TODO_LIST decision row); the "why is llama-embeddings.service dead" diagnosis was NOT queued by any prior session (new item below).
6. **dio falsification residual** — "reproduced at zero memory pressure" is one sample short of airtight (mem PSI sampled pre-crash only); mem-PSI sampler hardening landed in the follow-up wave, closing most of the gap.

## c) NOT STARTED

All deliberately out of the five tasks' scope and correctly left queued (not re-listed exhaustively — the queue holds them): A1 chattr +C application (owner-gated, evidence now in place), A2 XFS split (owner target needed), M12 GGUF→Samsung hot tier, bench-cold-load selftest fixture, image-safetensors fragmentation-writer attribution (TODO_LIST.md:127), gcs-staging + /data/docker owner reclaims, the upstream clean-error-for-embedding filing, kill-pass OOM-unit section + `.raw` companion + oom-invocations census in boot-evidence-pull (all three queued TODO_LIST.md:3321–3324).

## d) TOTALLY FUCKED UP

Nothing in this window destroyed data or broke a gate. Honest defect ledger from the five closeouts (each already caught in-session; recorded here because the pattern class recurs):

1. **Background-job self-sabotage (dio session)** — editing `bench-cold-load.sh` ~1 min after launching it as a background bench killed the run with a phantom bash syntax error. Lesson landed in AGENTS.md (2026-11-05); recurred zero times since per later sessions' reports.
2. **Daemon-race amend-forward as default (14:34 session, 5/5 commits; 15:10 session, 6/6)** — every commit lost the race to the auto-commit daemon and was amended; the amend path bypasses pre-commit .sh lint legs (compensated with standalone shellcheck each time). Structural gap, not malice; CONTRIBUTING documents the recovery.
3. **Bogus-constant scan (14:34 session)** — a hardcoded epoch (Oct 17) used for an Oct-28 crush-DB scan returned a truthful 0 for the WRONG day and nearly poisoned the attribution verdict; caught by re-deriving the epoch with `date -d`. The known-value rule exists for exactly this.
4. **`kill -0` zombie trap (storage session v1 harness)** — a crashed child is a zombie until reaped, so `kill -0` liveness "succeeded" and burned a 1200 s timeout; fixed with /proc state detection. Two production bench scripts still carry the dead `kill_pid` pattern — fixed per CHANGELOG-pruned row (ticked `[x]`).
5. **Leaked full-FS `find /` probe (14:34 session)** — auto-backgrounded and forgotten for most of the session on a storm-sensitive box; killed at closeout.
6. **Mis-specified reproduction nearly executed (dio session)** — the batch premise came from a prior VERIFIED report and was wrong; only a primary-evidence `coredumpctl` pre-read overturned it before a wrong upstream filing. Biggest positive lesson of the window.

## e) WHAT WE SHOULD IMPROVE

1. **Primary-evidence premise check before ANY reproduction/rerun** — `coredumpctl info` / live config grep at step 1; saved the window from filing a false upstream issue.
2. **Stage + commit within the daemon window; verify-then-amend only as recovery** — and re-run skipped .sh lint legs standalone after any daemon-swept amend (already de-facto policy; adherence was 11/11 commits this window).
3. **Fake-server smoke before the first real harness run** — death/timeout paths cost 1200 s to discover live.
4. **`bash -n` between every structural edit and the next execution** — two glued-line/no-op-sed bugs were 1-second checks.
5. **Annotate queue rows by content-assertion, never remembered line numbers** — one mis-annotation landed on the wrong rows this window (caught pre-commit).
6. **Harness results need a durable checked-in ledger** — gate numbers still land in volatile `~/.cache` JSONLs.
7. **Coredump evidence rots (~19 h)** — extraction policy decision still open (TODO_LIST.md:3226 `[decision]`).
8. **Query remote copies before declaring evidence impossible** — the forward-only decision initially ignored the ClickHouse copy one query away.

## f) NEXT (the valuable remainder; queue deltas in the Close-the-loop section below)

1. Unlock the deploy pipeline: run the lock-float proof for the 16-input drift (row queued; EVERY landed-but-undeployed fix in this window waits behind it — guard observability line, year-boundary join, bep fixtures are deploy-independent, the guard is not).
2. Take the strict-gate 23.4G cold-load baseline in a calm window (unblocks A1).
3. Push + tag storage-collector `6a67056`, bump SystemNix flake.lock, wire `dirSizes` for `/var/lib/monitor365-server`, deploy, verify the gauge reaches the 0700 tree (CAP_DAC_READ_SEARCH proof — agent-side du was blind 3.9G vs 145G).
4. Owner: contain-vs-relocate ruling for monitor365-server once the 7-day dir-size trend exists (decision row BLOCKED on the ask-channel gap; batch ids not in the tq DB).
5. Diagnose why `llama-embeddings.service` is inactive/dead while hermes-spawned servers hold its ports (new item below).
6. Confirm WHAT spawned the 05:40 bge servers (hermes-worker-cron suspected) — decides the routing fix shape.
7. ClickHouse probe for b0d70d73's systemd OOM-unit lines (overturn-or-confirm forward-only).
8. bep hardening cluster (all queued): systemd OOM-unit section, `.raw` companion artifact, oom-invocations census, SC2016 fix, both-fixture existence gate, `bep_ts_delta` known-value leg, year-boundary negative-test leg.
9. Guard-trip session-scope process-lineage capture (resolves the session-74 class live for the NEXT cascade).
10. bench-cold-load selftest fixture (guard paths, no GPU needed).
11. Collector hygiene cluster: MSRV 1.86 compile, PSI-gate lib-move + unit tests, abandon-not-cancel docs, `measure_dir` deprecation, FEATURES/README flag inventory, budget_exhausted surfacing, staleness Gatus conditions (all rows TODO_LIST.md:142–150).
12. Post-deploy: journal-watch one ioPause cycle to see the new skip-path line fire live; re-probe 8848/8849 ownership after any hermes restart.
13. Attribute the image-safetensors fragmentation writer (131KB/extents shredding).
14. Round-9 float registration completion is the SAME work as item 1 — do not double-dispatch (the 16-input row supersedes the 15-input row; tick the older when the proof lands).
15. Recount the check-todo-system pairing-DRIFT count after this window's appends (last recount: 74 post-prune).

(Items deliberately NOT re-minted: everything else from the five closeouts' §f lists is already present as an unchecked row — dedup-checked line-by-line against TODO_LIST.md before writing this section.)

## g) QUESTIONS (≤3)

All three owner questions from this window are ALREADY queued as `[decision]`/blocked rows by the first closeout instance (TODO_LIST.md:3343–3345): the hermes keep-vs-kill call for the 8848/8849 bge servers; the ClickHouse retention / backfill-carve-out call for b0d70d73; and the EVO-X2 thermal risk-acceptance / fan-control-surface call. No new owner question arose from the re-fire's re-verification. One process gap worth owner awareness (already a pipeline row class): the `tq ask` channel cannot accept batch-level task ids — decision items dispatched as batch members are dead-letter for the ask flow until per-item ids or a batch-ask path exist.

## h) BAND DRIFT

**None recorded.** `tq facts --type task.reprioritized` and the full journal (`tq facts`) hold zero reprioritization facts; no marker/ai/unblock/importance moves occurred in the window's timespan.

---

**Surfaces updated by this closeout:** this report; TODO_LIST.md (+2 dedup-checked items, evidence-ticks only — no existing item reworded or deleted); no archive moves (every candidate report under docs/status/ dated in this window is still the live `Source:` citation of open queue rows — archiving would break harvest provenance). CHANGELOG already carries the window's entry from the first closeout instance (`c4bbcd804`); re-verified current. FEATURES/README/ROADMAP: no window change touches their claims (the only shipped code faces are the guard line, the bep fix, and the bench harness — all covered by the CHANGELOG entry; the storage-collector ledger ships in the sibling repo, not here).
