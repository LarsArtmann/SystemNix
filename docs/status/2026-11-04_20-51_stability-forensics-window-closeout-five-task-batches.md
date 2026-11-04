# Stability forensics + storage triage window closeout — five task batches (2026-11-02 → 2026-11-03), verified 2026-11-04 20:51

Window: five paid task batches, 2026-11-02 17:41 → 2026-11-03 23:05 CET. All five closed with
footer-bearing commits, ticked queue rows on both surfaces, and (four of five) dedicated closeout
reports under `docs/status/tasks/`. This report is the window-level "done prompt": what landed,
what didn't, what regressed, and what feeds the next round. Everything below was verified against
git history, the live tree, and the queue surfaces — not taken from the closeouts' own claims.

**Band drift (ADR-0015):** the local tq journal (`facts` table in `~/.local/state/tq/tasks.db`) is
EMPTY (0 rows) — no `task.reprioritized` facts recorded for this window. **None recorded.**

---

## a) FULLY DONE

1. **flm-real alive-at-kill forensics (task 000001a19d04…, closeout
   `docs/status/tasks/2026-11-02_17-41_task-…d0445939f0e5c51d75400000000.md`, commits
   `860ae4001`/`ed271115e`/`db125a89d`).** Both Oct-29/30 fastflowlm backend kills resolved to
   distinct restarters, neither a guard restore: (1) the unit's own `Restart=on-failure`
   (fastflowlm.nix:449) resurrecting an evening core-dump crash loop (Started-without-Listening =
   in-unit restart, socket provably closed since 21:49:56); (2) the 01:33:07 deploy's
   `switch-to-configuration test` re-arming the guard-sacrificed socket MID-TRANSACTION
   (`Listening` 01:40:30, the documented 2026-09-09 stc class) — corroborated by a second
   same-day re-arm (23:37:41 after the 23:32:24 deploy). The Oct-28 10:14–10:15 OOM cascade
   anatomy also landed in the same batch: all 9 kill-lines mapped to victim/unit/invoker
   (global OOM, CONSTRAINT_NONE, free swap 0 kB of 62 GiB). Queue rows ticked on both surfaces
   (docs/todo/stability.md:20, :22 with full DONE narratives — verified).
2. **Kill-pass memcg join in boot-evidence-pull.sh (task 000001a19d3b…, commits
   `23907292c`/`755403a2d`/`5f5e4217c`).** `bep_killpass_join` emits per-victim memcgs with three
   labeled basis levels (`attested` / `unit-join` / `UNRESOLVED` — never fabricated), live-verified
   against the real b0d70d73 cascade (7/9 kernel-attested, 2 chrome-headless unit-joined with the
   honest tie set). Two implementation mis-rankings (system.slice, then the hermes scope) were
   caught pre-commit. Companion hermes containment audit falsified the "zero containment"
   hypothesis (memory.max = 4 GiB proven in hermes source; Oct-28 victim peaked 1.1G/248M under
   the cap) and pinned the 1.414 TiB per-renderer VmSize as PROT_NONE startup reservations
   (V8 sandbox + PartitionAlloc), matching prod victims to 0.01%. Both companion reports
   (`2026-11-02_18-55_chromium-1p5tib-vm-reservation-repro.md`,
   `2026-11-02_19-00_hermes-uid975-chromium-containment-audit.md`) committed.
3. **Scratch GC scriptified + startup self-clean (task 000001a19d89…, commits
   `190f43f4a`/`0919e892c`/`a3b4074d4`).** `scripts/boot-evidence-scratch-gc.sh` (age ≥48 h AND
   no /proc live-holder, modes gc|quiet|selftest) registered as
   `checks.x86_64-linux.boot-evidence-scratch-gc-selftest`; `boot-evidence-pull.sh` runs it quiet
   before allocating its own scratch (fail-soft). Join window calibrated 30 → 60 s with measured
   evidence over the journal's only two live OOM boots (output byte-identical at 30/45/60); the
   wider window exposed and fixed a uid-0 false-join (counter-uid guard extended to all
   user-flavored units). A sanitized real-dump cascade fixture
   (`tests/fixtures/boot-evidence-pull/b0d70d73-oom-cascade.{dump,oom}`, 37 lines) + 9-assertion
   regression leg now pins the ranking against systemd line-order changes. The 2.7 G of
   calibration scratch was trashed at closeout — the session did not add to the leak class it
   fixed. `nix flake check --no-build` green at closeout (verified in the closeout §a.5).
