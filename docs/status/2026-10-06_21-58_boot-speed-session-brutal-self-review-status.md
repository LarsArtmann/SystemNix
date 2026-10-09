# Boot-Speed Session — Brutal Self-Review & Status (2026-10-06 21:58)

**Session:** 2026-10-06 21:11 → 21:58. Trigger: "How can we make boot faster? DEEP research!" then "What did you forget? What could you have done better?" — this report covers ONLY this session's run and what it noticed. Format: `.md` at the user's explicit path demand (status-report skill default is HTML; the operator's explicit instruction wins — override flagged).

**Companion report:** `docs/status/2026-10-06_21-31_boot-speed-deep-research.md` (the work itself, corrected in place 21:55). This file is the honest layer on top of it.

## Self-review answers (the questions asked)

**1. What did you forget?**

- The **CHANGELOG entry** — the repo convention requires one for significant changes; written only during this review (now in `## [Unreleased] → Changed`).
- The **btrbk-rescue VM test blast radius** — I changed `btrfs-rescue-snapshot`'s wiring and never checked whether `checks.x86_64-linux.btrbk-rescue` asserts the old shape. Caught during this review; test inspected (drives the unit manually, line 102) and RUN: **PASS**.
- **`systemd-analyze firmware` unavailability** — mentioned in passing, never explained (needs UEFI FirmwarePerformanceTablet support; folds into the BIOS-walk item).
- The **WAL-gate assumption is unproven on the live host** (see §d2): everything hinges on the hermes gateway checkpointing+deleting `state.db-wal` on SIGTERM shutdown — never verified because it needs the deployed unit + a live restart (drains agent sessions, user-gated).

**2. What is stupid that we do anyway?**

- **The auto-commit daemon commits BROKEN intermediate states**: one daemon commit carries `fsckPass = 0` (an option that does not exist in this nixpkgs) — git history now contains a tree that cannot eval. The daemon also committed past the red `nix flake check` (paperless-gpt) all session. Both are the documented-by-design tradeoffs of the daemon, but "history contains unevaluable trees" is still stupid.
- **Blame numbers get quoted as unit cost** — `systemd-analyze blame` conflates dependency-wait with own-cost (bank-sync 55s ≠ bank-sync's own work; see §d1). We (I) keep reading it as per-unit cost.

**3. What could you have done better?**

- **Eval/journal-verify EVERY config fact before writing it** (two failures this session, §d1+§d2: `Type=notify` and `fsckPass`). Both were written from memory/prior-knowledge instead of one eval command each. The repo's own rule ("a 'verified' label must cover every fact asserted") exists exactly for this.
- **Chase arithmetic impossibilities immediately**: pool-usb-recovery showed 1:33 active at ~2min uptime with an OnBootSec=2min timer — arithmetically impossible. I said "not critical" and dropped it; the udev `SYSTEMD_WANTS` trigger (pool-recovery.nix:214) explains it in 30 seconds and changes the framing (it's a boot-window unit via udev, the ioTier demotion matters MORE than I claimed).
- **Run the blast-radius check of test files in the same breath as the wiring change** (btrbk-rescue above).

**4. What could you still improve?** — see §e/§f.

**5. Did you lie to you?** — **YES, twice, both caught and corrected in-session:**

- "bank-sync.service is Type=notify, event-store replay gates multi-user" — FALSE (Type=simple per eval; pool mounts at 17s; mechanism genuinely unknown). Corrected on ALL THREE surfaces (report §d2/§f3 + TODO_LIST row + docs/todo/services.md row) per the correction-surface rule.
- The implicit claim that `fileSystems.<mp>.fsckPass` exists — it does not in this nixpkgs (`noCheck` is the knob); the first write broke eval until fixed.
  Everything else claimed as verified was actually verified (3 VM test PASSes, toplevel eval, fstab render, timer evals, journal timestamps).

**6. How can we be less stupid?** — Make "assert = verify-first" mechanical: any config fact in a report gets the eval/journal command that produced it INLINE (I did this for ~90% of facts; the two lies were the two I skipped). Chasing-impossibilities: a blame number that can't be reconciled with its trigger source is a FINDING, not noise.

**7. Ghost systems?** No new ones — `hermes-perms-heal` is wired (hermes.wants + VM-tested), the new timers are enabled, deploy.sh references its block. One PRE-EXISTING ghost surfaced by the work: `boot.loader.timeout` micro-win is documented nowhere as a decision — now it's a queued decision.

**8. Scope creep?** Mild and contained: the v2→v3 test-literal drift fix and the paperless-gpt flag were adjacent, justified, and reported. The bank-sync deep-dive was CUT (correctly) once the framing collapsed.

**9. Did we remove something useful?** No — every removal (ExecStartPre walk, boot fsck, boot-gating) preserves its function on a different schedule; convergence cadence is unchanged (verified by the hermes VM test's per-restart assertions).

**10. Split brains?** One risk introduced: the perms-walk semantics now live in TWO comment layers (hermes.nix unit comment + docs/agents/systemd.md doctrine). They were written consistently; drift risk is low but real. Second, minor: `wait_perms_heal`'s count-based journal waits in test-hermes.nix duplicate the marker-string in module + test (a third copy is in the report) — acceptable for a test contract, noted.

**11. Tests?** The session's best habit: 3 real VM tests run to PASS (hermes, crush-hot-db, btrbk-rescue — the last only during review). Gap: NO test covers the WAL-gate branch of hermes-migrate-state (a fresh VM has no state.db; the branch needs a fixture db + `-wal` file). Queued (§f6).

---

## a) FULLY DONE

1. **Full boot measurement + root-cause chain** (firmware 62.5s / loader 2.7s / kernel 1.9s / initrd 5.8s / userspace 115.3s; hermes ExecStartPre = ~97s of it; boot -1 = 584s to multi-user with a 6-min timeout + retry).
2. **hermes perms walk → post-start `hermes-perms-heal.service`** (probe+heal moved as a pair — cv-state-perms lesson preserved; every-start convergence cadence kept; completion markers added; ioTier.build; TimeoutStartSec 10min; RequiresMountsFor; same caps as before).
3. **hermes integrity_check WAL-gated** (unclean-shutdown signal only; clean boots skip the 1.4 GB scan) + TimeoutStartSec 6→3min with rewritten budget comment.
4. **crush-hot-db-migrate + btrfs-rescue-snapshot de-gated** (OnBootSec=2min timers; deploy.sh explicit restart block for crush; audit stays green).
5. **buildcache boot fsck off** (`noCheck = true`; generated fstab verified `0 0`).
6. **ioTier.background on system-health-metrics + pool-usb-recovery.**
7. **Verification battery:** full toplevel eval (all eval-time audits) green; 3 VM tests PASS (hermes, crush-hot-db — with updated contracts pinning the NEW shapes — and btrbk-rescue during review); shellcheck deploy.sh; nix fmt clean; TODO-system checker clean.
8. **Doctrine:** `docs/agents/systemd.md` → "Boot critical-path discipline" (6 rules).
9. **Harvest:** 5 items queued (TODO_LIST + stability/services/pipeline libraries) + this report adds 4 more (§f, marked).
10. **CHANGELOG entry** (written during this review — was forgotten in the main run).
11. **All three bank-sync surfaces corrected** after the self-review caught the lie.

## b) PARTIALLY DONE

1. **Full-repo verification gate:** `nix flake check` could NOT be run green — another session's `test-paperless-gpt.nix` + flake.nix wiring (committed 20:54/21:00:52, before this session) aborts the aggregate eval. Worked around (toplevel eval + per-check evals + VM runs). NOTE: the file was being actively fixed by that session at 21:58 (working-tree modified).
2. **WAL-gate effectiveness on the live host:** implemented + VM-eval'd, but the core assumption (gateway SIGTERM shutdown checkpoints and deletes `state.db-wal`) is unverified — needs the deployed unit (§f6).
3. **bank-sync 55s activation:** measured, framing corrected, mechanism still undiagnosed (§f3).
4. **Impact projection:** "userspace ≤~40s" is an estimate; no calm-boot re-measure exists yet (§f2, [blocked:deploy]).

## c) NOT STARTED

1. Firmware 62.5s leg (BIOS walk — owner-gated, §f1).
2. bank-sync decoupling decision (needs mechanism first).
3. home-manager-lars 46.8s investigation (re-measure first).
4. Loader timeout 2→1 decision (boot-mirror tradeoff — queued §f7).
5. Docker/oci fleet + clickhouse/miniflux/oauth2/gatus calm-boot re-measure (deliberately deferred: storm victims, not gates).
6. initrd 5.8s (deliberately not started: verbose console is freeze-forensics doctrine).

## d) TOTALLY FUCKED UP

1. **The bank-sync lie:** wrote "Type=notify + event-store replay" as FACT into the report and two queue surfaces without ONE eval command. Both halves false (Type=simple; pool mounts at 17s). Violated the repo's own "verified label covers every fact" rule. Caught by this self-review ~40 min later; corrected on all three surfaces with the corrected-mechanism framing. Silver lining: the correction discipline (name the surfaces, show post-state) worked as designed once triggered.
2. **`fsckPass = 0` written from NixOS-docs memory:** the option does not exist in this nixpkgs — eval exploded, and the auto-commit daemon swept the broken state into git history before the fix (`noCheck = true`). Same failure class as d1 (unverified external claim), one level down.
3. **Dropped anomaly:** pool-usb-recovery's impossible blame number got a "not critical, whatever" instead of 30 seconds of grep — the udev trigger explained it and it materially improved the §e framing (ioTier demotion targets a boot-window unit). Small, but exactly the "a contradiction IS the verdict" rule I follow elsewhere.

## e) WHAT WE SHOULD IMPROVE

1. **Assert = verify-first, mechanically**: every config fact in a report carries its producing command inline. Both of this session's lies were facts I "knew" — the dangerous kind.
2. **Blame is not cost**: `systemd-analyze blame` includes dependency-wait. Any future boot/latency work should extract `systemd-analyze critical-chain` + per-unit `Activating→Active` journal deltas before naming a culprit.
3. **Test blast-radius check is part of the wiring change** — check every check that touches the unit's module in the same step.
4. **The daemon's unevaluable-trees problem**: history now contains non-eval-able intermediate commits (fsckPass). Not fixable by me (daemon design), but eval-before-write of option names (fresh API check per nixpkgs bump) eliminates MY contribution to it.
5. **Marker-count test waits** (wait_perms_heal): count-based journal greps desync if the unit restarts unexpectedly mid-test — a `--since @<activation-timestamp>` scoped query would be robust. Low priority, noted in the test.

## f) NEXT THINGS (up to 50; session-scoped)

**Already queued by the main run (pointers, not duplicated):**

1. `[blocked:user]` BIOS boot-time walk — firmware 62.5s (stability.md).
2. `[blocked:deploy]` Calm-boot re-measure — expect userspace ≤~40s (stability.md).
3. `[decision]` bank-sync 55s activation mechanism-first (services.md, corrected).
4. `[watch]` home-manager-lars activation post-storm (services.md).
5. `[watch]` test-paperless-gpt wiring red for the tree (pipeline.md — being fixed by the owning session at 21:58).

**Newly queued by THIS review (§f6-§f9 below get TODO rows):**
6. `[ready]` **WAL-gate falsification check** — after the deploy, on one clean `systemctl restart hermes` cycle: `journalctl -u hermes -b` must show NO integrity-scan output, and `stat /home/hermes/state.db-wal` must be absent post-shutdown. If `-wal` persists across clean stops, the gateway does not checkpoint on SIGTERM → every boot still pays the scan → the WAL-gate is inert and needs a different signal (folds into re-measure row, extended).
7. `[ready]` **Boot-duration textfile collector** — emit firmware/loader/initrd/userspace (from `systemd-analyze` JSON or the boot journal) into the node_exporter textfile dir each boot; a Gatus/trend check on userspace >60s catches the next slow-boot regression (the monitoring layer this work lacked).
8. `[decision]` **Loader timeout 2→1** — ~1s win vs boot-mirror selection window; owner call (stability.md).
9. `[ready]` **hermes-migrate-state WAL-branch VM fixture** — test-hermes.nix gets a state.db + `-wal` fixture asserting the integrity path still fires (and a clean-shutdown fixture asserting the skip) — the only untested branch this session shipped.

**Report-only (deliberately NOT harvested — reasons inline):**
10. bank-sync decoupling options — blocked on §f3 mechanism (row already carries it).
11. pocket-id 11.2s chain floor — re-measure first (covered by §f2 row's promote clause).
12. Docker fleet + clickhouse/miniflux/oauth2/gatus calm-boot re-measure — same promote clause.
13. `systemd-analyze firmware` enablement (UEFI FirmwarePerformanceTablet) — folds into the BIOS walk row at execution time.
14. initrd trim — rejected by doctrine (verbose freeze forensics); ROADMAP at best.
15. wait_perms_heal timestamp-scoped waits — test nicety, fold into §f9 when touched.
16. Split-brain watch: perms-walk comments in hermes.nix vs docs/agents/systemd.md — review-for-drift whenever either is edited (standing, not a row).
17. Daemon pre-commit-leg question — see §g1 (policy, may become a row on the owner's answer).
18. Daemon unevaluable-trees history hygiene — standing known tradeoff, documented here, no action available to agents.
19. The two orphaned hermes-migrate-state PIDs (boot -1 journal, attempt-1 leftovers emitting output at 533s) — D-state/orphan class, freeze-domain owners likely know; noted for the freeze-19 follow-ups, not boot.
20. bank-sync-paperless-token / other provisioners' boot cost audit — only if §f3 shows ExecStartPre-class costs; speculative, not queued.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Does the auto-commit daemon run the pre-commit legs on its commits?** It committed past the red `nix flake check` (paperless-gpt) and past intermediate broken states all session. If it bypasses hooks by design, fine — but then daemon-swept work (including MY fsckPass blunder) never sees the gate, and you may want a nightly "HEAD evals?" catch. If it DOES run them and passed, my model of the daemon is wrong and I'd like to know what it actually runs.
2. **Does the EVO-X2 BIOS expose Fast Boot / Memory Context Restore (or equivalent POST-init reduction) at all?** I cannot read the BIOS from the OS; the firmware leg is 62.5s — a third of the whole boot — and nothing in-repo can shrink it. Also: is BIOS-walking acceptable during the freeze-19 recovery window, or should it wait for thermal/storm stabilization?
3. **When do you want the deploy that carries these changes?** Everything is verified but UNDEPLOYED; the deploy restarts hermes (draining in-flight agent sessions — deploy.sh's own warning) and the next boot is the real re-measure. Your timing call.

---

**Verification appendix (this review's own actions):** bank-sync Type eval (`simple`), pool-mount journal (17.1s), btrbk-rescue VM test RUN → PASS, notify-claim sweep across all 3 surfaces → clean, CHANGELOG + corrections committed by the daemon (no manual commits — harness contract).
