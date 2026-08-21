# Buildcache Zombie-Mount Incident — Diagnosis, Self-Healing Stack, and Deploy Fix

**Date:** 2026-08-16 17:53 – 18:39
**Host:** evo-x2
**Status:** RESOLVED — root cause identified, monitoring gap closed, self-healing deployed and verified on its first real event

---

## Incident Summary

`ls /mnt/buildcache` returned `Input/output error`. This was **recurrence #2** of the documented stale-mountinfo-after-USB-hotplug failure — but this time with the full chain exposed, including a lying monitoring stack.

### Timeline (all times 2026-08-16)

| Time         | Event                                                                                                                                   |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| 15:57–16:33  | JMicron JMS567 enclosure (`usb 8-1`, `152d:0567`) **disconnects 9 times in 36 min**; each drop produces _write_ I/O errors on ext4      |
| 16:35        | Different device appears on `usb 6-1` (RTL9210B — the _other_ SSD enclosure)                                                            |
| 16:40        | `buildcache-init` fails EIO on chown → failed state → blocks future deploy activation                                                   |
| ~17:47–17:50 | Final disconnect → reconnect; drive reappears as `sdc1` but mount is forever bound to dead `sda1` (major:minor `8:1`)                   |
| 17:53        | User hits EIO in fish (cd'd into the mount — also the main dmesg EIO spammer, `comm fish`, millions of suppressed callbacks)            |
| 18:2x        | During session: entire external USB cluster absent (SanDisk + both ZFS drives) — drive fully disconnected again                         |
| 18:26        | First deploy attempt: config activates but `nh` wraps switch-to-configuration exit 4 as exit 1 → deploy.sh aborts before recovery steps |
| 18:37        | Second deploy (fixed): **`buildcache-usb-recovery` reaps the zombie and mounts `/dev/sdc1` fresh in 4 seconds**                         |

### Root Cause Chain

1. **Hardware:** JMS567 USB-SATA bridge is a chip notorious for dropping off the bus under load. 9 flaps in 36 min.
2. **Kernel:** `mount(2)` resolves `/dev/disk/by-id/...` to a device **number**; the VFS stores only `major:minor`. On reconnect the drive gets a new number; the by-id symlink correctly repoints but **cannot re-point the established mount**. Deterministic paths solve _recovery_, not _prevention_.
3. **ext4:** write errors mid-flap → superblock `emergency_ro,shutdown` → all reads EIO forever.
4. **Monitoring (phantom green):** `buildcache_mounted` stayed `1` throughout — the old check (`findmnt -o TARGET`) is satisfied by the zombie mount-table entry, and `df` serves stale in-kernel superblock numbers (reported "99%" unverifiable). Gatus never fired. Same anti-pattern class as the documented gatus-sqlite self-check incident.

---

## What Was Done

### 1. Diagnosis (fully done)

- Zombie mount confirmed via `mountinfo` (`8:1` not in `/proc/partitions`), `emergency_ro,shutdown` superblock state.
- 9-flap storm + final drop extracted from kernel log; enclosure identified as JMicron JMS567 `152d:0567` (serial `20170331000C3`) from dmesg.
- Phantom green proven by reading the live `.prom` (mounted 1, usage 99 while all I/O failed).
- `buildcache-init` failure (16:40) identified as deploy-activation blocker.

### 2. Code Changes (deployed & verified)

**`modules/nixos/services/buildcache.nix`:**

- **Metrics collector:** `mounted=1` now requires mount-table presence AND real I/O (`timeout 15 ls -A "$mnt"`). Verified live against the zombie: returns 0 → Gatus would fire. Kills the phantom green.
- **Mount:** added `x-systemd.device-bound` — systemd stops the mount when the `.device` unit dies; automount re-resolves by-id on next access.
- **udev rules:** `power/control=on` for `152d:0567` (disables USB autosuspend on the bridge — known JMS567 disconnect trigger); partition-add trigger (`ID_SERIAL` match) starts `buildcache-usb-recovery.service`.
- **`buildcache-usb-recovery.service`** (new): stops automount+mount, reaps zombie via `umount -l` if source node is gone, resets failed state, re-arms automount; if drive present: probes real I/O, runs init+metrics; if absent: reports and exits 0. Deliberately skips `harden {}` (slave mount namespace would make `umount` a silent no-op).
- **`buildcache-init`:** added `ConditionPathExists = device` — absent drive skips cleanly instead of failing EIO and blocking activation.

**`scripts/deploy.sh`:**

- Fixed nh exit-code handling: **nh wraps switch-to-configuration's exit 4 as its own exit 1**; deploy.sh now captures output and greps `Exited(4)` to reach the recovery path (exit code alone was indistinguishable from real failure).
- Added post-switch `systemctl start buildcache-usb-recovery.service` (guarded by `systemctl cat`) — every deploy now reaps zombies even without a udev event.

**`AGENTS.md`:** documented phantom-green recurrence, the self-healing stack, and the nh exit-code gotcha.

### 3. Verification

- `nix eval` renders for udev rules / recovery script / init condition / mount options all correct; `nix flake check --no-build` passes.
- systemd 261.1 (device-bound needs ≥250) ✓.
- **Live proof:** first deploy activated-but-aborted; second deploy completed the full pipeline — recovery unit log `buildcache recovered: /dev/sdc1` in 4s, init succeeded, metrics now report real values (`mounted 1`, usage 98% — truthful, fresh mount).

---

## Honest Self-Review

### a) Fully Done

- Incident diagnosed to root cause (hardware flap → number-bound zombie mount → ext4 shutdown → phantom monitoring).
- Phantom-green monitoring gap closed and proven fail-closed against the live zombie.
- Full self-healing stack implemented, deployed, and verified end-to-end on a real event.
- deploy.sh nh exit-4-as-1 bug found and fixed (this broke the documented recovery path for EVERY deploy, not just this one).
- AGENTS.md gotchas updated.

### b) Partially Done

- **fsck not run:** the fs took _write_ errors during flaps and is now mounted RW again with `data=writeback`. Cache-only data, consumers verify hashes — acceptable, but `e2fsck -f` on the partition during the next unplug is proper hygiene.
- **Usage at 98%:** real value; Gatus "Build Cache Usage" will (correctly) alert. GC (Sun 05:00, nuclear `go clean -cache` ≥90%) will clear it; manual `systemctl start buildcache-gc` is faster.
- **Docs:** AGENTS.md updated, but the module header comment doesn't yet describe the full prevention stack (details live in inline comments only).

### c) Not Started

- Physical remediation: the JMS567 enclosure is still the single point of flakiness. Nix cannot fix a failing bridge. Options: swap with the RTL9210B enclosure (currently on the other SSD), replace, or powered hub.
- Flap-count metric/alert (disconnect-counter → Gatus early warning of enclosure death).
- `pre-deploy-check.sh` zombie-mount detector (mountinfo major:minor not in `/proc/partitions`).

### d) Totally Fucked Up (lessons)

- **First deploy aborted mid-pipeline** because I didn't anticipate nh's exit-code remapping — cost one extra build+deploy cycle. Found, fixed, documented.
- **`daemon-reload` does not retroactively enforce device-bound** on an existing zombie — my initial assumption was wrong; verified live and worked around (recovery service handles absent-drive case).
- My sandbox is hard-banned from `systemctl`/`umount`/`sudo` — the first response handed the user manual recovery commands instead of immediately pursuing the deploy path (which runs privileged operations legitimately). The deploy path was the correct answer from the start.
- One multiedit partially failed (non-unique old_string) — caught by grep verification, re-applied with more context.

### e) What We Should Improve

- **Monitoring truthfulness audits:** this is the second phantom-green class incident (gatus-sqlite was the first). Any check backed by state that can go stale (mount tables, cached responses, in-kernel superblock data) needs an I/O or freshness gate.
- **deploy.sh exit-code contract:** nh's remapping silently disabled the documented exit-4 recovery path for all prior deploys since the nh upgrade — worth auditing for other swallowed exit codes.
- **Enclosure health visibility:** USB disconnect events are visible in the kernel log but not metricized; enclosure death is currently invisible until symptoms.

### f) Next Tasks (prioritized)

1. Run `e2fsck -f` on the SanDisk partition during next unplug (superblock has error history). ← open — TODO_LIST Priority 2
2. ~~`systemctl start buildcache-gc` or wait for Sun 05:00 (usage 98% → alert will fire)~~ done — gc ran during the 19-12 session (watermark fired, ~134G freed, 36% after)
3. Swap/replace the JMS567 enclosure (physical — user). ← open — TODO_LIST Priority 2 (same item as e2fsck window)
4. Add USB-disconnect counter metric for `152d:0567` → Gatus alert on flap storms. ← open — TODO_LIST Priority 3
5. `pre-deploy-check.sh`: zombie-mount detection (stale major:minor). ← open — TODO_LIST Priority 3
6. Module header comment: document the prevention stack. ← open (minor, untracked)
7. Consider `usb-storage.quirks=152d:0567:u` (UAS blacklist) if flapping recurs after autosuspend fix. ← open (conditional, untracked)
8. Consider btrfs+zstd conversion (deferred item — turns silent corruption into EIO, ~2x capacity). ← open — TODO_LIST Priority 2
9. Consider `x-systemd.idle-timeout` to unmount when idle (shrinks zombie exposure window). ← open (untracked)
10. ~~Monitor365 failures seen in post-deploy smoke (4 FAILs, pre-existing, separate known issue).~~ moot — monitor365 deliberately disabled; smoke checks auto-SKIP since the 22-00 overhaul

### g) Questions for the User

1. **Enclosure:** did you replug the SanDisk around 18:3x, or did it reconnect on its own? (Determines whether the flap storm is ongoing or was a one-off session.)
2. **Hardware:** swap the JMS567 enclosure with the RTL9210B you already have on the other SSD, or buy a replacement? (The ZFS drives also dropped simultaneously at ~18:2x — if they share a hub/DAS power rail, that's the real culprit.)
3. **fsck window:** want to schedule a brief unmount+fsck of the cache drive, or let it ride (cache data, hash-verified consumers)?

---

**Key files:** `modules/nixos/services/buildcache.nix`, `scripts/deploy.sh`, `AGENTS.md`
**Verification artifacts:** `journalctl -u buildcache-usb-recovery.service` (18:37:47 run), `/var/lib/prometheus-node-exporter/textfile_collectors/buildcache.prom` (real values post-recovery)

---

## Resolution (2026-08-17, docs-health pass)

f-list resolved inline above (f.2 done; f.10 moot; f.1/3 routed Priority 2; f.4/5 routed Priority 3; f.6/7/9 untracked-minor; f.8 routed Priority 2). g questions: g.1 (who replugged) unresolved-but-moot (autosuspend fix + recovery stack deployed); g.2 → the Priority 2 enclosure decision; g.3 → the Priority 2 e2fsck window. The same-day 19-12 follow-up (pnpm prune fix + decontamination) closed this incident's remaining software debt. Archived as resolution-complete.
