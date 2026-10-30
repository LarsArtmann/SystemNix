# Task-Queue window close-out — 2026-10-27..30 batch (closeout verdict for 000001a1858af2593f13b2d2f07b00000000)

**Written:** 2026-10-30 05:35–05:55 CET · **HEAD at write time:** `a2a3f195f` (tree clean) · **Window:** 5 dispatched tasks, 2026-10-27 → 2026-10-29

## a) FULLY DONE (verified against commits, queue surfaces, and reports)

All five window tasks closed; each verified on BOTH queue surfaces (TODO_LIST.md tick + domain-library tick):

1. **System-health collector hardening** (task `…7d6a2665`, monitoring.md) — re-dispatch verification found all three 2026-08-18 asks already holding in code: the docker-timeout premise is moot since the 2026-10-08 docker removal (zero docker refs left in the collector), the NRestarts read is single-call since the 2026-09-19 parallel-walk fix, MemoryMax 128M→256M since 2026-09-19. Closed as verified-landed (`9b6ee68d1`). The batch also shipped two real features: papdashboard ingest hardening — authenticated end-to-end /api/ingest POST in post-deploy-check (the old 401-only probe could never catch method/body/schema bugs) + 14 smoke sections enable-gated on wants-symlink presence instead of unit-file presence (`1ab9691e9`) — and the gatus alerting-dedup decision recorded as a deliberate NO at the gatus layer, owned by the PapDashboard insight enricher (`4e42cce47`). CHANGELOG carries all three entries; post-deploy verification of the batch is queued (TODO_LIST rows on the calm post-deploy re-run + monitoring library).
2. **[watch] monitor365-server IO escalation** (task `…fbfb8536`) — closed by live journal verification (trips #4454–#4461 confirmed monitor365-attributed exactly as claimed; attribution shift after ~16:00 Oct 27 discovered; service liveness re-verified via busctl; ownership of the DB intervention correctly left with the 2026-10-27 storage-crisis session). Both surfaces ticked in lockstep; closeout: docs/status/tasks/2026-10-28_01-38_task-000001a17fbfb8536b3c2e5f35f700000000.md. The residual ~10-min zone-6 cadence was spun off as a new watch row rather than folded into the closed one — correct.
3. **`scripts/io-writer-attribution.sh`** (task `…047c159`) — landed by the parallel stability-extinction executor (`9b1f5b4c5`), then verified + closed by this task per the re-dispatch protocol: fixture selftest re-run LIVE (PASS: delta math, ranking, threshold, vanished-cgroup skip, sanity counts, argv-free output), selftest registered as `checks.io-writer-attribution-selftest` (`347622af2`). Closeout: docs/status/tasks/2026-10-28_03-53_task-000001a180047c159cd6129d107800000000.md. Same dispatch verified + closed crash-triage (M10, `325804fdc`) and the per-boot SEV1 trip count / Gatus load-bearing check (F51, `66e1ec322` — including a live on-host execution of the REAL rendered sev1-bridge-check against the bootstorm fixture, all leg-9d assertions PASS, and a premise CORRECTION: the loadBearing gauge was already boot-scale, the genuinely missing leg was the SEV1-line surfacing).
4. **boot-evidence-pull.sh ClickHouse death-window section** (task `…1450ce1`) — landed pre-dispatch via daemon-swept commits `66967f60d` + `ca6dfd0d8` (the executor was never footer-attributed — see (d)), then re-dispatch-verified in a later queue session: selftest extended to all four CH states (ok/dark/failed/skipped) re-run LIVE — PASS; standalone shellcheck clean (the daemon-swept lint leg owed since 10-27); LIVE ClickHouse probe of the exact query shape confirmed table/columns/epoch-ns (newest row 06:00:05 UTC Oct 28 — the pipeline was DARK 12.6 h, the documented SEV1 collector outage, so the dark path is the live-observed state). Both surfaces ticked (TODO_LIST.md:160, docs/todo/stability.md:22) with the full evidence line; doc sync landed (stability.md remedy bullet + M22 autopsy rule name the remote-tail section).
5. **dnsblockd 3-item batch** (task `…8407382`) — items 1 (4318-refused journal spam → `LogFilterPatterns` filter + alarmed out-of-band observer) and 2 (readiness gate proves the real :53 UDP+TCP contract, wrong-port-map negative tests as a flake check) were already landed by two prior footer commits and correctly SKIPPED per protocol; item 3 (allowlist backup) was fully in-tree (daily 02:55 `Persistent` oneshot, pool-gated, restic-app-dumps path, deploy.sh converger) and THIS session closed both unticked ledger surfaces (`6041ef52f`), plus fixed the missing runbook section in docs/services/dnsblockd.md on sight. Closeout: docs/status/tasks/2026-10-29_03-17_task-000001a184073822d951926cda0e00000000.md. Later commits (`4957c807b`, `db568283c`, `392ad447c`) ticked the remaining dnsblockd rows (4318 silence, CA second-writer resolved as nixpkgs buildcatrust, 3-item batch close-out).

## b) PARTIALLY DONE

1. **Task `…1450ce1` has no footer-bearing commit.** Its work is landed and its queue surfaces are ticked, but the landing rode heuristic daemon commits — the executor's identity lives only in this report's reconstruction. Attribution gap, not a work gap.
2. **Live-state legs deferred by several closers:** the dnsblockd allowlist backup was closed on tree+wiring evidence without a same-session live probe (journal line + pool-copy listing — follow-up row queued by that closer); the papdashboard ingest batch's post-deploy verification is queued, not yet run; F51 leg 9d has never executed as a VM/flake test (host-probe-grade only, storm-gated).
3. **The 01-38 closeout's §f has ~40 report-only items** beyond its 10 queued picks (trip-cadence metric, casualty-list enumeration, PSI baseline, evidence retention, etc.) — most are genuinely plan/row-tracked, but they live only in that report until annotated.

## c) NOT STARTED (backlog the window skipped, verified still open)

- The plan-tracked stability backlog: M11 (journal-census/crash-autopsy), M15 (mr-sync idle IO class), M22 (watchdog-window vs flush-lag note), M24 (prune dry-run + WARN recount), M25 (role-split brief), M2/M3/M20 implementations (§7.1 owner-gated), M5/M6 deploy wave + reboot battery.
- Storage reclaims: the 55G Trash (owner trash-empty), the @cache-home.regular-dir-bak subvol delete (sudo), hot-DB waves (owner windows).
- The signoz OTel collector redeploy (root fix behind the 4318 filter) — still owner-gated; the filter is symptom management until it lands.
- Freeze #38 follow-up cluster (crash-triage run, guard census, SUPERB mapping, thermal re-open) — queued in stability.md, untouched this window.

## d) TOTALLY FUCKED UP

1. **`tq verdict` has written a 0-byte `$TQ_RESULT_FILE` for THIS close-out instance across 7 paid re-fires** (queued as TODO_LIST row 1717; verified still open at write time — `.tq-verify` exists, `tq facts --type task.reprioritized` answers but the verdict-file path is broken for this instance). Six fires exited claiming success while the queue read an empty file and re-claimed the task. This session writes the JSON manually as the fallback and verifies the file is non-empty before exiting. ~7 wasted paid dispatches — the most expensive defect in the window, and it is in the harness, not the repo.
2. **The 01-38 closeout's commit swallowed a parallel session's staged work** (`7465a7a3a` carries foreign `boot.nix` + pre-deploy-script changes under the wrong Task-Queue-ID) — amend-after-reject with a pathspec, which has no excluding power. Renarration/split still pending (TODO_LIST row exists).
3. **Footer attribution bypassed by daemon-swept landings** (task `…1450ce1` class, twice in this window's arc): work lands via `chore: auto-commit (heuristic)` and the paid dispatch becomes a verification-only close. The re-dispatch protocol handled it correctly, but each such fire costs a full session to prove what a footer commit would have proven for free.
4. **Chronic 72-char subject-limit rejections** — two separate closeouts in this window's arc walked into the same documented hook reject, and the first one's reject is what created (d).2. The rule is written in the very instructions being executed.
5. **Stale `[ready]` rows dispatched after their fix landed** — the dnsblockd batch was 2/3 already-done at dispatch; the ClickHouse item landed pre-dispatch. The re-dispatch protocol caught both, but the pipeline pays for re-discovery every time (improvement row queued by the dnsblockd closer: tick rows at fix-commit time).

## e) WHAT WE SHOULD IMPROVE

1. **Fix the tq verdict/$TQ_RESULT_FILE write path first** — it is converting every close-out into a re-fire loop (d).1). Until fixed: the done-prompt instructions should mandate the manual-write fallback + a non-empty-file assertion as the standard exit sequence, not just "if tq is not on PATH".
2. **Tick queue rows at fix-commit time** (dnsblockd closer's proposal) — a CI/pre-commit hook or tq-side audit comparing row text against landed footers would kill the stale-`[ready]` re-dispatch class.
3. **Footer-attribution for daemon-swept landings:** when an executor knows it will land via the daemon (storm-banned commits), it should still stage a footer-bearing empty-ish docs commit for attribution, or the done-prompt should accept "daemon-swept + verified" as a first-class outcome so the next fire skips re-proving.
4. **"Live" claims require same-session live probes** — the dnsblockd close-out's own §d.2 admission; the runbook-word upgrade rule is already in AGENTS.md and keeps being re-learned.
5. **Pre-commit snapshot reflex** (`git diff --cached --name-only` before ANY commit; pathspec on the FIRST attempt, never on an amend) — formalize in CONTRIBUTING's daemon-race section; the 01-38 §e list already drafts it.
6. **Annotate closeout reports' §f report-only residue** — a light `r`-kind (routed, no strike) annotate sweep over the 01-38 report would mark items 2–50 as routed/plan-tracked without minting dispatches.

## f) NEXT THINGS (≤10 queued; deduped against existing unchecked rows)

Appended to TODO_LIST.md this session (see the closeout commit diff for exact lines):
1. Confirm the gatus "Memory Guard Trip Churn" alert auto-RESOLVED after trip #4512 and `churn_mode` returned to 0 (the alert says it self-resolves; nobody confirmed). *Source: 01-38 closeout §f.22.*
2. Investigate the 2026-10-27 12:00 sev1-bridge repeat-fire dedup gap: 4 firings in 36 s for ONE condition state ("MEMORY EMERGENCY GUARD TRIPPED") — one-shot-per-state or dedup window needed. *§f.18.*
3. Build a week-over-week io PSI baseline (textfile metric or simple journal-derived table) to answer whether chronic zone-6 (9+ h at some avg10 35–70%) is new or the post-Samsung-roles normal. *§f.35.*
4. Check GC retention on the `io-psi-forensics` zone6-trip bundles for the 9-h chronic window before anyone reads them (store paths may have been GC'd). *§f.48.*
5. First real-storm execution of `scripts/io-writer-attribution.sh` (its selftest is green; the live run during the NEXT trip storm is the unproven leg). *Derived from the 047c159 closeout §b.*
6. Enumerate which sockets/sacrifice units the 9-h trip train stopped and verify ALL came back (restore_capped re-capped every ~10 min — was there a standing 9-h availability tax?). *Already queued in the window's own harvests (row 1673) — NOT re-added; listed for the cap ledger.*
7. Verify the dnsblockd allowlist backup actually fired live (journal + pool copy + restic snapshot) — *already queued by the 8407382 closer — NOT re-added.*
8. Fix the tq verdict/$TQ_RESULT_FILE 0-byte defect — *already queued (row 1717) — NOT re-added; promoted to first priority in (e).1.*
9–10. Reserved by dedup: remaining §f candidates (guard top-5 child-unit deltas, per-trip io.stat persistence, host-probe harness docs, spot-verify mechanism-claims rule) are already on the queue from this window's own closers — re-adding would mint the duplicate-dispatch class the dedup check exists to stop.

Net NEW appends this session: items 1–5 above (5 rows) + 1 blocked question row (below). The window's own closers had already harvested their §f well — the dedup check found no rewords needed.

## g) QUESTIONS FOR THE OWNER (queued as BLOCKED items)

1. **Is the signoz OTel collector redeploy planned for a specific window?** The dnsblockd 4318 `LogFilterPatterns` line must be re-audited in the SAME switch that revives the collector (the filter assumed a dead endpoint; a live one makes the refused-dial line signal-bearing again). — BLOCKED: queued.
2. **Do you accept a shared-tree history rewrite to renarrate/split the two foreign files inside `7465a7a3a`** (d).2), or should the boot-chain session own the renarration in its next report? (Row 1716 tracks the work as [ready]; the rewrite-risk call is yours.) — covered by the existing row; not duplicated as a BLOCKED item.
3. *(none further — the window's other open questions — chronic zone-6 policy, mid-band trip alert, 16:00 shift provenance — are already on the queue as [decision]/[watch] rows.)*

## h) BAND DRIFT

`tq facts --type task.reprioritized` over the journal returns **(0 facts)** — none recorded for this window or any earlier sequence. The journal holds no priority moves to explain; no marker/ai/unblock/importance reprioritizations occurred (or the reprioritized fact type is never emitted by this tq version — worth one harness question if moves are expected to be journaled).

## Docs-health notes

- CHANGELOG already carries entries for every user-visible change in this window (system-health close, papdashboard ingest batch, gatus dedup decision, dnsblockd rows) — verified by head-read; no additions needed. FEATURES/README/ROADMAP: no feature-status change in this docs-only window; untouched.
- The three task closeout reports under docs/status/tasks/ remain OPEN as Source rows (their §f residue is actively cited by queue rows) — not archived; a routed-verdict annotate sweep is queued in (e).6 as process improvement, not executed here (scope: docs maintenance only, and full inline resolution of 3 × ~100 items exceeds this pass).
- No files moved to docs/status/archived/ this pass: every candidate still carries open, referenced items.
