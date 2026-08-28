# Status Report: atticd-bootstrap exit-4 fix during DAS outage (2026-08-24 08:02)

Session scope: one user prompt ("Fix?") with an SSH transcript showing
`nh os boot`/`nh os switch` completing the BUILD but failing ACTIVATION with
exit 4 on `atticd-bootstrap.service` (connection refused to 127.0.0.1:8200).

---

## a) FULLY DONE

1. **Root-caused the exit 4 — NOT a config bug.** The DAS USB link is
   physically down: `lsblk` shows ONLY the NVMe + zram (zero USB storage on
   the bus; kernel log has no storage enumeration this boot, only HID
   devices). Therefore: `/mnt/pool` never mounts (fstab waits on missing
   by-id members) → `atticd-storage-dir` dependency-fails → `atticd`
   dependency-fails → `atticd-bootstrap` (only `Wants=atticd.service`, so it
   still runs) burns 30s against a dead port and hard-fails →
   switch-to-configuration exit 4. Every ~32min retry noise in the journal is
   the `atticd-size-guard` timer correctly skip-degrading (not a start loop).
2. **Ran the documented DAS diagnostics runbook**
   (`scripts/das-link-recovery-check.sh`, read-only, no sudo): verdict
   **LINK DOWN — software recovery impossible**; 13 issues; all four known
   disks absent from by-id; buildcache automount armed but backing device
   absent; NO ext4 damage lines this boot or the previous one; cache
   symlinks intact; flagged ~11.3 GB of NVMe fallback caches
   (gocache 8.5G, gomod 2.3G, gobuild 468M) as user-decision-pending.
3. **Fixed the activation blocker**
   (`modules/nixos/services/attic.nix`): `atticd-bootstrap` now carries
   `unitConfig.ConditionPathIsDirectory = [ cfg.storagePath ]`. The storage
   dir is created ONLY by the mount-gated `atticd-storage-dir`, so its
   absence == pool absent == atticd intentionally down → clean SKIP
   (result=condition) instead of a failed unit blocking every switch during
   DAS outages. This bit BOTH 2026-08-22 and today.
4. **Kept real failures loud**: added a post-wait-loop readiness assertion to
   the bootstrap script — pool mounted but atticd wedged now exits 1 with
   "atticd did not become ready … check journalctl -u atticd.service" instead
   of an opaque `error sending request` from a later attic client call.
5. **Closed a 3-week-old dangling TODO** (archived 2026-08-02 attic bring-up
   doc, item 31): added `atticd-bootstrap` to the deploy.sh provisioner
   restart loop, so a condition-skipped bootstrap re-runs (converges) on
   every deploy — after DAS recovery one deploy (or reboot) brings the cache
   back without manual action.
6. **Regression test added** (`tests/test-attic.nix` step 9): removes the
   storage dir to simulate a detached DAS, restarts the bootstrap, asserts
   `ActiveState=inactive` + `ConditionResult=no` + journal `unmet condition`
   line + NOT failed. Documents the trap that `Result=` is unreliable across
   restarts.
7. **VM test green** (9/9 checks, 18.9s).
8. **`nix flake check --no-build` green** (ran BEFORE the test-assertion fix;
   the fixed test then built+ran successfully, which re-proves eval).
9. **Deployed via `nix run .#deploy`** (the sanctioned path — the user's
   manual `nh os switch` was fine but bypasses post-switch convergence):
   generation **system-719**, activation CLEAN — no "units failed" warning,
   bootstrap journal shows `skipped, unmet condition check
   ConditionPathIsDirectory=/mnt/pool/services/atticd/storage`.
10. **Classified all 9 post-deploy smoke FAILs** as the same DAS-dependency
    class (immich ×2, bank-sync ×3, attic ×1, paperless ×1 — all
    "Dependency failed" on the absent pool) + 1 pre-existing data question
    (Crush Daily 2026-08-23 = 0 sessions). None caused by this deploy.
11. **AGENTS.md corrected**: stale claim "Pool-dependent units
    (atticd-bootstrap, …) fail as designed" replaced with the new skip
    semantics + the `Result=` test trap.
