# Freeze #45 Crash Triage + tq-Pool Storm Brake — Live Incident Session Status

**Instance:** Crush (glm-5.3), SystemNix repo, single-session incident response
**Window:** 2026-11-03 ~21:45 → 23:23 CET (report time)
**HEAD at start:** `bc2869e40` (daemon had advanced past conversation-start snapshot `c80843016`) · **HEAD at report time:** `fd900d10d` (own commits: `9ef607479`; decision-row update rode daemon batch `4b0954a9a`)
**Working tree:** shared (multiple parallel sessions live: superb-v3 sprints, deploy-wave, storage batch — one git index.lock collision at 22:40, resolved by waiting)
**Trigger (verbatim input):** `We cashed again way?` — interpreted as "We crashed again? Why?" — the box had hard-reset at 21:42:58, ~3 min before the question.

**Scope line — what this report VERIFIED vs did NOT:**
Verified live this session (probe cited at each claim): the crash boundary + reset reason (kernel log, next boot), the full guard/thermal census (`scripts/crash-triage.sh --boots 4`), the death-window IO attribution **on the recovery boot** (codified S-0035 probe set: 6 s per-pid join + cgroup io.stat ranking), the pool brake outcome (busctl + pgrep + sudo journal), and post-brake re-attribution ×2. NOT verified: the dead boot's OWN per-cgroup io attribution (io.stat died with the boot — the driver naming for boot `49e157e0` is a class-match from the identical no-match trip signature + heartbeats + the recovery boot's live measurement, stated as such in the ledger row); the llama-embeddings backlog mechanism (163 GB observed, cause hypothesized, not traced); nothing outside the incident was probed (per session instruction).

---

## TL;DR

The box crashed at 21:42:58 — **freeze #45**, the 7th consecutive watchdog reset in the Nov 2–3 worst-ever cluster. Family C (Branch C: IO-PSI livelock + Tctl ceiling): 78 guard trips all "NO eligible headless tree matched", 192 DEEP THROTTLE ENTERs (k10temp 98 °C, 72 in the final hour), 0 OOM, no panic/pstore/vmcore (the livelock discriminators), kill mechanism `hardware watchdog timer expired` (SP5100-tco, ≥30 s hang). Evidence pulled before journal vacuum (0.3 G headroom), ledger registered, and the storm driver attributed LIVE on the recovery boot: **a tq-agent-pool harvest agent respawning unindexed `sqlite3 … LIKE '%go-build-crush%'` full-table scans against `ChastityAPI/.crush/crush.db` on the QLC at 409 MB/s (28.3 GiB cgroup read in ~25 min)**. The owner braked it (`sudo systemctl stop tq-agent-pool.service` 22:22:30 — scanner dead in 20 s). The storm did NOT fully break: attribution layer 2 = llama-embeddings backlog (156 MB/s, 163 GB re-embedding), layer 3 = aggregate owner load (interactive crush session 75 MB/s, flm, quickshell, nsfw-classifier, builds). At report time: PSI avg10 90 % (down from 96), k10temp **84.5 °C (down from 99)**, 37 trips — thermal recovering, freeze-#46 watch continues.

---

## a) FULLY DONE