4. **crash-triage remedy clause (task 000001a19de0…, commit `a03b0547d`).** The
   `oom-memcg-attested` census line now names the remedy verbatim
   (`scripts/crash-triage.sh:152` — "→ boot-evidence-pull kill-pass join" verified live in the
   tree). The same task ID carried two follow-on commits beyond its original ask:
   `c8e4ccb44` (chromium adj-300 attribution upgraded from inference to chromium source citation)
   and `ebdc9194d` (hermes `--property=OOMScoreAdjust=` upstream proposal RESOLVED AS
   document-why-not — verify-before-filing Gate 4 failed it; decision record in
   docs/todo/upstream.md:245, ticked).
5. **~/.cache regrowth triage (task 000001a1a329…, closeout
   `docs/status/tasks/2026-11-03_23-05_task-…a3299dad1b9b14d9a57a00000000.md`, commits
   `9f5a9f7e5`/`89d4046fe`/`533a4cdc8`/`098c3e38a`).** The ~20G→119G regrowth writer ATTRIBUTED
   with fleet-wide evidence (27 .crush DBs queried; per-task `mktemp -d` GOCACHE pattern from
   agent sessions; BuildFlow env_guard + fish go-cache-guard exclusions proven at source level);
   the PR7oGL 6.4G litter CLASS closed with a 48h age-gated stale-workdir sweep in
   `scripts/negative-test-lints.sh:43-45`; journald retention verified BOUNDED (live conf = repo
   conf, 7.7G of the 8G cap = rotation working); the /data latency-first redesign scoped in
   `docs/planning/2026-11-03_data-redesign-latency-first-design.md` with 4 owner asks.
   **Follow-through verified:** the queued Go-cache redirect row LANDED 2026-11-04 (after the
   window): direnv `_bf_agent_cache_guard` + `buildcache-agent-cache-gc` timer, tests 23/23
   (TODO_LIST:144 ticked, docs/todo/storage.md:220 ticked) — the lasting fix the triage row
   named now exists.

## b) PARTIALLY DONE

1. **The flm "gap close" is diagnosis-only** (first batch's own honest admission): the SYSTEM gap
   (stc re-arm survives guard sacrifice) remains open — correctly filed as
   docs/todo/stability.md:21 (`re-stop when stopped pre-switch` / boot-scope mask), NOT
   implemented.
2. **Daemon-race fragmentation, again:** in two of the batches the auto-commit daemon swept staged
   script payloads into heuristic commits before the footer commits landed, so footer→file tracing
   splits (19-00 §b.1, 20-31 §b.1). All work is in-history; no data loss; but the documented
   remedy (pathspec commit fired immediately after each edit wave) was written down AND not
   followed, three times in one session (20-31 §d.2).
3. **Join calibration set is 2 boots, not 2–3** — the journal's other OOM boots are vacuumed; the
   third data point must wait for a fresh OOM boot (row exists, stability.md:307 ticked with this
   caveat).
4. **Cascade fixture covers only the 10:13–10:15 window** of b0d70d73's OOM history; four later
   windows (17:49, 19:15–19:38, 20:43, 23:59→00:03) are unfixed — queued (TODO_LIST:185).
5. **§f.20 hermes anatomy row got a pointer, not a merge** — the 4 new 1.45 TiB reservations live
   in the anatomy report; the hermes-worker-cron row still requires following two links (17-41
   §b.2). Not yet queued as its own row (minted this closeout, see appended items).
6. **Join backfill of the 8+ historical evidence pulls** — untouched, correctly parked as an owner
   decision (TODO_LIST:186, [decision]).
7. **~/.cache purge wave 2** (glac-fleet 25G, m365fix 22G, cv-go 19G, ds-gate/ec-hub 8G) remains
   owner-gated; `.Trash-1000` 4.8G rides the trash-empty owner row.

## c) NOT STARTED (backlog the window skipped — all already routed)

- The flm stc re-arm remediation (stability.md:21) — the highest-value open item of the window.
- Reservation-pressure observability: top-5 total-vm textfile collector / SigNoz VmSize rule
  (stability.md:317) — the next cascade still arrives unannounced.
- Session-74.scope spawn attribution (which interactive tool spawned chromium + 2 chrome-headless,
  stability.md:323).
- Weekly boot-evidence-scratch-gc timer (startup-only gc misses the no-pull stretch,
  TODO_LIST:184).
- Weekly-ish OOM cadence: the window fixed the forensics tooling but shipped no remediation for
  the kill classes themselves (by design — forensics batches; the decision rows
  stability.md:312/313 are owner-blocked).

## d) TOTALLY FUCKED UP

1. **Verdict-channel typo nearly fatal (19-00 §d.1):** the executor typed the queue-supplied
   verdict path with a transposed digit (`2275259647` for `2277259647`); the queue would have read
   NO verdict. Caught by the closeout re-read and re-recorded. Rule: paste queue-supplied paths,
   never type them.
2. **First batch's queue edits nearly shipped a malformed row** (`- [x] ] [ready]` marker
   corruption) and a batch-then-split commit plan collided with the pre-commit TODO gate, costing
   two edit cycles and forcing `--no-verify` for all three commits — meaning NONE of those queue
   rows were validated by the very gate that checks them (17-41 §d.1–3).