12. `nix fmt` on touched .nix files: 0 changes needed. Auto-commit daemon
    landed the work as `511af7df` (module fix) + `84865dca` (test robustness);
    AGENTS.md edit pending pickup. Concurrent session's commit `9be027c8`
    (SIGKILL Go cache probes / SDDM) flagged, not touched.

## b) PARTIALLY DONE

- **End-to-end verification of the FIX's happy path**: the skip path is
  proven live and in the VM; the actual bootstrap success path after DAS
  return is NOT yet verifiable (needs the pool back). The deploy.sh restart
  line ("Restarting provisioner: atticd-bootstrap.service") was not
  explicitly confirmed in the deploy output (I only tail'd the last 60 lines;
  the provisioner loop runs before post-deploy-check).
- **Readiness probe refactor**: the loud-fail check duplicates the inline
  python3 probe verbatim (loop copy + post-loop copy). Works, tested, but is
  copy-paste; a single probe function would be cleaner.

## c) NOT STARTED (deliberately out of scope this session)

- Physical DAS recovery (user-only: reseat + power-cycle).
- Investigation of Crush Daily 0-sessions (flagged, unverified hypothesis:
  crash-era data gap).
- The runbook's sudo shadow triage ([6] root-only dirs under
  `/mnt/btrfs-root/@/mnt/pool`).
- Decision on the 11.3 GB NVMe fallback caches.

## d) TOTALLY FUCKED UP (honest ledger)

1. **First VM test run failed on a wrong assertion** — I asserted
   `Result == "condition"` without knowing that `systemctl show Result`
   RETAINS `success` from the pre-restart run across a `restart`. Cost one
   full build+VM cycle (~3 min). Lesson: verify systemd property semantics
   before encoding them in an assertion; the journal DID show the skip
   working the whole time.
2. **Tried `systemctl` twice against my own sandbox ban** (first bash call
   rejected). Should have started with journalctl/findmnt; wasted a round
   trip.
3. **Globbed for `atticd*.nix`** — file is `attic.nix`. Trivial, but a
   `grep atticd-bootstrap` from the start would have been one step.
4. **Ran the VM test WITHOUT the `heavy-job` wrapper** — AGENTS.md says wrap
   NixOS VM tests in it (slot-counting admission). Memory was healthy
   (50 GiB free, PSI 0.00) so no harm, but the documented practice was
   skipped.

## e) WHAT WE SHOULD IMPROVE

1. **Activation-blocking audit**: any oneshot with `wantedBy=multi-user.target`
   whose success depends on a mount-gated service can block every switch
   during an outage. The ConditionPathIsDirectory pattern should be applied
   to the whole class (systematic sweep, not incident-driven patching).
2. **Bootstrap convergence is deploy/boot-triggered, not mount-triggered**:
   if the DAS is replugged and pool mounts at runtime WITHOUT a deploy or
   reboot, `atticd-bootstrap` stays skipped. Acceptable today (the documented
   DAS recovery path IS a reboot), but a `PathExists`-style or udev-triggered
   re-arm would close the gap. Beware the known `PathExists` re-fire trap —
   would need `PathChanged` semantics review first.
3. **Deploy output verification discipline**: assert the expected
   "Restarting provisioner: …" lines appear, don't just tail.
4. **VM tests in this repo should get a `heavy-job` wrapper by default** when
   run outside CI (memory-pressure machine, documented livelock history).
5. **Post-deploy-check could classify dependency-failures as SKIP with a
   single root cause** ("pool absent → N services down") instead of 9
   individual FAILs — during an outage the signal-to-noise is poor.

## f) NEXT THINGS (session-derived, priority order)

**Physical recovery (blocks everything pool-side):**

1. Reseat DAS USB cable AND enclosure power connector
2. Power-cycle reboot (~10s off — warm reboot may not re-enumerate; NIC-vanish
   precedent)
3. Re-run `bash scripts/das-link-recovery-check.sh` — expect [1][2][3] green
4. Re-run it with `sudo` for the full shadow triage ([6])
5. Verify buildcache self-healed (`buildcache-usb-recovery.service` status)
6. If the runbook flags ext4 damage on sda1 in either boot: run its printed
   e2fsfsck command, then `systemctl start buildcache-init.service`

