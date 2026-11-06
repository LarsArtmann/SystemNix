# Brutal self-review + session close-out — freeze-#50 triage, two config fixes, bundle-vanish investigation

**Session:** 2026-11-06 ~06:00–06:50 CET, single instance, dispatched by the owner's "We crashed again why!?". Live conditions during the whole session: boot 0 chronic re-storm (io PSI some avg10 83%, avg60 73%, load 50, guard trip #7453, ~18 crush processes) — every probe read-only or throwaway-user-unit, zero heavy evals. **Skill note:** brutal-self-review's default HTML output (`docs/reviews/`) was overridden by the owner's explicit in-chat instruction (markdown status report here, §a–§g format, no unrelated research); the skill's honesty question set (§1–§12) drove §d/§e instead.

**Scope line — VERIFIED here:** crash census via `scripts/crash-triage.sh --boots 4` (full-count greps); reset register from boot 0 kernel log; guard heartbeats + psi-wait-gate death lines quoted from boot -1; 5 deploy-refusal logs read from `/var/log/systemnix-deploys/`; device identity resolved via `/dev/disk/by-id` (Samsung=nvme0n1, Lexar=nvme1n1 this boot); both evidence pulls rc=0 and the pre-vacuum gate re-run **PASS** (all 4 exposed boots guarded — the step I had forgotten, discharged during this review); systemd-261 transient-unit A/B tests for the LogFilterPatterns grammar (glob rejected, `?*` rejected, `.*`-wrap accepted); `systemd-analyze calendar` for the OnCalendar fix; `git log -S` bounding the broken spec to **Nov 4 (`dc447e429`) → Nov 6 (~2 days dead, not "since module authoring" as my 06-45 report imprecisely said — corrected here)**.
**NOT verified here:** no repo eval (storm; leaf-string fixes whose validity is proven semantically — CI owns the walk); the LogFilterPatterns DENY path is untestable from agent shells (system-services-only; deploy-time verification owed); the bundle-vanish deleter is NOT identified.

## a) FULLY DONE

