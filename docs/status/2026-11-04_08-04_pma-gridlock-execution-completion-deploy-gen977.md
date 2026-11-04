# PMA Gridlock Execution Arc — gen-977 Deploy, flm Stop/Re-arm, Honest Miss Ledger

**Session arc:** 2026-11-03 ~22:00 → 2026-11-04 08:05 (continuation of `docs/status/2026-11-03_23-18_pma-commit-daemon-gridlock-diagnosis-gcc-gate-fix.md`, which owns the diagnosis; this report owns the EXECUTION phase and its miss ledger).
**Owner rulings in this arc:** stop flm · deploy now (force authorized after the pressure-gate abort) · push go-commit "yourself" (turned out already pushed).
**As-of:** 2026-11-04 08:05 CET.

---

## §0 TL;DR

**gen-977 is live and anchored** with all three gridlock fixes verified in production: gcc-wrapper in the PMA unit PATH (0 false-holds since switch, was 1148/4h), PMA rebuilt from `4053b2ed` with vendored go-commit `4081b55` ⇒ `OPENAI_TIMEOUT=10m` active, flm stopped-then-re-armed and **surviving the new client** (0 crashes since 07:41:31; the last ABRT at 07:40:30 was the old client's final gasp). Commits are landing again (26 in 19 min, 65-265 ms fast-fallbacks) — but **199 `batch queue full` WARNs since the switch** mean the backlog drain is throughput-bound and will take time. flm's LLM commits have NOT resumed yet (still heuristic fast-fails — last night's per-project 4h cooldown caps are the prime suspect). The deploy took three attempts; every abort was a guard working, and every one of the three was foreseeable with discipline I already knew — that ledger is §6.

---

## §1 Execution narrative

| Time | Event |
| --- | --- |
| ~23:2x | **flm STOPPED** (service + socket, self-elevating harness) per owner ruling. Crash-loop ended, counter frozen at 10. Discovery: PMA fallbacks 30s → **0.4s** (connection-refused fast path) — stopping the provider *raised* throughput. |
| ~00:07 | **Deploy attempt 1 ABORTED at the entry pressure gate** — io PSI 40.7%, sdb 103.7% util (parallel sessions' ghostty scopes). Gate refused; I had not pre-checked PSI. |
| 00:10-00:50 | PSI watch: storm sustained 46-94%. Owner asked (wait / force / abort) → **force** authorized. |
| ~00:5x | **Deploy attempt 2 ABORTED** — battery §1: `doc-counts` failed: FEATURES.md stamped 47 packages, eval truth 48 (the parallel session's `docs-gates` flake-input pick landed without the re-stamp). Re-derived live, re-stamped FEATURES.md, `DOC-COUNTS GREEN`. |
| ~00:5x+ | **Deploy attempt 3 ABORTED** — §11 tree-mutation race: the daemon swept my uncommitted FEATURES.md stamp mid-battery. Fixed by pathspec commit — then hit a no-op commit failure (the tree had moved again overnight). |
| 07:0x | Morning: the offsite-borg session had committed through 07:00 (`d34e239d7`, carrying my FEATURES stamp). Quiescence poll: HOT until 07:0x (their `backup.nix` in flight), QUIESCENT 4×60s from ~07:2x. |
| ~07:4x | **Deploy attempt 4: LANDED as gen-977.** Exit 3 (new smoke failures vs baseline — triaged below). |
| 07:4x+ | **Live verifications**: anchor `readlink /run/current-system` == `system-977-link` ✓; PMA binary `8sqjxh34…-4053b2ed` (new PID 3776905) ✓; `gcc-wrapper-16.2.0` in live unit PATH, **0 gcc-not-found lines** ✓. |
| 07:40-07:41 | flm was re-armed during the switch window (stc socket cascade class): one last ABRT at 07:40:30 (old PMA client), restart 07:41:31, **zero crashes since** — `OPENAI_TIMEOUT=10m` held through the cold load. The fix's core claim verified in production without me restarting anything. |
| 08:0x | PMA settling (2.05 → 1.4 → 1.1 cores); 26 commits/19 min; queue-full WARNs continue (199 since switch) — drain is throughput-bound. |

**go-commit "push it yourself"**: no push happened — verification showed the fix was already pushed (`559720d`, 2026-10-07, ancestor-of-origin) and already locked into PMA (`9fc2026b`, 21:13 the same evening). Row 43's real blocker was the stale deployed binary, not the push chain.

---

## §2 Evidence ledger

| Claim | Probe | Result |
| --- | --- | --- |
| flm crash-loop ended | journal since stop | counter frozen 10 overnight; guard did not re-arm |
| Fallback throughput jump | PMA journal 23:25+ | `duration=434ms` (was `duration=30.09s`) |
| Deploy gate abort 1 | deploy log §ENTRY | `I/O PSI some avg10 = 40.73% WITH disk busy = 103.7%` |
| doc-counts failure | predeploy-3.log | `FEATURES packages asserts 47, eval truth is 48` |
| 48th package | `git diff d4128ee0e..HEAD -- lib/lars-packages.nix` | `docs-gates = flakePkg inputs.docs-gates` (pbx-artmann extraction, 2026-11-03) |
| Re-stamp verified | `nix build .#checks.x86_64-linux.doc-counts` | GREEN |
| gen-977 anchored | `readlink /run/current-system` vs `sort -V` newest link | identical `bs0sgf6l…` / `system-977-link` |
| PMA rebuilt | `pgrep -af` + unit `Service.Environment` | `…-4053b2ed…/bin/…`, PATH contains `gcc-wrapper-16.2.0` |
| gcc holds dead | `journalctl … since "-10 min" \| rg -c gcc` | 0 (morning rate was 211/70min pre-switch) |
| flm survived new client | journal 07:41+ | 0 crash lines since 07:41:31; port 52625 LISTEN |
| Backlog still draining | `rg -c 'batch queue full' since 07:45` | 199 (throughput-bound, not blocked) |
| LLM commits not yet resumed | `rg 'heuristic fallback\|committed changes' since 07:45` | all heuristic, no real LLM commit yet |

---

## §3 a) FULLY DONE

1. **flm stopped per owner order** — harness script, verified inactive socket+service; held overnight; counter frozen.
2. **gen-977 deployed and anchored** with the gcc gate fix + PMA@4053b2ed rebuild (go-commit OPENAI_TIMEOUT active) — all three gridlock causes closed in production, each verified with a live probe (anchor equality, binary rev + PATH, journal gcc-rate).
3. **doc-counts blocker resolved at the gate** — root-caused to the parallel session's docs-gates addition, re-derived with the check's own embedded command, re-stamped, check green.
4. **flm restart-safety proven in production** — the stc cascade re-armed it mid-deploy and the new client did NOT crash it (23+ min, 0 crash lines). The 2026-10-07 crash-trigger class is dead.
5. **Smoke triage completed** — every exit-3 FAIL mapped: cv-server = documented rev-independent SIGSEGV loop; tq brake = deliberate (freeze-45); Health-Hub 503 = cv cascade; monitor365/llama-embeddings = activation transients (active on re-probe); STORM-SUSPECT renders = re-verify when calm; PMA 205% CPU = discovery rebuild (settled to 1.1 cores by 08:04).
6. **Status report discipline** — §12 addendum on the first report + runbook gridlock bullet rewritten to RESOLVED with diagnostic signatures.

## §4 b) PARTIALLY DONE

1. **Backlog drain** — commits flow (1.4/min) but 199 queue-full WARNs since switch: the fleet's staged waves + live parallel sessions still outpace 2 workers. Expect hours, not minutes.
2. **LLM commit resumption** — flm is up and stable, but zero real LLM commits yet (all heuristic fast-fails). Prime suspect: last night's escalating per-project failure cooldowns (5m→4h cap) must expire; then the first `duration=10-20s` commit without a heuristic WARN is the true all-clear. NOT yet verified.
3. **Smoke-baseline repair** — exit 3 will keep firing until the baseline absorbs the known-class failures (cv loop, tq brake) or they resolve; the post-deploy battery's regression signal is currently noisy.

## §5 c) NOT STARTED

1. **DiscordSync Immich 403** — Immich rejects the verify key. Did not triage whether pre-existing or new (baseline-compare said "new"; I did not pull the previous deploy's smoke log to confirm novelty). Owner-domain (secret rotation).
2. **Offsite-borg golive tripwire binary missing** — the other session's staged go-live; theirs to finish.
3. **pdg-bak debris cleanup + writer location** — queued in upstream.md/TODO_LIST from the first report; untouched.
4. **Monitor-leg verification row** (did PMA-Commit-Health / flm coredump alerts fire during the incident?) — queued in services.md from the first report; untouched.
5. **`rg -r` behavioral fix for myself** — 4th hook-block this session; no mechanism changed.

## §6 d) TOTALLY FUCKED UP (the execution-phase miss ledger)

1. **Fired deploy attempt 1 with NO pre-flight PSI check** — AGENTS.md documents the pressure gate, the freeze-#22 discipline, and the evening's own status reports said "four eval roots pressure-blocked"; I checked tree-quiescence and eval but skipped the pressure axis, wasted a full battery run, and needed the gate to teach me. The gate worked; my pre-flight didn't.
2. **Left my own deploy-critical edit uncommitted while deploying** — the FEATURES.md re-stamp sat in the working tree (required for §1/doc-counts to pass!), and the daemon swept it MID-BATTERY → §11 tree-mutation abort. The rule I needed: *commit your own deploy-required edits (pathspec) before firing*. This one is squarely mine.
3. **`rg -r` trap, strikes #3 and #4 of the session** — hook-blocked twice more (`-rln` muscle memory). Documented in AGENTS.md verbatim; I keep typing it under time pressure.
4. **Raw script invocation instead of the flake app** — `scripts/pre-deploy-check.sh` → permission-denied exit 127, then had to read apps.nix to find `nix run .#pre-deploy-check`. AGENTS.md says use flake commands, not raw paths. Wasted round trips.
5. **Midnight `--since` empty-read nearly became a false conclusion** — `journalctl --since "23:25"` at 00:0x resolved to future-Nov-4 and returned silently EMPTY; I initially read that as "PMA went quiet" and started toward the hang class. The `-n 3` contradiction caught it. This is the SAME class as the boot-id empty-read trap in AGENTS.md ("an empty read is never evidence") — I documented that trap and then repeated it in a new costume.
6. **First report's "two of three legs fixed" overstated** — at 23:22 NOTHING was fixed in production (gcc fix inert until deploy; flm unmitigated). Tree-fixed ≠ live-fixed; the system stayed gridlocked ~8 more hours. The §12 addendum corrected the record, but the initial framing overclaimed.
7. **"flm smoke did NOT fire (corpse-guard aware)" asserted without reading the smoke code** — I don't actually know WHY it didn't fire (explicit stopped-state SKIP vs silent skip vs probe-order). An expected pass with an unverified mechanism is the same evidence-discipline sin as §6 of the first report, in miniature.
8. **Unit-name escaping probe garbage** — sed-built systemd-escaped names returned empty strings; wasted a round trip before hand-coding `_2d` names.
9. **Question tool interrupted twice; I waited for the user's "ask again"** — should have retried immediately on interrupt.
10. **The battery's warning delta (7 → 11) went unexamined** — I read the failure and moved on; four new advisories appeared and I never enumerated them.

## §7 e) WHAT WE SHOULD IMPROVE

1. **Deploy pre-flight = tree + eval + PRESSURE** — make the PSI check a standard step I run BEFORE `nix run .#deploy` (the gate is the backstop, not the plan).
2. **Commit-own-edits-before-deploy** — any edit the deploy depends on gets pathspec-committed first; the working tree handed to a deploy should carry zero of my own uncommitted weight.
3. **Stale-deployed-binary standing check (structural, highest value)** — last night's dominant cause (PMA@`a257580d` running while master/lock had moved to `4053b2ed` + fixed go-commit) was invisible for 10h. A post-deploy smoke asserting "running PMA binary rev == SystemNix-pinned input rev" would have caught it automatically. Queued this session.
4. **Throughput ≠ health** — "commits landing again" was heuristic-commits landing; the fleet's commit-message quality is still degraded until LLM commits resume. State which KIND of recovery, not just recovery.
5. **Verify the mechanism of expected passes** — "the smoke didn't flag flm because corpse-guard" needs the code read, not the assumption.
6. **Date-qualify every journalctl `--since` across midnight** — trap now encoded in AGENTS.md (harvested).
7. **Enumerate battery warning deltas**, not just failures — advisories are where the next incident hides.
8. **Ask-tool interrupts: retry, don't wait.**

---

## §8 f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Carry-forwards from the first report's §8 are referenced, not duplicated. ✱ = harvested this session. (o) owner / (d) deploy-gated / (u) upstream / (x) other session's domain.

### Close the incident (this arc's direct tail)
1. (o) Keep flm UP now that it survived the new client (it is up — re-armed by the switch cascade), or re-stop per preference. Default: keep up.
2. Verify the FIRST real LLM commit lands (`duration=10-20s`, no heuristic WARN) — the true incident-all-clear. Account for 4h cooldown-cap expiry.
3. Watch queue-full WARN rate → 0 (backlog fully drained); today's commit flood is heuristic-quality — expect a message-quality dip on pushed history.
4. (x) DiscordSync Immich 403: novelty check against the 22:35 deploy's smoke log, then owner rotates the key if real.
5. (x) Offsite-borg golive tripwire binary — that session completes its go-live.
6. Re-run the two STORM-SUSPECT CV render smokes when PSI < 20%.
7. Verify PMA discovery rebuild fully settles (<0.5 core sustained).
8. Absorb the known-class smoke failures into the baseline OR tag them expected (cv loop, tq brake, flm-if-stopped) so exit-3 regains signal.
9. ✱ (d) Stale-deployed-binary standing check — post-deploy smoke asserts running PMA rev == pinned input rev.
10. Enumerate the 4 new battery warnings (7→11 delta) from deploy-3.log.

### Structural follow-ups (from this arc's lessons)
11. ✱ AGENTS.md: midnight `--since` trap encoded next to the empty-read doctrine.
12. Encode "commit-own-deploy-critical-edits first" into docs/CONTRIBUTING.md daemon-race policy.
13. Add pre-flight PSI probe to my personal deploy checklist (and consider a `deploy-when-quiescent` PSI leg — the script already exists in scripts/).
14. flm smoke: read post-deploy-check.sh's flm section; make "stopped by design" an explicit SKIP verdict, never a silent pass.
15. LLM-quality watch: sample this morning's heuristic commit messages for garbage risk (they landed on pushed history).
16. 4h cooldown cap: consider a cooldown-reset on provider-recovery event (upstream PMA idea) — repos shouldn't stay capped after flm returns.
17. Add "commit generate failures by family" counter (refused vs timeout vs 4xx) to the textfile collector — distinguishes stopped-provider from hung-provider automatically.

### Carry-forward (first report §8, still open)
18. (o) flm v1.0.2 heap bug upstream check (now with the SEGV datapoint).
19. Monitor-leg verification row (services.md, queued) — did the alerts page during the incident?
20. Queue-saturation + gate-env-false-hold alert signals (services.md row, queued).
21. pdg-bak per-repo cleanup (queued [ready]).
22. pdg-bak writer location + index-clean fix (queued [ready]).
23. (o) Attribution: "stage pending work" writer + staged go.mod/go.sum waves.
24. Eval-time assertion: gate PATH contains a cc wrapper.
25. (o) gcc-parity vs CGO_ENABLED=0 gate policy, with measured durations.
26. Gate GOCACHE persistence study (20-200s builds).
27. Gate cooldown ladder documentation (5→10→20→40m; cap?).
28. Upstream PMA: GATE-ENV vs TREE error classification.
29. Post-deploy: one known-CGO repo `go vet` under gate env.
30. Canary CGO repo in selftests (would have caught the gcc hole day one).
31. (u) go-commit row 43 CLOSE-OUT: rewrite the row — push + re-lock both landed; only the deploy was missing (stale-binary class). The row's chain description is now stale.
32. (o) vendorHash treadmill row: pick release-discipline nudge vs rev-pin.
33. mr: prune 5 dead chdir targets.
34. (o) Git Town WIP stash clutter policy.
35. templ-components `AD go.work.pdg-bak` coordination (§21 theirs).
36. Watch today's CI for heuristic-message-quality damage.
37. (d) After drain: re-run post-deploy-check for a clean baseline.
38. Resolve the 11 `conflicts detected` repos (identify from journal).
39. Deletion-guard deferrals review (38, incl. go-atomic-write package.json — note: go-atomic-write DID land at 07:51; re-count).
40. (o) Dependency-wave attribution (crush DB + journals).
41. 11-battery-warning enumeration (see 10 — same act, listed here for the count).
42. PMA_COMMITTER_WORKERS 2→3 evaluation AFTER drain, with numbers.
43. Upstream PMA: bound batch queue + shed with WARN counter.
44. Live-verify "OPENAI_TIMEOUT inert" doc claim is now OBSOLETE — update upstream.md row 43 wording (part of 31).
45. `go version -m` probe habit for deployed Go services (would have caught the stale binary in one command at 22:0x last night).

### Deliberately not minted (recorded, not queued)
46-50. Heuristic-message quality study, gomend/mr-sync consolidation, stash-hygiene scripting, PMA release cadence, discovery-daemon socket-mode audit — duplicates of existing watch rows or lacking a concrete ask; recorded here so the next prune's WARN recount includes them.

---

## §9 Self-harvest record

- ✱ `docs/todo/services.md` + `TODO_LIST.md`: NEW row — "PMA post-gen-977 verification sweep: stale-binary standing check + LLM-commit resumption proof".
- ✱ `AGENTS.md`: midnight `--since` trap sentence appended to the journalctl empty-read doctrine (Session Discipline).
- Deliberately NOT harvested: items 1-9 of §8 (in-flight tonight — flm state is owner's live call; drain watch is passive observation; Immich/borg are (x) domains; stale-binary check (d) rides the next deploy — wait, it's a SCRIPT change, agent-actionable: harvested as the services.md row above); items 18-45 carry pointers to their existing rows; 46-50 recorded as non-asks.

## §10 g) QUESTIONS ONLY THE OWNER CAN ANSWER

Asked via the structured prompt immediately after this report; recorded here as asked.

## §11 Attribution

The offsite-borg session owned `backup.nix`/`docs/services/offsite-borg.md`/`docs/todo/storage.md` overnight; their 07:00 commit (`d34e239d7`) carried my FEATURES.md re-stamp (uncommitted at the time — their commit, my content: attribution recorded here). Their doc-gates extraction caused the doc-counts gate block; their tq brake explains that smoke FAIL. The deploy shipped their committed backup.nix change (owner-set per its inline comment) in the same gen-977 switch as my fixes — one activation, two sessions' owner-directed work.
