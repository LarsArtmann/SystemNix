# Task 000001a0eaf255cff90e3b85a22accf257e2 — Guard scrub-stop phantom: verify + make the guard cancel scrubs

**Date:** 2026-09-30, session ~03:30–06:30
**Task source:** TODO_LIST storage section (harvested from `docs/status/2026-09-29_01-45_memory-guard-4-fixes-implemented-backup-starvation-catchup-slot.md` §e.2)
**Status at session start:** unstarted (two prior probe attempts by other sessions; one noted "deployed unit has NO ExecStop" — that probe read the WRONG unit, see verdict below)

---

## The work item (verbatim)

> **Guard scrub-stop may be a PHANTOM: `systemctl stop` on `btrfs-scrub@*` kills the CLI waiter, not the kernel-side scrub — only `btrfs scrub cancel` stops the operation (2026-09-28 boot: the scrub slice earned 5.9 TB over hours AFTER trip churn-stops; verify + make the guard cancel scrubs)**

---

## a) FULLY DONE

1. **Full verification performed; verdict CORRECTED.** The churn-stop WAS a phantom, but the claimed mechanism is wrong for this config:
   - The deployed `btrfs-scrub@` template (nixpkgs `tasks/filesystems/btrfs.nix`) already carries the kernel-side cancel: `Type=simple` + `ExecStop=btrfs-scrub-maybe-cancel %f` (a Python helper running `btrfs scrub cancel %f`, tolerating rc=2 "no running scrub"). Verified by reading `/etc/systemd/system/btrfs-scrub@.service` on the live host (system-800): **ExecStop IS present and points at the cancel helper**. The prior session's "deployed unit has NO ExecStop" claim was a misread of the STRAY unit `btrfs-scrub--.service` (which indeed has no ExecStop — it is a snapshots.nix artifact, never started).
   - `systemctl stop` on a correctly-named instance therefore BOTH kills the CLI waiter AND runs ExecStop, which cancels the kernel-side scrub. The claim's premise ("stop only kills the CLI waiter") is true only for a bare `btrfs scrub start -B` or a oneshot unit (where ExecStop is not used — the nixpkgs module comment is explicit: "simple and not oneshot, otherwise ExecStop is not used").
   - **The real bug: unit names.** The guard's `ioChurnUnits` named the STRAY unit files `btrfs-scrub--` / `btrfs-scrub-data` / `btrfs-scrub-mnt-pool` — unit files rendered from snapshots.nix's ExecStart override, which systemd never starts (the weekly timers pull the template instances `btrfs-scrub@-` / `@data` / `@mnt-pool`, confirmed via `systemd.targets.timers.wants` eval and the live service-health listings naming `btrfs-scrub@data.service`). Every trip's scrub stop was a silent no-op — this, not a cancel failure, is why the 2026-09-28 storm scrub read 5.9 TB through ~100 trips.
   - **Sibling bug, same root cause:** the scrubGuard deferral override documented live in AGENTS.md since 2026-08-31 was dead the whole time (same stray attrnames). The weekly scrub that fired into the Sep 26–28 storm ran RAW. This also retro-explains "no completed scrub since Aug 31" in the /data gate-b history beyond the earlier 203/EXEC explanation window.
