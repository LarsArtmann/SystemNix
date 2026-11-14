# Status Report — Crash-Loop Follow-Up: Attribution Wave, Storm Gate, Self-Review

**Session:** 2026-11-14 ~16:20–17:10 CET active + 18:30 wake (this report). Continuation of the 15:45–16:20 crash-loop fix-wave session (four fixes committed, undeployed).
**Live state at authoring (18:30):** IO PSI some avg10 = 99 (storm since ~13:20), linkers 96→90 (session-26 battery now slowly draining), memory PSI briefly 31.8, parallel waiter log stale 7 min (possible horizon death), tree clean, 28+ commits unpushed. NO deploy has landed — gen-1007 (14:55) is still live.

## a) FULLY DONE

1. **Census-orphan attribution complete (both remaining orphans + the user-manager blind spot):**
   - **x2dx2 = `forgejo-runner-evo\x2dx2.service` start-pre timeout loop** — since 13:58 (0 attempts yesterday), 27+ by 16:31, CI runner down all day. Mechanism proven live: genToken + provision legs finish in ~1s (`provision: connection identity present — nothing to do`), then the `+forgejo-provision-runner-cache` leg's `chgrp -R gitea-runner-cache /mnt/buildcache/ci-runner-cache/{ec-hub,gf-logs}` starves under the storm and hits `TimeoutStartSec=3min` → the 5-min ensure timer refires forever. **Caught in-flight (PID 2476106, chgrp mid-walk)** via `systemctl show -p ExecStartPre` stop_time=[n/a] + pgrep.
   - **cvagent (4 restarts) = systemd-oomd kills** (13:21/13:43, exit-2 at 14:04/15:27; 897 MB peak, 157 GB lifetime reads) — freeze-#54 collateral; the parallel session's P0 row owns the fix; corroborated via journal, deliberately not re-filed.
   - **User-manager failed sweep:** `nextd-refresh.service` = nextd daemon `/refresh` 500 on every 15-min tick since the 15:33 watchdog SIGABRT (main goroutine blocked in select **363 minutes** per the dump) — dispatch queue stale. `push-stall-watch.service` = **by-design** stall detector firing on the owner-gated unpushed commits; resolves with the push ruling.