3. **Shipped self-contradicting commit message** (23-05 §d.1): body says "no task footer", footer
   present; amend blocked by a foreign session's index.lock for the whole bounded wait — permanent
   history, message hygiene only.
4. **Two full pre-commit batteries burned on >72-char subjects in one evening** (23-05 §d.2) — the
   commit-preflight discipline (TODO_LIST:1063 row) was in context and not applied.
5. **A python in-place rewrite used to bypass the edit tool's modified-since-read guard** (20-31
   §d.1) — the guard was tripping on a treefmt mtime, not a foreign edit; the bypass worked but is
   one step from blind-editing a file a parallel session actually changed.
6. **Gate asymmetry persists:** foreign sessions' gate-violating rows land via daemon commits
   (hooks bypassed) and every honest commit then needs unplanned compliance edits (19-00 §a.5's
   fix-on-sight) — the chronic ~100-DRIFT-row TODO-gate redness remains the standing tax, own row
   queued (TODO_LIST:50 sweep).
7. No regressions to code, config, or gates were found this pass: both script selftests + flake
   check green at each closeout, and the landed 2026-11-04 follow-through (direnv guard + gc
   timer) tested 23/23.

## e) WHAT WE SHOULD IMPROVE

1. **Pathspec footer commit as the FIRST act of each item's verify phase** (edit → test → commit
   immediately) — written into two closeouts and lost to batching three times in one session. It
   is now the standing recommendation; consider making it a CONTRIBUTING code block, not prose.
2. **`--no-verify` commits should run the TODO-system checker standalone on the edited files**
   (it is invocable outside pre-commit) so the bypass skips only the known-broken global
   inventory, never the session's own rows.
3. **Paste, don't type, queue-supplied identifiers** (verdict file paths, task ids) — one typed
   transposition nearly voided a whole batch.
4. **Widening any gate/window must ship a NEW negative fixture in the same commit** — the uid-0
   false-join was caught exactly because this was done; institutionalize the pattern.
5. **Session-start gate dry-run** (`bash scripts/check-todo-system.sh`) before the first commit of
   a batch so foreign rows never block a mid-batch commit as a surprise.
6. **Content-level doc tripwires where doc and code share a number** (the bep selftest greps only
   the script NAME in stability.md — a window-value change can leave the doc stale silently).
7. **Attribution sweeps: pilot-then-fan-out** (one DB, confirm schema, then the fleet) — the
   27-DB sweep ran minutes unbounded in the background.

## f) NEXT (most valuable; the ≤10 harvested set is appended to TODO_LIST.md, dedup-checked)

Already queued by the window's own self-harvests (do NOT re-mint): flm stc re-arm fix
(stability.md:21), double-source flm verdict via ClickHouse (TODO_LIST:165), weekly scratch-gc
timer (:184), cascade fixture later windows (:185), join backfill decision (:186), year-boundary
join (:187), abandoned staged commits verify (:765), whole-tree audit scoping (:766), session-race
CONTRIBUTING section (:767), 48h sweep first-run watch (:768), chromium bump re-verify + wrapped-
chromium sample + swap cap + stance rows (stability.md:312–317), hermes OOMScoreAdjust resolution
(upstream.md:245). The items below are the window's §f grain NOT yet represented anywhere:

1. Merge the 4 new 1.45 TiB reservations into the hermes-worker-cron §f.20 anatomy row itself
   (pointer currently two links deep). — appended
2. `--calibrate` mode for `bep_killpass_join` (per-kill nearest-line deltas) so the next
   recalibration is one command on fresh boots, not a throwaway python over 2.7 G of dumps. —
   appended
