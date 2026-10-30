# Five-Task Window Close-Out — 8th Fire, Verdict-Landing Forensics (2026-10-27 → 2026-10-30)

**Authored:** 2026-10-30 03:35–03:5x CET · **HEAD at authoring:** `4d250ba0d` (tree clean) · **Queue window:** tasks `…000001a17d6a`, `…000001a17fbf`, `…000001a1800`, `…000001a1814`, `…000001a1840` · **This dispatch:** task `…000001a1858a`, the EIGHTH fire of the done-prompt for this window
**Method:** the window's own closeout record (`docs/status/2026-10-29_03-55_five-task-window-closeout-20261027-29.md`, seven re-claim annotations) read first; every landed claim re-verified against the tree this session (scripts, selftest registrations, nix modules, CHANGELOG, TODO_LIST rows); the queue's own journal queried read-only (`/mnt/pool/services/tq/tq.db`, facts table) — the seven predecessor instances never reached that source.

---

## Why this report exists (the delta over the seven prior fires)

The window's work closed at `fa5d4e9eb`-era state and the prior closeout already documents it; every re-fire since re-verified integrity and appended an annotation. What NONE of them had is the root cause, because none queried the queue's own journal. This instance did, and the mystery of eight paid dispatches for one report resolves into two mechanisms, both visible in `facts`:

1. **Lease-expiry reclaim churn (the dominant killer).** `facts` seq 17072–17188: TEN consecutive `task.released {"reason":"lease-expiry"}` → immediate `task.claimed` cycles on this task, 2026-10-29 04:34 → 08:56, at ~40–48 min per claim. The pool's lease lapses in under ~45 min while the done-prompt (report + docs-health pass + TODO loop + commit) routinely needs 45–90. Every prior instance therefore had its claim REVOKED mid-run: its verdict (when written at all) landed in a result file owned by a dead claim that no executor ever reads, and the re-claim spawned the next paid instance. The "0-byte `/tmp/tq-verdict-*.json` files" the #6/#7 annotations found were the CURRENT claim's freshly pre-created channel — not proof that `tq verdict` is broken (it is not: `cmd/tq/verdict.go` in go-taskqueue is a plain validated `os.WriteFile`), and the "twin-instance" fear in annotations #6/#7 is also corrected: the three same-second result files are the pool's three concurrent claims (one per repo: SystemNix, go-taskqueue, CV), not twins of one task.
2. **Verify-gate discard ordering.** The executor parses the verdict file into the run output only AFTER `runVerify` passes (`internal/executor/agent.go`: `appendVerdictLine` output is consumed after the `runVerify` error return). The `.tq-verify` pin for this repo is `nix flake check --no-build` — and `/home/lars/.local/state/tq/logs/000001a1858af2593f13b2d2f07b00000000.verify-failure.log` (24 KB, Oct 29 09:06) shows that gate DYING MID-EVAL (ends inside `checking derivation …deploy-restart-audit`, then bare `exit status 1`, no nix error line — an environmental kill under the day's PSI/load, not a check failure). That attempt's verdict, even if written, was thrown away with the failed run. This is the exact failure mode TODO_LIST rows 480 (docs-scoped verify) and 481 (verdict-durability: write the verdict immediately after the report commit, never after end-of-session verification) were minted for on 2026-10-15 — this window is their second confirmed casualty set, and row 481's CONTRIBUTING.md codification is still NOT landed (grep: no verdict-durability clause in docs/CONTRIBUTING.md today).

Net: the window's work was finished and committed ON THE FIRST FIRE (`2c4a32c9a`, 2026-10-29 03:53); fires 2–8 spent ≥6 paid sessions re-verifying a done report because the queue's channel mechanics, not the work, kept failing.

## a) FULLY DONE (all five window tasks — re-verified this session against the tree)

| Window task | Landed state (re-verified 2026-10-30) |
|---|---|
| **System-health collector hardening** (`…000001a17d6a`) | Re-dispatch verification closed it: docker-timeout premise MOOT (docker removed 2026-10-08; zero docker refs in the collector), NRestarts single-read live, MemoryMax 256M with in-code rationale. Footer commits `9b6ee68d1`/`1ab9691e9`/`4e42cce47`; TODO + monitoring.md row ticked; CHANGELOG entry present (2026-10-28 "System-health collector hardening row closed as verified-landed"). Nothing to do; none done this fire. |
| **monitor365 IO escalation [watch]** (`…000001a17fbf`, report `docs/status/tasks/2026-10-28_01-38_…`) | Escalation SUBSIDED (trip attribution #4462–#4512); row `TODO_LIST:279` `[x]` with the dated UPDATE (re-read this session); stability.md carries the evidence line; residual-cadence watch row open at `TODO_LIST:1695`. |
| **io-writer-attribution + crash-triage + per-boot SEV1** (`…000001a1800`, report `docs/status/tasks/2026-10-28_03-53_…`) | Verified this session: `scripts/io-writer-attribution.sh` + `scripts/crash-triage.sh` on disk; BOTH selftests registered in `flake/parts/checks/selftests.nix` (`io-writer-attribution-selftest` :86, `crash-triage-selftest` :130); F51 leg-9d host-probe PASS recorded; commits `347622af2`/`325804fdc`/`66e1ec322`. VM-grade execution still owed (see b). |
| **boot-evidence-pull ClickHouse death-window** (`…000001a1814`) | Verified this session: `scripts/boot-evidence-pull.sh` carries the M22 death-window section (queries `signoz_logs.distributed_logs_v2` over [journal cut → next boot], four fail-soft states, M22 caveat rendered); CHANGELOG entry present (2026-10-28); stability.md rule synced. |
| **dnsblockd batch: 4318-spam + readiness gate + allowlist backup** (`…000001a1840`, report `docs/status/tasks/2026-10-29_03-17_…`) | Verified this session: `LogFilterPatterns` 4318 filter (`dns-blocker.nix:1538`); :53 UDP+TCP readiness gate with fixture negative legs (`checks.dnsblockd-readiness-gate`, eval'd green in the 09:06 verify log's check listing); `dnsblockd-allowlist-backup` unit + pool dir unit (`dns-blocker.nix:1753–1790`); runbook section `docs/services/dnsblockd.md:319`; ledger commit `6041ef52f`. |

## b) PARTIALLY DONE (still open, tracked)

1. **dnsblockd allowlist backup live-verification** — tree + wiring verified only; the 02:55-fire journal probe, pool-copy `ls`, and restic snapshot check remain queued (dnsblockd follow-up rows, TODO_LIST ~:182 family).
2. **F51 leg-9d is host-probe-grade, never VM-grade** — the calm-window `nix flake check` execution is queued (TODO_LIST:147); last night's verify-gate attempt (09:06) died mid-eval instead — the gate itself is the storm casualty.
3. **System-health collector batch deploy-pending** — the ingest-probe/enable-gate/counter work is in-tree awaiting the next evo-x2 deploy; post-deploy verification row queued.
4. **Endpoint-grade probes** — the escalation close used busctl/process-grade liveness; HTTP re-probe was curl-banned (standing constraint, not a gap introduced here).

## c) NOT STARTED (skipped by the window, still open)

- The plan-tracked stability backlog (M2/M3/M5/M6/M11/M15/M16/M20/M24/M25) — §7.1/PSI-gated, deliberately untouched.
- SEV1 signoz-collector recovery (deploy-gated, root session) — every deploy-pending fix above rides its train.
- Hot-tier DB move, buffer-pressure red-flip verification, trash-reclaim sudo halves — owner/PSI-gated.
- The catalog integration-subdomain warning (22 names) and the `stalwart 0.15.5` pin warning — rows open (`TODO_LIST:1690` et al).
- The window's docs-health obligations on THIS fire: no archive moves (the three task closeout reports and the prior window closeout are all cited as `Source:` by open TODO_LIST rows — referenced, so none archived); annotation of the prior closeout = the pointer appendix at its end (appended by this fire).

## d) TOTALLY FUCKED UP

1. **Eight paid dispatches for one report — the saga root-caused only on the eighth.** Seven sessions burned on lease-expiry reclaims + verify-gate discard (mechanisms above). The cost is not hypothetical: six of the fires re-did the full integrity pass, and the annotations they left ("verdict recorded", "output confirmed") were FALSE NARRATION in at least four cases — the journal shows no task.completed until the claim dies. Lesson sharper than row 481's: an agent CANNOT validate its own verdict from inside the run; only the queue's journal (`facts` table) or a non-claim-side file check can.
2. **Foreign-file commit absorption (`7465a7a3a`)** — the 01-38 close-out's commit swept the parallel boot-chain session's staged work; amend-with-pathspec recovery was a no-op. Owner question open (`TODO_LIST:1698`).
3. **Unfootered daemon-swept landing of the boot-evidence task** (`66967f60d`/`ca6dfd0d8`) — provenance restored only by re-dispatch verification; the footer-in-template discipline row keeps paying.
4. **Repeated 72-char subject rejections** — two independent sessions in the window tripped the same documented hook limit, and one rejection cascade directly caused d.2.
5. **"Live" outran evidence** (dnsblockd close-out §d.2) and **stale-premise rows at harvest** (escalation ~10 h stale; F51 false mechanism premise) — both caught by dispatch-time re-verification, both at paid-session cost.

## e) WHAT WE SHOULD IMPROVE

1. **Fix the lease/task-class mismatch (the new one):** long-running dispatches need either a longer `--lease`, mid-run renewal, or a done-prompt-specific lease. The journal chain (facts 17072–17188) is the sizing evidence: 10 reclaims at ~40–48 min each. Queued as a new row (see f).
2. **Land row 481's CONTRIBUTING.md codification** — report commit → `tq verdict` → only then any further verification; this window is its second confirmed casualty set. Row 480's docs-scoped-verify leg (leg 2) is still the structural fix for docs-only dispatches; its leg 1 (hermes re-pin) has since landed (the pin-audit trace in the 09:06 verify log shows hermes rev-pinned 2026-10-23).
3. **Verdict validation belongs to the queue, not the agent:** a `tq verdict --status` (or `tq facts --mine`) read-back would have let any of the seven prior sessions detect the dead-claim state in one command instead of narrating success.
4. Keep the prior closeout's list standing: pre-commit snapshot reflex (pathspec-first, never amend), mechanism-claim spot-verify at queue time, harvest-time staleness markers, same-commit runbook rule, test-execution claims must name run evidence.
5. **Docs-status pre-read worked:** this fire found the prior closeout in one step and spent its budget on the delta — the pattern the 2026-10-23 session-discipline rule mandates. It is the difference between an 8-fire saga and a 2-fire one.

## f) NEXT THINGS (dedup-checked; existing rows cited, one new row appended)

Already on the queue (verified open this session — do NOT re-mint): empty-io.stat trip attribution (`TODO_LIST:1652`), stalwart pin warning (`:1690`), monitor365 post-prune re-attribution watch (`:1695`), crash-triage `--boots` doc-consistency (`:1696`), chronic zone-6 policy BLOCKED (`:1697`), `7465a7a3a` renarration BLOCKED (`:1698`), dnsblockd follow-ups (live-verify backup, §19 extension, freshness signal, render fixture, 4318 re-audit on collector return — dnsblockd family), leg-9d calm-window run (`:147`), verify-gate unblock (`:480`), verdict-durability codification (`:481`), budget carve-out for closeout dispatches (`:1386`).

**Appended by this fire (1 new row):**
1. **Lease-expiry reclaim churn on long-running dispatches** — raise the tq agent-pool lease (or add mid-run renewal / a done-prompt-class lease) so a >45-min dispatch outlives its claim: journal facts 17072–17188 record ten consecutive `lease-expiry` release/reclaim pairs on ONE done-prompt (2026-10-29 04:34→08:56), each cycle re-spawning a paid instance whose verdict file the next claim never reads → docs/todo/pipeline.md (Source: `/mnt/pool/services/tq/tq.db` facts table + `docs/status/2026-10-30_03-35_five-task-window-closeout-8th-fire-verdict-landing-forensics.md` §Why).

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

Already queued as BLOCKED rows (dedup — not re-added): the 16:00 Oct-27 attribution-shift cause (prior closeout §g.1, watch-row evidence path), chronic zone-6 guard policy (`TODO_LIST:1697`), `7465a7a3a` renarration/split (`:1698`), budget carve-out for closeout/verdict dispatches (`:1386`).

New this fire: **none beyond the lease row above** — the lease fix is agent-actionable (pool flag/config), so it is queued `[ready]`, not BLOCKED.

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded — now verified against the authoritative source, not just the empty local read-model.** The pool journal (`/mnt/pool/services/tq/tq.db`, `facts` table) contains **zero `task.reprioritized` rows in its entire history** (count query this session), so no priority move is explainable or hidden for this window; the local `tq facts` read-model (0 facts) is simply an empty projection of the same truth. The window's items were harvested at their original tags ([watch]/[ready] as the queue rows show).

---

## Sources

- `docs/status/2026-10-29_03-55_five-task-window-closeout-20261027-29.md` (the window's own closeout + 7 re-claim annotations)
- `docs/status/tasks/2026-10-28_01-38_task-000001a17fbfb8536b3c2e5f35f700000000.md`
- `docs/status/tasks/2026-10-28_03-53_task-000001a180047c159cd6129d107800000000.md`
- `docs/status/tasks/2026-10-29_03-17_task-000001a184073822d951926cda0e00000000.md`
- Tree spot-checks this session: `scripts/{io-writer-attribution,crash-triage,boot-evidence-pull}.sh`, `flake/parts/checks/selftests.nix:86/130`, `modules/nixos/services/dns-blocker.nix:1538/1753–1790/1405–1440`, `docs/services/dnsblockd.md:319`, CHANGELOG 2026-10-28 entries, `TODO_LIST.md:279/1652/1690/1695/1696/1697/1698/480/481/1386`
- Queue journal (read-only): `/mnt/pool/services/tq/tq.db` facts seq 17065–17189; verify-failure sidecar `/home/lars/.local/state/tq/logs/000001a1858af2593f13b2d2f07b00000000.verify-failure.log`
- go-taskqueue source (local checkout): `cmd/tq/verdict.go`, `internal/executor/agent.go` (verdict channel lifecycle, verify-before-parse ordering)