2. **Code fix landed** (daemon auto-committed as `777fa972`):
   - `modules/nixos/services/memory-emergency-guard.nix`: `ioChurnUnits` now names the three template instances; the churn re-arm EXCLUDES `btrfs-scrub@*.service` (btrfs scrub has NO resume — the stop→drain→re-arm cycle over an oscillating PSI is the freeze-#7 restart loop) with a disclosure line on the re-arm log. A guard-side `btrfs scrub cancel` was evaluated and REJECTED: the guard unit deliberately lacks CAP_SYS_ADMIN (the cancel ioctl requires it) and the template's ExecStop already performs the cancel inside the scrub unit's own sandbox — adding CAP_SYS_ADMIN to the guard for redundancy was judged not worth the escalation.
   - `platforms/nixos/system/snapshots.nix`: the scrubGuard ExecStart override moved onto the template (`"btrfs-scrub@".serviceConfig.ExecStart = lib.mkForce "${lib.getExe scrubGuard} %f"`); `%f` expands to the mountpoint (systemd.unit(5): unescaped instance name with `/` prepended — `@data` → `/data`, `-` → `/`), so the wrapper's `<mountpoint>` argument contract is preserved without script changes. The three stray unit definitions disappear from the config (verified by eval: services list now contains only `btrfs-scrub@` + `xfs_scrub_all`).
   - `tests/test-memory-emergency-guard.nix`: dummy `btrfs-scrub@` template (Type=simple + ExecStop writing a marker file, mirroring the real cancel-on-stop shape); scenario 8 proves the trip stops the INSTANCE and runs its ExecStop; scenario 8a proves the re-arm restarts the balance unit but leaves the scrub instance dead; `reset_state()` restores the instance and clears the marker.
3. **Docs landed** (daemon-committed `31392dbf` + later): AGENTS.md BTRFS §Scrub correction (dead-code admission + stray-attrname lesson), Zone-6 churn-stop semantics paragraph (instance names, ExecStop-cancel mechanism, re-arm exclusion), new Freeze #7 entry; `docs/services/memory-emergency-guard.md` runbook Zone-6 section rewritten; `docs/todo/stability.md` + `TODO_LIST.md` close-outs (this task + the freeze-7 re-arm-exclusion item + the AGENTS.md-freeze-7-entry item) and ONE new [ready] backlog item (eval-time stray-unit lint, queue + library).
4. **Verification of the eval/artifact surface:**
   - `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` green (all eval-time audits over the changed modules: deploy-restart-audit, systemd-shape-audit, port-registry, sops-key-audit, catalog warning only — pre-existing).
   - `nix flake check --no-build` green ("all checks passed").
   - Guard script derivation builds (writeShellApplication shellcheck gate) and the built script verifiably carries the instance names in `CHURN_UNITS`, the `btrfs-scrub@*.service` case-skip, and the disclosure line; `bash -n` OK.
   - Rendered `btrfs-scrub@.service` verified: `ExecStart=<scrubGuard> %f`, `ExecStop=<maybe-cancel> %f`, `Type=simple` (also noted upstream `SuccessExitStatus=1` now present).

## b) PARTIALLY DONE

1. **VM test NOT executed.** The test driver builds green (`checks.x86_64-linux.memory-emergency-guard.driver`), but the run was deferred twice: the host sat in an oscillating IO storm the whole session (io PSI some avg60 16→74% over ~2.5 h of polling; two calm dips of ~6 min were missed by a broken first poller, see §d). Running a qemu VM test into a 50%+ avg60 storm is exactly the reader-stacking class this task's sibling fixes target. **The VM test MUST run before this is considered deployed-quality work** (scenarios 8/8a assertions have never executed).
2. **Footer commit not yet created.** The auto-commit daemon absorbed every file edit within minutes; the one remaining TODO_LIST hunk (this task's AGENTS.md-entry close-out) landed in HEAD `6dce3346` MIXED with a parallel session's papdashboard queue row — amending would absorb foreign work (explicitly forbidden), so the footer commit is deferred until the VM test result adds the last legitimate change to commit alongside the close-out report (this file).

## c) NOT STARTED

- Deploy (owner-run, as always). Deploy notes: the changed template unit file will make stc restart the currently-FAILED `btrfs-scrub@-`/`@data` instances; scrubGuard then re-checks PSI/zram/heavy-readers at start, so a pressured box defers cleanly. Expect the chronic-FAIL exit-4 hazard (01-45 §f.12) at most once; the `SuccessExitStatus=[1]` upstream fix already present further defuses it.
- Live post-deploy verification that a trip's stop actually lands the kernel cancel (first Zone-6 trip with an active scrub; `btrfs scrub status` should show the scrub CANCELLED state, not running).

## d) TOTALLY FUCKED UP

1. **Two broken poller one-liners burned ~50 minutes.** The first had a string-vs-number comparison bug (`awk -v a="avg60=16.42" 'a<30'` compares STRINGS — "avg…" > "30" is false) and MISSED a real calm window (polls 8–10 at avg60 16–18%). The second's awk was mangled by shell quoting (`$$i`) and declared "WINDOW OPEN" on EMPTY values (0<30). The third (grep+cut, numeric compare, 2-consecutive-poll gate) worked but the storm never re-opened. Lesson: dry-run measurement scripts ONCE before trusting their gate; write pollers as file-based scripts, not quoting-sensitive one-liners.
2. **Missed the chance to run the VM test during the first dip** — the broken gate was the cause, but the deeper miss was not sanity-checking the poller's exit condition at t=0 (it should have been self-evidently wrong when poll 1 printed garbled fields).
3. **Git hunk-splitting dance was clumsy** (awk patch extraction failed, sed-range patch didn't apply, the add/remove-row dance left a staged-vs-worktree split needing `git restore --staged`). The correct move — check `git show --stat HEAD` FIRST and only then decide amend vs new commit — was applied eventually but after wasted cycles.
4. **Did not anticipate the daemon race early enough**: committing immediately after each file edit (small pathspec commits) would have avoided every absorb; instead I batched docs edits while the daemon's ~10-min cadence ate them.

## e) WHAT WE SHOULD IMPROVE

1. **A stray-unit eval lint would have caught BOTH bugs** (the guard's churn-list names and the deferral override) — queued as [ready] (docs/todo/stability.md + TODO_LIST). Warning-grade, needs a template/manual-start allowlist.
2. **The "verify the overridden attrname is the unit the timers actually instantiate" check should be a reflex** — one `nix eval ...systemd.targets.timers.wants` (or `systemctl list-unit-files | grep`) before trusting any `systemd.services.<name>` override. Now encoded in AGENTS.md (stray-attrname class).
3. **Agent-session PSI pollers should be repo scripts** (`scripts/`), fixture-checkable, not session-quoted one-liners — two of three failed here.
4. **The multi-agent daemon-commit reality makes per-file immediate commits the only race-free pattern** — batched edits guarantee absorption into heuristic commits.

## f) NEXT THINGS (ranked, in-lane first)

1. **[ready] Run `checks.x86_64-linux.memory-emergency-guard` VM test in the first sustained quiet window** (avg60 < 25 for ≥5 min), then commit the close-out with the task footer. Everything else in this report is already in-tree.
2. **[ready] Deploy** (owner): carries the corrected churn list, the template-mounted scrubGuard, the re-arm exclusion. Watch the first post-deploy Zone-6 trip with an active scrub: `btrfs scrub status` must show CANCELLED (proves the ExecStop cancel end-to-end).
3. **[ready] The new stray-unit lint** (queued this session) — closes the class for good.
4. **[already queued, other lanes]** scrub `Persistent=false` + serialization; root-cause the exit-1-after-"no errors found" FAILED state (a parallel session's lane now carries the `SuccessExitStatus` follow-up); guard silence in the 09:56 boot; trip-rate escalation page; post-freeze storm-drain verification.

## g) QUESTIONS (cannot resolve myself)

1. **VM test timing:** do you want it run the moment a calm window opens (agent-reachable via the fixed poller pattern), or bundled into the next deploy's quiet window?
2. **Was the freeze-7 re-arm exclusion + the `Persistent=false`/serialization half intended as ONE deploy?** They are queued separately; my exclusion is in-tree now — deploying it alone leaves the boot catch-up storm class (§f.2 of the freeze-7 report) open, which is fine but worth knowing before the deploy.
3. **Confirm the CAP_SYS_ADMIN rejection** for a guard-side explicit cancel — I judge the template's ExecStop sufficient; if you want belt-and-suspenders anyway, the guard unit's caps must grow and that is an owner call.

---

**Self-check:** nothing destroyed, no scope creep beyond the sibling freeze-7 exclusion item (required for correctness of the stop fix — the corrected names make the re-arm dangerous, so excluding scrubs is the same change's other half); all queue/library edits drifted-proofed (both files updated in the same change).
