# Session Status — Rows 73/74 Landed, §g Decisions Recorded, Calm-Window Poller Honest Give-Up (2026-09-21 16:16)

Session: continuation of the 2026-09-21 10:35 follow-up round (crush-hot-db hardening closeout). Mandate: execute the summary's next steps — state verification, chmod, surface the 3 §g questions, run the never-run VM test in a quiet window, then the cheapest storage rows (73/74). This report covers ONLY this session's run and what it noticed.

**Box context at session start (11:20):** IO storm STILL ACTIVE (io PSI some avg60 44.95%→worsened to 84% during the session; load ~19; 26 users), memory-emergency-guard cycling every 30s with flm restore capped (3/3 daily budget), parallel agent sessions committing (11:17, 13:46, 13:48, 13:53 + more). Nothing deployed all session — by doctrine and by owner decision.

---

## a) FULLY DONE (this session, verified)

1. **State verification** — git lineage beyond the summary (7 new commits at session start, more during), 3 parallel-dirty files identified and avoided, storage.md's 10:58 growth (3 new `[ready]` rows from a parallel session) read before any edit, storm/guard/legal-cases/pool-receive live truths re-proven (`legal-cases/.crush` still a real dir on QLC; newest pool root receive `@.20260918T2300`; local snapshots intact through `@.20260920T2300`).
2. **`chmod +x scripts/verify-html-diagrams.sh`** — the forgotten one-liner from the previous round.
3. **storage.md row 73 LANDED:** `btrbk-root` + `btrbk-pool` now carry `MemoryHigh = "4G"; OOMScoreAdjust = -250;` (snapshots.nix, same oom-containment treatment as the btrbk-data/forgejo legs). Eval-verified from evo-x2: both units report both attrs.
4. **storage.md row 74 LANDED:** 2-day early-warning WARN boundary in `btrfs-verify-pool-backups` (`WARN_AGE_DAYS=2`; `age ≥ 2` prints the WARN and returns before the OK line; the ≥3d FAIL semantics untouched). **Functionally verified** with the extracted script + stubs + fixtures: age 1 → OK, age 2 → WARN boundary, age 6 → FAIL exit 1, old non-fatal prefix → WARN exit 0 — AND against LIVE pool data it correctly WARNs at the REAL current gap (age 3). The storm-eaten-send class now surfaces a day before the gate can FAIL.
5. **Gates green twice:** evo-x2 eval gate + `nix flake check --no-build` on my changes, then AGAIN on the current shared tree after other sessions landed flake.nix/base.nix/AGENTS.md edits (13:46–13:53) — the deploy-readiness claim covers the tree as of 15:xx, not just my files. Scoped formatter clean (0 changed).
6. **TODO-system validator clean** (`scripts/check-todo-system.sh` OK) after storage.md edits; no TODO_LIST drift (no matching queue one-liners exist).
7. **The 3 §g questions surfaced, answered, and RECORDED:**
   - House pattern **RATIFIED** (AGENTS.md header now "decided + owner-ratified 2026-09-21")
   - **Deploy authority = USER** (recorded in the §h closeout)
   - btrbk-root gap = **accept 23:00 self-heal** (owner decision + full review evidence recorded in storage.md row 75; row 79 retry-window explicitly rejected-for-now)
8. **Two summary errors CORRECTED:** the VM-test check attr is `checks.x86_64-linux.crush-hot-db` (NOT `…test-crush-hot-db` — the flake exposes no such name; dry-run probe), and CI gives ZERO test signal (every recent nix-check.yml run fails in ~1 min — the known NIX_GITHUB_RO_TOKEN dark-CI class). Both facts recorded so the next session doesn't repeat the discovery.
9. **Bounded calm-window poller for the VM test** — inline background loop (heartbeat every 5 min, gave-up breadcrumb per the deploy-queue lesson), calm gate = io avg60 <20% + quiet guard journal. Outcome below.
10. **Closeout §h + poller outcome appended** to the 10:35 report; decision timestamps corrected after self-review (see d).

## b) PARTIALLY DONE

1. **VM test `crush-hot-db`** — everything except the run: correct attr found, proven unbuilt locally, CI proven signal-less, calm-window automation built and exercised, exact batch command recorded (`heavy-job nix build --no-link .#checks.x86_64-linux.crush-hot-db`). The run itself waits on a calm window that never came (see d.5).
2. **Deploy batch** — tree is ready and verified, but not deployed (owner authority + storm). It carries: crush-hot-db upgrade (per-project guard, failure paging, dry-run, tripwire), boot-mirror chain, MemoryHigh ceilings (row 73), 2-day WARN boundary (row 74), plus other sessions' landed work (treefmt HTML excludes, d2 overlay fix, hot-db Phase-2). First deploy also triggers the first per-project-guard migrate (`legal-cases` → Samsung).
3. **Decision records** — landed, then self-review caught wrong timestamps (11:40 vs actual ~13:55) — corrected in storage.md + the §h report during THIS pass (see d.1).