1. **Crash detection & boundary classification** — journal of boot `49e157e0` ends abruptly 21:42:58.977 mid-cv-relink-storm; the 3 "Reached target Shutdown" grep hits were USER-session instances (systemd[6179] etc.), not systemd[1] ceremony; no shutdown sequence exists. ClickHouse remote tail (evidence pull) is 2 s FRESHER (21:43:00.057) — the box lived ~2 s past the journal cut, then hung ≥30 s.
2. **Reset mechanism named** — next-boot kernel log: `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` (watchdogd 30 s, SP5100-tco). Cut→boot gap 96 s, inside the documented 92–131 s WDT envelope.
3. **Family discrimination per the canonical fork** — `scripts/crash-triage.sh --boots 4`: trips=78 (#6196 17:44:59 → #6274 21:41:31, storm ran the ENTIRE 4 h boot), throttle_ENTER=192, oom=0, proposal **C combined**. All three of today's earlier boots (#43 `deed9c84`, #44 `6e75c5e7`) re-confirmed WDT/family-C by the same tool.
4. **Evidence pull BEFORE vacuum** — `scripts/boot-evidence-pull.sh -b -1` → `docs/status/tasks/2026-11-03_21-05_boot-49e157e0-evidence-pull.md` (733 lines: boundary, census incl. guard heartbeat `avg60=79.55%, disk busy 100.0%, MemAvailable=33.0%` at 21:36:48, OOM-join empty, ClickHouse death-window 20 rows). Journal was at 7.7G/8G — 0.3 G from eating the boot.
5. **Ledger registration** — freeze #45 row in `docs/agents/stability.md` census (with the entry-gate-gap mechanism + honest live-attribution caveat), cluster table updated (Nov 2–3: **7 in 34 h, 4.9/day, #39–#45 worst cluster on record, six-consecutive recovery-boot WDT resets**), cadence 37 cuts/34 days.
6. **Live storm attribution (S-0035 codified probe set)** — 6 s per-pid `/proc/*/io` join: `sqlite3` **409.1 MB/s** (next: 39 MB/s); argv `SELECT count(*) FROM messages WHERE parts LIKE '%go-build-crush%'` on `/home/lars/projects/ChastityAPI/.crush/crush.db` (QLC); cgroup `system.slice/tq-agent-pool.service`; parent `crush run` harvest agent (redacted via `scripts/redact-argv.sh` per the argv-secrets rule). Cgroup ranking corroborates: pool 28.3 GiB R in ~25 min boot time.
7. **Pending TODO closed on BOTH surfaces** — the 21:21 session's `[ready]` storm-triage row ticked in `TODO_LIST.md:1840` + `docs/todo/stability.md` with the full answer (no drift).
8. **Owner decision row queued** — `[decision]` "tq-agent-pool IO-storm brake + foreign-project crush.db scan guard" with 4 options (stop now / mid-flight PSI brake / forbid foreign-DB scans / hot-tier project DBs); deliberately NOT `[ready]` while the storm is live (summoning pool agents is the amplifier).
9. **Committed** — `9ef607479` (evidence + ledger + rows; pathspec commit, hooks green) after the house hook rejected my first 84-char subject (see §d.1).
10. **Pre-vacuum gate re-run: PASS** — boot `49e157e0` now guarded by the committed evidence file; all 6 retained boots guarded.
11. **Brake verified effective** — owner executed `sudo systemctl stop tq-agent-pool.service` 22:22:30 (sudo journal `_COMM=sudo`, live attribution); sqlite3 count → 0 within 20 s; pool agent 694744 drained after finishing its storage batch (task report `2026-11-03_23-05_task-000001a1a329…md` on disk); timer inactive — no re-arm path while stopped.
12. **Post-brake re-attribution ×2 (layered-storm honesty)** — driver 2: `llama-server` under `llama-embeddings.service` 156 MB/s (163 GB cumulative — NOT in the top-12 at 22:06, i.e. backlog churn that started ~22:1x; a task-cancel burst hit its queue 23:17:43); driver 3 (current): interactive `crush` session 75 MB/s (session-56.scope) + flm-real + quickshell 47 MB/s + nsfw-classifier + build workers = aggregate owner load. Conclusion: **no agent-actionable rogue component remains** — measured, attributed, reported per the 2026-10-07 doctrine (zero SIGSTOPs, zero kills, zero unauthorized actions this session).

## b) PARTIALLY DONE

1. **The storm is not fully broken** — PSI avg10 90 % at report time (96 → 73 → 84 → 95 → 90 across the session; the falls and rebounds are the layered-driver cycling). Thermal DID break: 99 °C → 84.5 °C. Remaining levers are owner-side (pause parallel sessions/builds, quiescent reboot per freeze-#6 doctrine) — listed, not executed (doctrine: agents don't).
2. **llama-embeddings backlog mechanism sketched, not traced** — 163 GB re-embedding is consistent with the crash-recovery amplifier class (7 crashes today × full re-embed), but who enqueued it, and who cancelled tasks 243–250 at 23:17:43, was not established. No row exists yet for this amplifier in the ledger's amplifier list.
3. **Dead-boot attribution is a class-match, not a measurement** — the ledger row says so explicitly; a per-trip `top io` line would have settled it but the no-match trip shape omits it.
4. **Freeze-#46 watch handed off, not instrumented by me** — gatus/sev1-bridge own alerting; I left no session-side watcher. If the box dies tonight, the evidence-pull discipline picks it up next session.

## c) NOT STARTED (out of scope / owner-gated this session)

1. **Structural pool fixes** — mid-flight PSI brake inside the pool, forbid foreign-project crush.db scans, hot-tier project `.crush` DBs (the `[decision]` row owns them).
2. **Quiescent-reboot procedure** (stop embeddings backlog + monitor365 re-scan + recovery readers at next boot, let it settle) — owner action.
3. **Cooling floor** (BIOS fans/PPT) — the long-standing owner leg; the thermal ceiling was a co-killer tonight and 100 % of cuts since #33 are family C.
4. **Parallel sessions' work** (quotaboard deploy gating, cv upstream fix, storage wave 2) — owned by their sessions, untouched by me.

## d) TOTALLY FUCKED UP

**Nothing destructive. Honest near-misses, all caught by hooks or my own probes:**

1. **Commit subject 84 chars → house hook rejection** — the 72-char limit is documented; I burned a commit cycle on it. Zero damage (nothing landed).
2. **Premature "completed" claim in the decision row** — at 22:36 I wrote "stop job completed / drained gracefully" while `ListJobs` output IN THE SAME SESSION already showed the stop job pending and agent 694744 alive. Caught by my next probe and corrected BEFORE commit — but the assertion was written from hope, not from the live job state I literally held in hand (the exact "assert WHICH entity/state" class).
3. **Last attribution one-liner dropped the comm() join** — printed bare PIDs; needed a re-probe to name them. The quote-scrutiny standing rule applies to analysis one-liners and I shipped a lossy one.
4. **No content-pin at session START** — first ~10 probes ran before any `git rev-parse`; the pin happened only at first-write time (22:0x). No damage (tree was clean of my targets), but the discipline says pin before WORK, not before writes.
5. **Plan-executing-marker pre-read skipped** — I did the status-report pre-read (found the parallel sessions' reports) but never grepped `docs/planning/` for EXECUTING markers; the superb-v3 executor was live the whole window (proven by the 22:40 index.lock collision). Interference avoided by luck of disjoint files, not by check.
6. **`uptime -s` fumble** — not supported here; harmless, one wasted flag.

## e) WHAT WE SHOULD IMPROVE

1. **Ask the instant attribution lands** — the doctrine bars agent action, not agent asking. The brake happened ~15 min after attribution because the recommendation lived in prose the owner had to read. The structured question tool at 22:05 would have compressed the storm by 15 min.
2. **Lead with the contradiction** — my final wrap said "scanner confirmed dead, pool fully down" while PSI was climbing back to 84. The 2026-09-18 rule applies to close-outs too: the RISING PSI was the verdict, the dead scanner was a sub-fact.
3. **Multi-pass attribution must be doctrine** — a layered storm (scanner → embeddings → aggregate) is under-reported by one pass; re-run the probe set after ANY brake before claiming the storm broken. I did iterate, but only because PSI refused to cooperate — make it a rule, not luck.
4. **The pool cost two freezes (#25: 864 GB, #45: this) — the harness, not the agent, is the repeat offender** — the structural fix belongs in go-taskqueue (forbid/redirect sqlite full-scans of project `.crush` DBs), not only in SystemNix-side gates. The pool's PSI ENTRY gate has the freeze-#5 entry-only-trap shape: it cannot stop a mid-flight agent.
5. **llama-embeddings backlog belongs in the amplifier list** — the ledger names scrub loops, db-heal, migrate readers as crash-recovery amplifiers; a 163 GB re-embed after every crash is the same class and is absent.
6. **crash-triage/boot-evidence-pull should emit the next-boot reset-reason line inline** — I fetched it separately; the pull already parameterizes boot ids and the line is THE kill-mechanism evidence.
7. **The no-match trip shape loses its own evidence** — when attribution matches nothing, the trip line should still carry the top-3 cgroup io deltas (the match-window snapshot exists; only the no-match shape omits it). Freeze #45's dead-boot driver would have been MEASURED, not class-matched.

## f) WHAT WE SHOULD GET DONE NEXT (session-derived; harvest tags inline)

**NEW — self-harvested at authoring time into TODO_LIST.md + domain files (4 rows):**

1. `[ready]` **Codify multi-pass attribution into the IO-PSI probe-set section** — after ANY brake, re-run the probe set ≥2× before declaring a storm broken; layered-driver cycling measured live 2026-11-03 (409 MB/s scanner → 156 MB/s embeddings → aggregate 95 %). → TODO_LIST.md + docs/todo/stability.md (Source: this report §e.3)
2. `[ready]` **Add llama-embeddings backlog re-embedding to the crash-recovery amplifier list + ledger family notes** — 163 GB boot-cumulative re-embed observed live 2026-11-03; same class as scrub-loop/db-heal/migrate amplifiers, currently absent. → TODO_LIST.md + docs/todo/stability.md (Source: this report §e.5)
3. `[ready]` **crash-triage.sh + boot-evidence-pull.sh: emit the next-boot reset-reason line inline** — the kill-mechanism evidence currently requires a separate journal probe; both scripts already parameterize boot ids. → TODO_LIST.md + docs/todo/pipeline.md (Source: this report §e.6)
4. `[blocked:push]` **go-taskqueue upstream: forbid/redirect pool-agent sqlite full-scans of project `.crush` DBs** — two freezes from this class (#25 864 GB, #45); verify-before-filing gated (probe the harness's agent-contract surface first). → TODO_LIST.md + docs/todo/upstream.md (Source: this report §e.4)

**ALREADY QUEUED (this session or prior) — do NOT re-harvest:**

5. tq-pool brake structural options (a)–(d) — `docs/todo/stability.md` `[decision]` row + owner-executed-(a) update (this session)
6. Owner: pause parallel sessions/builds, cool, quiescent reboot per freeze-#6 doctrine — live incident, owner channel (§b.1)
7. Cooling-floor leg (BIOS fans/PPT) — long-standing owner decision, 100 % family-C co-killer (§c.3)
8. Freeze-#46 watch: evidence-pull + register if the box cuts again tonight — next session's crash-triage step 0 (§b.4)
9. cv-server upstream fix + 16a656f4 pin lift + post-fix chain — docs/todo/upstream.md:245 (parallel sessions own it; NOT this session's work)
10. The 21-24 report's §26 cv crash-loop detection — its author's self-harvest obligation, still verified-absent (flagged 21:35 report, flagged again here: two reports have now inherited it)

**DELIBERATELY NOT HARVESTED (with reasons):**

11. "Ask-the-instant-attribution-lands" (§e.1) — an agent-behavior lesson, not a queueable repo task; belongs in session conduct (this report is the record).
12. "Lead with the contradiction" close-out rule (§e.2) — same class; AGENTS.md already carries the 2026-09-18 rule, this is an application miss, not a missing rule.
13. ChastityAPI crush.db prevalence probe (how many pool tasks scan foreign DBs) — [ready]-worthy but the box is mid-storm; every new [ready] row is future pool fuel until the structural fix lands. Queue it after stabilization.
14. The no-match-trip-shape evidence loss (§e.7) — folds INTO the guard's zone-6 action-split design row already in docs/todo/stability.md (extend that row, don't duplicate it).

## g) QUESTIONS FOR THE OWNER (cannot be determined from the box)

1. **Quiescent reboot now or ride it out?** Thermal recovered (84.5 °C) but PSI avg10 is still ~90 % on aggregate owner load. The ledger says no recovery boot since Nov 2 survived; a quiescent reboot (recovery readers stopped at boot) is the doctrine answer — but only you can take the downtime and pause the Mac-side sessions/builds. Which way?
2. **Does the tq pool stay down until the structural fix lands, or do you want it restarted once PSI normalizes?** Its exit state is "failed" (post-stop), timer inactive — it will NOT auto-return; restarting re-arms the foreign-DB scan risk until go-taskqueue forbids it.
3. **Is the llama-embeddings full re-embed after crashes intended behavior (corpus rebuild by design) or a bug to queue upstream?** 163 GB per recovery boot is either the RAG design or its degenerate case — the design intent isn't visible from SystemNix.

---

**Live state at report time (23:23):** PSI io some avg10=90.4/avg60=94.8 · k10temp 84.5 °C (recovering) · guard trips this boot: 37 · pool: stopped/failed, timer inactive, no re-arm · OWN commits: `9ef607479` (+ daemon-batched row update, content verified).
