# Boot evidence pull: id8 ccec16f7 (full: ccec16f7079941d98fc17505f50ef990)

Pulled 2026-10-15 22:13 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-15 03:14:01 -> 2026-10-15 22:30:25 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 ccec16f7 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 15 03:14:01 evo-x2 kernel: Linux version 7.2.9 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC Sat Oct  3 10:43:16 UTC 2026
Oct 15 03:14:01 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 03:14:01 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounting /run/wrappers...
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounting /tmp...
Oct 15 22:30:25 evo-x2 systemd[1]: Stopping Flush Journal to Persistent Storage...
Oct 15 22:30:25 evo-x2 systemd[1]: home-lars-.cache-nix.mount: Deactivated successfully.
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounted /home/lars/.cache/nix.
Oct 15 22:30:25 evo-x2 systemd[1]: mnt-btrfs\x2droot.mount: Deactivated successfully.
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounted /mnt/btrfs-root.
Oct 15 22:30:25 evo-x2 systemd[1]: mnt-samsung\x2dnix.mount: Deactivated successfully.
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounted /mnt/samsung-nix.
Oct 15 22:30:25 evo-x2 systemd[1]: run-keys.mount: Deactivated successfully.
Oct 15 22:30:25 evo-x2 systemd[1]: Unmounted /run/keys.
Oct 15 22:30:25 evo-x2 systemd[1]: run-secrets.d.mount: Deactivated successfully.
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 2781
- thermal-THROTTLE-lines: 8
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 15 03:16:00 evo-x2 memory-emergency-guard-check[25956]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.91% sustained (max disk busy -1%, MemAvailable=72.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (546s < 600s, 54s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 03:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:17:00 evo-x2 memory-emergency-guard-check[43833]: MEMORY EMERGENCY: I/O PSI some avg60=68.49% sustained (max disk busy 100.0%, MemAvailable=71.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 03:18:11 evo-x2 memory-emergency-guard-check[43833]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3145, zone 6) — top io since last trip: system.slice/bank-sync.service/io.stat +196MB
Oct 15 03:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 1min 11.537s wall clock time, 11.4M memory peak, 10.6M read from disk, 95.6M written to disk.
Oct 15 03:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:22:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:24:00 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 03:26:59 evo-x2 memory-emergency-guard-check[234215]: MEMORY EMERGENCY io drained (io PSI some avg60=39.26% < 40%) — churn units re-armed (re-arm #74)
Oct 15 03:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:27:29 evo-x2 memory-emergency-guard-check[381996]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 03:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:32:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:34:31 evo-x2 memory-emergency-guard-check[638272]: MEMORY EMERGENCY: I/O PSI some avg60=40.98% sustained (max disk busy 100.0%, MemAvailable=62.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 03:34:46 evo-x2 memory-emergency-guard-check[638272]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3146, zone 6) — top io since last trip: system.slice/io.stat +58372MB, system.slice/nix-daemon.service/io.stat +23239MB, user.slice/user-1000.slice/io.stat +8609MB
Oct 15 03:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 15.391s wall clock time, 10.2M memory peak, 9.7M read from disk, 40.5M written to disk.
Oct 15 03:35:14 evo-x2 memory-emergency-guard-check[698936]: MEMORY EMERGENCY io drained (io PSI some avg60=39.83% < 40%) — churn units re-armed (re-arm #75)
Oct 15 03:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:35:31 evo-x2 memory-emergency-guard-check[721732]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.42% sustained (max disk busy 100.0%, MemAvailable=61.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 03:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 209ms CPU time over 960ms wall clock time, 12M memory peak, 3.4M read from disk, 4K written to disk.
Oct 15 03:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:44:33 evo-x2 memory-emergency-guard-check[1075309]: MEMORY EMERGENCY: I/O PSI some avg60=68.41% sustained (max disk busy 99.6%, MemAvailable=34.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 03:44:53 evo-x2 memory-emergency-guard-check[1075309]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3147, zone 6) — top io since last trip: system.slice/io.stat +231565MB, system.slice/tq-agent-pool.service/io.stat +94018MB, system.slice/nix-daemon.service/io.stat +28745MB
Oct 15 03:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 19.948s wall clock time, 9.6M memory peak, 47.8M read from disk, 46.9M written to disk.
Oct 15 03:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:45:33 evo-x2 memory-emergency-guard-check[1113607]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.46% sustained (max disk busy 100.0%, MemAvailable=52.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 03:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:54:33 evo-x2 memory-emergency-guard-check[1369179]: MEMORY EMERGENCY: I/O PSI some avg60=48.82% sustained (max disk busy 56.0%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 03:54:48 evo-x2 memory-emergency-guard-check[1369179]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3148, zone 6) — top io since last trip: system.slice/io.stat +220456MB, system.slice/tq-agent-pool.service/io.stat +178467MB, user.slice/io.stat +13664MB
Oct 15 03:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 15.264s wall clock time, 11.7M memory peak, 14.2M read from disk, 6.9M written to disk.
Oct 15 03:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:55:33 evo-x2 memory-emergency-guard-check[1403520]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.39% sustained (max disk busy 100.0%, MemAvailable=59.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 03:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:57:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:58:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:58:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:00:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:02:48 evo-x2 memory-emergency-guard-check[1729111]: MEMORY EMERGENCY io drained (io PSI some avg60=37.83% < 40%) — churn units re-armed (re-arm #76)
Oct 15 04:02:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:04:36 evo-x2 memory-emergency-guard-check[1872359]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 04:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:08:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:10:36 evo-x2 memory-emergency-guard-check[2129038]: MEMORY EMERGENCY: I/O PSI some avg60=42.35% sustained (max disk busy 100.0%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 04:10:39 evo-x2 memory-emergency-guard-check[2129038]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3149, zone 6) — top io since last trip: system.slice/io.stat +71217MB, system.slice/nix-daemon.service/io.stat +41360MB, user.slice/io.stat +18088MB
Oct 15 04:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 2.714s wall clock time, 8.6M memory peak, 10.2M read from disk, 66.9M written to disk.
Oct 15 04:11:07 evo-x2 memory-emergency-guard-check[2170431]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.25% sustained (max disk busy 100.0%, MemAvailable=56.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 04:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:12:43 evo-x2 memory-emergency-guard-check[2260097]: MEMORY EMERGENCY io drained (io PSI some avg60=39.62% < 40%) — churn units re-armed (re-arm #77)
Oct 15 04:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:15:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:16:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:18:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:20:39 evo-x2 memory-emergency-guard-check[2455674]: MEMORY EMERGENCY: I/O PSI some avg60=53.31% sustained (max disk busy 73.3%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 04:20:41 evo-x2 memory-emergency-guard-check[2455674]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3150, zone 6) — top io since last trip: system.slice/io.stat +83209MB, system.slice/inboxclean-web.service/io.stat +20223MB, system.slice/nix-daemon.service/io.stat +12068MB
Oct 15 04:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.025s CPU time over 3.113s wall clock time, 6.9M memory peak, 2.8M read from disk, 18M written to disk.
Oct 15 04:21:09 evo-x2 memory-emergency-guard-check[2497503]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.62% sustained (max disk busy 41.7%, MemAvailable=56.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 04:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:22:15 evo-x2 memory-emergency-guard-check[2572612]: MEMORY EMERGENCY io drained (io PSI some avg60=39.04% < 40%) — churn units re-armed (re-arm #78)
Oct 15 04:22:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:25:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:26:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:26:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:27:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:28:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:30:40 evo-x2 memory-emergency-guard-check[2928501]: MEMORY EMERGENCY: I/O PSI some avg60=46.54% sustained (max disk busy 58.8%, MemAvailable=51.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 04:30:44 evo-x2 memory-emergency-guard-check[2928501]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3151, zone 6) — top io since last trip: system.slice/io.stat +73099MB, system.slice/nix-daemon.service/io.stat +8971MB, user.slice/io.stat +8546MB
Oct 15 04:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.048s CPU time over 3.449s wall clock time, 9M memory peak, 18.4M read from disk, 81.3M written to disk.
Oct 15 04:31:20 evo-x2 memory-emergency-guard-check[2950255]: MEMORY EMERGENCY io drained (io PSI some avg60=37.99% < 40%) — churn units re-armed (re-arm #79)
Oct 15 04:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:31:40 evo-x2 memory-emergency-guard-check[2971084]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.64% sustained (max disk busy 73.3%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 04:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:40:41 evo-x2 memory-emergency-guard-check[3239642]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 04:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:41:41 evo-x2 memory-emergency-guard-check[3274753]: MEMORY EMERGENCY: I/O PSI some avg60=55.37% sustained (max disk busy 83.0%, MemAvailable=65.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 04:41:42 evo-x2 memory-emergency-guard-check[3274753]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3152, zone 6) — top io since last trip: system.slice/io.stat +30292MB, user.slice/io.stat +9861MB, user.slice/user-1000.slice/io.stat +9788MB
Oct 15 04:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 1.167s wall clock time, 10.7M memory peak, 10.5M read from disk, 58.1M written to disk.
Oct 15 04:42:11 evo-x2 memory-emergency-guard-check[3284868]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.42% sustained (max disk busy 70.3%, MemAvailable=65.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 04:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:47:19 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 04:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:49:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:51:44 evo-x2 memory-emergency-guard-check[3468697]: MEMORY EMERGENCY: I/O PSI some avg60=65.09% sustained (max disk busy 100.0%, MemAvailable=63.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 04:52:02 evo-x2 memory-emergency-guard-check[3468697]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3153, zone 6) — top io since last trip: system.slice/io.stat +44406MB, user.slice/io.stat +11927MB, user.slice/user-1000.slice/io.stat +11856MB
Oct 15 04:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 18.434s wall clock time, 10M memory peak, 22.2M read from disk, 78.9M written to disk.
Oct 15 04:52:14 evo-x2 memory-emergency-guard-check[3479996]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.71% sustained (max disk busy 100.0%, MemAvailable=63.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 04:52:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:52:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:57:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:57:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 182ms wall clock time, 10.6M memory peak, 2.2M read from disk, 4K written to disk.
Oct 15 04:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 04:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:01:23 evo-x2 memory-emergency-guard-check[3926765]: MEMORY EMERGENCY io drained (io PSI some avg60=39.35% < 40%) — churn units re-armed (re-arm #80)
Oct 15 05:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:01:49 evo-x2 memory-emergency-guard-check[3951451]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 05:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:02:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:03:19 evo-x2 memory-emergency-guard-check[4032605]: MEMORY EMERGENCY: I/O PSI some avg60=40.70% sustained (max disk busy 99.2%, MemAvailable=50.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:03:25 evo-x2 memory-emergency-guard-check[4032605]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3154, zone 6) — top io since last trip: system.slice/io.stat +78217MB, system.slice/tq-agent-pool.service/io.stat +30942MB, user.slice/io.stat +20684MB
Oct 15 05:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 5.638s wall clock time, 10M memory peak, 272K read from disk, 18.7M written to disk.
Oct 15 05:03:49 evo-x2 memory-emergency-guard-check[4048497]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.38% sustained (max disk busy 99.8%, MemAvailable=46.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:03:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:04:20 evo-x2 memory-emergency-guard-check[4067620]: MEMORY EMERGENCY io drained (io PSI some avg60=37.54% < 40%) — churn units re-armed (re-arm #81)
Oct 15 05:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:04:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:05:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:05:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:07:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:07:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:08:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:11:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:13:19 evo-x2 memory-emergency-guard-check[64124]: MEMORY EMERGENCY: I/O PSI some avg60=62.36% sustained (max disk busy 68.0%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:13:30 evo-x2 memory-emergency-guard-check[64124]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3155, zone 6) — top io since last trip: system.slice/io.stat +221222MB, system.slice/tq-agent-pool.service/io.stat +192937MB, system.slice/inboxclean-web.service/io.stat +11781MB
Oct 15 05:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 10.474s wall clock time, 11M memory peak, 23.4M read from disk, 8.2M written to disk.
Oct 15 05:13:49 evo-x2 memory-emergency-guard-check[76498]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.50% sustained (max disk busy 100.0%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:17:53 evo-x2 memory-emergency-guard-check[240817]: MEMORY EMERGENCY io drained (io PSI some avg60=37.53% < 40%) — churn units re-armed (re-arm #82)
Oct 15 05:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:23:21 evo-x2 memory-emergency-guard-check[500442]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 05:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:23:51 evo-x2 memory-emergency-guard-check[507132]: MEMORY EMERGENCY: I/O PSI some avg60=60.78% sustained (max disk busy 95.2%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:23:57 evo-x2 memory-emergency-guard-check[507132]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3156, zone 6) — top io since last trip: system.slice/io.stat +70259MB, system.slice/tq-agent-pool.service/io.stat +48951MB, user.slice/io.stat +9762MB
Oct 15 05:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 5.748s wall clock time, 11.1M memory peak, 14.4M read from disk, 56.9M written to disk.
Oct 15 05:24:21 evo-x2 memory-emergency-guard-check[522755]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.30% sustained (max disk busy 100.0%, MemAvailable=61.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:29:34 evo-x2 gatus[11072]: 2026/10/15 05:29:34 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 05:29:35 evo-x2 gatus[11072]: 2026/10/15 05:29:35 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 05:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:31:36 evo-x2 gatus[11072]: 2026/10/15 05:31:36 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 15 05:31:36 evo-x2 gatus[11072]: 2026/10/15 05:31:36 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 15 05:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:32:55 evo-x2 memory-emergency-guard-check[815438]: MEMORY EMERGENCY io drained (io PSI some avg60=37.08% < 40%) — churn units re-armed (re-arm #83)
Oct 15 05:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:33:52 evo-x2 memory-emergency-guard-check[842898]: MEMORY EMERGENCY: I/O PSI some avg60=50.10% sustained (max disk busy 88.6%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:33:54 evo-x2 memory-emergency-guard-check[842898]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3157, zone 6) — top io since last trip: system.slice/io.stat +146448MB, system.slice/tq-agent-pool.service/io.stat +117433MB, user.slice/io.stat +13174MB
Oct 15 05:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 1.933s wall clock time, 10.1M memory peak, 4.6M read from disk, 21M written to disk.
Oct 15 05:34:22 evo-x2 memory-emergency-guard-check[864013]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.57% sustained (max disk busy 44.8%, MemAvailable=54.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:35:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:35:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:38:27 evo-x2 memory-emergency-guard-check[1093770]: MEMORY EMERGENCY io drained (io PSI some avg60=36.06% < 40%) — churn units re-armed (re-arm #84)
Oct 15 05:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:38:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:39:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:40:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:40:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:43:53 evo-x2 memory-emergency-guard-check[1288222]: MEMORY EMERGENCY: I/O PSI some avg60=42.82% sustained (max disk busy 98.9%, MemAvailable=39.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:43:58 evo-x2 memory-emergency-guard-check[1288222]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3158, zone 6) — top io since last trip: system.slice/io.stat +213517MB, system.slice/tq-agent-pool.service/io.stat +176933MB, user.slice/io.stat +14878MB
Oct 15 05:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 5.534s wall clock time, 9.9M memory peak, 22.6M read from disk, 63.7M written to disk.
Oct 15 05:44:23 evo-x2 memory-emergency-guard-check[1313881]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.65% sustained (max disk busy 95.6%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:44:55 evo-x2 memory-emergency-guard-check[1325605]: MEMORY EMERGENCY io drained (io PSI some avg60=36.76% < 40%) — churn units re-armed (re-arm #85)
Oct 15 05:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:49:03 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 05:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 106ms CPU time over 138ms wall clock time, 10.2M memory peak, 2.9M read from disk, 4K written to disk.
Oct 15 05:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:53:54 evo-x2 memory-emergency-guard-check[1609744]: MEMORY EMERGENCY: I/O PSI some avg60=54.56% sustained (max disk busy 100.0%, MemAvailable=37.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 05:54:14 evo-x2 memory-emergency-guard-check[1609744]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3159, zone 6) — top io since last trip: system.slice/io.stat +63677MB, user.slice/io.stat +15814MB, user.slice/user-1000.slice/io.stat +15146MB
Oct 15 05:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.183s CPU time over 19.971s wall clock time, 8.8M memory peak, 49.7M read from disk, 95.4M written to disk.
Oct 15 05:54:24 evo-x2 memory-emergency-guard-check[1638524]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.56% sustained (max disk busy 86.2%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 05:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:56:27 evo-x2 memory-emergency-guard-check[1732416]: MEMORY EMERGENCY io drained (io PSI some avg60=34.42% < 40%) — churn units re-armed (re-arm #86)
Oct 15 05:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 05:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:01:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:03:56 evo-x2 memory-emergency-guard-check[1905316]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 06:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:05:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:05:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:06:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:06:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:07:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:08:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:10:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:11:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:11:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:12:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:13:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:13:57 evo-x2 memory-emergency-guard-check[2208446]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 06:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:14:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:20:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:21:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:21:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:23:57 evo-x2 memory-emergency-guard-check[2426117]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 06:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:24:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:25:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:26:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:29:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:31:58 evo-x2 memory-emergency-guard-check[2660142]: MEMORY EMERGENCY: I/O PSI some avg60=40.02% sustained (max disk busy 99.2%, MemAvailable=46.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 06:32:00 evo-x2 memory-emergency-guard-check[2660142]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3160, zone 6) — top io since last trip: system.slice/io.stat +111162MB, system.slice/inboxclean-web.service/io.stat +39491MB, user.slice/io.stat +26943MB
Oct 15 06:32:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:32:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 918ms CPU time over 2.963s wall clock time, 9.3M memory peak, 5.1M read from disk, 32.8M written to disk.
Oct 15 06:32:28 evo-x2 memory-emergency-guard-check[2688583]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.18% sustained (max disk busy 100.0%, MemAvailable=48.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 06:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:32:28 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 06:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:36:26 evo-x2 memory-emergency-guard-check[2780601]: MEMORY EMERGENCY io drained (io PSI some avg60=37.53% < 40%) — churn units re-armed (re-arm #87)
Oct 15 06:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 197ms CPU time over 27.298s wall clock time, 5.9M memory peak, 1.4M read from disk, 4K written to disk.
Oct 15 06:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:37:34 evo-x2 gatus[11072]: 2026/10/15 06:37:34 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 15 06:37:35 evo-x2 gatus[11072]: 2026/10/15 06:37:35 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 15 06:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 195ms CPU time over 267ms wall clock time, 9M memory peak, 3.9M read from disk, 4K written to disk.
Oct 15 06:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:42:01 evo-x2 memory-emergency-guard-check[2942655]: MEMORY EMERGENCY: I/O PSI some avg60=72.19% sustained (max disk busy 100.0%, MemAvailable=46.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 06:42:07 evo-x2 memory-emergency-guard-check[2942655]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3161, zone 6) — top io since last trip: system.slice/io.stat +40424MB, user.slice/io.stat +23572MB, user.slice/user-1000.slice/io.stat +23385MB
Oct 15 06:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 963ms CPU time over 5.728s wall clock time, 15.8M memory peak, 17.2M read from disk, 70.7M written to disk.
Oct 15 06:42:31 evo-x2 memory-emergency-guard-check[2973883]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.35% sustained (max disk busy 87.7%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 06:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 154ms CPU time over 213ms wall clock time, 7.1M memory peak, 1.2M read from disk, 4K written to disk.
Oct 15 06:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:52:03 evo-x2 memory-emergency-guard-check[3316337]: MEMORY EMERGENCY: I/O PSI some avg60=53.57% sustained (max disk busy 70.2%, MemAvailable=45.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 06:52:07 evo-x2 memory-emergency-guard-check[3316337]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3162, zone 6) — top io since last trip: system.slice/io.stat +59083MB, user.slice/io.stat +26745MB, user.slice/user-1000.slice/io.stat +25939MB
Oct 15 06:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 766ms CPU time over 4.449s wall clock time, 9.9M memory peak, 11M read from disk, 52.7M written to disk.
Oct 15 06:52:33 evo-x2 memory-emergency-guard-check[3339502]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.64% sustained (max disk busy 84.8%, MemAvailable=41.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 06:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:54:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:55:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:57:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 06:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:02:06 evo-x2 memory-emergency-guard-check[3728513]: MEMORY EMERGENCY: I/O PSI some avg60=57.33% sustained (max disk busy 67.7%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:02:08 evo-x2 memory-emergency-guard-check[3728513]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3163, zone 6) — top io since last trip: system.slice/io.stat +46320MB, system.slice/inboxclean-web.service/io.stat +15095MB, system.slice/nix-daemon.service/io.stat +10564MB
Oct 15 07:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 2.856s wall clock time, 10.4M memory peak, 6.6M read from disk, 70.7M written to disk.
Oct 15 07:02:36 evo-x2 memory-emergency-guard-check[3742454]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.84% sustained (max disk busy 74.8%, MemAvailable=49.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:12:08 evo-x2 memory-emergency-guard-check[97219]: MEMORY EMERGENCY: I/O PSI some avg60=47.07% sustained (max disk busy 51.7%, MemAvailable=51.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:12:13 evo-x2 memory-emergency-guard-check[97219]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3164, zone 6) — top io since last trip: system.slice/io.stat +25084MB, system.slice/inboxclean-web.service/io.stat +14098MB, user.slice/io.stat +8422MB
Oct 15 07:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 4.849s wall clock time, 10.3M memory peak, 11M read from disk, 83.9M written to disk.
Oct 15 07:12:38 evo-x2 memory-emergency-guard-check[129154]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.07% sustained (max disk busy 65.7%, MemAvailable=52.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:16:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:18:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:20:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:22:11 evo-x2 memory-emergency-guard-check[447322]: MEMORY EMERGENCY: I/O PSI some avg60=57.21% sustained (max disk busy 33.2%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:22:13 evo-x2 memory-emergency-guard-check[447322]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3165, zone 6) — top io since last trip: system.slice/io.stat +30177MB, system.slice/nix-daemon.service/io.stat +19046MB, system.slice/inboxclean-web.service/io.stat +8246MB
Oct 15 07:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 868ms CPU time over 2.826s wall clock time, 9.6M memory peak, 20.5M read from disk, 84.5M written to disk.
Oct 15 07:22:41 evo-x2 memory-emergency-guard-check[469008]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.99% sustained (max disk busy 66.4%, MemAvailable=51.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:24:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:32:13 evo-x2 memory-emergency-guard-check[941187]: MEMORY EMERGENCY: I/O PSI some avg60=63.58% sustained (max disk busy 98.6%, MemAvailable=47.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:32:15 evo-x2 memory-emergency-guard-check[941187]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3166, zone 6) — top io since last trip: system.slice/io.stat +35312MB, system.slice/inboxclean-web.service/io.stat +16597MB, user.slice/io.stat +14104MB
Oct 15 07:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 860ms CPU time over 2.358s wall clock time, 8.4M memory peak, 5.5M read from disk, 41.4M written to disk.
Oct 15 07:32:43 evo-x2 memory-emergency-guard-check[983425]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.08% sustained (max disk busy 99.8%, MemAvailable=47.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:33:16 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 07:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:35:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:35:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:36:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:37:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:42:15 evo-x2 memory-emergency-guard-check[1331127]: MEMORY EMERGENCY: I/O PSI some avg60=55.70% sustained (max disk busy 100.0%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:42:30 evo-x2 memory-emergency-guard-check[1331127]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3167, zone 6) — top io since last trip: system.slice/io.stat +32136MB, user.slice/io.stat +10702MB, user.slice/user-1000.slice/io.stat +10323MB
Oct 15 07:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 873ms CPU time over 14.834s wall clock time, 9.8M memory peak, 13.6M read from disk, 4.7M written to disk.
Oct 15 07:42:45 evo-x2 memory-emergency-guard-check[1346354]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.74% sustained (max disk busy 100.0%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:51:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:52:17 evo-x2 memory-emergency-guard-check[1661942]: MEMORY EMERGENCY: I/O PSI some avg60=58.67% sustained (max disk busy 53.2%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 07:52:22 evo-x2 memory-emergency-guard-check[1661942]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3168, zone 6) — top io since last trip: system.slice/io.stat +45107MB, user.slice/io.stat +16821MB, user.slice/user-1000.slice/io.stat +16786MB
Oct 15 07:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 723ms CPU time over 5.055s wall clock time, 11.5M memory peak, 30.3M read from disk, 107.5M written to disk.
Oct 15 07:52:47 evo-x2 memory-emergency-guard-check[1680716]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.85% sustained (max disk busy 91.3%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 07:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 07:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:02:20 evo-x2 memory-emergency-guard-check[1889101]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 08:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:02:50 evo-x2 memory-emergency-guard-check[1906498]: MEMORY EMERGENCY: I/O PSI some avg60=57.32% sustained (max disk busy 87.0%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:02:51 evo-x2 memory-emergency-guard-check[1906498]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3169, zone 6) — top io since last trip: system.slice/io.stat +12690MB, system.slice/inboxclean-web.service/io.stat +9349MB, user.slice/io.stat +7214MB
Oct 15 08:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 577ms CPU time over 1.603s wall clock time, 10.1M memory peak, 4M read from disk, 48.6M written to disk.
Oct 15 08:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:03:51 evo-x2 memory-emergency-guard-check[1934493]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.35% sustained (max disk busy 91.4%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:03:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:04:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:04:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:06:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:07:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:08:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:12:53 evo-x2 memory-emergency-guard-check[2145639]: MEMORY EMERGENCY: I/O PSI some avg60=71.40% sustained (max disk busy 91.6%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:12:56 evo-x2 memory-emergency-guard-check[2145639]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3170, zone 6) — top io since last trip: system.slice/io.stat +11725MB, system.slice/inboxclean-web.service/io.stat +7192MB, user.slice/io.stat +3156MB
Oct 15 08:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 2.676s wall clock time, 10.5M memory peak, 6.5M read from disk, 55.4M written to disk.
Oct 15 08:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:13:53 evo-x2 memory-emergency-guard-check[2158924]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.53% sustained (max disk busy 93.7%, MemAvailable=51.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:15:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:16:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:16:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:21:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:22:28 evo-x2 memory-emergency-guard-check[2362005]: MEMORY EMERGENCY io drained (io PSI some avg60=37.52% < 40%) — churn units re-armed (re-arm #88)
Oct 15 08:22:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:22:56 evo-x2 memory-emergency-guard-check[2368537]: MEMORY EMERGENCY: I/O PSI some avg60=40.94% sustained (max disk busy 75.2%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:23:00 evo-x2 memory-emergency-guard-check[2368537]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3171, zone 6) — top io since last trip: system.slice/io.stat +12470MB, system.slice/inboxclean-web.service/io.stat +4838MB, system.slice/nix-daemon.service/io.stat +4709MB
Oct 15 08:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 575ms CPU time over 4.563s wall clock time, 11.4M memory peak, 14.4M read from disk, 54.1M written to disk.
Oct 15 08:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:23:56 evo-x2 memory-emergency-guard-check[2385954]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.20% sustained (max disk busy 76.1%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:32:57 evo-x2 memory-emergency-guard-check[2486124]: MEMORY EMERGENCY: I/O PSI some avg60=77.58% sustained (max disk busy 77.5%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:32:59 evo-x2 memory-emergency-guard-check[2486124]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3172, zone 6) — top io since last trip: system.slice/io.stat +15157MB, system.slice/inboxclean-web.service/io.stat +12762MB, user.slice/io.stat +1162MB
Oct 15 08:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 552ms CPU time over 2.229s wall clock time, 11M memory peak, 9.9M read from disk, 62.8M written to disk.
Oct 15 08:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:33:57 evo-x2 memory-emergency-guard-check[2499879]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.98% sustained (max disk busy 76.6%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:35:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:39:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:40:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:43:01 evo-x2 memory-emergency-guard-check[2584502]: MEMORY EMERGENCY: I/O PSI some avg60=80.96% sustained (max disk busy 60.3%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:43:02 evo-x2 memory-emergency-guard-check[2584502]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3173, zone 6) — top io since last trip: system.slice/io.stat +19170MB, system.slice/inboxclean-web.service/io.stat +17760MB, system.slice/clickhouse.service/io.stat +630MB
Oct 15 08:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 484ms CPU time over 1.106s wall clock time, 11M memory peak, 1.3M read from disk, 35.5M written to disk.
Oct 15 08:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:44:01 evo-x2 memory-emergency-guard-check[2599141]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.24% sustained (max disk busy 59.9%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:53:03 evo-x2 memory-emergency-guard-check[2691959]: MEMORY EMERGENCY: I/O PSI some avg60=76.54% sustained (max disk busy 53.2%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 08:53:04 evo-x2 memory-emergency-guard-check[2691959]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3174, zone 6) — top io since last trip: system.slice/io.stat +33406MB, system.slice/inboxclean-web.service/io.stat +26682MB, system.slice/forgejo.service/io.stat +5386MB
Oct 15 08:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 477ms CPU time over 916ms wall clock time, 11.1M memory peak, 1.6M read from disk, 33M written to disk.
Oct 15 08:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:54:03 evo-x2 memory-emergency-guard-check[2707450]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.55% sustained (max disk busy 52.6%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 08:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 08:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:03:07 evo-x2 memory-emergency-guard-check[2811722]: MEMORY EMERGENCY: I/O PSI some avg60=77.82% sustained (max disk busy 41.8%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:03:08 evo-x2 memory-emergency-guard-check[2811722]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3175, zone 6) — top io since last trip: system.slice/io.stat +28430MB, system.slice/inboxclean-web.service/io.stat +26972MB, user.slice/io.stat +723MB
Oct 15 09:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 480ms CPU time over 581ms wall clock time, 10.9M memory peak, 1.1M read from disk, 33.6M written to disk.
Oct 15 09:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:04:07 evo-x2 memory-emergency-guard-check[2836278]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.86% sustained (max disk busy 39.8%, MemAvailable=52.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:13:10 evo-x2 memory-emergency-guard-check[2936167]: MEMORY EMERGENCY: I/O PSI some avg60=80.28% sustained (max disk busy 38.3%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:13:10 evo-x2 memory-emergency-guard-check[2936167]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3176, zone 6) — top io since last trip: system.slice/io.stat +12909MB, system.slice/inboxclean-web.service/io.stat +11647MB, user.slice/io.stat +11249MB
Oct 15 09:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 493ms CPU time over 621ms wall clock time, 11.4M memory peak, 2.9M read from disk, 40.8M written to disk.
Oct 15 09:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:14:10 evo-x2 memory-emergency-guard-check[2950654]: MEMORY EMERGENCY still active (I/O PSI some avg60=82.22% sustained (max disk busy 32.1%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:15:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:23:13 evo-x2 memory-emergency-guard-check[3086401]: MEMORY EMERGENCY: I/O PSI some avg60=79.93% sustained (max disk busy 23.4%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:23:14 evo-x2 memory-emergency-guard-check[3086401]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3177, zone 6) — top io since last trip: system.slice/io.stat +20003MB, system.slice/forgejo.service/io.stat +8320MB, system.slice/inboxclean-web.service/io.stat +7770MB
Oct 15 09:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 498ms CPU time over 603ms wall clock time, 11.2M memory peak, 1.4M read from disk, 35.5M written to disk.
Oct 15 09:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:24:13 evo-x2 memory-emergency-guard-check[3102024]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.93% sustained (max disk busy 21.8%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:31:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:31:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:33:14 evo-x2 memory-emergency-guard-check[3205073]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 09:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:33:44 evo-x2 memory-emergency-guard-check[3208683]: MEMORY EMERGENCY: I/O PSI some avg60=85.03% sustained (max disk busy 79.7%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:33:46 evo-x2 memory-emergency-guard-check[3208683]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3178, zone 6) — top io since last trip: system.slice/io.stat +13102MB, system.slice/inboxclean-web.service/io.stat +11288MB, system.slice/nix-daemon.service/io.stat +699MB
Oct 15 09:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 485ms CPU time over 1.209s wall clock time, 11.3M memory peak, 1.3M read from disk, 39.9M written to disk.
Oct 15 09:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:34:45 evo-x2 memory-emergency-guard-check[3222728]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.28% sustained (max disk busy 80.3%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:41:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:41:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:42:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:42:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:43:46 evo-x2 memory-emergency-guard-check[3297848]: MEMORY EMERGENCY: I/O PSI some avg60=87.10% sustained (max disk busy 88.9%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:43:48 evo-x2 memory-emergency-guard-check[3297848]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3179, zone 6) — top io since last trip: system.slice/io.stat +21756MB, system.slice/inboxclean-web.service/io.stat +20716MB, system.slice/clickhouse.service/io.stat +566MB
Oct 15 09:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 464ms CPU time over 1.634s wall clock time, 11.3M memory peak, 496K read from disk, 27.7M written to disk.
Oct 15 09:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:44:46 evo-x2 memory-emergency-guard-check[3312182]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.70% sustained (max disk busy 99.7%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:44:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:45:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:47:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:47:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:48:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:48:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:52:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:53:48 evo-x2 memory-emergency-guard-check[3389746]: MEMORY EMERGENCY: I/O PSI some avg60=86.07% sustained (max disk busy 95.5%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 09:53:50 evo-x2 memory-emergency-guard-check[3389746]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3180, zone 6) — top io since last trip: system.slice/io.stat +14135MB, system.slice/inboxclean-web.service/io.stat +10091MB, system.slice/clickhouse.service/io.stat +686MB
Oct 15 09:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 467ms CPU time over 1.852s wall clock time, 11.2M memory peak, 624K read from disk, 33.8M written to disk.
Oct 15 09:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:54:49 evo-x2 memory-emergency-guard-check[3404094]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.87% sustained (max disk busy 95.7%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 09:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 09:59:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:03:53 evo-x2 memory-emergency-guard-check[3482215]: MEMORY EMERGENCY: I/O PSI some avg60=86.21% sustained (max disk busy 88.0%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:03:54 evo-x2 memory-emergency-guard-check[3482215]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3181, zone 6) — top io since last trip: system.slice/io.stat +9082MB, system.slice/inboxclean-web.service/io.stat +7936MB, system.slice/clickhouse.service/io.stat +595MB
Oct 15 10:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 518ms CPU time over 2.006s wall clock time, 12.2M memory peak, 6.4M read from disk, 60.8M written to disk.
Oct 15 10:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:04:53 evo-x2 memory-emergency-guard-check[3496423]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.10% sustained (max disk busy 90.8%, MemAvailable=53.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:04:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:07:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:13:53 evo-x2 memory-emergency-guard-check[3574230]: MEMORY EMERGENCY: I/O PSI some avg60=83.58% sustained (max disk busy 85.9%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:13:54 evo-x2 memory-emergency-guard-check[3574230]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3182, zone 6) — top io since last trip: system.slice/io.stat +20495MB, system.slice/inboxclean-web.service/io.stat +18542MB, system.slice/hermes.service/io.stat +947MB
Oct 15 10:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 437ms CPU time over 1.144s wall clock time, 12.5M memory peak, 432K read from disk, 24.1M written to disk.
Oct 15 10:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:14:53 evo-x2 memory-emergency-guard-check[3592347]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.07% sustained (max disk busy 87.8%, MemAvailable=53.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:18:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:20:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:22:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:23:54 evo-x2 memory-emergency-guard-check[3683011]: MEMORY EMERGENCY: I/O PSI some avg60=85.17% sustained (max disk busy 84.7%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:23:55 evo-x2 memory-emergency-guard-check[3683011]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3183, zone 6) — top io since last trip: system.slice/io.stat +9183MB, system.slice/forgejo.service/io.stat +4483MB, system.slice/inboxclean-web.service/io.stat +3530MB
Oct 15 10:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 458ms CPU time over 924ms wall clock time, 11.6M memory peak, 864K read from disk, 29.9M written to disk.
Oct 15 10:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:24:54 evo-x2 memory-emergency-guard-check[3699420]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.96% sustained (max disk busy 86.9%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:31:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:33:55 evo-x2 memory-emergency-guard-check[3782855]: MEMORY EMERGENCY: I/O PSI some avg60=85.08% sustained (max disk busy 77.5%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:33:57 evo-x2 memory-emergency-guard-check[3782855]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3184, zone 6) — top io since last trip: system.slice/io.stat +19919MB, system.slice/inboxclean-web.service/io.stat +18940MB, system.slice/clickhouse.service/io.stat +528MB
Oct 15 10:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 472ms CPU time over 1.493s wall clock time, 10.6M memory peak, 816K read from disk, 33.9M written to disk.
Oct 15 10:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:34:56 evo-x2 memory-emergency-guard-check[3797568]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.57% sustained (max disk busy 81.2%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:37:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:40:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:43:56 evo-x2 memory-emergency-guard-check[3875922]: MEMORY EMERGENCY: I/O PSI some avg60=85.04% sustained (max disk busy 75.5%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:43:56 evo-x2 memory-emergency-guard-check[3875922]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3185, zone 6) — top io since last trip: system.slice/io.stat +9416MB, system.slice/inboxclean-web.service/io.stat +8521MB, system.slice/clickhouse.service/io.stat +528MB
Oct 15 10:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 454ms CPU time over 529ms wall clock time, 11.4M memory peak, 832K read from disk, 25.1M written to disk.
Oct 15 10:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:44:56 evo-x2 memory-emergency-guard-check[3890898]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.79% sustained (max disk busy 81.3%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:53:57 evo-x2 memory-emergency-guard-check[3971749]: MEMORY EMERGENCY: I/O PSI some avg60=87.32% sustained (max disk busy 76.0%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 10:53:59 evo-x2 memory-emergency-guard-check[3971749]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3186, zone 6) — top io since last trip: system.slice/io.stat +5067MB, system.slice/inboxclean-web.service/io.stat +4010MB, system.slice/clickhouse.service/io.stat +648MB
Oct 15 10:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 468ms CPU time over 1.532s wall clock time, 11.5M memory peak, 1.5M read from disk, 37.8M written to disk.
Oct 15 10:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:54:57 evo-x2 memory-emergency-guard-check[3987441]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.40% sustained (max disk busy 75.1%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 10:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 10:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:02:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:03:59 evo-x2 memory-emergency-guard-check[4069997]: MEMORY EMERGENCY: I/O PSI some avg60=84.83% sustained (max disk busy 67.2%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:04:00 evo-x2 memory-emergency-guard-check[4069997]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3187, zone 6) — top io since last trip: system.slice/io.stat +7209MB, system.slice/inboxclean-web.service/io.stat +5983MB, system.slice/clickhouse.service/io.stat +723MB
Oct 15 11:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 481ms CPU time over 660ms wall clock time, 11.3M memory peak, 4.3M read from disk, 41.7M written to disk.
Oct 15 11:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:05:00 evo-x2 memory-emergency-guard-check[4084824]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.09% sustained (max disk busy 62.7%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:14:02 evo-x2 memory-emergency-guard-check[4166347]: MEMORY EMERGENCY: I/O PSI some avg60=87.62% sustained (max disk busy 60.3%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:14:04 evo-x2 memory-emergency-guard-check[4166347]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3188, zone 6) — top io since last trip: system.slice/io.stat +14612MB, system.slice/inboxclean-web.service/io.stat +13293MB, system.slice/clickhouse.service/io.stat +607MB
Oct 15 11:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 1.778s wall clock time, 11.9M memory peak, 6.2M read from disk, 50.2M written to disk.
Oct 15 11:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:15:02 evo-x2 memory-emergency-guard-check[4185218]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.08% sustained (max disk busy 58.7%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:23:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:24:04 evo-x2 memory-emergency-guard-check[90605]: MEMORY EMERGENCY: I/O PSI some avg60=84.97% sustained (max disk busy 56.1%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:24:05 evo-x2 memory-emergency-guard-check[90605]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3189, zone 6) — top io since last trip: system.slice/io.stat +15236MB, system.slice/inboxclean-web.service/io.stat +8542MB, system.slice/forgejo.service/io.stat +5407MB
Oct 15 11:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 452ms CPU time over 1.010s wall clock time, 11.6M memory peak, 2M read from disk, 24.3M written to disk.
Oct 15 11:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:25:04 evo-x2 memory-emergency-guard-check[122740]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.98% sustained (max disk busy 58.4%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:25:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:31:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:34:07 evo-x2 memory-emergency-guard-check[251498]: MEMORY EMERGENCY: I/O PSI some avg60=85.19% sustained (max disk busy 40.8%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:34:08 evo-x2 memory-emergency-guard-check[251498]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3190, zone 6) — top io since last trip: system.slice/io.stat +15853MB, system.slice/inboxclean-web.service/io.stat +14279MB, system.slice/clickhouse.service/io.stat +1182MB
Oct 15 11:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 439ms CPU time over 510ms wall clock time, 11.6M memory peak, 656K read from disk, 18.9M written to disk.
Oct 15 11:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:35:08 evo-x2 memory-emergency-guard-check[276254]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.45% sustained (max disk busy 41.2%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:44:11 evo-x2 memory-emergency-guard-check[401896]: MEMORY EMERGENCY: I/O PSI some avg60=84.99% sustained (max disk busy 31.2%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:44:11 evo-x2 memory-emergency-guard-check[401896]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3191, zone 6) — top io since last trip: system.slice/io.stat +17244MB, system.slice/inboxclean-web.service/io.stat +15829MB, system.slice/clickhouse.service/io.stat +1033MB
Oct 15 11:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 460ms CPU time over 704ms wall clock time, 11.7M memory peak, 1.1M read from disk, 29.5M written to disk.
Oct 15 11:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:45:11 evo-x2 memory-emergency-guard-check[431789]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.41% sustained (max disk busy 34.9%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:50:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:50:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:51:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:54:13 evo-x2 memory-emergency-guard-check[565589]: MEMORY EMERGENCY: I/O PSI some avg60=84.00% sustained (max disk busy 21.5%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 11:54:14 evo-x2 memory-emergency-guard-check[565589]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3192, zone 6) — top io since last trip: system.slice/io.stat +23885MB, system.slice/forgejo.service/io.stat +11182MB, system.slice/inboxclean-web.service/io.stat +11060MB
Oct 15 11:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 454ms CPU time over 603ms wall clock time, 10.9M memory peak, 3M read from disk, 23.8M written to disk.
Oct 15 11:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:55:13 evo-x2 memory-emergency-guard-check[590535]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.27% sustained (max disk busy 25.6%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 11:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:56:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:57:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 11:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:04:15 evo-x2 memory-emergency-guard-check[679954]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 12:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:04:45 evo-x2 memory-emergency-guard-check[685527]: MEMORY EMERGENCY: I/O PSI some avg60=85.06% sustained (max disk busy 85.5%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:04:49 evo-x2 memory-emergency-guard-check[685527]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3193, zone 6) — top io since last trip: system.slice/io.stat +5042MB, system.slice/inboxclean-web.service/io.stat +3712MB, system.slice/clickhouse.service/io.stat +683MB
Oct 15 12:04:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:04:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 524ms CPU time over 3.834s wall clock time, 11.5M memory peak, 14.8M read from disk, 36.4M written to disk.
Oct 15 12:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:05:45 evo-x2 memory-emergency-guard-check[698475]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.19% sustained (max disk busy 85.9%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:07:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:14:47 evo-x2 memory-emergency-guard-check[785455]: MEMORY EMERGENCY: I/O PSI some avg60=86.31% sustained (max disk busy 86.7%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:14:47 evo-x2 memory-emergency-guard-check[785455]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3194, zone 6) — top io since last trip: system.slice/io.stat +18903MB, system.slice/inboxclean-web.service/io.stat +17706MB, system.slice/clickhouse.service/io.stat +608MB
Oct 15 12:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 455ms CPU time over 646ms wall clock time, 10.4M memory peak, 1.4M read from disk, 30.4M written to disk.
Oct 15 12:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:15:47 evo-x2 memory-emergency-guard-check[797518]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.19% sustained (max disk busy 87.3%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:21:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:21:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:22:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:22:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:24:47 evo-x2 memory-emergency-guard-check[875529]: MEMORY EMERGENCY: I/O PSI some avg60=79.78% sustained (max disk busy 91.5%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:24:51 evo-x2 memory-emergency-guard-check[875529]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3195, zone 6) — top io since last trip: system.slice/io.stat +16526MB, system.slice/inboxclean-web.service/io.stat +14867MB, system.slice/clickhouse.service/io.stat +614MB
Oct 15 12:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 502ms CPU time over 4.087s wall clock time, 12.7M memory peak, 14M read from disk, 13.9M written to disk.
Oct 15 12:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:25:47 evo-x2 memory-emergency-guard-check[887603]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.20% sustained (max disk busy 91.6%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:34:50 evo-x2 memory-emergency-guard-check[963791]: MEMORY EMERGENCY: I/O PSI some avg60=87.17% sustained (max disk busy 93.4%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:34:51 evo-x2 memory-emergency-guard-check[963791]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3196, zone 6) — top io since last trip: system.slice/io.stat +24041MB, system.slice/inboxclean-web.service/io.stat +23019MB, system.slice/clickhouse.service/io.stat +625MB
Oct 15 12:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 483ms CPU time over 619ms wall clock time, 11M memory peak, 3.1M read from disk, 34.3M written to disk.
Oct 15 12:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:35:50 evo-x2 memory-emergency-guard-check[976240]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.41% sustained (max disk busy 92.7%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:44:53 evo-x2 memory-emergency-guard-check[1061543]: MEMORY EMERGENCY: I/O PSI some avg60=85.42% sustained (max disk busy 91.0%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:44:54 evo-x2 memory-emergency-guard-check[1061543]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3197, zone 6) — top io since last trip: system.slice/io.stat +18398MB, system.slice/inboxclean-web.service/io.stat +13120MB, system.slice/forgejo.service/io.stat +4153MB
Oct 15 12:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 478ms CPU time over 1.049s wall clock time, 11.9M memory peak, 1.3M read from disk, 31.9M written to disk.
Oct 15 12:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:45:53 evo-x2 memory-emergency-guard-check[1076299]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.93% sustained (max disk busy 85.8%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:54:56 evo-x2 memory-emergency-guard-check[1161345]: MEMORY EMERGENCY: I/O PSI some avg60=85.35% sustained (max disk busy 76.7%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 12:54:56 evo-x2 memory-emergency-guard-check[1161345]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3198, zone 6) — top io since last trip: system.slice/io.stat +14083MB, system.slice/inboxclean-web.service/io.stat +13089MB, system.slice/clickhouse.service/io.stat +569MB
Oct 15 12:54:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:54:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 457ms CPU time over 556ms wall clock time, 11M memory peak, 672K read from disk, 25.3M written to disk.
Oct 15 12:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:55:56 evo-x2 memory-emergency-guard-check[1173656]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.55% sustained (max disk busy 76.4%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 12:55:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:56:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:57:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 12:59:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:04:57 evo-x2 memory-emergency-guard-check[1250655]: MEMORY EMERGENCY: I/O PSI some avg60=87.02% sustained (max disk busy 75.6%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:04:59 evo-x2 memory-emergency-guard-check[1250655]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3199, zone 6) — top io since last trip: system.slice/io.stat +14519MB, system.slice/inboxclean-web.service/io.stat +13375MB, system.slice/clickhouse.service/io.stat +498MB
Oct 15 13:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 1.769s wall clock time, 10.8M memory peak, 11.7M read from disk, 55.3M written to disk.
Oct 15 13:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:05:58 evo-x2 memory-emergency-guard-check[1262830]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.75% sustained (max disk busy 73.0%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:12:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:15:02 evo-x2 memory-emergency-guard-check[1340109]: MEMORY EMERGENCY: I/O PSI some avg60=86.12% sustained (max disk busy 60.9%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:15:03 evo-x2 memory-emergency-guard-check[1340109]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3200, zone 6) — top io since last trip: system.slice/io.stat +6875MB, system.slice/inboxclean-web.service/io.stat +5847MB, system.slice/clickhouse.service/io.stat +500MB
Oct 15 13:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 449ms CPU time over 1.322s wall clock time, 11.4M memory peak, 1.7M read from disk, 32.4M written to disk.
Oct 15 13:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:16:02 evo-x2 memory-emergency-guard-check[1352575]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.38% sustained (max disk busy 62.7%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:22:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:22:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:24:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:25:06 evo-x2 memory-emergency-guard-check[1431904]: MEMORY EMERGENCY: I/O PSI some avg60=86.14% sustained (max disk busy 45.4%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:25:06 evo-x2 memory-emergency-guard-check[1431904]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3201, zone 6) — top io since last trip: system.slice/io.stat +9135MB, system.slice/inboxclean-web.service/io.stat +8136MB, system.slice/clickhouse.service/io.stat +521MB
Oct 15 13:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 453ms CPU time over 540ms wall clock time, 11M memory peak, 800K read from disk, 27.1M written to disk.
Oct 15 13:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:26:07 evo-x2 memory-emergency-guard-check[1444250]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.40% sustained (max disk busy 44.9%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:30:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:33:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:35:13 evo-x2 memory-emergency-guard-check[1521585]: MEMORY EMERGENCY: I/O PSI some avg60=87.68% sustained (max disk busy 29.4%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:35:15 evo-x2 memory-emergency-guard-check[1521585]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3202, zone 6) — top io since last trip: system.slice/io.stat +11092MB, system.slice/inboxclean-web.service/io.stat +10030MB, system.slice/clickhouse.service/io.stat +577MB
Oct 15 13:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 460ms CPU time over 1.767s wall clock time, 11.7M memory peak, 2.5M read from disk, 41.1M written to disk.
Oct 15 13:35:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:36:13 evo-x2 memory-emergency-guard-check[1534805]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.58% sustained (max disk busy 37.4%, MemAvailable=54.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:36:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:37:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:38:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:39:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:39:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:40:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:41:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:41:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:44:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:45:16 evo-x2 memory-emergency-guard-check[1628479]: MEMORY EMERGENCY: I/O PSI some avg60=85.44% sustained (max disk busy 25.8%, MemAvailable=56.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:45:17 evo-x2 memory-emergency-guard-check[1628479]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3203, zone 6) — top io since last trip: system.slice/io.stat +18097MB, system.slice/hermes.service/io.stat +6741MB, system.slice/forgejo.service/io.stat +5328MB
Oct 15 13:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 450ms CPU time over 965ms wall clock time, 11.3M memory peak, 512K read from disk, 26.2M written to disk.
Oct 15 13:45:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:46:46 evo-x2 memory-emergency-guard-check[1649851]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.73% sustained (max disk busy 90.1%, MemAvailable=56.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:48:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:51:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:52:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:54:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:55:18 evo-x2 memory-emergency-guard-check[1727437]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 13:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:55:48 evo-x2 memory-emergency-guard-check[1731675]: MEMORY EMERGENCY: I/O PSI some avg60=84.88% sustained (max disk busy 90.8%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 13:55:49 evo-x2 memory-emergency-guard-check[1731675]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3204, zone 6) — top io since last trip: system.slice/io.stat +23763MB, system.slice/inboxclean-web.service/io.stat +22580MB, system.slice/clickhouse.service/io.stat +682MB
Oct 15 13:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 415ms CPU time over 748ms wall clock time, 10.6M memory peak, 192K read from disk, 10.4M written to disk.
Oct 15 13:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:56:49 evo-x2 memory-emergency-guard-check[1747715]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.96% sustained (max disk busy 93.3%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 13:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 13:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:02:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:03:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:05:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:05:50 evo-x2 memory-emergency-guard-check[1828024]: MEMORY EMERGENCY: I/O PSI some avg60=86.73% sustained (max disk busy 100.0%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:05:51 evo-x2 memory-emergency-guard-check[1828024]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3205, zone 6) — top io since last trip: system.slice/io.stat +21740MB, system.slice/inboxclean-web.service/io.stat +20568MB, system.slice/clickhouse.service/io.stat +584MB
Oct 15 14:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 456ms CPU time over 967ms wall clock time, 11.5M memory peak, 1.1M read from disk, 27.5M written to disk.
Oct 15 14:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:06:51 evo-x2 memory-emergency-guard-check[1843912]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.73% sustained (max disk busy 96.8%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:08:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:11:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:11:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:15:53 evo-x2 memory-emergency-guard-check[1926167]: MEMORY EMERGENCY: I/O PSI some avg60=84.11% sustained (max disk busy 89.9%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:15:53 evo-x2 memory-emergency-guard-check[1926167]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3206, zone 6) — top io since last trip: system.slice/io.stat +15899MB, system.slice/forgejo.service/io.stat +11340MB, system.slice/inboxclean-web.service/io.stat +3398MB
Oct 15 14:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 444ms CPU time over 533ms wall clock time, 11.4M memory peak, 192K read from disk, 22.8M written to disk.
Oct 15 14:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:16:53 evo-x2 memory-emergency-guard-check[1941470]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.60% sustained (max disk busy 87.7%, MemAvailable=55.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:19:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:20:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:25:55 evo-x2 memory-emergency-guard-check[2021456]: MEMORY EMERGENCY: I/O PSI some avg60=85.48% sustained (max disk busy 78.8%, MemAvailable=55.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:25:55 evo-x2 memory-emergency-guard-check[2021456]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3207, zone 6) — top io since last trip: system.slice/io.stat +26471MB, system.slice/inboxclean-web.service/io.stat +25328MB, system.slice/clickhouse.service/io.stat +577MB
Oct 15 14:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 459ms CPU time over 564ms wall clock time, 10.3M memory peak, 1.3M read from disk, 27.2M written to disk.
Oct 15 14:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:26:55 evo-x2 memory-emergency-guard-check[2036538]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.50% sustained (max disk busy 78.1%, MemAvailable=55.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:33:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:35:56 evo-x2 memory-emergency-guard-check[2114863]: MEMORY EMERGENCY: I/O PSI some avg60=86.49% sustained (max disk busy 80.8%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:35:57 evo-x2 memory-emergency-guard-check[2114863]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3208, zone 6) — top io since last trip: system.slice/io.stat +26372MB, system.slice/inboxclean-web.service/io.stat +24880MB, system.slice/clickhouse.service/io.stat +742MB
Oct 15 14:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 454ms CPU time over 1.190s wall clock time, 11.5M memory peak, 720K read from disk, 28.6M written to disk.
Oct 15 14:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:36:56 evo-x2 memory-emergency-guard-check[2129738]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.29% sustained (max disk busy 79.1%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:37:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:41:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:45:59 evo-x2 memory-emergency-guard-check[2204876]: MEMORY EMERGENCY: I/O PSI some avg60=86.28% sustained (max disk busy 71.6%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:45:59 evo-x2 memory-emergency-guard-check[2204876]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3209, zone 6) — top io since last trip: system.slice/io.stat +4558MB, system.slice/inboxclean-web.service/io.stat +3357MB, system.slice/clickhouse.service/io.stat +614MB
Oct 15 14:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 447ms CPU time over 738ms wall clock time, 11.5M memory peak, 400K read from disk, 22.8M written to disk.
Oct 15 14:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:46:59 evo-x2 memory-emergency-guard-check[2219192]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.49% sustained (max disk busy 71.6%, MemAvailable=55.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:54:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:56:02 evo-x2 memory-emergency-guard-check[2292816]: MEMORY EMERGENCY: I/O PSI some avg60=85.08% sustained (max disk busy 56.5%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 14:56:02 evo-x2 memory-emergency-guard-check[2292816]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3210, zone 6) — top io since last trip: system.slice/io.stat +9856MB, system.slice/inboxclean-web.service/io.stat +8827MB, system.slice/clickhouse.service/io.stat +567MB
Oct 15 14:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 443ms CPU time over 511ms wall clock time, 11.1M memory peak, 512K read from disk, 21.3M written to disk.
Oct 15 14:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:57:02 evo-x2 memory-emergency-guard-check[2307788]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.71% sustained (max disk busy 57.9%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 14:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 14:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:01:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:02:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:06:04 evo-x2 memory-emergency-guard-check[2384716]: MEMORY EMERGENCY: I/O PSI some avg60=87.35% sustained (max disk busy 53.6%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:06:05 evo-x2 memory-emergency-guard-check[2384716]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3211, zone 6) — top io since last trip: system.slice/io.stat +18662MB, system.slice/inboxclean-web.service/io.stat +17351MB, system.slice/clickhouse.service/io.stat +819MB
Oct 15 15:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 481ms CPU time over 1.637s wall clock time, 11.6M memory peak, 2M read from disk, 34.8M written to disk.
Oct 15 15:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:07:04 evo-x2 memory-emergency-guard-check[2399252]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.15% sustained (max disk busy 54.6%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:09:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:10:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:16:06 evo-x2 memory-emergency-guard-check[2476965]: MEMORY EMERGENCY: I/O PSI some avg60=86.98% sustained (max disk busy 50.7%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:16:07 evo-x2 memory-emergency-guard-check[2476965]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3212, zone 6) — top io since last trip: system.slice/io.stat +20774MB, system.slice/inboxclean-web.service/io.stat +15396MB, system.slice/forgejo.service/io.stat +4280MB
Oct 15 15:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 460ms CPU time over 1.006s wall clock time, 12.1M memory peak, 2M read from disk, 33.2M written to disk.
Oct 15 15:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:17:06 evo-x2 memory-emergency-guard-check[2491939]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.94% sustained (max disk busy 48.2%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:26:08 evo-x2 memory-emergency-guard-check[2567918]: MEMORY EMERGENCY: I/O PSI some avg60=84.89% sustained (max disk busy 37.4%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:26:09 evo-x2 memory-emergency-guard-check[2567918]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3213, zone 6) — top io since last trip: system.slice/io.stat +7010MB, system.slice/inboxclean-web.service/io.stat +5915MB, system.slice/clickhouse.service/io.stat +621MB
Oct 15 15:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 442ms CPU time over 1.085s wall clock time, 11.7M memory peak, 1.4M read from disk, 29.7M written to disk.
Oct 15 15:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:27:09 evo-x2 memory-emergency-guard-check[2585214]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.83% sustained (max disk busy 39.2%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:30:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:36:11 evo-x2 memory-emergency-guard-check[2659516]: MEMORY EMERGENCY: I/O PSI some avg60=86.40% sustained (max disk busy 29.8%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:36:12 evo-x2 memory-emergency-guard-check[2659516]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3214, zone 6) — top io since last trip: system.slice/io.stat +6932MB, system.slice/inboxclean-web.service/io.stat +5826MB, system.slice/clickhouse.service/io.stat +644MB
Oct 15 15:36:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:36:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 463ms CPU time over 554ms wall clock time, 11.1M memory peak, 1.2M read from disk, 29.7M written to disk.
Oct 15 15:36:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:37:12 evo-x2 memory-emergency-guard-check[2673929]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.74% sustained (max disk busy 26.2%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:38:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:41:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:44:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:45:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:46:14 evo-x2 memory-emergency-guard-check[2747881]: MEMORY EMERGENCY: I/O PSI some avg60=82.35% sustained (max disk busy 20.5%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:46:14 evo-x2 memory-emergency-guard-check[2747881]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3215, zone 6) — top io since last trip: system.slice/io.stat +14661MB, system.slice/inboxclean-web.service/io.stat +13249MB, system.slice/clickhouse.service/io.stat +592MB
Oct 15 15:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 447ms CPU time over 540ms wall clock time, 11.1M memory peak, 1M read from disk, 29.2M written to disk.
Oct 15 15:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:47:14 evo-x2 memory-emergency-guard-check[2762381]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.48% sustained (max disk busy 27.2%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:48:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:56:17 evo-x2 memory-emergency-guard-check[2840638]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 15:56:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:56:47 evo-x2 memory-emergency-guard-check[2847269]: MEMORY EMERGENCY: I/O PSI some avg60=87.12% sustained (max disk busy 92.9%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 15:56:49 evo-x2 memory-emergency-guard-check[2847269]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3216, zone 6) — top io since last trip: system.slice/io.stat +9073MB, system.slice/inboxclean-web.service/io.stat +7888MB, system.slice/clickhouse.service/io.stat +804MB
Oct 15 15:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 420ms CPU time over 1.167s wall clock time, 11.5M memory peak, 560K read from disk, 17M written to disk.
Oct 15 15:57:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:57:48 evo-x2 memory-emergency-guard-check[2860406]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.19% sustained (max disk busy 94.0%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 15:57:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 15:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:02:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:06:53 evo-x2 memory-emergency-guard-check[2971369]: MEMORY EMERGENCY: I/O PSI some avg60=64.78% sustained (max disk busy 88.4%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:06:54 evo-x2 memory-emergency-guard-check[2971369]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3217, zone 6) — top io since last trip: system.slice/io.stat +11303MB, system.slice/inboxclean-web.service/io.stat +10015MB, user.slice/io.stat +2201MB
Oct 15 16:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 1.781s wall clock time, 9.9M memory peak, 2.6M read from disk, 46.5M written to disk.
Oct 15 16:07:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:07:53 evo-x2 memory-emergency-guard-check[2991377]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.24% sustained (max disk busy 88.7%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:15:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:15:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:16:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:16:54 evo-x2 memory-emergency-guard-check[3220885]: MEMORY EMERGENCY: I/O PSI some avg60=72.48% sustained (max disk busy 79.9%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:16:55 evo-x2 memory-emergency-guard-check[3220885]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3218, zone 6) — top io since last trip: system.slice/io.stat +14125MB, system.slice/forgejo.service/io.stat +5649MB, system.slice/inboxclean-web.service/io.stat +5437MB
Oct 15 16:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 497ms CPU time over 1.779s wall clock time, 10.7M memory peak, 1.7M read from disk, 38.1M written to disk.
Oct 15 16:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:17:54 evo-x2 memory-emergency-guard-check[3237619]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.53% sustained (max disk busy 86.0%, MemAvailable=55.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:26:56 evo-x2 memory-emergency-guard-check[3340186]: MEMORY EMERGENCY: I/O PSI some avg60=81.68% sustained (max disk busy 76.4%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:26:56 evo-x2 memory-emergency-guard-check[3340186]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3219, zone 6) — top io since last trip: system.slice/io.stat +12367MB, system.slice/inboxclean-web.service/io.stat +10214MB, system.slice/nix-daemon.service/io.stat +926MB
Oct 15 16:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 530ms CPU time over 729ms wall clock time, 9.5M memory peak, 1.9M read from disk, 35.2M written to disk.
Oct 15 16:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:27:56 evo-x2 memory-emergency-guard-check[3362385]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.38% sustained (max disk busy 72.7%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:36:57 evo-x2 memory-emergency-guard-check[3468816]: MEMORY EMERGENCY: I/O PSI some avg60=74.66% sustained (max disk busy 76.0%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:36:58 evo-x2 memory-emergency-guard-check[3468816]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3220, zone 6) — top io since last trip: system.slice/io.stat +8561MB, system.slice/inboxclean-web.service/io.stat +7378MB, user.slice/io.stat +2204MB
Oct 15 16:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 428ms CPU time over 704ms wall clock time, 11M memory peak, 8.2M written to disk.
Oct 15 16:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:37:57 evo-x2 memory-emergency-guard-check[3482639]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.68% sustained (max disk busy 70.8%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:41:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:47:00 evo-x2 memory-emergency-guard-check[3578777]: MEMORY EMERGENCY: I/O PSI some avg60=79.83% sustained (max disk busy 63.3%, MemAvailable=55.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:47:00 evo-x2 memory-emergency-guard-check[3578777]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3221, zone 6) — top io since last trip: system.slice/io.stat +37838MB, system.slice/inboxclean-web.service/io.stat +26786MB, system.slice/forgejo.service/io.stat +9840MB
Oct 15 16:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 466ms CPU time over 552ms wall clock time, 11.7M memory peak, 912K read from disk, 27.5M written to disk.
Oct 15 16:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:48:00 evo-x2 memory-emergency-guard-check[3592926]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.35% sustained (max disk busy 61.7%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:57:03 evo-x2 memory-emergency-guard-check[3715330]: MEMORY EMERGENCY: I/O PSI some avg60=83.95% sustained (max disk busy 58.4%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 16:57:04 evo-x2 memory-emergency-guard-check[3715330]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3222, zone 6) — top io since last trip: system.slice/io.stat +20982MB, system.slice/inboxclean-web.service/io.stat +18790MB, user.slice/io.stat +1767MB
Oct 15 16:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 461ms CPU time over 1.046s wall clock time, 11M memory peak, 880K read from disk, 30.2M written to disk.
Oct 15 16:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:58:03 evo-x2 memory-emergency-guard-check[3729905]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.31% sustained (max disk busy 55.6%, MemAvailable=55.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 16:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 16:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:00:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:07:06 evo-x2 memory-emergency-guard-check[3894189]: MEMORY EMERGENCY: I/O PSI some avg60=51.71% sustained (max disk busy 78.6%, MemAvailable=51.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 17:07:09 evo-x2 memory-emergency-guard-check[3894189]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3223, zone 6) — top io since last trip: system.slice/io.stat +12097MB, system.slice/inboxclean-web.service/io.stat +7691MB, user.slice/io.stat +2749MB
Oct 15 17:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 3.467s wall clock time, 10M memory peak, 14M read from disk, 62.5M written to disk.
Oct 15 17:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:08:06 evo-x2 memory-emergency-guard-check[3958453]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.75% sustained (max disk busy 76.8%, MemAvailable=49.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 17:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:08:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:10:17 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 17:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:11:36 evo-x2 memory-emergency-guard-check[4091265]: MEMORY EMERGENCY io drained (io PSI some avg60=37.58% < 40%) — churn units re-armed (re-arm #89)
Oct 15 17:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:15:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:16:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:17:07 evo-x2 memory-emergency-guard-check[157670]: MEMORY EMERGENCY: I/O PSI some avg60=73.78% sustained (max disk busy 99.8%, MemAvailable=48.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 17:17:10 evo-x2 memory-emergency-guard-check[157670]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3224, zone 6) — top io since last trip: system.slice/io.stat +37116MB, system.slice/nix-daemon.service/io.stat +20280MB, user.slice/io.stat +12402MB
Oct 15 17:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 692ms CPU time over 2.869s wall clock time, 10.1M memory peak, 3.9M read from disk, 42.5M written to disk.
Oct 15 17:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:18:07 evo-x2 memory-emergency-guard-check[178932]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.98% sustained (max disk busy 100.0%, MemAvailable=50.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 17:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:27:09 evo-x2 memory-emergency-guard-check[478130]: MEMORY EMERGENCY: I/O PSI some avg60=53.61% sustained (max disk busy 88.9%, MemAvailable=45.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 17:27:13 evo-x2 memory-emergency-guard-check[478130]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3225, zone 6) — top io since last trip: system.slice/io.stat +34311MB, system.slice/nix-daemon.service/io.stat +16948MB, user.slice/io.stat +14194MB
Oct 15 17:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.068s CPU time over 4.285s wall clock time, 7M memory peak, 9.2M read from disk, 64.3M written to disk.
Oct 15 17:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:28:10 evo-x2 memory-emergency-guard-check[518805]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.07% sustained (max disk busy 88.3%, MemAvailable=44.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 17:28:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:29:48 evo-x2 memory-emergency-guard-check[583468]: MEMORY EMERGENCY io drained (io PSI some avg60=37.59% < 40%) — churn units re-armed (re-arm #90)
Oct 15 17:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:30:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:37:12 evo-x2 memory-emergency-guard-check[853913]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 17:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:38:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:41:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:42:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:47:15 evo-x2 memory-emergency-guard-check[1197735]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 17:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:49:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:50:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:52:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:57:18 evo-x2 memory-emergency-guard-check[1466459]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 17:57:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:57:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 17:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:02:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:03:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:04:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:05:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:05:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:06:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:07:20 evo-x2 memory-emergency-guard-check[1764557]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 18:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:08:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:08:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:09:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:10:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:10:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:11:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:14:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:14:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:17:21 evo-x2 memory-emergency-guard-check[2032815]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 18:17:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:22:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:24:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:25:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:27:23 evo-x2 memory-emergency-guard-check[2853301]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 18:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:28:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:29:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:31:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:31:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:32:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:32:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:33:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:37:24 evo-x2 memory-emergency-guard-check[3234252]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 18:37:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:47:25 evo-x2 memory-emergency-guard-check[3573827]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 18:47:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:49:37 evo-x2 gatus[11072]: 2026/10/15 18:49:37 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 18:49:37 evo-x2 gatus[11072]: 2026/10/15 18:49:37 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 18:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:50:55 evo-x2 memory-emergency-guard-check[3688879]: MEMORY EMERGENCY: I/O PSI some avg60=41.03% sustained (max disk busy 71.7%, MemAvailable=48.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 18:50:57 evo-x2 memory-emergency-guard-check[3688879]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3226, zone 6) — top io since last trip: system.slice/io.stat +323995MB, system.slice/nix-daemon.service/io.stat +156573MB, system.slice/inboxclean-web.service/io.stat +85320MB
Oct 15 18:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 1.981s wall clock time, 7.7M memory peak, 3.2M read from disk, 32.8M written to disk.
Oct 15 18:51:30 evo-x2 memory-emergency-guard-check[3700955]: MEMORY EMERGENCY io drained (io PSI some avg60=34.50% < 40%) — churn units re-armed (re-arm #91)
Oct 15 18:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:51:36 evo-x2 gatus[11072]: 2026/10/15 18:51:36 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 15 18:51:36 evo-x2 gatus[11072]: 2026/10/15 18:51:36 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 15 18:51:39 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 18:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:54:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:55:33 evo-x2 gatus[11072]: 2026/10/15 18:55:33 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 15 18:55:33 evo-x2 gatus[11072]: 2026/10/15 18:55:33 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 15 18:55:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:56:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:57:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 18:59:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:00:56 evo-x2 memory-emergency-guard-check[3936715]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 19:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:04:57 evo-x2 memory-emergency-guard-check[4033576]: MEMORY EMERGENCY: I/O PSI some avg60=44.07% sustained (max disk busy 78.9%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:04:59 evo-x2 memory-emergency-guard-check[4033576]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3227, zone 6) — top io since last trip: system.slice/io.stat +38276MB, system.slice/inboxclean-web.service/io.stat +21118MB, user.slice/io.stat +7071MB
Oct 15 19:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 596ms CPU time over 2.284s wall clock time, 11.4M memory peak, 11.1M read from disk, 67.9M written to disk.
Oct 15 19:05:27 evo-x2 memory-emergency-guard-check[4045772]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.39% sustained (max disk busy 36.1%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 19:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:05:34 evo-x2 gatus[11072]: 2026/10/15 19:05:34 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 19:05:34 evo-x2 gatus[11072]: 2026/10/15 19:05:34 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 15 19:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:07:31 evo-x2 memory-emergency-guard-check[4088206]: MEMORY EMERGENCY io drained (io PSI some avg60=39.28% < 40%) — churn units re-armed (re-arm #92)
Oct 15 19:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:07:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:10:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:11:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:11:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:12:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:13:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:14:58 evo-x2 memory-emergency-guard-check[321648]: MEMORY EMERGENCY: I/O PSI some avg60=53.71% sustained (max disk busy 83.9%, MemAvailable=51.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:15:01 evo-x2 memory-emergency-guard-check[321648]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3228, zone 6) — top io since last trip: system.slice/io.stat +32140MB, system.slice/nix-daemon.service/io.stat +12945MB, user.slice/io.stat +11434MB
Oct 15 19:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.246s CPU time over 3.988s wall clock time, 7.5M memory peak, 3M read from disk, 13.7M written to disk.
Oct 15 19:15:28 evo-x2 memory-emergency-guard-check[352975]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.49% sustained (max disk busy 66.2%, MemAvailable=51.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 19:15:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:16:03 evo-x2 memory-emergency-guard-check[385607]: MEMORY EMERGENCY io drained (io PSI some avg60=37.65% < 40%) — churn units re-armed (re-arm #93)
Oct 15 19:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:16:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:16:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:17:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:24:59 evo-x2 memory-emergency-guard-check[681882]: MEMORY EMERGENCY: I/O PSI some avg60=45.71% sustained (max disk busy 91.3%, MemAvailable=48.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:26:08 evo-x2 memory-emergency-guard-check[681882]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3229, zone 6) — top io since last trip: system.slice/io.stat +27605MB, user.slice/io.stat +17231MB, user.slice/user-1000.slice/io.stat +17185MB
Oct 15 19:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 1min 8.548s wall clock time, 8.6M memory peak, 912K read from disk, 120.6M written to disk.
Oct 15 19:26:08 evo-x2 memory-emergency-guard-check[727773]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.78% sustained (max disk busy 99.3%, MemAvailable=48.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (69s < 600s, 531s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 19:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 133ms CPU time over 167ms wall clock time, 9.9M memory peak, 2.2M read from disk, 4K written to disk.
Oct 15 19:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 151ms wall clock time, 11.4M memory peak, 2.3M read from disk, 4K written to disk.
Oct 15 19:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 183ms wall clock time, 10.8M memory peak, 2.6M read from disk, 4K written to disk.
Oct 15 19:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:35:09 evo-x2 memory-emergency-guard-check[1025954]: MEMORY EMERGENCY: I/O PSI some avg60=49.09% sustained (max disk busy 41.0%, MemAvailable=50.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:35:12 evo-x2 memory-emergency-guard-check[1025954]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3230, zone 6) — top io since last trip: system.slice/io.stat +14619MB, user.slice/io.stat +11103MB, user.slice/user-1000.slice/io.stat +10665MB
Oct 15 19:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 3.071s wall clock time, 13.3M memory peak, 16.3M read from disk, 79.1M written to disk.
Oct 15 19:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:36:10 evo-x2 memory-emergency-guard-check[1057679]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.89% sustained (max disk busy 41.2%, MemAvailable=49.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 19:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:39:00 evo-x2 memory-emergency-guard-check[1138717]: MEMORY EMERGENCY io drained (io PSI some avg60=39.24% < 40%) — churn units re-armed (re-arm #94)
Oct 15 19:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:45:12 evo-x2 memory-emergency-guard-check[1361427]: MEMORY EMERGENCY: I/O PSI some avg60=42.00% sustained (max disk busy 100.0%, MemAvailable=39.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:49:50 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; MEMORY GUARD DEAD" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (301s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard".
Oct 15 19:50:02 evo-x2 memory-emergency-guard-check[1361427]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3231, zone 6) — top io since last trip: system.slice/io.stat +56579MB, user.slice/io.stat +38560MB, user.slice/user-1000.slice/io.stat +38225MB
Oct 15 19:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.139s CPU time over 4min 50.895s wall clock time, 7.5M memory peak, 25.8M read from disk, 57.4M written to disk.
Oct 15 19:50:03 evo-x2 memory-emergency-guard-check[1518896]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.26% sustained (max disk busy 100.0%, MemAvailable=34.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (291s < 600s, 309s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 19:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:50:04 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 19:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:51:48 evo-x2 memory-emergency-guard-check[1602152]: MEMORY EMERGENCY io drained (io PSI some avg60=36.63% < 40%) — churn units re-armed (re-arm #95)
Oct 15 19:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:52:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:53:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:54:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:55:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:55:34 evo-x2 memory-emergency-guard-check[1759988]: MEMORY EMERGENCY: I/O PSI some avg60=56.49% sustained (max disk busy 56.6%, MemAvailable=42.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 19:55:35 evo-x2 memory-emergency-guard-check[1759988]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3232, zone 6) — top io since last trip: system.slice/io.stat +29691MB, system.slice/inboxclean-web.service/io.stat +9056MB, user.slice/io.stat +8448MB
Oct 15 19:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 533ms CPU time over 1.326s wall clock time, 9.8M memory peak, 992K read from disk, 20.6M written to disk.
Oct 15 19:56:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 147ms wall clock time, 8.4M memory peak, 1.2M read from disk, 4K written to disk.
Oct 15 19:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 19:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:00:07 evo-x2 memory-emergency-guard-check[1857428]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.25% sustained (max disk busy 57.0%, MemAvailable=38.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (273s < 600s, 327s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:05:12 evo-x2 memory-emergency-guard-check[2039175]: MEMORY EMERGENCY io drained (io PSI some avg60=37.50% < 40%) — churn units re-armed (re-arm #96)
Oct 15 20:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:05:38 evo-x2 memory-emergency-guard-check[2063623]: MEMORY EMERGENCY: I/O PSI some avg60=41.62% sustained (max disk busy 64.9%, MemAvailable=40.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:05:41 evo-x2 memory-emergency-guard-check[2063623]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3233, zone 6) — top io since last trip: system.slice/io.stat +48853MB, system.slice/inboxclean-web.service/io.stat +20539MB, user.slice/io.stat +12590MB
Oct 15 20:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 654ms CPU time over 2.757s wall clock time, 10.1M memory peak, 2.1M read from disk, 31.7M written to disk.
Oct 15 20:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 198ms CPU time over 291ms wall clock time, 8.2M memory peak, 3.1M read from disk, 4K written to disk.
Oct 15 20:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:10:09 evo-x2 gatus[11072]: 2026/10/15 20:10:09 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 15 20:10:09 evo-x2 memory-emergency-guard-check[2245653]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.13% sustained (max disk busy 99.7%, MemAvailable=39.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (271s < 600s, 329s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:15:40 evo-x2 memory-emergency-guard-check[2616738]: MEMORY EMERGENCY: I/O PSI some avg60=65.17% sustained (max disk busy 100.0%, MemAvailable=21.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:16:53 evo-x2 memory-emergency-guard-check[2616738]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3234, zone 6) — top io since last trip: system.slice/io.stat +59019MB, user.slice/io.stat +28717MB, user.slice/user-1000.slice/io.stat +27788MB
Oct 15 20:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.561s CPU time over 1min 13.443s wall clock time, 8.9M memory peak, 94.3M read from disk, 87.8M written to disk.
Oct 15 20:16:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:18:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:20:24 evo-x2 memory-emergency-guard-check[2939096]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.82% sustained (max disk busy 100.0%, MemAvailable=21.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (284s < 600s, 316s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:20:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:22:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:22:59 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 20:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:23:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 169ms CPU time over 567ms wall clock time, 13.8M memory peak, 4.7M read from disk, 4K written to disk.
Oct 15 20:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:25:55 evo-x2 memory-emergency-guard-check[4098655]: MEMORY EMERGENCY: I/O PSI some avg60=63.99% sustained (max disk busy 97.7%, MemAvailable=24.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:26:00 evo-x2 memory-emergency-guard-check[4098655]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3235, zone 6) — top io since last trip: system.slice/io.stat +83265MB, user.slice/io.stat +33180MB, user.slice/user-1000.slice/io.stat +31885MB
Oct 15 20:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 956ms CPU time over 5.784s wall clock time, 10M memory peak, 31.7M read from disk, 62.6M written to disk.
Oct 15 20:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:30:26 evo-x2 memory-emergency-guard-check[4193510]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.81% sustained (max disk busy 98.5%, MemAvailable=45.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (272s < 600s, 328s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:35:57 evo-x2 memory-emergency-guard-check[120682]: MEMORY EMERGENCY: I/O PSI some avg60=64.40% sustained (max disk busy 63.0%, MemAvailable=43.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:36:13 evo-x2 memory-emergency-guard-check[120682]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3236, zone 6) — top io since last trip: system.slice/io.stat +26306MB, user.slice/io.stat +13088MB, user.slice/user-1000.slice/io.stat +12855MB
Oct 15 20:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 807ms CPU time over 16.561s wall clock time, 10.2M memory peak, 23.1M read from disk, 4M written to disk.
Oct 15 20:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:40:28 evo-x2 memory-emergency-guard-check[214760]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.58% sustained (max disk busy 96.2%, MemAvailable=43.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (271s < 600s, 329s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:45:58 evo-x2 memory-emergency-guard-check[365843]: MEMORY EMERGENCY: I/O PSI some avg60=49.14% sustained (max disk busy 44.4%, MemAvailable=32.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:46:08 evo-x2 memory-emergency-guard-check[365843]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3237, zone 6) — top io since last trip: system.slice/io.stat +15110MB, system.slice/inboxclean-web.service/io.stat +7071MB, user.slice/io.stat +4387MB
Oct 15 20:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 706ms CPU time over 9.367s wall clock time, 9.8M memory peak, 7.5M read from disk, 12.8M written to disk.
Oct 15 20:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:50:29 evo-x2 memory-emergency-guard-check[458413]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.04% sustained (max disk busy 88.1%, MemAvailable=38.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (271s < 600s, 329s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 20:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:52:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:55:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:56:00 evo-x2 memory-emergency-guard-check[558455]: MEMORY EMERGENCY: I/O PSI some avg60=52.80% sustained (max disk busy 100.0%, MemAvailable=39.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 20:56:05 evo-x2 memory-emergency-guard-check[558455]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3238, zone 6) — top io since last trip: system.slice/io.stat +34666MB, system.slice/inboxclean-web.service/io.stat +15188MB, system.slice/nix-daemon.service/io.stat +11541MB
Oct 15 20:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.129s CPU time over 6.006s wall clock time, 8.1M memory peak, 16.3M read from disk, 69.7M written to disk.
Oct 15 20:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:57:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 20:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:00:30 evo-x2 memory-emergency-guard-check[730761]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.57% sustained (max disk busy 56.4%, MemAvailable=35.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (270s < 600s, 330s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:01:38 evo-x2 memory-emergency-guard-check[747300]: MEMORY EMERGENCY io drained (io PSI some avg60=36.93% < 40%) — churn units re-armed (re-arm #97)
Oct 15 21:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:08:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:08:30 evo-x2 memory-emergency-guard-check[898539]: MEMORY EMERGENCY: MemAvailable=9.0% AND zram=93.0% (shmem-unevictable trap: model pages cannot evict with full zram) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 21:09:05 evo-x2 memory-emergency-guard-check[928740]: sort: write failed: 'standard output': Broken pipe
Oct 15 21:09:05 evo-x2 memory-emergency-guard-check[928740]: sort: write error
Oct 15 21:09:05 evo-x2 memory-emergency-guard-check[898539]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3239, zone 2) — top io since last trip: system.slice/io.stat +92304MB, user.slice/io.stat +45655MB, user.slice/user-1000.slice/io.stat +44232MB
Oct 15 21:09:20 evo-x2 memory-emergency-guard-check[898539]: MEMORY EMERGENCY io drained (io PSI some avg60=37.43% < 40%) — churn units re-armed (re-arm #98)
Oct 15 21:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.354s CPU time over 49.631s wall clock time, 6.8M memory peak, 34.8M read from disk, 59.3M written to disk.
Oct 15 21:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:09:26 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 21:09:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:10:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:10:50 evo-x2 memory-emergency-guard-check[965870]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.26% sustained (max disk busy 100.0%, MemAvailable=23.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (140s < 600s, 460s remaining; last trip zone=2) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:10:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:12:59 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=8.44%, MemAvailable=14.3%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 15 21:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:14:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:14:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:18:52 evo-x2 memory-emergency-guard-check[1284171]: MEMORY EMERGENCY: I/O PSI some avg60=63.21% sustained (max disk busy 99.5%, MemAvailable=39.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 21:18:55 evo-x2 memory-emergency-guard-check[1284171]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3240, zone 6) — top io since last trip: system.slice/io.stat +76855MB, user.slice/io.stat +26697MB, user.slice/user-1000.slice/io.stat +25451MB
Oct 15 21:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 847ms CPU time over 2.639s wall clock time, 8.3M memory peak, 14.5M read from disk, 66M written to disk.
Oct 15 21:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:20:53 evo-x2 memory-emergency-guard-check[1396467]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.56% sustained (max disk busy 99.9%, MemAvailable=40.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:20:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:22:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:23:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 211ms CPU time over 357ms wall clock time, 5.4M memory peak, 1.7M read from disk, 4K written to disk.
Oct 15 21:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:27:18 evo-x2 memory-emergency-guard-check[1621032]: MEMORY EMERGENCY io drained (io PSI some avg60=36.67% < 40%) — churn units re-armed (re-arm #99)
Oct 15 21:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:28:55 evo-x2 memory-emergency-guard-check[1742398]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 21:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:29:24 evo-x2 memory-emergency-guard-check[1762801]: MEMORY EMERGENCY: I/O PSI some avg60=50.05% sustained (max disk busy 99.8%, MemAvailable=31.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 21:29:26 evo-x2 memory-emergency-guard-check[1762801]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3241, zone 6) — top io since last trip: system.slice/io.stat +43616MB, user.slice/io.stat +17570MB, user.slice/user-1000.slice/io.stat +17423MB
Oct 15 21:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 1.290s wall clock time, 9.6M memory peak, 9M read from disk, 31.8M written to disk.
Oct 15 21:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:30:54 evo-x2 memory-emergency-guard-check[1801724]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.32% sustained (max disk busy 100.0%, MemAvailable=26.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 147ms wall clock time, 10M memory peak, 1.9M read from disk, 4K written to disk.
Oct 15 21:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:34:18 evo-x2 gatus[2250307]: 2026/10/15 21:34:18 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 15 21:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:34:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:35:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:36:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:39:29 evo-x2 memory-emergency-guard-check[2056678]: MEMORY EMERGENCY: I/O PSI some avg60=63.69% sustained (max disk busy 100.0%, MemAvailable=22.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 21:39:37 evo-x2 memory-emergency-guard-check[2056678]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3242, zone 6) — top io since last trip: system.slice/io.stat +42556MB, user.slice/io.stat +13981MB, user.slice/user-1000.slice/io.stat +13825MB
Oct 15 21:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 596ms CPU time over 8.199s wall clock time, 10.2M memory peak, 6.3M read from disk, 33.3M written to disk.
Oct 15 21:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:40:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:41:20 evo-x2 memory-emergency-guard-check[2111300]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.24% sustained (max disk busy 91.1%, MemAvailable=39.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (112s < 600s, 488s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:49:54 evo-x2 memory-emergency-guard-check[2394952]: MEMORY EMERGENCY: I/O PSI some avg60=75.16% sustained (max disk busy 100.0%, MemAvailable=28.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 21:49:57 evo-x2 memory-emergency-guard-check[2394952]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3243, zone 6) — top io since last trip: system.slice/io.stat +30330MB, user.slice/io.stat +18244MB, user.slice/user-1000.slice/io.stat +17206MB
Oct 15 21:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 791ms CPU time over 2.911s wall clock time, 7.6M memory peak, 384K read from disk, 12.4M written to disk.
Oct 15 21:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:51:24 evo-x2 memory-emergency-guard-check[2436552]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.80% sustained (max disk busy 100.0%, MemAvailable=25.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 21:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:56:28 evo-x2 systemd[1665]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 21:56:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:57:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 21:59:56 evo-x2 memory-emergency-guard-check[2748814]: MEMORY EMERGENCY: I/O PSI some avg60=46.20% sustained (max disk busy 100.0%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 22:00:02 evo-x2 memory-emergency-guard-check[2748814]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3244, zone 6) — top io since last trip: system.slice/io.stat +24961MB, user.slice/io.stat +20633MB, user.slice/user-1000.slice/io.stat +20457MB
Oct 15 22:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.121s CPU time over 5.848s wall clock time, 7.3M memory peak, 8.9M read from disk, 59.1M written to disk.
Oct 15 22:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:01:27 evo-x2 memory-emergency-guard-check[2804393]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.14% sustained (max disk busy 99.6%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 22:01:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:06:34 evo-x2 memory-emergency-guard-check[2921863]: MEMORY EMERGENCY io drained (io PSI some avg60=38.81% < 40%) — churn units re-armed (re-arm #100)
Oct 15 22:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:07:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:08:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:09:58 evo-x2 memory-emergency-guard-check[2978865]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 22:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:16:12 evo-x2 systemnix-deploy-tail[3050992]: ✗ memory-emergency-guard tripped 5× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 15 22:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:18:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:19:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:19:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:20:02 evo-x2 memory-emergency-guard-check[3089011]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 15 22:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:21:32 evo-x2 memory-emergency-guard-check[3102152]: MEMORY EMERGENCY: I/O PSI some avg60=57.07% sustained (max disk busy 36.6%, MemAvailable=46.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 22:21:33 evo-x2 memory-emergency-guard-check[3102152]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3245, zone 6) — top io since last trip: user.slice/io.stat +49996MB, user.slice/user-1000.slice/io.stat +47889MB, system.slice/io.stat +32243MB
Oct 15 22:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 455ms CPU time over 1.698s wall clock time, 11M memory peak, 6.4M read from disk, 34.9M written to disk.
Oct 15 22:22:02 evo-x2 memory-emergency-guard-check[3109935]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.75% sustained (max disk busy 47.0%, MemAvailable=47.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 22:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:25:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:26:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 22:28:36 evo-x2 systemd[1]: memory-emergency-guard.timer: Deactivated successfully.
Oct 15 22:28:36 evo-x2 gatus[1924605]: 2026/10/15 22:28:36 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
```

## THERMAL THROTTLE lines
```
Oct 15 03:15:40 evo-x2 thermal-pstate-guard-check[23233]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 15 08:14:42 evo-x2 thermal-pstate-guard-check[2166615]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Oct 15 08:18:06 evo-x2 thermal-pstate-guard-check[2207559]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 15 08:26:54 evo-x2 thermal-pstate-guard-check[2417435]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=66C(hi:95/lo:80)
Oct 15 16:10:29 evo-x2 thermal-pstate-guard-check[3048182]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 15 16:17:56 evo-x2 thermal-pstate-guard-check[3240436]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=68C(hi:95/lo:80)
Oct 15 17:06:14 evo-x2 thermal-pstate-guard-check[3857876]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 15 22:23:14 evo-x2 thermal-pstate-guard-check[3119530]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=59C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 15 03:14:01 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 03:14:01 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 03:14:01 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 15 03:14:03 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