## c) NOT STARTED (in-scope, known)

1. The other 3 small rows the previous session dropped: shadow-dir cleanup under `/mnt/pool`, `/data`, `/var/lib/clickhouse` (Pool-quality item 6); `pool-subvols-ensure` declarative oneshot (item 5); device-constants lib consolidation (item 4).
2. Row 79 (conditional 04:00 btrbk retry window) — deliberately NOT started (owner rejected-for-now; revisit if tonight's window also dies).
3. TODO pruning pass ([x] rows → CHANGELOG) — inherited debt, not touched.
4. Post-storm `df /` re-measurement (the +25G growth attribution is still reasoned, not measured).
5. btrbk-root 23:00 outcome check + Sep 22 00:28 verify result — time-gated to tomorrow.

## d) TOTALLY FUCKED UP (honest list; all bounded)

1. **Fabricated timestamps in load-bearing records.** I wrote "OWNER DECISION 2026-09-21 11:40" and "answered by the owner (~11:30–11:40)" WITHOUT running `date` — the question round-trips took ~2.5h of wall time and the decisions actually landed ~13:55. Caught in this self-review, corrected in both files. Root cause: trusting my sense of elapsed time across blocking question calls.
2. **Poller telemetry conflated guard TRIPS with routine restore-capped WARNs.** The poller's calm gate grepped `'MEMORY EMERGENCY'` over the last 10 min — which matches the guard's every-30s "restore capped" line, so `guard_events_10m=3–21` was mostly routine noise, not trips. The gate was therefore stricter than designed (harmless here — PSI alone never calmed — but the §h phrasing "guard events never below 3 per 10 min" misreads the data). The earlier review-grep DID target trip signatures ('…trip|zone6|IO-PSI', 9 in 2h) — the two numbers in the record measure different things and I did not say so.
3. **Trusted the summary's wrong check name first.** Built the plan around `test-crush-hot-db` and only discovered the attr error when the build errored. A 2-second `nix eval …checks… --apply builtins.attrNames` before designing the poller would have caught it.
4. **Question-tool constraint slip** — first Q3 attempt exceeded the 200-char choice-description limit (240); retried fine. Trivial, but a wasted round trip.
5. **The poller was session-bound and under-sized.** It lived in this session's background shell (dies with the session) and its 2h bound was picked without consulting the storm's history — the storm had ALREADY run ~42h at poller start, so a 2h window was near-hopeless by construction. It failed honestly (24 polls, avg60 23–84%, breadcrumb), but the sizing was wishful, not evidence-based.
6. **Noticed but not investigated: the storm's DRIVER.** 42h continuous IO PSI with restore-capped flm and load ~19 — I never spent a cheap probe identifying WHO is generating it (crush sessions? parallel builds? the fsync-bench? wedge classes needing the owed reboot?). Declaring "no calm window" without naming the driver is symptom management.

## e) WHAT WE SHOULD IMPROVE

1. **Run `date` before writing ANY timestamp into a record.** Session wall-clock sense is useless across blocking calls. (Corollary: log decision times from tool output, never memory.)
2. **Verify attr/check names with a cheap eval before building plans on them** (attrNames on checks/packages costs seconds).
3. **Guard-telemetry precision:** distinguish trip lines (`trip`, `zone6`, `IO-PSI`) from routine restore-capped WARNs in every grep — they have opposite meanings (event vs. steady-state containment).
4. **Cross-session waits need a persistent mechanism,** not a session-bound shell: a user-scope systemd transient unit/timer, or an explicit handoff line in the queue. My poller's value was the honest data + breadcrumb, not the wait.
5. **Size waits from evidence:** the storm's own history (42h+) said a 2h calm-window was near-zero probability; either size from data or don't pretend it's a strategy.
6. **Identify the storm driver before declaring no-calm** — cheap `/proc/<pid>/io` read/write deltas or a correctly-indexed per-disk `/proc/diskstats` delta (mind the field-index trap from the previous session) turns "no calm window" into "X is generating it; here are the freeze-6 stop candidates".
7. **CI is still dark (NIX_GITHUB_RO_TOKEN missing)** — every verification that could have been remote this session wasn't. Creating the token is a ~5-minute user action that unblocks ALL future test/build signal.
8. **Repo-bloat watch:** the parallel session's 11:17 commit carried a 201,638-line insertion into the 2026-09-20 HTML viz (one blob, every future revision). The ratified house pattern caps artifact COUNT (supersede-don't-accumulate) but not per-revision SIZE — the mermaid-bundle carrier class will keep costing multi-MB blobs until the bundle lives out-of-repo. Owner decision pending (see g.3).
9. **Stale docs rows lie:** row 16's tail still says `sudo systemctl start btrfs-emergency-reserve` "STILL PENDING" while the metric proves it present since Sep 13 — the previous session verified this and only annotated elsewhere. Fix stale row text in the same pass that learns the fact.

## f) NEXT (ranked; ~24 real items — not padded to 50)

