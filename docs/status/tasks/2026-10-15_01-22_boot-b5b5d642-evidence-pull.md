# Boot evidence pull: id8 b5b5d642 (full: b5b5d64245c34f2087ef45bf7c68c794)

Pulled 2026-10-15 01:22 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-15 02:19:14 -> 2026-10-15 03:12:26 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 b5b5d642 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 15 02:19:14 evo-x2 kernel: Linux version 7.2.9 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC Sat Oct  3 10:43:16 UTC 2026
Oct 15 02:19:14 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 02:19:14 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 15 03:12:22 evo-x2 postgres[1825866]: [1825866] HINT:  Rebuild all objects in this database that use the default collation and run ALTER DATABASE paperless REFRESH COLLATION VERSION, or build PostgreSQL with the right library version.
Oct 15 03:12:22 evo-x2 cv[5426]: INFO  request method=GET path=/health/live status=200 duration=110.598µs client_ip=127.0.0.1 request_id=6ad028760000070a921f79e19877b18c
Oct 15 03:12:22 evo-x2 cv[5426]: INFO  Health check completed overall_status=warn checks_count=40 uptime=52m42s
Oct 15 03:12:22 evo-x2 cv[5426]: INFO  request method=GET path=/health status=200 duration=336.691µs client_ip=127.0.0.1 request_id=6ad028760000070b233df0a43fd58f05
Oct 15 03:12:23 evo-x2 inboxclean[2246]: 2026/10/15 03:12:23 INFO request method=GET path=/dead-letters status=200 duration=57.935377ms client_ip=192.168.1.62 request_id=6ad02877000000dc015ff44da938a6c5
Oct 15 03:12:23 evo-x2 inboxclean[2246]: 2026/10/15 03:12:23 INFO request method=GET path=/health status=503 duration=224.864µs client_ip=192.168.1.62 request_id=6ad02877000000dd0dbb87d39b7e423f
Oct 15 03:12:23 evo-x2 systemd[1]: Starting Memory + I/O pressure (PSI) metrics for node_exporter textfile...
Oct 15 03:12:24 evo-x2 emeet-pixyd[29786]: 2026/10/15 03:12:24 INFO http request method=GET path=/api/health status=503 duration=42.289µs
Oct 15 03:12:25 evo-x2 file-renamer[1933]: 2026-10-15T03:12:25+02:00 INFO  watcher: Status requested status=warn fail_checks=0
Oct 15 03:12:25 evo-x2 file-renamer[1933]: 2026-10-15T03:12:25+02:00 INFO  watcher: request method=GET path=/status status=200 duration=1.023663ms client_ip=127.0.0.1 request_id=6ad028790000009e99b1c4a9b80d4e00
Oct 15 03:12:26 evo-x2 emeet-pixyd[29786]: 2026/10/15 03:12:26 INFO http request method=GET path=/ status=0 duration=295.612µs
Oct 15 03:12:26 evo-x2 indexer[1938]: INFO request method=GET path=/ status=200 duration=5.340307ms client_ip=192.168.1.150 request_id=6ad0287a000000a9dc0db3d6e261a2cb
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 123
- thermal-THROTTLE-lines: 1
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 15 02:21:15 evo-x2 memory-emergency-guard-check[17878]: MEMORY EMERGENCY io drained (io PSI some avg60=23.00% < 40%) — churn units re-armed (re-arm #73)
Oct 15 02:21:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:23:13 evo-x2 memory-emergency-guard-check[40887]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.67% sustained (max disk busy 98.1%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (444s < 600s, 156s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 02:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:26:14 evo-x2 memory-emergency-guard-check[103482]: MEMORY EMERGENCY: I/O PSI some avg60=77.60% sustained (max disk busy 100.0%, MemAvailable=42.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 02:27:51 evo-x2 memory-emergency-guard-check[103482]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3140, zone 6)
Oct 15 02:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 934ms CPU time over 1min 37.077s wall clock time, 10.5M memory peak, 3M read from disk, 338.7M written to disk.
Oct 15 02:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:29:22 evo-x2 systemd[1856]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 15 02:29:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:30:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:32:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:33:23 evo-x2 memory-emergency-guard-check[301201]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.54% sustained (max disk busy 99.7%, MemAvailable=59.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (429s < 600s, 171s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 02:33:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:34:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:34:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 146ms wall clock time, 9.9M memory peak, 1M read from disk, 4K written to disk.
Oct 15 02:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:36:24 evo-x2 memory-emergency-guard-check[460578]: MEMORY EMERGENCY: I/O PSI some avg60=74.94% sustained (max disk busy 100.0%, MemAvailable=64.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 02:36:41 evo-x2 memory-emergency-guard-check[460578]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3141, zone 6) — top io since last trip: system.slice/io.stat +66478MB, system.slice/nix-daemon.service/io.stat +30715MB, user.slice/io.stat +17600MB
Oct 15 02:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 615ms CPU time over 16.965s wall clock time, 10M memory peak, 5.9M read from disk, 132.4M written to disk.
Oct 15 02:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 157ms wall clock time, 7.7M memory peak, 1.1M read from disk, 4K written to disk.
Oct 15 02:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:43:32 evo-x2 memory-emergency-guard-check[746607]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.84% sustained (max disk busy 97.6%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (428s < 600s, 172s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 02:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:46:32 evo-x2 memory-emergency-guard-check[891534]: MEMORY EMERGENCY: I/O PSI some avg60=96.72% sustained (max disk busy 100.0%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 02:46:49 evo-x2 memory-emergency-guard-check[891534]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3142, zone 6) — top io since last trip: system.slice/io.stat +55931MB, system.slice/nix-daemon.service/io.stat +24526MB, user.slice/io.stat +16800MB
Oct 15 02:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 864ms CPU time over 16.575s wall clock time, 10.7M memory peak, 1.4M read from disk, 80.7M written to disk.
Oct 15 02:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:53:33 evo-x2 memory-emergency-guard-check[1137800]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.48% sustained (max disk busy 100.0%, MemAvailable=57.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (421s < 600s, 179s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 02:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:56:34 evo-x2 memory-emergency-guard-check[1244623]: MEMORY EMERGENCY: I/O PSI some avg60=90.69% sustained (max disk busy 97.4%, MemAvailable=56.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 02:57:52 evo-x2 memory-emergency-guard-check[1244623]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3143, zone 6) — top io since last trip: system.slice/io.stat +47561MB, user.slice/io.stat +23839MB, user.slice/user-1000.slice/io.stat +23668MB
Oct 15 02:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 911ms CPU time over 1min 18.553s wall clock time, 10.9M memory peak, 736K read from disk, 133.9M written to disk.
Oct 15 02:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:59:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 02:59:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:02:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:03:54 evo-x2 memory-emergency-guard-check[1482480]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.66% sustained (max disk busy 100.0%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (440s < 600s, 160s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 15 03:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 141ms CPU time over 201ms wall clock time, 9.8M memory peak, 1.8M read from disk, 4K written to disk.
Oct 15 03:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:06:54 evo-x2 memory-emergency-guard-check[1624516]: MEMORY EMERGENCY: I/O PSI some avg60=87.19% sustained (max disk busy 100.0%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 15 03:06:55 evo-x2 memory-emergency-guard-check[1624516]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3144, zone 6) — top io since last trip: system.slice/io.stat +68728MB, user.slice/io.stat +15202MB, system.slice/inboxclean-web.service/io.stat +15151MB
Oct 15 03:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 1.090s wall clock time, 9.8M memory peak, 3.6M read from disk, 69M written to disk.
Oct 15 03:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:08:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 15 03:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 15 02:21:03 evo-x2 thermal-pstate-guard-check[17536]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 15 02:19:14 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 02:19:14 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/6hd6lr16i9kv5vm8hyb9p3vr2x6ai745-nixos-system-evo-x2-26.11.20261011.7fd4004/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 15 02:19:14 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 15 02:19:16 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