2. **`systemd-analyze syscall-filter` verification:** `syslog` NOT in `@system-service` (exact-list grep rc=1; full dump shows it only under `@known`) — the monitor365.nix comment is TRUE as written; no correction needed. Battery item closed.
3. **bank-sync pre-start-backup sizing:** upstream design is `cp -f` onto ONE rolling `data.db.pre-start.bak` (207 MB, overwritten every start; bank-sync/deploy/nixos/bank-sync.nix:283-300 + live sudo verify) — **the 39-restart loop grew nothing**. The 4 dated pre-qonto-import .baks (~408 MB) remain owner-reclaim; the pre-existing services.md decision row was UPDATED with this verification + the 750 permission-blind note (no duplicate row created).
4. **Three TODO surfaces landed + committed (`2601b517d`):** runner `[ready]` row (TODO_LIST queue + services.md library pair), nextd `[watch]` row (library-only, fix is nextd-repo territory), bank-sync row update.
5. **§c attribution addendum** appended to the 16-20 report + committed (`b4e320760`) — all row citations resolve.
6. **Deploy coordination read + decision:** the freeze-#54 session's armed calm-window waiter (`~/.cache/band-deploy2.log`) owns the next deploy; the same master tree carries my wave, so their fire deploys the four fixes + bank-sync repin. Takeover condition documented (waiter-log staleness past horizon at calm).
7. **Storm forensics:** the battery is a session-26 SSH cargo-nextest run on monitor365 (ancestry walked: cargo→nextest→sccache→rustc→gcc→collect2→mold), started 15:46:58 (4 min post-boot — the freeze-#54 recovery amplifier). Wedge-vs-crawl answered: **~495 KB/s aggregate sdb write** (crawling, not zero).

## b) PARTIALLY DONE

1. **Deploy — blocked, correctly gated, executor deferred.** IO PSI never left the 98–99 band this session. Not forced (owner-gated). Pre-flight `--keep-going` build and the drv-equality no-op probe both remain unrun (gated on calm). At 18:30 the battery is DRAINING (96→90 linkers) but their waiter looks possibly dead (log stale since 18:23) — the takeover branch may become live after this report.
2. **Runner loop — attributed + rowed, NOT fixed in-wave.** Deliberate: mid-storm edit of a battle-tested 1500-line shared module + a 5th undeployed change = risk without urgency (self-heals post-storm). Defensible, but it stays the honest boundary of this wave: attributed-and-queued, not fixed.
3. **Verification battery (4 fixes) — prepared, not runnable.** Baseline taken: 2 monitor365 dmesg SIGSYS coredumps today (15:01:07, 15:43:11) — post-deploy target is ZERO new. Battery text lives in the `[blocked:deploy]` rows (both surfaces).

## c) NOT STARTED

- The deploy itself, the battery, the surface close-out (tick [blocked:deploy] rows, CHANGELOG deploy entry) — all downstream of the gate.
- Crash-loop alert leg (TODO_LIST:598) — owner-gated, untouched.
- nextd daemon fix, cvagent P0 fix session — other sessions'/repos' work, only rowed here.

## d) TOTALLY FUCKED UP (self-review, brutal)

1. **Commit subject 74 chars — 5TH STRIKE of the class.** The handoff EXPLICITLY named this trap ("4th strike") and I still shipped a 74-char subject on attempt #1 (`docs: crash-loop report addendum — census orphans attributed, deploy coord`). I did not count before the heredoc. The hook caught it; one wasted commit cycle.
2. **Fabricated-zero near-miss in the throughput probe.** First sdb measurement: `findmnt` resolved `systemd-1`, `/sys/block/systemd-1/stat` doesn't exist, w1/w2 came back EMPTY, and `$((w2 - w1))` silently evaluated to **0** — I printed "0 KB/s", which read as a HARD WEDGE. Truth (proper probe): 495 KB/s crawl. The empty-var-to-zero arithmetic trap is the quote-scrutiny rule's sharpest tooth and I nearly fed a wrong verdict to the owner's stop decision. Caught only because the artifact smelled wrong.
3. **80-minute unmonitored "standing takeover."** At 17:10 I ended the turn promising "if the waiter dies past its horizon, I take over and fire." Between 17:10 and this 18:30 wake, NOTHING monitored that condition — an ended turn keeps no watch. If calm had opened at 17:30 with a dead waiter, the promise was empty paper. Their waiter was the only real guard, and it now looks stale. A takeover condition needs a wake source (timer unit, nextd dispatch, or an explicitly open turn), not a sentence in a report.
4. **Did not run `journalctl --list-boots` before cross-hour forensics.** I counted runner restarts 13:58→16:31 and read cvagent PIDs without noticing the 15:41:18→15:41:46 freeze-#54 reboot myself — the parallel session's report had to teach me the boot boundary (their §d.1 is my miss too, cheaper only because I didn't mis-attribute). The session-discipline rule exists; I skipped it.
5. **Duplicate-row near-miss (bank-sync).** Drafted a new reclaim row before grepping for an existing one — services.md:1117 (2026-11-10) already covered it. Caught on re-read; applied the no-duplication rule late instead of by reflex.
6. **Two wasted edit attempts on TODO files** — edited off `sed`/`rg` reads, which don't refresh the edit tool's read-tracking. Known mechanics, still burned two round-trips mid-race-window.
7. **Time perception drifted ~8 minutes** ("it must be ~16:52" at 16:44) — no `date` at resume or after sleeps, despite timestamps being load-bearing all session (the gate-log corrected me).

## e) WHAT WE SHOULD IMPROVE

1. **Count the commit subject BEFORE the heredoc** (`printf %s "$subj" | wc -c`) — five strikes means "I'll be careful" is not a control. Consider a tiny pre-commit length guard (the house hook exists — I hit it, so the fix is behavioral: draft, count, commit).
2. **Empty-var arithmetic must fail loudly in probe one-liners**: `w1=$(cat … || true)` + `$((w1))` = silent 0. Guard probes with non-empty validation (`: "${w1:?empty}"`) or `set -u` — the existing quote-scrutiny rule should gain this nuance (one line: "an arithmetic on an unset/empty var yields 0, the most plausible-looking fake number").
3. **Standing conditions need a wake source.** Any "I will X when Y" written into a report must name its trigger mechanism (dispatch row with a timer, the nextd queue, or staying in-turn). Otherwise write "no one is watching" — which is the truth.
4. **`journalctl --list-boots | tail -2` as the FIRST probe of any cross-hour timeline** — the parallel session proposed the reboot-signature checklist; my session is a second data point for it. Belongs in AGENTS.md session discipline next to the boot-evidence rules.
5. **Grep the target library for an existing row BEFORE drafting** (dedup at draft time, not at insert time).
6. **One PSI sampler, not two** — I started my own gate logger while the parallel session's waiter already sampled every 60s; my only unique columns were dirty+evalhot. Marginal load, but duplicate surfaces are the split-brain class at small scale.

## f) NEXT (up to 50, grouped; ★ = owner-gated, ◆ = this session's continuation, ▸ = rowed for dispatch)

1. ★ Storm ruling: stop session-26 battery or let it drain (evidence: 495 KB/s crawl, freeze-#55 risk; now draining 96→90).
2. ★ Push the 28+ unpushed commits (also clears push-stall-watch's by-design failure).
3. ★ DEPLOY_FORCE_PRESSURE authority through storms — never used, still unrated.
4. ★ Crash-loop alert leg (TODO_LIST:598) — build now or after the wave deploys?
5. ★ cvagent: leave stopped until its P0 fix, or restart accepting the read storm (parallel session's Q2).
6. ◆ Verify the parallel waiter's liveness (log stale since 18:23 — if dead at calm, the takeover branch is LIVE).
7. ◆ If takeover fires: drv-equality probe first (`nix eval --raw …drvPath` vs `nix-store -q --deriver $(readlink /run/current-system)`) — skip no-op switches.
8. ◆ Pre-flight `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` (enumerates FOD failures — the bank-sync ad8a90c9 vendorHash gets its first real-build proof).
9. ◆ Deploy via `nix run .#deploy`; watch `/var/log/systemnix-deploys/<ts>.log`.
10. ◆ Anchor check post-deploy: FULL process tree empty (`pgrep -f 'nh os|switch-to-configuration'`), then `readlink /run/current-system` == newest `system-N-link` BY NUMBER (never mtime).
11. ◆ Battery 1/4: audiblesync `ActiveState=active` + `:8481` bound + `/healthz` 200 (python3 urllib; curl is tool-banned).
12. ◆ Battery 2/4: immich converger `Result=success` + `stat -c '%a %U:%G' /var/lib/immich-api-keys/takeout-import.env` → `400 lars:users` + api_key row in converger output.
13. ◆ Battery 3/4: monitor365 — `coredumpctl list --since <switch-ts>` shows ZERO new dmesg entries (baseline: 2 today, last 15:43) + agent MAC-scan journal lines appear.
14. ◆ Battery 4/4: bank-sync ExecStart store path ends `bank-sync-ad8a90c9…` + zero exit-65 since switch.
15. ◆ Run `scripts/post-deploy-check.sh` (the functional smoke layer) after the battery.
16. ◆ Tick BOTH `[blocked:deploy]` wave rows (TODO_LIST ~437 + services.md ~746) in ONE pathspec commit with the pre-commit `git log -1` peek.
17. ◆ CHANGELOG deploy-landing entry.
18. ◆ Post-deploy failed-unit re-census (`systemctl --failed` + `--user --failed`): expect nextd-refresh still failing (nextd repo owns it), push-stall-watch pending owner push.
19. ◆ Kill my background gate logger (job `06E`) once the deploy lands or the session definitively ends — do not leak the sampler.
20. ▸ Runner fix session (new [ready] row): decouple the chgrp -R walk from the 3-min start chain (non-blocking oneshot / ExecStartPost / stale-uid guard) — write the one-paragraph design note first.
21. ◆ Post-storm: verify the runner SELF-HEALS (active within one ensure-timer cycle) — confirms storm-collateral read; if it does NOT self-heal, the row escalates.
22. ▸ nextd repo session: watchdog-hang root cause (goroutine blocked 363 min) + the /refresh 500 handler error — dispatch queue is stale until then.
23. ▸ Consider an OnFailure alert for nextd-refresh (currently a silent user-manager failed state — the census blind spot that hid it).
24. ▸ cvagent P0 fix session (parallel session's row): app.facts 500s, oomd at 1G MemoryMax, read-retry loop coupling.
25. ◆ Verify the parallel session landed their cvagent P0-row 15:41 correction (their §f.3; their surface).
26. ★ bank-sync dated .baks (~408 MB) reclaim — owner call on the pool.
27. ◆ Post-storm: watch the IO PSI recovery curve — distinguishes crawl-vs-wedge retroactively and calibrates future wait/horizon math.
28. ◆ If session-26 gets stopped mid-link: check monitor365 `target/` for truncated mold outputs before trusting any subsequent build there.
29. ▸ Feed this session's evidence (495 KB/s aggregate, static PID set, SSH-scope ungated) into the stability-crisis Pareto plan (24e35a515) — the un-gateable SSH battery class.
30. ▸ Boot-signature checklist → AGENTS.md session discipline (two independent data points now: their §d.1 + my §d.4).
31. ▸ Empty-var-zero nuance → extend the quote-scrutiny bullet (AGENTS.md) with the `:?empty` guard pattern (§e.2).
32. ◆ After the push ruling: watch CI catch-up on 28+ commits (nix-check + negative-tests will re-run).
33. ◆ After the push: verify push-stall-watch goes green on its next tick.
34. ◆ After nextd heals: verify the dispatch queue catches up (the next-queue skill's data path).
35. ◆ Coordination: the takeover condition lives only in my addendum — if the parallel session re-arms or re-fires, cross-check `~/.cache/band-deploy2.log` BEFORE any fire (single-deploy invariant).
36. ◆ btrbk 23:10 window interplay: if the deploy lands near it, the band-80 admission + catch-up slot (their §f.2) runs post-switch — do not double-fire btrbk-projects manually.
37. ◆ audiblesync deeper verify: a real sync cycle completes in the journal (healthz alone proves liveness, not function).
38. ◆ immich deeper verify: the takeout-import key authenticates (converger log "existing/created" + one authenticated request) — not just file perms.
39. ◆ monitor365 deeper verify: the MAC-scan output actually returns lines (grant works end-to-end, not just "no coredump").
40. ▸ Upstream relaxation (next dispatch to monitor365 repo): the agent module could ship the kernel-log grant itself (noted in the resolved SECCOMP row).
41. ◆ llama-chat: nothing live to verify (unit config-disabled); the RestartSteps render proof stays the evidence of record.
42. ◆ Watch freeze-#55 risk while the battery drains — if the box cuts again, all timelines reset and the boot-evidence protocol leads.
43. ◆ Post-deploy anchor follow-up: `nix run .#pre-reboot-check` only if any reboot gets planned (none is).
44. ▸ [watch] nextd row trigger review after the nextd fix lands: close it with a verified /refresh 200 tick.
45. ▸ Fold the "one PSI sampler" hygiene (§e.6) into the next session-start checklist when a parallel waiter is detected.
46. ◆ Harvest check at close-out: the [x]-prune pass (TODO_LIST → CHANGELOG) after the battery rows tick — expect WARN-count rise, recount per the prune rule, don't panic.
47. ◆ Gatus: confirm no crash-loop-adjacent checks went stale during the storm window (the storm hid everything at PSI 99).
48. ◆ Session-end tree hygiene: confirm no stray staging left from the pathspec commits.
49. ▸ Re-dispatch verification protocol applies to any re-fired [ready] rows from this wave (docs/CONTRIBUTING.md — five steps).
50. ◆ Final wave close-out: one CHANGELOG line covering deploy + battery + attribution addendum as the wave's record.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Session-26 battery: stop it or let it drain?** It is now draining (96→90 linkers) but at ~495 KB/s aggregate; it gates every deploy, risks freeze #55, and SSH/TTY scopes are outside every gate + the 2026-10-07 license revocation forbids me SIGSTOPping it. Your battery or a dispatch's?
2. **Push the 28+ unpushed commits now?** They include two sessions' undeployed-but-committed work; the push also clears the by-design push-stall-watch failure. GitHub push protection + secret-scan history are wired; the only open question is owner timing.
3. **If the parallel deploy waiter is dead (its log is stale since 18:23) and calm opens tonight: do I fire the deploy myself (my takeover condition), or leave the tree undeployed until you rule?** The wave + repin ride whichever fires first — the question is who owns the trigger while your three other rulings (force/push/alert-leg) are pending.

## Harvest record (self-harvest, at authoring time)

- Already rowed BEFORE this report: runner `[ready]` (TODO_LIST + services.md pair), nextd `[watch]`, bank-sync row update (`2601b517d`); §c addendum (`b4e320760`). The battery remains the `[blocked:deploy]` rows (both surfaces).
- Deliberately NOT harvested: items 1–5/26/42 (owner-gated — no row can act for the owner), 6–9/19/27–28/35–36 (transient tonight-only continuation mechanics, owned by this session's todo list), 30–31 (AGENTS.md edits — separate discipline edits, queued as items here for the next docs pass), 47–48 (session-end hygiene, self-executing). No unrowed durable work remains.