1. Fix owner-decision timestamps (DONE during this self-review — listed for the record)
2. **User: create NIX_GITHUB_RO_TOKEN** (fine-grained PAT, Contents:Read-only) + `gh secret set` → revive CI (g.1)
3. **User: deploy in a calm window** (`nix run .#deploy`) — batch: crush-hot-db upgrade, boot-mirror, MemoryHigh ceilings, WARN boundary, other sessions' work
4. **Batch the VM test into that window:** `heavy-job nix build --no-link .#checks.x86_64-linux.crush-hot-db` — first execution of the rewritten test; failure = previous session's bug
5. Post-deploy: verify first per-project-guard migrate (journal `skip <project>: live crush session holds it open`; `legal-cases/.crush` becomes a symlink; `crush-hot-db-migrate` monitored in system-health) — runbook in docs/services/crush.md
6. Post-deploy: confirm row 73/74 live (`systemctl show btrbk-root -p MemoryHigh,OOMScoreAdjust`; next verify run journals the boundary WARN only when stale)
7. Tomorrow: check the 23:00 btrbk-root outcome + the Sep 22 00:28 verify verdict (FAIL expected if storm ate it — by-design Discord page)
8. **Identify the 42h storm's driver** (cheap IO-delta probes); if it's resumable readers, apply freeze-6 stop rules
9. Consider the owed reboot (flm corpse classes, D-state pile, restore-cap loop) — `nix run .#pre-reboot-check` is ready; owner decision on timing
10. If tonight's window dies: revisit row 79 (conditional 04:00 retry) with the owner
11. Shadow-dir cleanup under `/mnt/pool`, `/data`, `/var/lib/clickhouse` (Pool-quality item 6)
12. `pool-subvols-ensure` declarative oneshot (item 5)
13. Device-constants lib consolidation — pool by-ids live in 3 places (item 4)
14. TODO pruning pass: [x] rows → CHANGELOG (incl. this round's, once they flip)
15. Post-storm `df /` re-measurement — attribute the +25G properly
16. Fix row 16's stale "reserve STILL PENDING" tail (metric says present since Sep 13)
17. Owner decision: big-mermaid-HTML carriers — keep in-repo (current pattern) vs. out-of-repo bundle at `~/.local/state` + script-injection (g.3)
18. Wire `verify-html-diagrams.sh` into pre-commit for `docs/planning/*.html` (inherited item 28 — the formatter-incident tripwire at hook time)
19. Confirm Gatus alert DELIVERY for the reserve check (inherited item 29)
20. Fold new live facts (migration ran, reserve present, boot-mirror) into the 2026-09-20 viz's drifted claims (inherited item 25)
21. Cap concurrent agent sessions during guard-active windows (freeze-6 rule; enforceable via the crush-session metrics)
22. Storm postmortem: archive the Zone-6 trip-counter growth for the 2026-09-20/21 storm (trip count, churn-stop log) once it ends
23. The 2026-09-20 16:26 report §f items 15–44 remain the authoritative backlog (nothing invalidated this round)
24. Previous session's never-run-VM-test landmine generalizes: any rewritten-but-unbuilt check should carry a `[blocked:calm]` queue row with the exact build command, so the next session doesn't re-derive it (this report records it for crush-hot-db)

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Will you create the NIX_GITHUB_RO_TOKEN now?** (fine-grained PAT, Contents: Read-only, then `gh secret set NIX_GITHUB_RO_TOKEN -R LarsArtmann/SystemNix`). I cannot mint tokens or write repo secrets on your behalf. Until it exists, CI stays dark and every check verification must burn local IO on this storm-bound box — including the crush-hot-db VM test that could otherwise have run remotely today.
2. **Is the 42h IO storm known/accepted churn, or should an agent actively hunt and stop its drivers?** I can identify them with cheap probes, but stopping user-visible workloads (crush sessions, your builds, parallel agents) exceeds my authority; the guard only contains flm/churn units, not the readers themselves. If you know it's your own workload, I'll leave it alone; if not, say the word and I'll investigate + propose stops.
3. **HTML blob policy:** the 2026-09-20 viz now costs a ~200k-line blob in every future git revision (the mermaid bundle rides in-file per the ratified pattern). Keep big carriers in-repo as ratified, or move the shared mermaid bundle out-of-repo (`~/.local/state/systemnix/mermaid-*.js`, artifacts script-inject at build/verify time) and supersede the current file once? The ratified pattern is workable either way — this is a repo-growth-vs-simplicity trade only you can set.

---

**Bottom line:** both cheap storage rows landed and functionally verified; all three owner decisions surfaced, answered, and recorded (one with a timestamp error I caught and fixed myself); the VM test is fully staged behind physics — a 42-hour storm that never offered a 2h calm window; nothing fucked up irreversibly, six bounded mistakes owned above; the deploy is yours, the tree is ready, and the two highest-leverage next acts (CI token, storm verdict) are one decision each.

**Waiting for instructions.**
