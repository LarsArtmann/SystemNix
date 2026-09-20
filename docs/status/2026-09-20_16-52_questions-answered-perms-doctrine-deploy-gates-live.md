# Questions Answered From the Docs — Perms Doctrine Closed, Deploy Gates Live-Validated, One Unanchored Deploy to Re-Run

**Date:** 2026-09-20 16:52 CEST · **Session:** continuation of `2026-09-20_15-02_cv-state-perms-heal-deploy-blocker-fix.md` (15:15 → 16:52)
**Directive:** answer my own 3 open questions by reading ALL `docs/status/2026-09-1*` + `2026-09-2*`, then READ/UNDERSTAND/RESEARCH/REFLECT → execute-and-verify step by step → this report → wait.

---

## 0. Headline

All three questions answered **from source, not inference**. The fast-path/heal-symmetry doctrine
was closed across cv (already landed 14:05) + hermes (landed this session, VM-tested, and
**live-proven**: the heal fired on real child-ownership drift at 16:27:42 that the old root-only
probe would have missed). Three deploy.sh gates landed and were **live-validated** — the guard
trip-recency gate held my deploy ~19 min, the eval gate refused to fire into a parallel session's
broken mid-edit tree, and the terminal anchor assertion caught a REAL unanchored activation
(rc=14). Cost of the session: my own deploy exit-4'd on a hermes start-timeout under its own
build IO → **the system is currently UNANCHORED** (profile system-787 vs current `g118vva3…`),
re-anchor blocked by new Zone-6 trips #654/#655 (16:32/16:46) — earliest clean window ~17:46.

## a) FULLY DONE

1. **Read the full 09-1x/09-2x status corpus** (~105 files: the nine 2026-09-20 reports in full;
   ~55 named 09-1x reports via full-title + headline index with targeted deep reads; ~45 task-*
   queue reports indexed + grepped for CV/assets/PSI signals — the corpus contains NO record of
   the CV assets root-intervention origin; only the three 09-20 docs mention it).