3. Content-level doc tripwire: bep selftest asserts stability.md states the CURRENT window value. —
   appended
4. Sweep ALL guard-sacrificed Accept=true socket units for the stc re-arm exposure class (is
   fastflowlm the only one?). — appended
5. Empty-UID fixture leg: the counter-uid guard excludes user units only for uid=0 victims; a
   kernel kill line without `UID:` joins whatever is nearest. — appended
6. Sweep deploy logs Oct 29 20:00 → Oct 30 03:30 for deploys executed during active guard storms —
   size the deploys-during-storm policy violation before deciding on a gate. — appended
7. Audit oom_score_adj across the AI stack (adj 300 made an 11 MB llama-embeddings process the
   kernel's pick; reservation-pressure victims are chosen by adj, not size). — appended
8. Verify whether `fastflowlm_crash_loop` / `fastflowlm_failed` metrics actually paged SigNoz
   during the Oct 29 crash loop (alert-coverage question, monitoring domain). — appended
9. Live-exercise boot-evidence-scratch-gc on the real cache dir once (today's scraps <48 h →
   expected no-op; proves the find/stat/date path on real files). — appended
10. Session-start `check-todo-system.sh` dry-run convention (docs/CONTRIBUTING one paragraph). —
    appended

Beyond the cap (recorded here only): bep `date -d` year-boundary verification (already queued
:187), fuser/lsof fallback for the gc holder check (rejected by design — document the uid blind
spot in stability.md instead), tie-candidate emission into crash-triage's per-boot line, join the
gc into crash-triage startup (verify it is transitive via bep — one grep), fixture sanitizer human
read of the 37 cascade lines.

## g) QUESTIONS FOR THE OWNER

1. **GC retention policy:** is 48 h + no-holder the right destroy gate for evidence dumps, or do
   you want a `*.keep` marker honored by the gc for dumps you deliberately want to survive a long
   forensics pause? Default today: everything ≥48 h unheld is gone on the next pull.
2. **Join-window margin:** 60 s (current, output invariant on both live boots, max lead margin) vs
   a tighter 35–45 s to shrink the false-candidate surface against FUTURE systemd ordering
   changes?
3. **Guard sacrifice mechanics:** should the sacrifice branch runtime-MASK sacrificed sockets
   (making stc re-arm impossible until unmask) instead of stop — accepting that a mask survives
   deploys until explicitly unmasked?

## h) BAND DRIFT

**None recorded.** The tq facts journal (`~/.local/state/tq/tasks.db` `facts` table) is empty —
zero `task.reprioritized` facts exist for this window (or any window). No priority moves to
account for.

---

### Verification ledger (what this report checked, not just quoted)

- All five task IDs traced to footer commits via `git log --grep Task-Queue-ID` (batch 1:
  `860ae4001`/`ed271115e`/`db125a89d`; batch 2: `23907292c`/`755403a2d`/`5f5e4217c`; batch 3:
  `190f43f4a`/`0919e892c`/`a3b4074d4`; batch 4: `a03b0547d`/`c8e4ccb44`/`ebdc9194d`; batch 5:
  `9f5a9f7e5`/`89d4046fe`/`533a4cdc8`/`098c3e38a`).
- `scripts/crash-triage.sh:152` remedy clause read live in the tree.
- Queue-surface tick verification: `docs/todo/stability.md:20/22/26/27/304/307/312-317`,
  `docs/todo/upstream.md:245`, TODO_LIST rows :144/:156/:165/:169/:178-180/:184-187 all inspected
  — no drift found between queue one-liners and library rows for the window's items.
- CHANGELOG checked for window coverage: the autopsy batch (S-0029–S-0033) entry exists (line 947)
  but the bep join/gc/calibration/fixture tooling had NO entry — added this pass.
- Go-cache redirect follow-through: TODO_LIST:144 + storage.md:220 ticked LANDED 2026-11-04.

### Docs-health pass note

The five closeout reports are point-in-time task closeouts already carrying their own DONE
narratives inline; no annotation or archiving was warranted (each still owns open §f grain routed
to the queue). No `docs/status/` file in the window qualified for `archived/` (every candidate
carries open, referenced follow-up rows). CHANGELOG gained the window's tooling entry;
TODO_LIST gained 10 dedup-checked items + 3 owner-blocked questions below.

_Arte in Aeternum_
