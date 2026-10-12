# 2026-10-12 13:40 — Boot-time dispatch: "boot is slow" measured, root-caused, four boot-path fixes landed

Owner question: *"Boot is slow; should I enable Fast Boot in the BIOS?"*
One agent session among several (parallel sessions were root-causing the crm
PocketID outage + the dnsblockd startup hang — both reports same day — and
driving the session-long IO storm with go test / nix builds / an image batch).

## a) Fully done

1. **Measured, not vibes.** Boot 0 (13:05:41): `14min 19.244s` = firmware
   `1m02.654s` + loader `4.036s` + kernel `1.909s` + initrd `13.329s` +
   **userspace `12m57.314s`**. Chronic (boots -4/-2/-1): firmware is a FLAT
   62.6-62.7s every boot; userspace swings 2min → 15min. Fast Boot verdict:
   only lever for the firmware minute (~4% of this boot); userspace is the
   storm, not the firmware.
2. **Userspace anatomy (blame + critical-chain + journal, IO-storm-aware):**
   - `llama-chat` = the multi-user critical path: attempt 1 burned 8min04s in
     the ExecStartPost /health probe (240 × 2s retry budget exhausted at
     exactly 8min while the 23.4G model page-in starved) → status=22 →
     Restart=on-failure → attempt 2 remapped for 4m36s more. ~13min of boot
     path from one unit.
   - `pool-usb-recovery` 12m44s wall / 193ms CPU: converge_consumers'
     BLOCKING `systemctl start` serialized it behind the slowest consumer
     (discordsync), and the held flock suppressed concurrent runs for the
     whole window.
   - `discordsync-db-heal` 12m44s wall / 193ms CPU: GB-scale
     `PRAGMA integrity_check` starved on the QLC root.
   - `clickhouse` 10m52s starting (state findmnt-verified on the QLC root
     subvol `nvme0n1p6[/@]`) + `crush-hot-db-migrate` 10m2s = the storm's eye
     and its timer-fed log-walk.
     **CORRECTION 2026-10-12 17:4x:** the findmnt above was misread — live
     state is `/dev/nvme0n1p9`, a DEDICATED 100G XFS partition on the SAME
     QLC disk (not the root btrfs subvol). Same NAND, same storm conclusion;
     different migration shape (partition copy, not subvol move). The
     storage.md relocation row carries the corrected premise.
   - `btrfs-compsize` OnBootSec=5min fired INTO the storm and timed out
     (530ms CPU over 2m08s wall) → OnFailure noise.
   - `forgejo` restart-cascade: its `maxAttempts = 30` override (60s DNS-gate
     budget) predates and undid the 2026-08-31 180s library default raised
     for exactly this box; failed 5× + start-limit-hit on this boot
     (compounded by the dnsblockd startup HANG found by the parallel session —
     see that report; the 180s gate absorbs slow blocklist loads, the hang
     needs its own fix).
3. **Four fixes landed (eval `nix flake check --no-build` green, all audit
   gates pass; deploy PSI-gated at write time):**
   - pool-recovery.nix: consumer starts → `systemctl start --no-block`
     (convergence guarantee kept: jobs enqueue, failures surface in journal).
   - btrfs-health.nix: compsize OnBootSec 5min→30min + TimeoutStartSec
     120s→10min (timeout must tolerate contention, not race it).
   - forgejo.nix: both DNS gates drop `maxAttempts = 30` → inherit 180s.
   - llama-chat.nix: ExecStartPost `--retry 240→400` (~13.3min budget inside
     the 15min TimeoutStartSec; attempt = instant while 503ing).
   - systemd.md gotcha added: converger oneshots that start other units must
     use `--no-block`.

## b) Verification status

- Eval: full flake check green (incl. gate-timeout-audit, deploy-restart-audit,
  systemd-shape-audit, memory-watermark-audit).
- treefmt on the four files: 0 changed.
- Pre-deploy suite: 78 passed / 0 failed, twice. First attempt correctly
  blocked by the PSI gate (real storm, other sessions' builds — waited ~35min
  for drain); second attempt blocked by the PHANTOM leg (PSI 53% with disks at
  1.0% busy) — verified the documented corpse-pile class before overriding:
  0 D-state processes across 3 scans, all devices ≤1% util, rust-cache
  automount healthy on /dev/sdc1 → `DEPLOY_FORCE_PRESSURE=1` (the classifier
  gap itself is the standing stability.md phantom-PSI row).
- First switch landed but left the profile UNANCHORED (reboot would revert);
  re-ran deploy → **profile generation system-876 anchored**.
- Post-switch live asserts, ALL GREEN: is-system-running=**running** (not
  degraded), zero failed units; compsize TimeoutStartSec=10min + timer
  OnBootSec=30min; llama-chat ExecStartPost `--retry 400` rendered;
  forgejo-wait-dns store script `seq 1 90` (180s budget);
  pool-usb-recovery store script `systemctl start --no-block` ×2.
- Post-deploy smoke: 146 PASS / 3 FAIL — all three triaged as not-mine/
  not-regressions: (1) nix-daemon 1479% CPU = parallel sessions' builds
  (transient); (2) node_exporter 317 lines/min = the two textfile-collector
  defects ALREADY FILED by the freeze-28 session (monitoring.md:20);
  (3) bank-sync sync_errors_total>0 "since restart" = restart-transient,
  ZERO errors in the 15min after, unit active.
- The TRUE verdict is the NEXT boot's `systemd-analyze`: userspace should drop
  the llama-chat 8min wasted-restart cycle, the compsize timeout, and the
  converger serialization (structural storm remains until the storage.md
  ClickHouse relocation).

## c) Fast Boot answer (the owner's actual question)

CORRECTED after the 16-boot series: firmware time is a **warm-vs-cold split**,
not flat — the one clean warm reboot in the record (boot -13, the 7.2.9 deploy
reboot, 2026-10-05, 28s turnaround) posted **6.789s**; all 14 cold/watchdog
boots posted 62.5-62.7s. Today's 62.7s was a **watchdog reset** (`x86/amd:
Previous system reset reason [0x02000800]: hardware watchdog timer expired`,
13:05:41 — the freeze-28 event; the parallel session's report covers the
freeze itself). So: 62.7s is the COLD-boot firmware cost (AMI 5.36 retraining
the 128G LPDDR5X), the 6.8s fast path EXISTS, and the BIOS levers are plain
Fast Boot + (where exposed) Memory Context Restore / MRC Fast Boot — expected
cold firmware → ~7-15s. The owner challenge was right: 62.7s cold-post IS a
problem worth fixing at the BIOS layer. Full decision context + the
post-enable NVRAM verify (Samsung 000C first) lives in the enriched
[blocked:user] row, docs/todo/stability.md.

## f) Follow-ups (self-harvested at authoring time)

1. Boot IO storm structural fix (ClickHouse state → hot-DB disk, archived
   Samsung plan first customer) → docs/todo/storage.md [ready] +
   TODO_LIST.md queue one-liner. **Harvested ✓**
2. Fast Boot owner decision + post-enable NVRAM verify → docs/todo/stability.md
   [blocked:user] (deliberately not in the harvested queue: user-gated). **Harvested ✓**
3. dnsblockd startup hang + discordsync-db-backup failure: owned by the
   parallel sessions' reports (docs/status/2026-10-12_13-38_* + 13-36_*); not
   re-filed here (single-owner rule). **Deliberately not harvested ✓**