2. **Q1 answered (recurrence semantics, source-verified)**: the assets drift is BOTH structural
   AND one-off. Upstream CV's own fix comment states it: *"store trees are 0555, and a read-only
   synced dir would break the next start's overwrite"* — plain `cp -r` from the nix store
   propagates read-only modes into `$state/assets` at EVERY sync; separately the montserrat font
   dirs were root-owned ("operator root intervention", origin never pinned anywhere). The
   upstream fix is ALREADY on CV master: best-effort `rm -rf … || true` + best-effort `cp -r` +
   **`chmod -R u+w` post-copy**. Bonus: master also carries `goPkg = pkgs.go_1_27` — my FOD
   probe at `048b10733` **passed the go floor** (the AGENTS hold's escape condition is met) and
   failed only on a stale upstream vendorHash (`got sha256-HRIrd53B5PcwN3qcInxrAFBBnbUhQiBvSNaMw5OwcgY=`,
   rev-scoped to 048b10733). A parallel session is ACTIVELY working the CV repo (HEAD moved
   048b10733→e16a235b4 mid-session, go.mod churn 15:41–15:47, hash not yet refreshed) — hands
   off per multi-agent discipline; the probe data point is recorded for them in my addendum.
3. **Q2 answered (my report's claim was stale — corrected)**: `hot-user-caches-go-build-bootstrap`
   no longer exists — the 13:58 session deliberately REMOVED the go-build cache entry (HM
   `mkOutOfStoreSymlink` canonicalization made its automount unloadable, `hot-user-caches.nix:79-92`,
   `deploy.sh:455`); the orphaned 0755 subvol is inert by design. Nothing to start. `cv-scan`
   self-heals at the 18:23 timer tick (the 12:23 failure was the pre-fix dead server).
4. **Q3 answered**: the ~30% io PSI was a live Zone-6 storm tail — trips **#650 13:58, #651
   14:12, #652 15:06, #653 15:17** bracket my 14:08 deploy (freeze-#5 doctrine breach, confirmed
   from the guard journal). Drivers per the docs: geometrikks-era build churn, qemu-aarch64
   emulation, **rogue hermes llama-servers** (PID 805159/805161 holding 8848/8849/8127/8128 —
   user kill-decision still pending), crush-session QLC churn. PSI drained to ~10% by 15:45,
   then RE-stormed during my 16:18 deploy (trips #654/#655).
5. **`cv-state-perms` heal summary journaling** (`cv.nix`): drift count + 3-entry sample before
   the walks, convergence check after (`converged (N entries healed)` / `WARNING — unhealable
   residue`), never fatal. Hit and fixed the `''${var:-default}` Nix-escape trap (flake check
   caught it).
6. **hermes-perms sibling blindspot closed** (`hermes.nix`): `tree_converged()` now runs the
   same find as the heal's chown branch (same `-xdev`, same `workspace/projects` prune, `.ssh`
   included); file-mode drift deliberately unprobed (exec-preserving `X` semantics have no find
   predicate — documented in-module). `bash -n` + semantics probe locally; **VM test
   `.#checks.x86_64-linux.hermes` GREEN** (81.77s, all perms assertions hold).
7. **AGENTS.md doctrine entries**: (1) fast-path/heal predicate-symmetry bullet (with
   symlink-safe `-perm`, CAP_FOWNER cross-ref, heal-summary rule, sibling-audit note); (2) the
   deploy exit-code line extended (rc=12 pressure OR trip-recency, rc=14 unanchored, rc=3 smoke).
8. **deploy.sh three gates**: Zone-6 trip-recency gate (refuse on any guard trip in the last
   60 min — a calm PSI reading inside that window is a dip between trips, not evidence of calm;
   same `DEPLOY_FORCE_PRESSURE` override, exit 12); exit-4 failed-unit dump BEFORE
   `reset-failed` clears the evidence; terminal anchor assertion → **exit 14** (checked after
   all recovery steps so nothing is skipped). `bash -n` + the deploy app derivation built
   (writeShellApplication shellcheck/shfmt gate GREEN).
9. **docs/todo triage**: browser-history empty-batch heartbeat row `[ready]` (the quiet-day 503
   — the one uncovered baseline fail; Bank-Sync SCA + FastFlowLM corpse already tracked);
   xdg-desktop-portal dependency-flap watch row (evidence: 14:22 + 15:56 bursts, "graphical
   user session is inactive" adjacent). `check-todo-system.sh` OK both times.
10. **CHANGELOG**: 3 entries (cv fast-path fix + heal summary; hermes fast-path walk; deploy.sh
    gates + rc surface).
11. **Report addendum** on the 15-02 doc: all question answers, corrections (my fix rode
    `fc49dbe5`, not `34db241a`; go-build moot; fleet state: system-787 anchored 15:06, mirror
    ARMED, pre-reboot-check 23/0, only user reboot pending), follow-on work executed.
12. **Deploy #1 through the new gates (live validation)**: the guard-window waiter held the
    deploy ~19 min (trips #652/#653 in window until 16:17) — the exact refusal my 14:08 deploy
    deserved; the eval gate refused to fire at 16:03 (parallel session's `storage-collector.nix`
    UMask edit was mid-flight broken — priority conflict) and fired at 16:17:57 once the tree
    evaluated; **the anchor assertion caught the real unanchored activation** (`❌ UNANCHORED …
    REBOOT WILL REVERT. Re-run: nix run .#deploy`).
13. **Dismissed-noise items closed with evidence**: `fastflowlm@` instance exits at 14:10-14:12
    = NORMAL per-connection socket lifecycle (socat bridge, ~30s instances deactivating
    successfully); inboxclean-sync 30-min failures = the known user-gated `invalid_grant`.

## b) PARTIALLY DONE

1. **The re-anchor deploy** — the whole point of the new rc=14 instruction, NOT yet executed:
   deploy #1 (16:17:57) activated `g118vva3…` but **exit-4'd on a hermes start-timeout**
   (16:34:02, `hermes-migrate-state` SIGKILLed at the budget under the deploy's own IO churn —
   io PSI avg10 hit 26.8% during activation/smoke) → profile stayed **system-787 = UNANCHORED**.
   Hermes self-recovered via auto-restart (gateway fully live 16:42+, cron delivering,
   mem-trim heartbeats through 16:51). The re-deploy is blocked by trips **#654 16:32 + #655
   16:46** — my own gate demands a trip-free 60-min window, earliest **~17:46**. The waiter
   pattern that did the waiting is documented in this report (inline, heartbeat, no /tmp files).
2. **New gates live-validated, with caveats**: rc=14 is proven by the printed message only —
   my waiter's `DEPLOY_RC=$?` measured `tail`'s exit (0), not the deploy's (pipe artifact,
   see d.1). The trip-recency gate passed legitimately at entry (60-min trip-free) but the
   build's OWN IO re-stormed the box — entry gates are structurally blind to self-inflicted
   pressure (see e.2/e.5).
3. **hermes perms change**: deployed + **live-proven valuable** (the heal fired on real child
   drift at 16:27:42 — "fixing ownership and permissions in /home/hermes" — drift the old
   root-only fast path would have fast-path-exited past), but the first restart timed out
   (10min36s wall vs 6min `TimeoutStartSec`, confirmed by eval) — the cold-cache ownership
   walk + migrate-state stack against the documented load-bearing budget. Restart 2 succeeded
   (~8min wall per journal timestamps — I cannot fully reconcile that with the 6min budget
   from outside; the unit is running, which is the observable that matters).

## c) NOT STARTED

1. The re-anchor `nix run .#deploy` itself (window-gated, ~17:46+; second run should not
   restart hermes — unit file unchanged vs current-system — so it should anchor cleanly).
2. Root-side post-heal confirmation snapshot (`sudo find /var/lib/cv -xdev \( ! -user cv -o
   ! -group cv -o ! -perm -u+w \) -print | head` — expect empty; needs sudo).
3. cv-scan green verification at the 18:23 tick; tonight's 03:30 cv-backup pool receive.
4. The CV flake lock move (owned by the ACTIVE CV-repo session: vendorHash refresh at their
   final rev → push → my recorded probe protocol → `nix flake lock --update-input cv`).
5. Idle-window `nix run .#post-deploy-check` to freeze a new baseline (the Hermes NEW-fail
   ages out; expect CV to drop out once the 18:23 scan runs green).
6. Hermes smoke start-grace (deploy.sh's 10s settle is structurally too short when stc
   restarts hermes — 5-8min start) — design candidate only, see e.3.
7. Hermes `TimeoutStartSec` 6→10min decision (owner call, see g.2).
8. Checking whether the smoke "Hermes" NEW-fail persists in the baseline file (it was a
   mid-restart probe artifact; next smoke should pass it).

## d) TOTALLY FUCKED UP (honest ledger)

1. **The waiter's rc capture was a pipe-discipline violation**: `nix run .#deploy 2>&1 | tail
   -75; echo "DEPLOY_RC=$?"` printed `DEPLOY_RC=0` while the deploy actually exited 14 — `$?`
   measured `tail`. The rc=14 exit is known only from the gate's own printed message. Should
   have used `PIPESTATUS[0]` or no pipe. Ironic: the repo documents this exact class
   (`nix build | tail` masking FOD exit codes).
2. **I deployed into a self-made pressure window**: entry gates were legitimately green
   (60-min trip-free at 16:17), but my deploy's BUILD IO drove avg10 to ~27% during
   activation → hermes start-timeout → the unanchored state I then had to detect with my own
   new gate. The gate design assumed pressure comes from OUTSIDE the deploy.
3. **I did not pre-check the perms walk's cold-cache cost against the hermes budget** despite
   the 12:26 report warning "the hermes start budget is now load-bearing (5m09s vs 6min)". The
   first start timed out. The walk itself completed (migrate started after it), but stacking
   was foreseeable.
4. **My 15:02 report shipped two stale claims** (go-build bootstrap "runs at next boot";
   commit hash `34db241a`) that the docs sweep falsified in minutes. I wrote them from
   session-local memory instead of re-verifying module/commit state — the same
   point-in-time-on-a-moving-system sin the geometrikks session confessed.
5. Minor: my initial guess of the xdg-portal flap window (14:09-14:14) was wrong (actual
   14:22); the smoke's Hermes NEW-fail classification as "transient" was correct but I only
   verified hermes's recovery minutes later, not before writing interim conclusions.

## e) WHAT WE SHOULD IMPROVE (concrete)

1. **Wrapper rc discipline**: any poller/deployer capturing a piped command's status must use
   `PIPESTATUS[0]` (or run unpiped into a file + `tail` the file). Deploy's own rc is now a
   contract (12/13/14/3) — measuring it wrong defeats the contract.
2. **Deploy self-pressure is a real gate hole**: entry gates sample BEFORE the build; the
   build itself can storm the box. Candidate: re-check PSI immediately before `nh os switch`
   (post-build, pre-activation) — activation restarts units INTO whatever pressure the build
   left behind.
3. **Smoke start-grace for slow starters**: when stc restarts a unit with a multi-minute
   start (hermes 5-8min), the 10s-settle smoke structurally fails it. Candidate: the smoke's
   per-service probes treat "activating (start in progress, unit restarted this deploy)" as
   SKIP-with-note instead of FAIL.
4. **Hermes budget**: 6min is now marginal with the ownership walk added (cold-cache). The
   documented knob is `TimeoutStartSec` — 10min trades slower failure detection for fewer
   restart-churn exit-4s (see g.2).
5. **Fast-path probes that add walks should be sized before shipping** (metadata-walk cost on
   a cold contended QLC) — a one-off `time find <stateDir> -xdev -prune ...` measurement
   during review would have flagged the stacking risk.

## f) Up to 50 things to get done next (prioritized, scoped to this session's threads)

1. **Re-run `nix run .#deploy` in a trip-free 60-min window (earliest ~17:46)** — second run
   carries no hermes unit-file change → no restart → should anchor cleanly; verify profile
   bumps past system-787 and rc=0 (or rc=3-only).
2. After anchor: confirm three-way anchor (profile == current-system == default boot entry).
3. Verify the 18:23 cv-scan runs green (first funnel tick on the healed server).
4. Verify tonight's 03:30 cv-backup pool receive (cv-server healthy since 14:08).
5. Idle-window `nix run .#post-deploy-check` → new baseline (Hermes ages out, CV drops if
   scan green).
6. Root-side cv heal confirmation snapshot (c.2) — user or privileged session.
7. CV session handoff: they refresh vendorHash at their final rev → re-probe →
   `nix flake lock --update-input cv` → heal keeps as insurance; upstream `chmod -R u+w`
   then covers future drift at the source.
8. Decide hermes `TimeoutStartSec` 6→10min (g.2) and, if bumped, deploy with the re-anchor.
9. Hermes smoke start-grace design (e.3) — likely a post-deploy-check.sh tweak.
10. deploy.sh pre-switch PSI re-check (e.2) — small, high-value.
11. Wrapper rc discipline (e.1) — fix any remaining `| tail; echo $?` in poller patterns
    (mine was ad-hoc; `~/.local/state/boot-mirror-queue.sh` should be audited for the same).
12. Kill-or-keep decision on rogue hermes llamas (g.3) — frees 4.2G + 20% CPU + closes the
    recurring dark-port pressure source.
13. Post-reboot (user): `bootctl status` PARTUUID proof + pre-reboot-check green + flm
    :52625 corpse cleared + FastFlowLM smoke PASS (baseline shrinks again).
14. Post-reboot: go-build automount absence re-verified (entry removed — no unit should exist).
15. File the browser-history empty-batch heartbeat upstream (the `[ready]` todo row).
16. xdg-desktop-portal flap triage (owner look at which dependency fails; watch row exists).
17. Watch guard Zone-6 behavior overnight: trips #650-655 all today — if the cadence holds
    after the crush-hot-db migration completes, revisit `ioChurnUnits` coverage (the
    recovery-reader class from freeze #6).
18. inboxclean main-account re-consent (user-gated, standing since Sep 4 — every 30-min tick
    fails; the only remaining cause of service-health-check reds).
19. Consider a `system_hermes_start_duration_seconds` textfile metric (start-budget trend was
    invisible until it bit — the 12:26 warning was a one-off measurement).
20. Sweep other heal/fast-path pairs for the symmetry rule (forgejo-subvol-bootstrap,
    clickhouse-xfs-ownership-heal, atticd-storage-dir) — doctrine is in AGENTS.md now; audit
    is mechanical.
21. The parallel session's `storage-collector.nix` UMask fix rode my deploy — verify the
    storage textfile lands 0644 and `node_textfile_scrape_error` stays 0 (their thread, one
    observation from me post-deploy).
22. Bank-Sync SCA approval (user, ~90-day class) — clears the standing baseline fail.
23. After the CV lock move: retire the "CV Pipeline Store Health" wait — no, verify the
    go-health rich-format pattern still matches (rev ≥ ed8b92f already held; the move only
    adds the content-sync fix).
24. Confirm the daemon committed the last docs batch (CHANGELOG/AGENTS/desktop.md were dirty
    pre-deploy; tree showed them committed by 16:5x — hash-range `1e727445..1105ab73`).
25. If a future deploy exit-4s again: the new failed-unit dump makes triage one journal read —
    use it, don't re-derive (the 12:26 session's ask, now shipped).
26. Consider gating the deploy on `pgrep` crush-session count (the recurring storm driver)
    — owner decision, not unilateral.
27. The `2026-09-20_10-21` phantom-deletion incident's remediation (crush-hot-db guard +
    sops-skill git restore) is STILL pending on user design decisions (their g.1/g.2) —
    not mine, flagging visibility.
28. Samsung hot-disk `corrupt 12` triage (their g.3, P0 candidate) — user-gated.

## g) Up to 3 questions I CANNOT figure out myself

1. **Reboot sequencing vs the current unanchored state**: the boot mirror is ARMED and
   pre-reboot-check certified system-787 "SAFE TO REBOOT" — but my deploy left the box
   UNANCHORED (running `g118vva3…` = 787 + today's fixes: cv heal hardening, hermes fast-path,
   deploy.sh gates, storage-collector UMask, geometrikks parallel work). Options: (a) wait for
   my re-anchor (~17:46+ window, minutes) then reboot — boots everything; (b) reboot now —
   reverts to 787 (loses today's afternoon fixes, keeps the certified state). Which do you
   want? (My recommendation: (a) — the fixes include the deploy gates themselves.)
2. **Hermes start budget**: first restart timed out at 6min under deploy IO (migrate-state +
   the new cold-cache ownership walk); restart 2 succeeded. Bump `TimeoutStartSec` to 10min
   (the documented knob), accepting slower failure detection — or keep 6min and accept an
   occasional exit-4-then-recover cycle on contended deploys?
3. **The rogue hermes llama-servers** (PID 805159/805161, since 05:40, 4.2G, ports
   8848/8849/8127/8128, contributing to today's io PSI windows incl. trips #654/#655): kill
   them? They are hermes-user processes I cannot kill from this sandbox, and the standing
   decision from the earlier sessions was yours. `sudo kill 805159 805161`.

---

## Ops state at report time (16:52)

- Profile **system-787**, current-system `g118vva3…` (**UNANCHORED** — reboot reverts; re-run
  deploy at the next trip-free window, earliest ~17:46).
- Hermes: RUNNING (recovered from the 16:34 start-timeout; gateway live, cron delivering).
- cv-server: serving (200s through 15:39); cv-state-perms fast-path converging on restarts.
- Guard: Zone-6 trips #654 (16:32) + #655 (16:46); io PSI avg10 ~30% at report time (storm
  window — the re-anchor deploy is correctly gated shut by my own new rule).
- Tree: clean except a parallel session's `geometrikks.nix` edit in flight; all my work
  daemon-committed (`f4d7bb8a`, `1a4fd1b4`, `5b7506f5`, then `1e727445..1105ab73`).
- Deploy exit-code surface as of today: 12 pressure/trip-recency · 13 lock contention ·
  **14 unanchored** · 3 new smoke failures.

*No secrets. Public-repo rule respected throughout.*