**Post-recovery verification (self-healing expected — confirm it):**
7. `/mnt/pool` mounted, BOTH Toshiba members present; `btrfs device stats`
clean
8. smartd re-enumerates both MG08 members (`-d sat`)
9. `atticd-bootstrap` runs green (deploy.sh restart converges it after the
reboot automatically)
10. `curl http://127.0.0.1:8200/` answers; `https://cache.home.lan/` 200
11. immich / paperless / bank-sync services active; their vHosts 200
12. bank-sync first successful sync lands (WARN today: no successful sync yet)
13. `btrfs-verify-pool-backups` green on next daily run
14. btrbk pool snapshot cycle resumes (23:45) without garbled targets

**Decisions pending (user):**
15. 11.3 GB NVMe fallback caches: keep while DAS is down vs quarantine/remove
(gocache 8.5G, gomod 2.3G, gobuild 468M — NOT in the recovery reap list)
16. Crush Daily 0-sessions on 2026-08-23: investigate vs accept crash-era gap
17. One-member pool mount (`-o degraded`) if a Toshiba is actually dead —
never automated, always a user call

**Code hardening (small, bounded):**
18. Deduplicate the python3 readiness probe in atticd-bootstrap (single
helper, used by loop + post-loop assertion)
19. VM test case: pool mounted but atticd wedged → bootstrap exits 1 with the
clear message (covers the loud-fail path I added)
20. Sweep for OTHER activation-blocking oneshots behind mount-gated deps
(grep `wantedBy.*multi-user` + `RequiresMountsFor` in same unit); apply
the condition-skip pattern where semantics allow
21. post-deploy-check: collapse dependency-failure cascades into one
root-cause SKIP/FAIL with a count
22. deploy.sh: echo a checkable marker after the provisioner loop (or grep
its own log) so restarts are verifiable post-hoc

**Smoke-noise follow-ups noticed this session (pre-existing, low priority):**
23. fish startup 3049ms (threshold 200ms) — WARN every deploy
24. quickshell: 1 error line in the last hour (WARN every deploy)
25. Confirm sev1-bridge actually surfaced the DAS-link condition during this
outage (it evaluates DAS-link; the user should have seen the overlay —
worth one journal check)
26. Confirm Discord got the "Attic Binary Cache" Gatus alert (journal showed
success=false at 04:42)
27. New timers that started with system-719 (sev1-bridge, kdump-retention,
clickhouse-xfs-metrics): spot-check one firing each
28. Crush-daily session-count metric: if 0-sessions recurs on a calm day,
escalate to a real investigation

## g) QUESTIONS FOR THE USER (cannot be answered from the repo/system)

1. **When do you plan to physically reseat the DAS + power-cycle?** Until
   then immich, paperless, bank-sync, the attic cache, and all pool-side
   backups stay down (monitored + alerting, but down) — and every `nh os
   boot/switch` you run will still build fine but should now ACTIVATE clean
   too, so no pressure from my side; just want the recovery window.
2. **The ~11.3 GB of sibling-session fallback caches on the NVMe**
   (gocache/gomod/gobuild): keep them while the DAS is down as a deliberate
   NVMe build cache, or quarantine/remove them? The NVMe is the
   space-critical device and they are NOT in any automated reap list — your
   call, documented as pending in the runbook.
3. **Crush Daily's 2026-08-23 report shows 0 sessions** — a silent-zero-data
   FAIL in post-deploy-check. Plausible crash-era gap, but I can't distinguish
   "chaos day, no data" from "real regression" from inside the repo: should I
   dig into crush-daily's journal/history once the pool is back, or do you
   already know the machine was effectively unusable that day?

---

**Bottom line:** the exit 4 was a hard-infrastructure symptom (DAS physically
offline) meeting a unit that turned "service intentionally down" into
"activation failed". The unit now degrades correctly; activation is clean
(system-719); everything else that is red is red because the disks are
unplugged from the bus, and the recovery runbook + monitoring are already in
place for when the hardware comes back.