1. **The owner's question answered at minute ~20: freeze #50, family C, WDT reset, no deploy cause.** Boot `7c876ae0` ran Nov 5 20:39:20 → cut 05:56:21 (9 h 17 m); reset register `0x02000800` hardware-watchdog. Census: **210 zone-6 trips (#7227→#7436), ALL no-match — zero pauses/sacrifices all boot; 378 DEEP-THROTTLE ENTERs (never cooled, 98 °C at 10 min in); 0 OOM; 22.6 trips/h — new series record.** Final-hour heartbeats: io PSI avg60 90–96%, disk 97–100%, MemAvail 30–55% (crash-#3 class); final journal line = psi-wait-gate flm WAIT @ 90.71%.
2. **Cause chain named from the deploy-gate snapshots:** chronic multi-session agent fleet (sibling reports: PSI avg10 91→98.5, load 145→156) pegging **sdb USB-buildcache ×4**, Samsung nvme0n1 (03:52), pool sda 102.8% (05:53), plus the 05:00 maintenance battery; drivers TTY-holding agent sessions — structurally unpausable, fourth boot in a row of 100% no-match trips.
3. **Six storm-window deploy attempts verified vetoed, anchor INTACT all night** (system-983 == current-system): 23:15 float-register abort + 03:52/05:53/06:00/06:01 `=1` extreme-band refusals — the #49 tier-2 veto's first live night, 5/5 blocks. Nothing forced through; the crash had NO deploy cause.
4. **Both crashed boots evidenced before the journal vacuum edge** (7.9G/8G cap): `docs/status/tasks/2026-11-06_05-11_boot-7c876ae0-evidence-pull.md` (#50) + `…05-29_boot-5819f35d…` (#49 backfill, discharging the triage's UNEVIDENCED flag), and the forgotten `pre-vacuum-evidence-gate.sh` re-run **PASS** during this review.
5. **Ledger row #50 landed** in `docs/agents/stability.md` (census table, death-window cites, the vanish finding in corrected form).
6. **Fix 1 landed + verified: `buildcache-agent-cache-gc.timer` NEVER fired** — `OnCalendar="daily 05:20"` unparseable → "Timer unit lacks value setting. Refusing." every boot since **Nov 4** (`dc447e429`, bounded by `git log -S`) → fixed `"*-*-* 05:20:00"`, `systemd-analyze`-verified (next elapse 05:20). Repo-wide sweep found no other keyword+time OnCalendar.
7. **Fix 2 landed + compile-verified: dnsblockd LogFilterPatterns glob→ERE** — the Nov 4 systemd float silently killed the 2026-10-28 journal-spam gate (leading-`*` glob = bare quantifier in ERE; "Bad pattern" at every boot since; dnsblockd's 1/min OTel spam confirmed flowing in boot 0). Fixed `~.*4318: connect: connection refused.*`; A/B-proven that the old glob AND a `?*` variant are rejected and the shipped form compiles; `.*`-wrap chosen to be correct under BOTH search and full-match semantics.
8. **Both pending-deploy surfaces synced** (TODO_LIST.md one-liner + `docs/todo/stability.md` row, full-line edits): the tree's deploy payload now carries both fixes.
9. **Two new [ready] rows harvested into `docs/todo/stability.md`** at authoring time (vanish investigation with exoneration map; death-window bundle survival).
10. **Session report authored** (`docs/status/2026-11-06_06-45_freeze-50-triage-…-status.md`) with self-harvest + deliberate-not-harvested markers.

## b) PARTIALLY DONE

1. **The bundle-vanish investigation — facts nailed, deleter unnamed.** Boot -1 completed **199** captures; keep-50 bounded the stock to ~50 fsynced bundles at reset; ALL gone by T+10min while non-matching Nov 3 files survived. Exonerated (do-not-re-walk map in the [ready] row): tmpfiles `R …30d` + `q …14d` (user-mode A/B: fresh targets survive `--create` AND `--create --remove --boot`), writer retention keep-50 (≤14 completions at vanish time), PrivateTmp (plain transient), guard/audit/tmp-cleaner modules (read), sudo journal + fish history (empty). Remaining: sibling-session manual cleanup (scoped .crush query protocol needed first — full scans are the #45 storm class), systemd internals, unlogged btrfs edge.
2. **LogFilterPatterns deny-path verification deferred to deploy time** (system-services-only; agent shells cannot exercise it). Owed checks post-switch: the "Bad pattern" boot line gone + dnsblockd 4318 spam dry.
3. **Freeze-#51 watch documented, not resolved:** boot 0 re-armed the amplifier fleet live (staging bundle at T+5m40s: project-discovery 8.7G, dnsblockd 5.0G, llama-vlm 5.6G, nix-daemon 1.8G) and stayed chronic all session (17+ trips, all no-match). The levers all worked (calm-gate refusals, tier-2 vetoes, psi-wait-gate holds) — the LOAD is unowned.

## c) NOT STARTED

1. The structural storm asks remain queued untouched: golangci-lint fleet cap, PSI-aware dispatch gate ([decision], owner-gated since 2026-09-29), monitor365/dnsblockd cold-boot profiling, hot-tier ratification — this session only added evidence.
2. No checks BUILT for the two fixed configs (OnCalendar parse leg, LogFilterPatterns compile leg — §f items).
3. No commit by this session (daemon swept everything in mixed batches; `--`-pathspec splits are the owner's call).
4. The 187 unharvested-§f docs-gates WARN — standing drift; the new sibling 06-35 report belongs to its own session.

## d) TOTALLY FUCKED UP

1. **I shipped a wrong mechanism claim into the SHARED ledger before grounding it:** row #50's first version attributed the bundle vanish to "classic fsync-file-without-fsync-dir" — then I read the writer and found it does the FULL durability dance (file fsync → dir fsync → rename → parent fsync, lines 142-156, built for exactly this class). Caught within minutes and corrected in-row, but for a window the shared tree asserted a falsehood about a subsystem whose entire purpose is evidence integrity. Exactly the class the 2026-09-29 rule bans: assert the mechanism only after reading the mechanism's code.
2. **~90 minutes of rabbit hole past the answer:** the owner asked "why did we crash" — answerable at minute 20; the vanish consumed the rest. It DID yield two [ready] rows and permanently killed four hypotheses (tmpfiles empirically, retention mathematically, PrivateTmp by read, storage by the Nov 3-file survivor) — but the discipline call was borderline, and under an ACTIVE storm the opportunity cost was real.
3. **Typed `rg -rn` twice** after the 2026-10-23 doctrine documents this exact trap (hook blocked both; the hook message literally says "third strike on this host"). Zero corrupted readings escaped, but I am part of the statistic now.
4. **My 06-45 report said the timer was broken "since authoring"** — unbounded claim; `git log -S` puts the spec at Nov 4. Corrected here. Small, but it is precisely the "process-discipline claims are the class most often asserted falsely" pattern (skill question 12).
5. **Forgot the pre-vacuum gate re-run** that both pull scripts explicitly instruct ("next: git add + commit, then re-run scripts/pre-vacuum-evidence-gate.sh") — discharged during this review, PASS. Forgetting the script's own printed next-step is a reading-comprehension failure, not an information gap.

### Honesty audit (skill §5, §7, §10, §11)

- **Did I lie?** No falsehood left standing uncorrected: the fsync-dir claim (§d.1) and the "since authoring" bound (§d.4) were the two overreaches, both corrected in the same session. The "NEVER ran" claim for the timer is solid (unparseable spec = cannot fire; refusal logged every boot checked).
- **Ghost systems found (§7):** (a) the tmpfiles `R /var/tmp/io-psi-forensics-* 30d` backstop — by design it can NEVER fire usefully: keep-50 churns every bundle within hours, so the 30-day OS-level backstop guards an empty set; (b) the guard's "top io since last trip" attribution feature (2026-09-28) emitted ZERO lines across boot -1's 210 trips — it rides socket/sacrifice action lines, and the IO-PAUSE era's dominant trip class is exactly what it doesn't cover: a live capability, blind for the current boot profile. Both are integration gaps, not unwired products — rows exist for neither until this report (§f.10/§f.11).
- **Split brains (§10):** (a) the dnsblockd comment claimed the spam was gated while the filter was inert (healed by the fix, comment updated); (b) two retention layers with contradictory assumptions (keep-50 hours-vs `30d` backstop never reached); (c) duplicate `/var/tmp` tmpfiles ages (configuration.nix `14d` first-wins vs upstream tmp.conf `30d` discarded — the documented first-wins trap, one more instance); (d) ledger row #50 v1 vs reality (self-inflicted, corrected).
- **Tests (§11):** my fixes have semantic verification only (systemd-analyze, transient-unit compile) and NO pinned repo checks — under a future systemd/nixpkgs float both classes break again silently. The CI-leg proposals are §f.7/§f.8.

## e) WHAT WE SHOULD IMPROVE

1. **Ground-then-claim, mechanically:** for ANY "X is broken because Y" row, read the Y implementation BEFORE writing the row — I want a personal rule upgrade: the writer's source must be open in the same tool-call batch as the first claim edit.
2. **Cap rabbit holes by question answered:** the owner's question was answered at minute 20; the deep-dive should have been gated on "does this change the verdict?" (it didn't — verdict was family-C-storm before the first bundle was read). New rule: after the primary question is answered, further digs get a written hypothesis FIRST, then a time box.
3. **Evidence survival needs a design, not exonerations:** the capture pipeline (199 captures → keep-50 → 0 attributable at T+10min) is an evidence factory with a shredder at the door. The [ready] row's boot-pin/auto-pull options need an owner pick, then a selftest.
4. **The no-match trip class needs its own attribution leg** — extend "top io since last trip" (or the bundle trigger) to IO-PAUSE no-match trips; four boots in a row, the guard's ONLY per-trip evidence channel is silent.
5. **Config-grammar CI legs:** parse every OnCalendar in the tree (`systemd-analyze calendar` is scriptable) and compile every LogFilterPatterns (the transient-unit harness works headless in CI) — both breakage classes were silent for 2 days and would be caught at next CI run by ~30 lines total.
6. **Storm-safe .crush attribution protocol:** a scoped, index-bounded query recipe (time-window + thread-id bounds, never parts-LIKE full scans) so post-incident actor attribution doesn't require choosing between blindness and a freeze-#45 repeat.
7. **Verify-before-inheriting held this session** (anchor state, veto behavior, gate wiring all re-verified live before reuse) — keep doing exactly this; it is what caught the vanish premise drift early.

## f) Up to 50 things we should get done next

Existing-row items are marked (row) — they are ALREADY harvested; do not re-file. New items from THIS session carry their landing surface. Ordered by impact × effort.

1. **(row)** Re-run the pending deploy when io PSI some avg10 < 20 sustained — carries fastflowlm removal + both of today's fixes; anchor discipline + the 19:42 battery after.
2. **Deploy-time verification battery for today's fixes** (new, owed): post-switch — "Bad pattern" boot line gone; dnsblockd 4318 spam dry in journal; `systemctl list-timers` shows buildcache-agent-cache-gc with next elapse; a live dnsblockd OTel-error line gets filtered (write one via `logger`-equivalent or restart the unit against a down collector).
3. **CI leg: OnCalendar lint** — parse every `OnCalendar` in modules/platforms via `systemd-analyze calendar` in a check (30 min; catches the 2-day-silent class forever). New check in `flake/parts/checks/`.
4. **CI leg: LogFilterPatterns compile** — the transient-unit A/B harness (`systemd-run --user -p LogFilterPatterns=…`) scripted as a fixture check. New check.
5. **(row)** Death-window bundle survival: owner picks boot-pin (a) vs calm-gate auto-pull (b) → implement + extend the forensics selftest.
6. **(row)** Vanish deleter investigation — first step is the scoped .crush query protocol (§e.6), THEN the query; never a full scan under storm.
7. **Scoped .crush attribution recipe** — document the bounded-query pattern in docs/agents/ (time-window, thread-id, rowid bounds; a hard "never parts-LIKE under PSI>40" guard).
8. **(row)** PSI-aware dispatch gate for agent sessions — owner decision, 5 storm deaths of evidence now (was 3).
9. **(row)** golangci-lint flock fleet cap in the direnv guard.
10. **Guard attribution leg for IO-PAUSE trips** — emit "top io since last trip" (or a bounded per-cgroup delta) on no-match trips; the ghost-system gap (§d Honesty audit a/b).
11. **Remove or re-purpose the never-firing 30d tmpfiles backstop** — either delete the rule or make keep-50 the single documented retention (split-brain (b) cleanup).
12. **Single-source the /var/tmp tmpfiles age** (14d in configuration.nix vs upstream 30d discarded) — one surface, one age (split-brain (c) cleanup).
13. **Journal vacuum headroom alert** — 7.9G/8G cap, 0.1G headroom at triage time; a gatus threshold (e.g. <10% headroom WARN) so evidence pulls stop being luck-dependent. Monitoring domain.
14. **Freeze-#51 watch handling** — if the next recovery boot re-storms identically, the standing playbook is: let the gates hold, queue the deploy, do NOT force (tier-2 demands `=2` — treat that as a last resort with owner sign-off).
15. **dnsblockd OTel ordering** — the spam's root cause is exporter-up-before-collector at boot; an After=/requires on the signoz OTel endpoint (or a bounded retry) kills the class the filter merely mutes. Services domain.
16. **Capture cadence adaptivity** — 2.5-min bundles under storm × keep-50 = churn; consider a per-boot capture budget or escalating-interval throttle in io-psi-forensics.sh (pairs with §f.5).
17. **Backfill the #49 row's evidence field** with the new 05-29 pull path (one-line doc sync; the row predates the pull).
18. **`git log -S` date-bounding pass over my 06-45 report's remaining claims** — one more precision sweep in the spirit of §d.4 (cheap, catches any other unbounded "since" wording).
19. **(row)** monitor365-server 7.5G cold-boot profiling.
20. **(row)** dnsblockd cold-boot blocklist burst profiling.
21. **(row)** Hot-tier ratification (owner-gated) + HM-symlink extendModules proof.
22. **T26 batch 2 pacing answer** (owner; carries from 05-34).
23. **Lock-red follow:** the sibling flake.lock treefmt-nix deep-copy regrowth — consumer follows fix, gated on sibling quiescence (from 05-34 §b.1, still red at session end).
24. **D2 deploy authorization + T15/T16/T27** (deploy-gated, owner; unchanged).
25. **docs-gates WARN drift recount** (standing; 187 — next prune unmasks more, expected).
26. **Add `check-todo-system.sh` to my personal session-close ritual** — I skipped it until the artifacts check; ran late, structure was clean by luck of ordering.
27. **Consider a `systemd-analyze verify`-style boot-unit smoke in CI** — it would have flagged BOTH today's units (timer refusal + bad pattern) without a boot; needs scoping (units are host-rendered; the fixture would need the rendered tree). Follow-up spike, no commitment.
28. **Owner-visible one-liner for storm state** — every session re-derives PSI/load/trip-state by hand; a tiny `scripts/storm-state.sh` (read-only, PSI + zram + guard trip counter + top-3 stalled cgroups) would standardize the first 60 seconds of every triage.
29. **Stop using "since authoring" unbounded** — personal wording rule: every "since/before X" claim carries a commit-or-boot bound or says "unbounded".
30. **Session-start boot check** — this session began 2 min after a WDT reset with no prior signal; a crushrc-level `uptime`/boot-id banner would make "the box just crashed" visible before the first tool call (pair with the status-report pre-read doctrine).

Deliberately NOT harvested: §e.1/§e.2 (personal-discipline rules — they live here and in my 06-45 report, not as queue rows); §f.2/§f.14/§f.18 (owed sub-steps of already-landed rows/reports, not standalone asks); §f.27 (spike without commitment). Everything else routes to existing rows — no duplicate filing.

## g) Questions I cannot answer myself

1. **The vanish deleter:** did YOU (or an interactive shell of yours, ~06:00±20 min today) run any cleanup touching `/var/tmp/io-psi-forensics-*`? Fish history is empty but open terminals don't write history — if no, I'll proceed to the scoped .crush query protocol (never a full scan) with your explicit go-ahead, since sibling agent sessions are the only remaining in-repo-scope suspects.
2. **PSI-aware dispatch gate — which layer?** (the standing owner [decision], now with 5 storm deaths of evidence): tq-pool entry gating, a BuildFlow step gate, or a crush-session-level env guard? Entry gates provably can't stop mid-flight work; you own where the refusal should live.
3. **Bundle survival design:** boot-pin (old-boot bundles never pruned — simple, unbounded growth risk) vs calm-gate auto-pull (bounded, one pull per boot, adds boot-time IO) vs both? Your pick lands in §f.5.
