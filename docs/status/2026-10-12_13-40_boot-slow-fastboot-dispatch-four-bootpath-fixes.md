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
- Pre-deploy suite: 78 passed / 16 warnings / 0 failed — then the PSI gate
  BLOCKED the switch (io some avg10 65-87% for 20+ min, other sessions'
  builds): deploy queued behind a drain poll (DEPLOY_FORCE_PRESSURE=1
  deliberately NOT used — the gate documents the freeze-precursor class).
- Post-switch (pending): systemd-analyze on the NEXT boot is the true verdict;
  unit-level asserts after switch: compsize timer OnBootSec=30min +
  TimeoutStartSec=10min, llama-chat ExecStartPost retry 400, forgejo wait-dns
  scripts `seq 1 90`, pool-usb-recovery script `--no-block`.

## c) Fast Boot answer (the owner's actual question)

Plain Fast Boot (NOT Ultra Fast): YES, worth ~60s/boot AND it mitigates the
DAS boot-hang class — but it is a user BIOS action; enriched the existing
[blocked:user] row in docs/todo/stability.md with the measured firmware data
and the post-enable NVRAM verify (BootCurrent/LoaderDevicePartUUID must still
decode to Samsung 000C — mirror has been first in BootOrder since 09-30 and
the decode half of that verify is still open).

## f) Follow-ups (self-harvested at authoring time)

1. Boot IO storm structural fix (ClickHouse state → hot-DB disk, archived
   Samsung plan first customer) → docs/todo/storage.md [ready] +
   TODO_LIST.md queue one-liner. **Harvested ✓**
2. Fast Boot owner decision + post-enable NVRAM verify → docs/todo/stability.md
   [blocked:user] (deliberately not in the harvested queue: user-gated). **Harvested ✓**
3. dnsblockd startup hang + discordsync-db-backup failure: owned by the
   parallel sessions' reports (docs/status/2026-10-12_13-38_* + 13-36_*); not
   re-filed here (single-owner rule). **Deliberately not harvested ✓**
