# Status: Deploy-Chain Unblock, Anchor Repairs, and the DiscordSync Silent Failure — 2026-10-14 14:53 CEST

**Session scope:** unblock the failed `nix run .#deploy` (pasted 12:09 output), get evo-x2 deployed and verified, and chase every failure the deploy chain exposed. Parallel agent session(s) were live throughout (threshold retune, sudo env_keep fix, their own status report `2026-10-14_*-anchor-sudo-envkeep-gate-fix-session-status.md`, bank-sync SCA diagnosis) — attribution is called out explicitly everywhere their work and mine touch.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **io-psi-forensics FOD unblocked** — shellcheck info-findings (SC2012×2, SC2016×2) failed its `writeShellApplication` build; script fixed (ls→`find`, suppressions on intentional self-greps), shellcheck-clean via nixpkgs shellcheck, behavioral selftest OK, selftest check builds | commit 4418f0db; `nix build .#checks.x86_64-linux.io-psi-forensics-selftest` exit 0 |
| a2 | **Gate shim PSI marker fixed** — the parallel session's owner-ratified retune (20→80) moved the script default but left `--replace-fail '{NIX_HEAVY_GATE_PSI:-20}'`; building `nix` aborted on every deploy. Marker now `:-80` (module option still governs the installed value) | commit 92cf5ea3; toplevel builds green |
| a3 | **Trip-history marker fixed** (found by the `--keep-going` enumeration, not by domino) — `{-:...}` was a transposition of bash's `{VAR:-...}` and never matched anything since it landed (40e41469, daemon-swept, never build-tested) | commit 259a7446; live-verified against the built gate file before editing |
| a4 | **Deployed twice, second one stuck** — running generation `hy79p8g5` carries both blocker fixes + the 80% threshold; provisioners converged, gate self-test passed in production (it refused my own smoke run, by design) | deploy logs 12:38 + 13:0x |
| a5 | **tq-agent-pool start-limit sized for the psi-gate contract** — upstream's effective 5-per-300s killed the gate's 30s retry loop after 2.5 min of storm (start-limit-hit 12:41, pool dead); now 40-per-1800s, still bounded, OnFailure intact. Pool verified alive and harvesting after the switch | tq-agent-pool.nix:389-393; journal 13:30 harvest lines; pgrep 1 proc |
| a6 | **DiscordSync resurrected + source fix landed** — the 01:01 db-heal left the recovered DB **root-owned** → service-user SQLITE_READONLY, silent crash-loop 07:04→13:28 (pre-dating this session's deploys). Manual chown + restart at 13:32: ACTIVE since (same PID ~1.4h), 200s on `/` and `/healthz`, projections settled (0 worker crashes/10 min), zero readonly errors. Source fix: both heal recovery paths now chown back to the service user (3rd recurrence of the class: Aug 4, Sep 20, Oct 14) | manual fix via elevated throwaway; commit bb070afc (discordsync.nix) |
| a7 | **Anchor hand-repairs (×2)** — nh's post-switch profile-set runs `sudo … nix build --profile`, sudo strips `NIX_HEAVY_GATE_FORCE`, gate refused it → exit-14 UNANCHORED after both deploys. Repaired per procedure: `sudo env NIX_HEAVY_GATE_FORCE=1 nix build --no-link --profile system <current-system>` + `switch-to-configuration boot`; profile 883 = running gen, verified | /tmp script pattern (trashed after); ANCHORED verification output |
| a8 | **Boot chain audited + mirror refreshed** — pre-reboot-check: 21 passed / 0 failed, SAFE TO REBOOT; boot-mirror-sync restarted after the day's activations (50 entries / 170M, OK) | pre-reboot-check output 13:3x |
| a9 | **Queue harvest (11 rows)** — every §f direct follow-up landed in TODO_LIST.md + the owning domain lib at authoring time (services 6, stability 2, pipeline 3), each with a live-verified Source pointer | commits 8defaf97 (daemon sweep, verified contents) |
| a10 | **AGENTS.md memory block** — deploy-anchor gate interaction, the verified two-step repair, and the `VAR=1 cmd && cmd2` env-prefix gotcha recorded for future sessions | AGENTS.md:143; commit 9012498c |
| a11 | **Daemon-swept lint legs re-run standalone** — shellcheck on both swept `.sh` files after daemon commits bypassed the staged-path legs (house rule; hit twice today) | SHELLCHECK_CLEAN outputs |

## b) PARTIALLY DONE

| # | Item | Gap |
|---|------|-----|
| b1 | **Post-deploy smoke** — full re-run done once under force: tq PASS (recovered), DiscordSync PASS-able (manually fixed minutes later), but the run still carried pre-existing FAILs (FastFlowLM, bank-sync) and I did not drive it to a clean 0-FAIL verdict | FastFlowLM + bank-sync need owner input (see g1/g2); node-exporter journal-rate FAIL is queued (parallel session, monitoring.md) |
| b2 | **The three deploy-wave fixes (env_keep, tq sizing, heal chown) are committed but only partially live** — running gen hy79p8g5 predates the heal chown (live-fixed manually instead) and the sudo env_keep leg (worked around by hand-anchoring). Next storm re-tests everything | queued: services.md deploy+verify rows |
| b3 | **Threshold-80 live verification** — PSI-leg verified (refusal now fires on the trip-recency leg at PSI ~55), but the 80% death-band itself hasn't fired in anger yet | needs a real ≥80% storm or a forced test |
| b4 | **Root-cause of the 01:01 DB corruption** — the *consequence* chain (root-owned recovery artifact → 6h silent failure) is fixed at source; the *cause* of the corruption itself (3rd recurrence) is unprobed | queued (services.md) |

## c) NOT STARTED

- FastFlowLM intended-state decision (retire vs repair) — owner question, not probed beyond confirming unit-exists/socket-dead.
- bank-sync SCA re-approval — human 2FA flow; a sibling session already filed a diagnosis report (`docs/status/2026-10-14_14-53_bank-sync-empty-sca-token-diagnosis-phone-change.md` — phone-change failure mode) while I was working.
- inboxclean-sync + service-health-check standing failures — visible in the 12:09 AND 13:10 failed-unit lists; I flagged them early and then dropped them (see d2). Queued now.
- DiscordSync quarantine graveyard cleanup (~5.3 GB: 4.2 GB Sep 20 + 1.1 GB Oct 14 corrupt copies) — owner-gated, queued.
- The 01:00-01:05 crash-window forensics (what corrupted the DB).

## d) TOTALLY FUCKED UP (mine, honestly)

1. **I destroyed my own best evidence.** Piped the deploy output through `tail -50/60`, so nh's own stderr — including `Failed to set system profile` — was thrown away. That sent me into a long WRONG theory ("nh 4.4.2 skips profile-set") with sourcegraph/fetch archaeology, until the parallel session's queue entry surfaced the real mechanism (sudo strips the gate escape var). The truth was in the first 20 lines I discarded. **Never truncate diagnostic output; tee to a file.**
2. **I dropped two standing failed units mid-investigation.** inboxclean-sync and service-health-check were in the very first failed-unit list I read at 12:09, I noted them, and then never came back. They failed again at 13:10. Only the report-writing pass caught the drop. Queued now — but that's a focus failure, not a discovery.
3. **The env-prefix bug cost me three round trips.** `VAR=1 a && b` only prefixes `a`: the first gate-marker commit failed its hook (transient "lock regression" that was actually the gate refusing the hook's `nix eval`), and my anchor script's verify hardcoded `system-882-link`, producing a false STILL-UNANCHORED on the second repair. Both were my own scripting sloppiness, both fixed live, both now in AGENTS.md.
4. **The daemon swept me three times because I batch.** Editing several files then committing let the auto-commit daemon (a) absorb my work into heuristic commits and (b) sweep parallel-session files into the same commits (665fedb0, bb070afc), which then made safe amends impossible for two of the three. Per-edit pathspec commits would have avoided all three collisions.
5. **I nearly encoded a false upstream claim.** The "nh 4.4.2 skips profile-set" theory was minutes away from becoming a queued upstream item; it would have been a fabricated-premise row (the exact class this repo has a selftest for). Caught before queuing — but only because the sibling session had already documented the real mechanism, not because my own verification loop caught it.
6. **`nix fmt` reformatted five files I wasn't otherwise touching.** Pure formatter churn, but it crossed paths with the parallel session's in-flight gate work and rode commits it didn't belong to. Scoped formatting (`treefmt <files>`) was available and didn't get used until late.

## e) WHAT WE SHOULD IMPROVE

1. **Marker-coupling is a split brain that killed two deploys today.** The gate script's bash defaults and the module's `--replace-fail` patterns must move in lockstep, and nothing enforces it (the parallel session added a selftest tripwire for the sudo leg; the HISTORY marker is still uncovered). Right fix: `@MARKER@` literals substituted unconditionally. Queued (stability.md).
2. **`nix flake check --no-build` is eval-only and that blind spot is structural.** io-psi-forensics passed every eval gate and failed the actual deploy on shellcheck info-findings. Pre-deploy needs a cheap build-class smoke for app FODs (§11b). Queued (pipeline.md).
3. **exit-14 should self-heal.** deploy.sh already detects the unanchored state; the repair is two known commands. Auto-repair (with the gate escape inside sudo) turns a human-loop abort into a one-shot deploy. Queued (pipeline.md).
4. **Three PSI thresholds now exist by design (deploy 20 / tq-gate 30 / shim 80)** — each individually documented, nowhere jointly. One doctrine table so the next retune moves them consciously. Queued (stability.md).
5. **Stormy deploys need two escape vars and nothing says so** (DEPLOY_FORCE_PRESSURE for deploy.sh's gate, NIX_HEAVY_GATE_FORCE for the shim refusing the outer `nix run` and nh's profile-set). Document the pair until the env_keep leg ships. Queued (pipeline.md).
6. **Privileged recovery scripts must restore service-user ownership** — the db-heal class (root writes → service locked out for hours, silently) generalizes: any `+`-privileged ExecStartPre that replaces service-owned files should chown back. Worth an audit across modules. Queued as part of the discordsync row (follow-up).
7. **Multi-agent session hygiene:** the parallel session and I twice edited adjacent surfaces of the same feature within minutes (retune/marker; threshold/selftest). It worked, but the near-misses (my fmt churn riding their commit; my near-duplicate of their queue item) argue for a quick `git log --since` check before touching any file in a feature another session visibly owns.

## f) TOP THINGS TO GET DONE NEXT (up to 50; brainstorm beyond the queued items is ROADMAP fuel — harvest routing applied)

**Queued this session (TODO_LIST + domain libs, live-verified):**
1. Deploy the sudo env_keep leg + verify inheritance (parallel session's row; the anchor class dies with it) — stability.md
2. Deploy + verify the discordsync db-heal chown fix; runbook update; backup timer green — services.md
3. Root-cause the 01:01 corruption (recurrence #3); owner-gated ~5.3 GB quarantine cleanup — services.md
4. Triage inboxclean-sync + service-health-check standing failures — services.md
5. Verify tq start-limit 40/1800 under a real storm (retries ≥20 min, no start-limit-hit) — services.md
6. FastFlowLM: retire-or-repair decision — services.md [decision]
7. bank-sync SCA re-approval (human; sibling session already filed the phone-change diagnosis) — services.md [blocked:user]
8. Gate shim: @MARKER@ substitution replacing default-value markers — stability.md
9. Three-line PSI doctrine table — stability.md
10. deploy.sh anchor self-heal on exit-14 — pipeline.md
11. Pre-deploy build-class smoke for app FODs (shellcheck blind spot) — pipeline.md
12. Document the two-var stormy-deploy escape — pipeline.md
13. go-taskqueue upstream: StartLimitBurst keys are in [Service] where systemd ignores them — upstream.md (verify-before-filing then PR)
14. tq spawn-time PSI gate in the harvest loop (pre-existing row) — upstream.md
15. node-exporter ~360 journal lines/min (§18 standing FAIL camouflage) — monitoring.md (parallel session's row)

**Already live, needs verification only:**
16. Confirm btrbk-forgejo-clean / pbx-backup-pull / discordsync-db-backup stayed green after the deploy's reset-failed (they cleared from the failed list; one journal glance each).
17. Confirm the gate selftest tripwire (parallel session) also covers the HISTORY marker, not just sudo env_keep.
18. Next deploy: confirm exit-0 with NO hand-anchor needed (the env_keep proof).

**Small, high-certainty (not yet queued — pickup candidates):**
19. tq-pool smoke verdict false-fails during restart cascades ("agent pool NOT active" mid-restart) — grace window on the check.
20. DiscordSync smoke SKIP reason ("API binds after thumb-hash backfill") should distinguish backfill-in-progress from dead — it read as ambiguous today.
21. Extend the io-psi-forensics selftest with a shellcheck-clean tripwire so lint drift fails the check, not the deploy.
22. `docs/services/discordsync.md` runbook: add the "root-owned DB after heal" symptom + one-line remedy (folded into item 2's row, listed here so it isn't lost).
23. Audit other `+`-privileged ExecStartPre scripts for the same ownership-restoration gap as db-heal (monitor365 duckdb heal, signoz lock clear are named siblings in the gotcha).
24. the two lock-regression false alarms today (gate refusing the hook's eval) — consider teaching the pre-commit fast guard to retry once with the gate escape and say so loudly, instead of failing as "tarball regression" (misleading error text).

**Brainstorm / ROADMAP fuel (deliberately NOT harvested — no verified ask yet):**
25. IO-tier shaping for nixbld build load (nvme0n1 sat at 95% util through every build wave; ioTier machinery exists).
26. Chronic-storm latch (ACTIVE→CHRONIC sev1 state machine) — already a queued design row; this session's all-day 6-trips/hour pattern is more fuel for it.
27. §17 memory-throttle top offenders (inboxclean-web 1.79M, forgejo 911k MemoryHigh events) — ceiling tuning candidates; counters are since-boot so baseline noise first.
28. Boot-mirror NVRAM reversion #2 still standing (mirror not first in BootOrder) — re-activate + re-decode per AGENTS.md when a reboot window is acceptable.
29. A `docs/services/nix-heavy-builds-gate.md` runbook (the gate now has module + script + selftest + sudo leg + two escape vars; no service doc).
30. Unify the escape-var story long-term: one var, env_keep'd, honored by both gates (depends on 9/12 landing first).
31. docs/status/ corpus is large; a docs-health ANNOTATE pass over 2026-10-14's four+ reports (mine, the anchor session's, the bank-sync one, window-closeout) to cross-link the shared incident chain.
32. Reconsider `nix fmt` scoping convention (whole-tree fmt mid-session churns parallel sessions' files; scoped fmt for in-session edits, whole-tree at closeout).
33. Pre-commit fast-guard error text says "tarball regression" even when the real cause is a transient eval failure — differentiate the two (misdiagnosis cost me a retry today).
34. tq daemon budget message ("30/30 tasks enqueued today") could expose the budget counter as a prom gauge — it would have explained the pool's idle state without journal math.
35. Consider `switch-to-configuration boot` inside deploy.sh's unanchored-recovery path (folded into item 10's design).
36. Add `nh_output` capture-to-file in deploy.sh (`tee /dev/stderr | cat > /tmp/nh-last-switch.log`) so post-mortems stop losing nh stderr — direct cost of d1.
37. Smoke baseline: record the pre-deploy failed-units set and diff it post-deploy (the 12:09 list vs 13:10 list comparison was manual today).
38. The tq `dbPath` env wiring renders a literal path in the unit while `poolSettings` carries it — minor single-source cleanup.
39. Gate refusal message says "NIX_HEAVY_GATE_FORCE=1 nix run bypasses" — add "and export it if you chain commands" (the env-prefix trap hit me twice).
40. Long-term: make the pre-commit nix legs read their eval-expense memo from the cache even under gate refusals (the memo HIT path already skips the eval; the miss path is the one that dies).

(The skill's Top-25 default was exceeded per your "up to 50"; items 25-40 are brainstorm-grade and deliberately not harvested into TODO surfaces — routing rigor per the docs-health HARVEST anti-patterns.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **FastFlowLM:** is it supposed to be running on evo-x2, or is it retired like Ollama (owner directive 2026-10-12)? The unit is enabled, the socket is dead, and every smoke run FAILs on it — I can fix it or remove it and its smoke/guard legs, but the intent is yours.
2. **DiscordSync quarantines:** the DB corrupted identically three times (Aug 4, Sep 20, Oct 14 01:01). Do you want the ~5.3 GB quarantine graveyard kept for forensics or reclaimed — and should I prioritize the 00:50-01:05 crash-window forensics over the queued deploy-wave work?
3. **Deploy timing:** the env_keep + tq-sizing + heal-chown wave is committed but not in the running generation. Given the box tripped the memory guard 6×/hour all day, do you want me to push that deploy through at the next PSI dip (verifying the anchor survives without hand-repair), or hold until the chronic storm subsides?

---

*Report convention note: written as `.md` at your explicit path demand — the status-report skill's canonical format is styled HTML; flagged as a one-off override, not propagated into the skill.*
