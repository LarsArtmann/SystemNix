# Monitor365 IO-Storm Review, Quiesce Verification, and SystemNix Fix — Session Status (Part 4)

**Reported:** 2026-10-27 00:10 CET · **Instance:** same session lineage as Parts 1–2 (third dispatch tonight: "FUCKING REVIEW WHAT TAKE SO MUCH FUCKING I/O")
**Scope:** THIS interval only — 23:30 → 00:10, the root-cause review, quiesce verification, and the SystemNix-side fix. Parts 1–2 (lock-float repair → gen-953; scan-storm attribution) + the parallel session's 23:24 monitor365-repo report stand as prior art.
**HEAD at write time:** daemon-churning (content-verified in HEAD's tree — see §d.1); **Deployed:** gen-954 (22:55; the "reboot" was that deploy, not a crash)

## The answer, up front

The ~430 GB evening IO storms are **fully explained and paused — by quiesce, not yet by fix**. Five interlocking causes (agent `batch_size=100` → 500 POSTs/cycle; per-upload `MAX(sequence)` full-table scan; a 380M-event backlog that never acks; gen_* migrations that could never apply; watchdog restart churn × the `cleanup_cycle=0` startup full MV refresh). The whole stack was deliberately quiesced at **23:10:48 (watchdog timer stopped) → 23:11:04 (server killed)** — owner/parallel-session action, NOT this instance — and live verification shows **0.0 MB system IO** and both units down. The real fix exists upstream but is **unpushed**; SystemNix needs a lock bump + deploy before anything un-quiesces.

## Timeline (compact)

| Time | Event |
| --- | --- |
| 23:3x | Pre-read: Part 2 report + service runbook + module. Journal: server PID churns 6× in 90 min, every kill `status=9/KILL`. |
| 23:4x | Watchdog journal: `health check failed (HTTP 000000) — restarting server` = the kill-loop driver. SEV1 bridge flagged `UNIT CRASH LOOP` 23:09. |
| 23:4x | Source-read at the **deployed** rev `77b4a3ae` (caught local-HEAD ≠ lock-rev before reading wrong code): `cleanup_cycle` seeds at 0 → full MV refresh (full-table COUNT) at EVERY start; `batch_size` option = default 100; `gen_app` = generated column absent from live DB. |
| 23:5x | Found the parallel session's 23:24 report IN the monitor365 repo (untracked) — their session had root-caused deeper (MAX(sequence), 380M backlog) and implemented fixes. Did NOT touch their repo. |
| 23:59 | Quiesce actor+order pinned: watchdog timer "Deactivated" 23:10:48, server killed 23:11:04 — deliberate safe-order stop, not this session. |
| 00:0x | Quiesce live-verified: 20s cgroup delta = **0.0 MB across all units** (instrument sanity-checked first); server `failed`, agent `inactive`. SystemNix fix landed: `batch_size = mkDefault 5000` (eval-verified). |
| 00:1x | Docs + harvest rows + report. Git raced the daemon twice (§d.1). |

---

## a) FULLY DONE

1. **Restart-cycling proven from journal forensics** — 6 server PIDs in 90 min, all `status=9/KILL`; the watchdog's `HTTP 000000 → restarting server` line identifies the killer; loop cadence ~10–15 min at storm peak.
2. **The startup full MV refresh found in source** — `background.rs:162-165` (`cleanup_cycle % 24 == 0`, seeds at 0) × `materialized_views.rs:200` (`COUNT(*) … FROM events GROUP BY tenant_id`) = the "daily" full-table scan firing at every process start; the watchdog churn re-armed it every restart. This is THIS session's independent addition to the parallel session's analysis (their report defers MV profiling to post-storm, their §8.32).
3. **`batch_size` located and fixed SystemNix-side** — upstream default 100 (`nix/lib/settings.nix` `ints.between 1 10000` + the init/pair TOML template); `batch_size = lib.mkDefault 5000` landed in `monitor365.nix`, `nix eval` verified (`5000`), `nix fmt` clean. Inert until the agent starts — correct posture.
4. **Quiesce actor, order, and state established** — timer stopped 23:10:48, server killed 23:11:04 (safe-stop order = watchdog first), server now `failed`, agent `inactive`; SEV1 `UNIT CRASH LOOP` context at 23:09. Not my action; flagged per concurrent-session discipline.
5. **Quiesce effect live-verified twice** — 30s and 20s cgroup-delta samples: zero units above threshold, top-5 unconditional = 0.0 MB; PSI decayed from avg300 43% to background. Monitor365 quiesce still holding at 00:1x (re-checked during the load-110 spike: server `failed`, agent `inactive`).
6. **The parallel session's work discovered BEFORE duplicating it** — their 23:24 report (untracked, in-repo) root-caused MAX(sequence) + the 380M backlog + the never-applied migrations and implemented five fixes (sequence watermark, gen_* removal, dmesg latch, xdotool gate, cache TTL). Their §8.16–19 explicitly assign the deployment side — this session stayed in its lane.
7. **Docs state fully rewritten for the next responder** — runbook section (quiesce state, do-not-restart warning, ship path, verification-attribution), scan-storm todo row → `[blocked:push]` ship-path row (services.md + TODO_LIST twins), new upstream row for the `cleanup_cycle` fix, status report Part 3.
8. **Self-harvest executed at authoring time** — `scripts/io-attrib.sh` queued (monitoring.md + TODO_LIST verbatim-title twin) after the sampler was hand-rolled for the FOURTH consecutive session tonight; gate-clean on the third attempt (§d.4).
9. **A verification overstatement in my own docs caught and fixed before waiting** — the runbook originally claimed the whole 5-cause chain was "all verified live"; items 1, 3 and the migration-runner limitation are ADOPTED from the parallel session's probes. Corrected inline (assert WHICH evidence answers WHICH claim).
10. **The 17-file foreign edit burst identified and left alone** — a fourth session's live `ordering-cycle-audit.nix` work (their queue rows pre-announced it); zero interference.

## b) PARTIALLY DONE

1. **The storm fix end-to-end** — root cause: DONE. SystemNix config: DONE. Actual storm-ending deploy: **`[blocked:push]`** on the parallel session's verification gates + commit + push (origin/master == deployed `77b4a3ae`; local ahead 6, five fixes mid-verification). Then: lock bump → deploy → verify → un-quiesce decision.
2. **gen_app / §g-Q2 from Part 2 — ANSWERED** (upstream schema history: migrations 020–024 could never apply on DuckDB; NOT user dashboard content) — but the fix itself rides their unpushed branch; the live Binder Error spam stops only at deploy.
3. **The `cleanup_cycle` startup-refresh fix** — root-caused + queued upstream (`docs/todo/upstream.md` + TODO_LIST twin); the 1-line patch is NOT implemented (their repo is mid-flight; touching it risks collision — deliberately not done).
4. **Runbook now owns the operational state** (§a.7) — but the `/health` 308 repoint row stays open and UNPROBABLE while the server is down (no live Location to probe).
5. **Load-110 spike at 00:1x attributed only coarsely** — CPU-side, concurrent session's battery; monitor365 exonerated live (units down, zero IO). Not chased further: out of scope.

## c) NOT STARTED

1. **Lock bump + deploy of the fixed monitor365** — hard-blocked on their push (see §b.1); the deploy itself (§11 FOD battery, post-deploy smoke) not started.
2. **380M-event backlog strategy** — drain-via-upload vs reconcile vs discard: owner decision (their report's Questions); zero progress by design.
3. **DuckDB relocation off the QLC root** — hot-tier subvol pattern; unchanged, owner's storage-doctrine call.
4. **Watchdog retire-vs-rework** ("page, don't restart" — their §7.4) — not started; decision needed BEFORE or AT the deploy (keeping it as-is through the first post-deploy window is also defensible).
5. **`max_events_per_day` cap restore + schema-migrate hack removal** — cap value unverified live (admin-gated); removing the hack without setting the cap reverts tenants to the 10k/day upstream default → the unbounded-buffer trap. Sequenced behind the owner's cap decision.
6. **Carried untouched:** fastflowlm "started ≠ serving" (three report cycles now), pre/post-deploy failed-unit reconciliation (7→3), float-register proof-marker, upstream FOD download-scope fix, tmp subvol, pocket-id-provision/buildcache-gc triage, Part 1's 50-item menu remainder.

## d) TOTALLY FUCKED UP

1. **Daemon-race git interleaving hit me TWICE despite the discipline** — (1) my `--amend` of the daemon's batch_size commit silently became an amend of the daemon's NEXT sweep (my 5 docs files) — wrong message on correct content, caught via reflog, rewritten with `reset --soft` + pathspec commits; (2) the runbook-fix amend landed on ANOTHER daemon commit, producing a "Queue io-attrib" message over a 3-file commit containing the foreign session's audit-module hunk. Root cause: staged operations + background shells + a ~10-min daemon with 7 live sessions = the content-pin is stale by execution time. Content was NEVER lost (verified against HEAD's tree) but three commits wear heuristic or mismatched messages. This class needs a mechanical antidote (§e.2).
2. **Two 72-char title rejections in a row** — batch commit (78) and docs commit (74). The gate is documented; I didn't count. Each cost a full background round.
3. **Heredoc-in-&&-chain parse failure** — mvdan/sh choked on the two-heredoc chain; wasted a round; fixed for good with `-F` message files (the pattern that stuck).
4. **TODO-gate took three attempts** — (1) cited the not-yet-existing 00-10 report as Source (gate checks references), (2) queue title paraphrased the library title (identity check — the backticked `scripts/io-attrib.sh` broke the match), (3) verbatim title passed. The title-identity rule exists in AGENTS.md; I paraphrased anyway.
5. **systemd unit probing fumbled across three variants** — a sed-based escaper produced `monitor365_server_service` garbage; `NRestarts`/`Result` queried on the wrong interface (.Unit vs .Service); only the documented LoadUnit+grep pattern worked. The pattern was already in AGENTS.md — I re-derived it badly under load.
6. **First sampler run returned empty and I nearly read it as "all quiet"** — the 50 MB threshold silently filtered everything; the top-5-unconditional sanity run (also the instrument's own verification) came AFTER. Right answer, wrong order — the quote-scrutiny rule demands the known-value check FIRST.
7. **`redact-argv.sh` invocation botched once** — process-substitution form produced empty output (the tool that exists to prevent secret leaks was the thing that failed silently). Works when called plainly; the fancy form was unjustified.
8. **Runbook overstatement shipped for ~40 minutes** (§a.9) — caught during report writing, not at write time. The fix landed, but the default should be to label adopted evidence at composition.

## e) WHAT WE SHOULD IMPROVE

1. **Productize `scripts/io-attrib.sh` — QUEUED this time** (monitoring.md + TODO_LIST, gate-clean). Four sessions, four hand-rolls, two near-miss readings. This is the docs-feedback-loop threshold crossed twice over.
2. **A commit-hygiene rule for daemon-heavy windows** — never amend after a prior command in the same chain; content-pin IMMEDIATELY before `git commit` (not before the whole step); prefer fresh pathspec commits over amends when the daemon is live; accept heuristic messages on swept content instead of rewrites. Tonight's two races both came from amending "what the daemon just did" and being wrong about what that was.
3. **Adopted-vs-verified labeling as a composition default** — every multi-source claim in durable docs should name which session/probe verified it (tonight's chain: 2 items first-hand, 3 adopted). The assert-WHICH-surface rule, applied to evidence provenance.
4. **The status-report pre-read rule WORKED — keep advertising it** — the 10-second `git status` glance at the monitor365 repo surfaced the parallel session's 23:24 report before I wrote a single line of overlapping analysis or touched their tree. Cost of the check: one command. Cost of skipping it: a collision with a live session mid-verification.
5. **LoadUnit-first deserves its promotion into the standard probe set** (it's already in a carried AGENTS.md row) — tonight it was the ONLY correct variant of four attempts; the escaped-path forms failed in both directions.
6. **Heredoc message files (`git commit -F`) as the default for multi-line messages** — one parse failure settled it; message files also survive background-shell moves.

## f) NEXT THINGS (delta list + carried; up to 50)

(Harvest status: the io-attrib row was harvested at authoring time. Everything else here is deliberately a menu — the `[blocked:push]` ship-path row and the `cleanup_cycle` upstream row were already queued earlier tonight; bulk-queueing a 40-row brainstorm violates HARVEST routing. Say the word and I harvest any subset.)

| # | Task | Impact | Effort | Provenance |
| --- | --- | --- | --- | --- |
| 1 | Upstream session: finish monitor365 verification gates → commit → push (their §8.1–15) | High | M | Their repo, in flight |
| 2 | SystemNix: flake lock bump to the pushed monitor365 rev → `nix run .#deploy` → §11 battery | High | M | `[blocked:push]` row, queued |
| 3 | Post-deploy: verify pool errors stay 0, journal clean, `/health` route resolved (probe the 308 Location), agent-watchdog SERVER_HEALTH repoint | High | S | Queued (merged /health row) |
| 4 | Un-quiesce decision (owner): restart server; agent start timing vs 380M backlog (§g Q1) | High | S | Owner |
| 5 | `cleanup_cycle=1` (or persisted-stamp) upstream fix for the startup full MV refresh | High | S | Queued upstream row |
| 6 | Backlog drain execution per §g Q1 decision + zero-progress alerting while draining | High | M | Their §8.20–24 |
| 7 | `max_events_per_day` cap set (250k/day recommended) + replace the schema-migrate hack | High | S | Queued (cap decision §g Q2) |
| 8 | Watchdog retire-vs-rework decision (page-not-restart) — §g Q3 | Medium | S | Their §7.4 |
| 9 | Write `scripts/io-attrib.sh` | High | S | **Harvested** 084d340c0-lineage |
| 10 | DuckDB relocation off the QLC root (hot-tier pattern + PSI-gated migrate) | Medium | M–L | Open owner call |
| 11 | Migration-runner DEBUG→WARN on failed migrations + startup schema canary | Medium | S | Their §8.26–27 |
| 12 | MV-refresh cost profiling post-storm (incremental window queries vs scrambled zone maps) | Medium | M | Their §8.32 |
| 13 | Amend-or-annotate the three daemon-raced commits' messages at the next rebase window (cosmetic) | Low | S | §d.1 |
| 14 | Commit-hygiene rule (§e.2) into CONTRIBUTING daemon-race section | Medium | S | §e.2 |
| 15 | fastflowlm "started ≠ serving" verification (carried 3×) | Medium | S | Carried |
| 16 | Pre/post-deploy failed-unit reconciliation 7→3 (github-auto-assign, opencloud, inboxclean-sync) | Low | S | Carried |
| 17 | geometrikks + crowdsec-prereq gen-954 ordering-cycle victims (fourth session may own it — check their report first) | Medium | M | Carried |
| 18 | Ordering-cycle eval audit + negative-test leg (fourth session appears ON IT — coordinate, don't duplicate) | High | M | Carried |
| 19 | post-deploy-check ordering-cycle grep + runner smoke (fourth session's scripts are dirty in-tree right now) | Medium | S | Carried |
| 20 | float-register silent-green-proof fix + proof-marker | High | S/M | Carried |
| 21 | Upstream FOD download-scope fix → lift go-taskqueue/branching-flow pin-backs | High | M | Carried |
| 22 | Upstream vendor-hash paste batch (15+ tools) to end the shim treadmill | Medium | M | Carried |
| 23 | `/mnt/hot/users/lars/tmp` subvol provisioning | Medium | M | Carried |
| 24 | pocket-id-provision exit-1 diagnosis | Medium | S | Carried |
| 25 | buildcache-gc.service failure diagnosis | Medium | S | Carried |
| 26 | Root-fs watch: 50 G free and falling | Medium | S | Carried |
| 27 | CHANGELOG entry for gen-953/954 (19-hash repair + ordering fixes + tonight) | Medium | S | Carried |
| 28 | Verify the gen-954 deploying session's status report landed (23-10 file was untracked at 23:10) | Low | S | New tonight |
| 29 | agent config validation upstream: warn/clamp batch_size < 1000 | Low | S | Their §8.39 |
| 30 | process-collector event volume sanity (212 events/min; top backlog contributor) | Medium | S | Their §8.37 |
| 31 | afk_status on a headless server — should it run? | Low | S | Their §8.38 |
| 32 | `GET /api/v1/devices/evo-x2/config` 404 noise per cycle | Low | S | Their §8.36 |
| 33 | latency collector 12s median investigation | Low | S | Their §8.34 |
| 34 | fs_event `watch_paths = []` semantics | Low | S | Their §8.35 |
| 35 | 17:44 stale-eval anomaly root-cause (drv paths identical post-edit) | High | M | Carried |
| 36 | TODO cross-reference convention ("See:" between rows of one incident) | Low | S | Part 2 §e.3 |
| 37 | Batch-analyze shim-ledger drop economics | Medium | S | Carried |
| 38 | Log pressure-override + gate-abort events from deploy.sh | Low | S | Carried |
| 39 | Confirm home-lars-tmp.automount fails fast-loud | Low | S | Carried |
| 40 | service-health-check + ci-watchdog triage (one IS the notifier) | Medium | S | Carried |

(40 rows: 1–14 delta tonight, 15–40 carried per Parts 1–2 + their repo report. The Part 1 50-item table's remaining rows stand.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Un-quiesce sequencing: when the fixed server is deployed, do you want the AGENT restarted too (380M backlog drains through the fixed pipeline), or held for a separate drain/reconcile/discard decision?** The backlog is the storm's fuel; an automatic agent start re-loads it against a server that can now ack — but 380M events through any pipe is hours of writes on the QLC root, and the discard option needs your data-loss sign-off.
2. **What should `max_events_per_day` be set to (250k/day was the standing recommendation), and should the ad-hoc `monitor365-schema-migrate` script then be deleted?** Deleting it without setting the cap silently reverts tenants to the 10k/day upstream default and re-arms the unbounded-buffer trap — I won't sequence that without your number.
3. **Should the 5-min `monitor365-server-watchdog` be reworked (page-a-human instead of SIGKILL-restart) or kept as-is through the first post-deploy window?** It drove tonight's restart churn (33/24h, each restart = WAL replay + a full MV refresh), but it is also the only thing that auto-heals a genuine wedge — I can't weigh your pager tolerance.

---

*Self-harvest record: the io-attrib row (this session's single NEW direct follow-up) was queued at authoring time — `docs/todo/monitoring.md` + TODO_LIST verbatim-title twin, gate-clean commit in tree. The `[blocked:push]` ship-path row and the `cleanup_cycle` upstream row were queued earlier tonight (Part 3 interval). The runbook adopted-vs-verified correction landed before this report (§a.9).*

*Format note: `.md` per the user's explicit path demand (status-report skill is HTML-canonical; override honored, not propagated). Cross-references: Part 1 `2026-10-26_20-40_lock-float-repair-gen953-deploy-status.md`, Part 2 `2026-10-26_21-07_monitor365-scan-storm-attribution-status.md`, Part 3 `2026-10-26_23-43_monitor365-io-storm-root-cause-quiesce-status.md`, parallel session `~/projects/monitor365/docs/status/2026-10-26_23-24_live-io-storm-root-cause-and-fixes.md`.*
