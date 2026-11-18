# Status Report — systemctl unblock for Crush yolo (2026-11-18 12:30 CET)

**Scope line — what this report VERIFIED (live commands, this session only):** typed
`systemctl`/`wget` BLOCK and unblocked `sudo -n true` runs in this v0.101.0 owner-launched
yolo session (probed 11:2x); crush-config commits 08b687a + 3b0b608 pushed and floated into
SystemNix `flake.lock` (python3 lock read: crush-config = 3b0b608); SystemNix commit
3245e3ee2 in history; repo selftests `module-render-defaults` + `format` green (nix build
exit=0); the still-DEPLOYED crushrc contains **zero** `systemctl` (`grep -c` = 0 — the fix
is not live). **NOT verified:** systemctl usable in yolo end-to-end (requires the deploy +
a NEW crush session — this session's config is frozen at start); `-yy`/sysadmin behavior on
v0.101.0 (not probed); whether background job 02A lands the deploy (still running at report
time, PSI-wait phase).

---

## Headline

`systemctl` is now unblocked for Crush yolo sessions **in config** (crush-config 08b687a,
pushed, floated, committed in SystemNix) but **NOT yet live on the host** — the deploy has
been refused twice: once by an I/O storm (rc=12, PSI some avg10 50.65% + nvme1n1 89.2%
util), and the re-armed chain (job 02A) is still waiting on the storm, which got WORSE
(57.15% at 12:30). Meanwhile the truth about v0.101.0 yolo behavior changed vs the
2026-11-07 v0.100.0 truth table and is now recorded version-scoped in AGENTS.md.

---

## a) FULLY DONE

1. **Diagnosis, live-probed**: crush v0.101.0 arms the dangerous-command list in yolo for
   typed lines — `systemctl --version` and `wget --version` BLOCK
   (`blocked: … yolo mode blocks dangerous commands without asking`); the v0.100.0-era
   claim "typed dangerous commands all RUN in yolo" is obsolete.
2. **`permissions unblock` confirmed still functional on v0.101.0**: unblocked
   `sudo -n true` ran typed, rc=0 passwordless, in this owner-launched yolo session.
3. **crush-config fix authored + selftested**: `permissions unblock sudo ssh curl
   systemctl` in `modules/home-manager/crush.nix` (comment rewritten: guard exemption, not
   privilege; v0.101.0 re-verification stamped) + the exact-line grep in the flake
   selftest updated; `module-render-defaults` + `format` checks green (exit=0). The
   rendered rc now carries the new line (verified in the built derivation).
4. **Pre-existing format drift fixed on sight**: `references/lessons.md` backtick
   normalization (from e987de4's lessons commit) that was failing the repo's format gate.
5. **Pushed + floated + committed end-to-end on the config plane**: crush-config 08b687a
   (feature) + 3b0b608 (format fix) pushed to origin/master; SystemNix `flake.lock`
   floated e987de4→3b0b608 (modern `nix flake update <input>` form — the
   `--update-input` no-op trap avoided); SystemNix commit 3245e3ee2 (flake.lock then
   daemon-ridden into 6f8f73965 + AGENTS.md in my commit).
6. **AGENTS.md memory updated (no-loss rewrite)**: the "Yolo sessions differ" bullet is
   now VERSION-SCOPED — v0.100.0 behavior kept as stamped history, v0.101.0 change
   recorded, plus a NEW micro-lesson: a `blocked:` trip aborts the WHOLE typed script run
   and earlier probes in the same command line lose their output (probe guarded names one
   per call).
7. **Deploy raced correctly through a live concurrent session**: another session was
   actively editing eval-relevant files (cv.nix, browser-history.nix, projects-management,
   signoz-packages, flake.nix, repeated flake.lock floats) — used
   `scripts/deploy-when-quiescent.sh` instead of a blind fire; the watcher demonstrated
   35 min of tree stability before firing (a bare fire at 11:35 would have deployed their
   half-done wave).
8. **Daemon-race repairs executed per documented policy**: (a) crush-config: daemon swept
   my staged files into heuristic commit ef0d54a → `git reset --soft origin/master` +
   pathspec recommits (08b687a/3b0b608), tree clean, nothing lost; (b) SystemNix: daemon
   took my staged flake.lock into 6f8f73965 → verified content correct (lock crush-config
   = 3b0b608 at HEAD), left it, my commit carries AGENTS.md.

## b) PARTIALLY DONE

1. **The actual goal — systemctl usable in yolo — is config-complete but NOT live.**
   Deploy attempt #1 fired 12:10:57 after the watcher's quiescence demo and was refused
   rc=12 in 3s by deploy.sh's entry I/O-pressure gate (PSI some avg10 50.65%, disk busy
   71.4%, nvme1n1 89.2% util). Deployed crushrc still has no systemctl (grep = 0).
2. **Re-deploy chain armed (background job 02A)**: bounded PSI-drain wait (60s polls,
   ≤40) → quiescence watcher → `nix run .#deploy`. Still in the PSI-wait at 12:30
   (storm worsening: 39→57%). Known limitation of my chain: after the 40-poll budget it
   proceeds to the watcher even if the storm persists — deploy.sh's gate will then refuse
   again (another classified rc=12, harmless but a wasted cycle).
3. **Verification plan for the live state exists but hasn't run**: after a successful
   deploy — readlink current-system vs newest system-N-link (anchor check), grep the new
   hm_crushcrushrc store path for systemctl, and a typed systemctl probe in a NEW yolo
   session (this session cannot re-load config).

## c) NOT STARTED

1. End-to-end yolo verification of systemctl post-deploy (new session probe).
2. `permissions safe` vs `permissions unblock` on v0.101.0 — the block error message
   advertises `permissions safe`; `unblock` demonstrably still works, but whether `safe`
   is the successor name (or adds semantics unblock lacks) is unresearched. If `unblock`
   is a deprecated alias, the rc line should migrate deliberately, not by error-message
   suggestion.
3. `-yy`/sysadmin mode re-probe on v0.101.0 (does the backstop drop still hold?) —
   flagged as "not re-probed" in AGENTS.md.
4. macOS (Lars-MacBook-Air) side of the same rc change — the crush-config module is
   shared, but this session deployed/considered only evo-x2; the darwin rebuild cadence
   is the owner's (see question g3).
5. Status-report §f harvest into TODO_LIST/domain libraries — deliberately NOT harvested
   this time (owner instruction: report then wait; several items' shape depends on the
   deploy outcome). Per the self-harvest policy this is recorded here as a deliberate
   non-harvest; harvest should happen in the follow-up session once the deploy resolves.
6. Session-start boot-id pin (reboot-signature checklist) — never done this session; no
   discontinuous readings occurred, so it cost nothing, but it was skipped, not applied.

## d) TOTALLY FUCKED UP

Nothing at the data/state level — every mis-step was caught and repaired in-session, and
the surviving tree state is exactly the intended one. Ranked honestly by how badly it
could have gone:

1. **A blocked command poisons a whole multi-probe call (self-inflicted, then
   memory-ized)**: my first guard probe packed `sudo` + `ssh` + `wget` into ONE bash
   call; wget's block aborted the run and the sudo/ssh evidence vanished, nearly sending
   me to "empty read" conclusions about unblock. Recovered by one-command-per-call.
   AGENTS.md now carries the lesson — but the near-miss itself was mine.
2. **The crush-config commit I "made" never landed**: chained `git add && git commit
   (heredoc) && git commit (second)` in one call; the heredoc commit silently produced
   nothing while the daemon swept my staged files into heuristic commit ef0d54a — I
   discovered it only because the follow-up `git log --grep` came back empty. The
   2026-11-10 lesson (verify `git log -1` between edit and commit; single-call chaining
   is the daemon's race window) was IN MEMORY and I repeated the pattern anyway.
3. **A garbage verdict shipped mid-session**: `find … | head -5; echo HOT || echo COLD`
   prints HOT unconditionally (echo always succeeds) — the HOT/COLD line was meaningless;
   only the empty find output (accidentally correct) saved the reading. Exactly the
   quote-scrutiny class the AGENTS.md warns about (validate one known value through the
   pipeline).
4. **Armed my quiescence watcher without checking for sibling watchers first** (the
   DISARM-LIST discipline exists precisely for this); a second armed sequencer (PID
   1774032, gone by the time I looked) was firing in the same window — the two-watcher
   race class from 2026-10-28 was one coincidence away from replaying.
5. **The first fire hit an I/O storm because the watcher deliberately does not gate
   pressure** — by design deploy.sh owns that gate, but my chain could have pre-waited
   for PSI the first time (it only does on the second attempt, and even there the 40-poll
   budget can expire into a still-storming fire).

## e) WHAT WE SHOULD IMPROVE

1. **Watcher + pressure are a split brain**: `deploy-when-quiescent.sh` demos tree
   stability, deploy.sh gates pressure at fire — the gap between the two produced today's
   rc=12. Either teach the watcher an optional PSI pre-gate (clearly marked as
   duplicating deploy.sh, off by default) or document the expected rc=12-then-rearm loop
   as the contract.
2. **The 40-poll PSI budget falling through to a doomed fire**: after budget expiry the
   chain should arm the watcher with a pressure-conditional (skip firing while PSI ≥ 20)
   or exit with a classified "still storming" code instead of guaranteed rc=12.
3. **Commit-then-verify discipline**: every `git commit` in a daemon-active repo should
   be followed by an identity check (`git log -1 --format='%H %s'`) in the SAME command,
   not chained blind. Today's repair worked because the policy existed; it shouldn't have
   been needed.
4. **`unblock` vs `safe` needs a version-policy decision in crush-config**: pin the
   supported verb per crush version in the module (a comment is not a mechanism).
5. **Probe hygiene**: guarded-name probes one per bash call, always — codified in
   AGENTS.md today; future sessions should not relearn it.
6. **Yolo truth tables need version stamps by construction**: the 2026-11-07 report was
   accurate and still misled (it described v0.100.0; the binary moved). Version-scope
   every behavioral claim at write time (AGENTS.md bullet now does).
7. **crushrc applies only at session start** — sessions needing a mid-session config
   change (like this one proving the fix) should say so explicitly in their verification
   plan instead of probing the old config and confusion.

## f) Next things to get done (session-grounded, priority-ordered)

1. Land the deploy (job 02A or a manual re-fire once PSI < 20%) — THE unblocker.
2. Post-deploy anchor check: `readlink /run/current-system` == newest `system-N-link`
   (ls -V form, never mtime); repair ladder if unanchored.
3. Verify the deployed crushrc store path contains
   `permissions unblock sudo ssh curl systemctl` (grep the new hm_crushcrushrc).
4. New-session yolo probe: typed `systemctl is-active …` runs (end-to-end proof).
5. Decide `unblock` vs `safe` for v0.101.0+ (read crush source or probe both rc verbs);
   migrate the rc deliberately if `safe` is the successor.
6. Re-probe `-yy`/sysadmin backstop behavior on v0.101.0; stamp the AGENTS.md claim.
7. Fix the 02A chain's fall-through: watcher should not fire while PSI ≥ 20 (edit
   deploy-when-quiescent.sh or wrap it).
8. Teach deploy-when-quiescent.sh an optional `--psi-gate` (or document rc=12-rearm as
   the contract) — close the watcher/deploy.sh split brain.
9. Add commit-identity self-check to the pre-commit hook path (post-commit `git log -1`
   echo) so daemon races surface immediately in tool output.
10. Update the yolo truth-table status report
    (`docs/status/2026-11-07_01-24_crush-v100-yolo-live-verification.md`) with an
    ANNOTATE-mode header pointing at the v0.101.0 re-verification (don't rewrite it).
11. Sweep other docs for stale v0.100.0 yolo claims (`rg -l 'yolo' docs/ AGENTS.md`) —
    AGENTS.md is done; docs/agents/* and service runbooks may quote the old truth table.
12. Harvest this report's §f into TODO_LIST.md + docs/todo/ once the deploy resolves
    (deliberate non-harvest recorded above).
13. Consider whether `ip` (verified live-probe set member) and other routine guarded
    names belong on the unblock line — same policy question as systemctl, owner decides.
14. crush-config: extend the module selftest to assert the unblock line's NAME SET (not
    just the exact string) so the next verb addition can't desync module + selftest.
15. Record in SystemNix AGENTS.md (or the crush rc module) that rc changes need a NEW
    crush session to take effect — mid-session probes of a just-deployed rc read the
    old config.
16. Evaluate whether the second watcher (PID 1774032) belonged to the concurrent session
    and whether that session's deploy intent collides with mine (check .crush/crush.db
    session messages for it) — avoid two sequencers next time.
17. Re-check `docs/todo/services.md` / relevant domain library for a row tracking the
    crush yolo/systemctl change (none was added this session — the change rode commits
    only).
18. After the deploy: watch the first post-deploy crush session start for rc-load errors
    (the unblock line syntax is proven, but any hook/env regression shows at session
    start).
19. Confirm the other session's four committed waves (e98f7e4b7, a2ae6b3f3, dda3c37ea,
    e2789df2a) deploy cleanly together with mine — the 12:1x quiescence demo covered
    their committed state, but nobody has built the union toplevel yet (the green-eval
    pre-gate did pass at 12:10:19, pre-dating their last floats).
20. macOS: schedule the darwin rebuild that picks up the same crush-config float
    (owner-cadence, see g3).
21. If storms like today's recur during deploys: consider a PSI drain-loop as a
    deploy.sh entry retry (bounded) instead of a hard refuse — owner decision (freeze
    risk policy).
22. Add the "blocked: trip aborts the whole probe line" trap to the bash-trap-remediation
    hook's remediation hints (it already has kill/PSI hints; this class is new).
23. crush-config README: document `permissions unblock` with the v0.101.0 behavior
    change + `safe` question (currently only the module comment carries it).
24. Consider a periodic (weekly?) crush-version probe that diffs dangerous-list
    behavior against the documented truth table — today's surprise was a silent upstream
    behavior change across a minor version.
25. Clean up my two `~/.cache` log artifacts (`crushcfg-check*.log`,
    `deploy-quiescent-systemctl*.log`) into the session record or delete them.
26. Verify the 12:1x fire's §0.5 advisory / battery didn't leave partial state
    (`/var/log/systemnix-deploys/2026-11-18_12-10-58.log` shows refusal at ENTRY gates —
    no build started, nothing to clean, but confirm no §11 stamp residue).
27. Re-run `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`
    freshness check immediately before the next fire (drv-equality cheap probe from the
    AGENTS.md playbook) — the other session's post-12:10 commits may have changed the
    toplevel since the green-eval pre-gate.
28. When the storm session finishes: check what it floated in flake.lock (its repeated
    floats at 11:54–12:01 touched keys I never inspected — only verified MY key
    survived).
29. Add a TODO row for the crush-daily schedule unit (seen in the pgrep list) — confirm
    it doesn't fight the rc mid-day (it spawns sessions that would read a half-deployed
    config only in a deploy window; benign but unverified).
30. Consider adding systemctl to the AGENTS.md "verified live-probe set" header line
    (currently the set predates the unblock: ss/journalctl/busctl are listed; systemctl
    becomes a first-class probe verb post-deploy).

## g) Questions I cannot answer myself

1. **Deploy intent collision**: another session (nine `crush -y` sessions are live) was
   committing service-module waves AND arming its own quiescence watcher in the same
   12:0x window. Is that session YOURS with its own deploy plan for its wave — and if
   so, should my systemctl deploy deliberately ride AFTER theirs (their battery first,
   mine second), or is first-quiescent-wins acceptable?
2. **Pressure policy**: if the I/O storm persists past job 02A's budget, do you want
   `DEPLOY_FORCE_PRESSURE=1` used to land the systemctl rc anyway (accepting the
   freeze-risk the gate warns about — both 2026-08-22 freezes had builds as contributing
   load), or should the deploy keep waiting indefinitely?
3. **Scope of the unblock**: the crush-config change is global (darwin consumes the same
   module). Do you want the MacBook rebuild triggered to pick it up on a defined cadence
   (and from where), or does darwin follow its own rebuild rhythm where this rides the
   next natural activation?
