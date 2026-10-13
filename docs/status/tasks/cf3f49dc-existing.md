# Boot evidence pull: id8 cf3f49dc (full: cf3f49dca02c44628bcad37329469a89)

Pulled 2026-10-13 22:12 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-12 13:05:41 -> 2026-10-14 00:11:46 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 cf3f49dc — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 12 13:05:41 evo-x2 kernel: Linux version 7.2.9 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC Sat Oct  3 10:43:16 UTC 2026
Oct 12 13:05:41 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/i8ycx8pfdgb07s7d54zl0d9br215bb62-nixos-system-evo-x2-26.11.20261008.e7439b6/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 12 13:05:41 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 14 00:12:08 evo-x2 systemd[1]: gpu-active.service: Deactivated successfully.
Oct 14 00:12:08 evo-x2 systemd[1]: Finished GPUActive / GPUReclaim textfile collector for node_exporter.
Oct 14 00:12:08 evo-x2 systemd[1]: Starting NVMe SMART metrics collector for node_exporter textfile...
Oct 14 00:12:08 evo-x2 systemd[1]: Starting PapDashboard services.json drift check for node_exporter textfile...
Oct 14 00:12:08 evo-x2 systemd[1]: papdashboard-services-json-check.service: Deactivated successfully.
Oct 14 00:12:08 evo-x2 systemd[1]: Finished PapDashboard services.json drift check for node_exporter textfile.
Oct 14 00:12:08 evo-x2 systemd[1]: nvme-metrics.service: Deactivated successfully.
Oct 14 00:12:08 evo-x2 systemd[1]: Finished NVMe SMART metrics collector for node_exporter textfile.
Oct 14 00:12:08 evo-x2 cv[2823771]: INFO  Health check completed overall_status=warn checks_count=40 uptime=26h18m46s
Oct 14 00:12:08 evo-x2 cv[2823771]: INFO  request method=GET path=/health status=200 duration=233.383µs client_ip=127.0.0.1 request_id=6aceacb80000e389960e8d834b743a68
Oct 14 00:12:08 evo-x2 server[2808397]: INFO request method=GET path=/api/questions status=200 duration=394.676µs client_ip=127.0.0.1 request_id=6aceacb80000551be0a1e89b6021826f
Oct 14 00:12:09 evo-x2 systemd[1]: Starting Memory emergency guard: sacrifice FastFlowLM before the thrash-freeze cliff (MemAvailable/zram thresholds)...
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 4719
- thermal-THROTTLE-lines: 35
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 12 13:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:10:10 evo-x2 memory-emergency-guard-check[46357]: MEMORY EMERGENCY: I/O PSI some avg60=78.29% sustained (max disk busy 100.0%, MemAvailable=79.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 13:10:11 evo-x2 memory-emergency-guard-check[46357]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2804, zone 6)
Oct 12 13:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:10:41 evo-x2 memory-emergency-guard-check[56776]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.08% sustained (max disk busy 100.0%, MemAvailable=79.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 13:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:20:20 evo-x2 memory-emergency-guard-check[179682]: MEMORY EMERGENCY: I/O PSI some avg60=67.77% sustained (max disk busy 39.6%, MemAvailable=63.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 13:20:20 evo-x2 memory-emergency-guard-check[179682]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2805, zone 6) — top io since last trip: system.slice/io.stat +48665MB, system.slice/llama-chat.service/io.stat +19848MB, user.slice/io.stat +5987MB
Oct 12 13:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:20:50 evo-x2 memory-emergency-guard-check[189865]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.84% sustained (max disk busy 47.8%, MemAvailable=57.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 13:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:23:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:25:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:25:31 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 13:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:30:24 evo-x2 memory-emergency-guard-check[321807]: MEMORY EMERGENCY: I/O PSI some avg60=71.81% sustained (max disk busy 100.0%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 13:30:24 evo-x2 memory-emergency-guard-check[321807]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2806, zone 6) — top io since last trip: system.slice/io.stat +23101MB, system.slice/inboxclean-web.service/io.stat +10705MB, user.slice/io.stat +3031MB
Oct 12 13:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:30:54 evo-x2 memory-emergency-guard-check[344788]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.59% sustained (max disk busy 100.0%, MemAvailable=60.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 13:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:31:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:40:27 evo-x2 memory-emergency-guard-check[693742]: MEMORY EMERGENCY: I/O PSI some avg60=46.34% sustained (max disk busy 82.4%, MemAvailable=42.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 13:40:28 evo-x2 memory-emergency-guard-check[693742]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2807, zone 6) — top io since last trip: system.slice/io.stat +12576MB, user.slice/io.stat +11241MB, user.slice/user-1000.slice/io.stat +9288MB
Oct 12 13:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:40:57 evo-x2 memory-emergency-guard-check[744298]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.17% sustained (max disk busy 91.5%, MemAvailable=43.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 13:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:50:29 evo-x2 memory-emergency-guard-check[1160200]: MEMORY EMERGENCY: I/O PSI some avg60=53.14% sustained (max disk busy 32.1%, MemAvailable=59.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 13:50:29 evo-x2 memory-emergency-guard-check[1160200]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2808, zone 6) — top io since last trip: system.slice/io.stat +27715MB, user.slice/io.stat +12819MB, user.slice/user-1000.slice/io.stat +12436MB
Oct 12 13:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:50:59 evo-x2 memory-emergency-guard-check[1190106]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.54% sustained (max disk busy 53.0%, MemAvailable=70.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 13:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:52:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:55:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 13:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:00:30 evo-x2 memory-emergency-guard-check[1354269]: MEMORY EMERGENCY: I/O PSI some avg60=51.10% sustained (max disk busy 91.2%, MemAvailable=44.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 14:00:30 evo-x2 memory-emergency-guard-check[1354269]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2809, zone 6) — top io since last trip: system.slice/io.stat +32783MB, user.slice/io.stat +4251MB, user.slice/user-1000.slice/io.stat +4208MB
Oct 12 14:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:01:00 evo-x2 memory-emergency-guard-check[1365076]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.71% sustained (max disk busy 25.9%, MemAvailable=61.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 14:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:06:12 evo-x2 memory-emergency-guard-check[1450222]: MEMORY EMERGENCY io drained (io PSI some avg60=38.87% < 40%) — churn units re-armed (re-arm #3)
Oct 12 14:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:10:32 evo-x2 memory-emergency-guard-check[1558955]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 14:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:15:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:18:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:19:34 evo-x2 memory-emergency-guard-check[1759773]: MEMORY EMERGENCY: I/O PSI some avg60=41.58% sustained (max disk busy 99.6%, MemAvailable=31.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 14:19:35 evo-x2 memory-emergency-guard-check[1759773]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2810, zone 6) — top io since last trip: system.slice/io.stat +44568MB, system.slice/inboxclean-web.service/io.stat +10879MB, user.slice/io.stat +7312MB
Oct 12 14:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:20:04 evo-x2 memory-emergency-guard-check[1782895]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.91% sustained (max disk busy 100.0%, MemAvailable=33.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 14:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:23:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:29:36 evo-x2 memory-emergency-guard-check[1987042]: MEMORY EMERGENCY: I/O PSI some avg60=54.43% sustained (max disk busy 25.9%, MemAvailable=59.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 14:29:36 evo-x2 memory-emergency-guard-check[1987042]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2811, zone 6) — top io since last trip: system.slice/io.stat +25872MB, system.slice/inboxclean-web.service/io.stat +6299MB, user.slice/io.stat +4906MB
Oct 12 14:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:30:06 evo-x2 memory-emergency-guard-check[2013273]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.50% sustained (max disk busy 54.4%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 14:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:30:57 evo-x2 gatus[105274]: 2026/10/12 14:30:57 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 12 14:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:31:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:31:46 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 14:32:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:39:40 evo-x2 memory-emergency-guard-check[2207200]: MEMORY EMERGENCY: I/O PSI some avg60=61.92% sustained (max disk busy 100.0%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 14:39:43 evo-x2 memory-emergency-guard-check[2207200]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2812, zone 6) — top io since last trip: system.slice/io.stat +54099MB, user.slice/io.stat +7352MB, user.slice/user-1000.slice/io.stat +3880MB
Oct 12 14:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:40:10 evo-x2 memory-emergency-guard-check[2226685]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.92% sustained (max disk busy 60.7%, MemAvailable=61.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 14:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:49:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:51:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:54:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:54:43 evo-x2 memory-emergency-guard-check[2787777]: MEMORY EMERGENCY: I/O PSI some avg60=44.95% sustained (max disk busy 96.7%, MemAvailable=39.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 14:54:45 evo-x2 memory-emergency-guard-check[2787777]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2813, zone 6) — top io since last trip: system.slice/io.stat +82143MB, system.slice/nix-daemon.service/io.stat +17088MB, system.slice/inboxclean-web.service/io.stat +6930MB
Oct 12 14:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:55:13 evo-x2 memory-emergency-guard-check[2803091]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.47% sustained (max disk busy 31.5%, MemAvailable=56.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 14:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:57:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:57:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 14:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:04:46 evo-x2 memory-emergency-guard-check[2926730]: MEMORY EMERGENCY: I/O PSI some avg60=68.28% sustained (max disk busy 67.4%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:04:46 evo-x2 memory-emergency-guard-check[2926730]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2814, zone 6) — top io since last trip: system.slice/io.stat +16986MB, user.slice/io.stat +10797MB, user.slice/user-1000.slice/io.stat +10596MB
Oct 12 15:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:05:16 evo-x2 memory-emergency-guard-check[2940323]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.04% sustained (max disk busy 84.7%, MemAvailable=60.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:05:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:10:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:14:47 evo-x2 memory-emergency-guard-check[3176174]: MEMORY EMERGENCY: I/O PSI some avg60=64.13% sustained (max disk busy 93.2%, MemAvailable=60.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:14:48 evo-x2 memory-emergency-guard-check[3176174]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2815, zone 6) — top io since last trip: system.slice/io.stat +13892MB, user.slice/io.stat +9110MB, user.slice/user-1000.slice/io.stat +9060MB
Oct 12 15:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:15:17 evo-x2 memory-emergency-guard-check[3201629]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.64% sustained (max disk busy 94.3%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:24:49 evo-x2 memory-emergency-guard-check[3537434]: MEMORY EMERGENCY: I/O PSI some avg60=64.21% sustained (max disk busy 98.4%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:24:49 evo-x2 memory-emergency-guard-check[3537434]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2816, zone 6) — top io since last trip: system.slice/io.stat +11003MB, user.slice/io.stat +10454MB, user.slice/user-1000.slice/io.stat +10445MB
Oct 12 15:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:25:19 evo-x2 memory-emergency-guard-check[3557050]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.33% sustained (max disk busy 96.8%, MemAvailable=60.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:34:51 evo-x2 memory-emergency-guard-check[3769673]: MEMORY EMERGENCY: I/O PSI some avg60=57.24% sustained (max disk busy 97.5%, MemAvailable=47.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:34:51 evo-x2 memory-emergency-guard-check[3769673]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2817, zone 6) — top io since last trip: system.slice/io.stat +20272MB, user.slice/io.stat +9872MB, user.slice/user-1000.slice/io.stat +9825MB
Oct 12 15:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:35:21 evo-x2 memory-emergency-guard-check[3784907]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.49% sustained (max disk busy 100.0%, MemAvailable=44.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:36:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:39:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:40:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:44:56 evo-x2 memory-emergency-guard-check[3976442]: MEMORY EMERGENCY: I/O PSI some avg60=65.31% sustained (max disk busy 62.8%, MemAvailable=62.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:44:56 evo-x2 memory-emergency-guard-check[3976442]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2818, zone 6) — top io since last trip: system.slice/io.stat +21226MB, user.slice/io.stat +15906MB, user.slice/user-1000.slice/io.stat +14908MB
Oct 12 15:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:45:27 evo-x2 memory-emergency-guard-check[3993599]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.40% sustained (max disk busy 36.6%, MemAvailable=63.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:48:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:48:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:49:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:50:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:50:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:52:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:55:00 evo-x2 memory-emergency-guard-check[102403]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 15:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:55:30 evo-x2 memory-emergency-guard-check[108262]: MEMORY EMERGENCY: I/O PSI some avg60=48.18% sustained (max disk busy 44.2%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 15:55:31 evo-x2 memory-emergency-guard-check[108262]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2819, zone 6) — top io since last trip: system.slice/io.stat +30589MB, system.slice/forgejo.service/io.stat +12546MB, user.slice/io.stat +10291MB
Oct 12 15:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:56:01 evo-x2 memory-emergency-guard-check[118600]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.29% sustained (max disk busy 21.1%, MemAvailable=60.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 15:56:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:57:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 15:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:01:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:02:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:06:04 evo-x2 memory-emergency-guard-check[329871]: MEMORY EMERGENCY: I/O PSI some avg60=42.40% sustained (max disk busy 54.2%, MemAvailable=44.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:06:05 evo-x2 memory-emergency-guard-check[329871]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2820, zone 6) — top io since last trip: system.slice/io.stat +18863MB, user.slice/io.stat +11869MB, user.slice/user-1000.slice/io.stat +11057MB
Oct 12 16:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:06:35 evo-x2 memory-emergency-guard-check[340248]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.32% sustained (max disk busy 28.9%, MemAvailable=42.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 16:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:12:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:16:08 evo-x2 memory-emergency-guard-check[557045]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 16:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:16:38 evo-x2 memory-emergency-guard-check[567377]: MEMORY EMERGENCY: I/O PSI some avg60=49.06% sustained (max disk busy 29.2%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:16:38 evo-x2 memory-emergency-guard-check[567377]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2821, zone 6) — top io since last trip: system.slice/io.stat +20212MB, system.slice/inboxclean-web.service/io.stat +8310MB, user.slice/io.stat +7170MB
Oct 12 16:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:17:38 evo-x2 memory-emergency-guard-check[598166]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.11% sustained (max disk busy 63.9%, MemAvailable=60.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 16:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:21:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:26:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:26:43 evo-x2 memory-emergency-guard-check[769612]: MEMORY EMERGENCY: I/O PSI some avg60=58.10% sustained (max disk busy 23.6%, MemAvailable=60.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:26:44 evo-x2 memory-emergency-guard-check[769612]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2822, zone 6) — top io since last trip: system.slice/io.stat +12799MB, system.slice/inboxclean-web.service/io.stat +8156MB, system.slice/nix-daemon.service/io.stat +3106MB
Oct 12 16:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:27:43 evo-x2 memory-emergency-guard-check[796108]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.05% sustained (max disk busy 49.9%, MemAvailable=61.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 16:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:32:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:36:46 evo-x2 memory-emergency-guard-check[890593]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 16:36:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:37:46 evo-x2 memory-emergency-guard-check[901289]: MEMORY EMERGENCY: I/O PSI some avg60=76.27% sustained (max disk busy 42.8%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:37:46 evo-x2 memory-emergency-guard-check[901289]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2823, zone 6) — top io since last trip: system.slice/io.stat +17786MB, system.slice/inboxclean-web.service/io.stat +10030MB, system.slice/nix-daemon.service/io.stat +5695MB
Oct 12 16:37:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:38:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:38:46 evo-x2 memory-emergency-guard-check[916390]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.59% sustained (max disk busy 25.4%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 16:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:40:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:40:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:41:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:41:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:44:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:44:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:47:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:47:47 evo-x2 memory-emergency-guard-check[1003394]: MEMORY EMERGENCY: I/O PSI some avg60=78.54% sustained (max disk busy 44.7%, MemAvailable=60.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:47:48 evo-x2 memory-emergency-guard-check[1003394]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2824, zone 6) — top io since last trip: system.slice/io.stat +9274MB, system.slice/nix-daemon.service/io.stat +4165MB, system.slice/inboxclean-web.service/io.stat +3735MB
Oct 12 16:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:48:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:48:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:50:18 evo-x2 memory-emergency-guard-check[1031143]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.12% sustained (max disk busy 34.8%, MemAvailable=60.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (151s < 600s, 449s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 16:50:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:52:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:57:49 evo-x2 memory-emergency-guard-check[1098957]: MEMORY EMERGENCY: I/O PSI some avg60=72.33% sustained (max disk busy 51.7%, MemAvailable=60.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 16:57:49 evo-x2 memory-emergency-guard-check[1098957]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2825, zone 6) — top io since last trip: system.slice/io.stat +17542MB, system.slice/inboxclean-web.service/io.stat +6687MB, system.slice/forgejo.service/io.stat +4829MB
Oct 12 16:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 16:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:00:20 evo-x2 memory-emergency-guard-check[1123260]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.13% sustained (max disk busy 47.8%, MemAvailable=60.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (151s < 600s, 449s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:07:54 evo-x2 memory-emergency-guard-check[1186638]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 17:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:08:25 evo-x2 memory-emergency-guard-check[1190504]: MEMORY EMERGENCY: I/O PSI some avg60=74.18% sustained (max disk busy 25.0%, MemAvailable=60.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:08:26 evo-x2 memory-emergency-guard-check[1190504]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2826, zone 6) — top io since last trip: system.slice/io.stat +11734MB, system.slice/nix-daemon.service/io.stat +5174MB, system.slice/inboxclean-web.service/io.stat +5018MB
Oct 12 17:08:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:10:28 evo-x2 memory-emergency-guard-check[1220371]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.50% sustained (max disk busy 27.0%, MemAvailable=60.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (123s < 600s, 477s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:18:32 evo-x2 memory-emergency-guard-check[1340370]: MEMORY EMERGENCY: I/O PSI some avg60=59.64% sustained (max disk busy 29.2%, MemAvailable=60.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:18:33 evo-x2 memory-emergency-guard-check[1340370]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2827, zone 6) — top io since last trip: system.slice/io.stat +11691MB, system.slice/inboxclean-web.service/io.stat +7817MB, user.slice/io.stat +3563MB
Oct 12 17:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:20:32 evo-x2 memory-emergency-guard-check[1364178]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.01% sustained (max disk busy 32.2%, MemAvailable=60.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:26:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:28:36 evo-x2 memory-emergency-guard-check[1486021]: MEMORY EMERGENCY: I/O PSI some avg60=60.46% sustained (max disk busy 25.6%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:28:36 evo-x2 memory-emergency-guard-check[1486021]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2828, zone 6) — top io since last trip: system.slice/io.stat +15329MB, system.slice/inboxclean-web.service/io.stat +8363MB, system.slice/forgejo.service/io.stat +5320MB
Oct 12 17:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:30:37 evo-x2 memory-emergency-guard-check[1516966]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.14% sustained (max disk busy 27.9%, MemAvailable=60.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 600s, 479s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:38:40 evo-x2 memory-emergency-guard-check[1714626]: MEMORY EMERGENCY: I/O PSI some avg60=42.90% sustained (max disk busy 53.0%, MemAvailable=36.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:38:41 evo-x2 memory-emergency-guard-check[1714626]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2829, zone 6) — top io since last trip: system.slice/io.stat +10741MB, system.slice/inboxclean-web.service/io.stat +7721MB, user.slice/io.stat +6659MB
Oct 12 17:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:40:40 evo-x2 memory-emergency-guard-check[1832492]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.51% sustained (max disk busy 100.0%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:40:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:48:43 evo-x2 memory-emergency-guard-check[2029229]: MEMORY EMERGENCY: I/O PSI some avg60=73.03% sustained (max disk busy 97.0%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:48:43 evo-x2 memory-emergency-guard-check[2029229]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2830, zone 6) — top io since last trip: system.slice/io.stat +19105MB, user.slice/io.stat +9643MB, user.slice/user-1000.slice/io.stat +8791MB
Oct 12 17:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:49:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:50:43 evo-x2 memory-emergency-guard-check[2171644]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.34% sustained (max disk busy 100.0%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 17:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:51:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:54:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:55:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:55:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:58:45 evo-x2 memory-emergency-guard-check[2350843]: MEMORY EMERGENCY: I/O PSI some avg60=67.34% sustained (max disk busy 100.0%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 17:58:46 evo-x2 memory-emergency-guard-check[2350843]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2831, zone 6) — top io since last trip: system.slice/io.stat +16444MB, user.slice/io.stat +12234MB, user.slice/user-1000.slice/io.stat +11424MB
Oct 12 17:58:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 17:59:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:00:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:00:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:01:17 evo-x2 memory-emergency-guard-check[2400360]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.47% sustained (max disk busy 27.6%, MemAvailable=59.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (152s < 600s, 448s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:01:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:01:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:02:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:02:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:04:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:05:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:05:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:08:47 evo-x2 memory-emergency-guard-check[2692130]: MEMORY EMERGENCY: I/O PSI some avg60=75.80% sustained (max disk busy 100.0%, MemAvailable=56.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 18:08:48 evo-x2 memory-emergency-guard-check[2692130]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2832, zone 6) — top io since last trip: system.slice/io.stat +20912MB, system.slice/nix-daemon.service/io.stat +7429MB, system.slice/inboxclean-web.service/io.stat +7353MB
Oct 12 18:08:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:10:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:10:53 evo-x2 gatus[2049883]: 2026/10/12 18:10:53 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 12 18:11:17 evo-x2 memory-emergency-guard-check[2781092]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.36% sustained (max disk busy 33.6%, MemAvailable=42.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (150s < 600s, 450s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:11:56 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 18:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:18:49 evo-x2 memory-emergency-guard-check[3150833]: MEMORY EMERGENCY: I/O PSI some avg60=43.56% sustained (max disk busy 74.4%, MemAvailable=36.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 18:18:52 evo-x2 memory-emergency-guard-check[3150833]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2833, zone 6) — top io since last trip: system.slice/io.stat +57081MB, user.slice/io.stat +24963MB, user.slice/user-1000.slice/io.stat +23504MB
Oct 12 18:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:21:20 evo-x2 memory-emergency-guard-check[3290432]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.88% sustained (max disk busy 65.1%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (151s < 600s, 449s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:23:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:25:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:28:53 evo-x2 memory-emergency-guard-check[3597702]: MEMORY EMERGENCY: I/O PSI some avg60=79.73% sustained (max disk busy 100.0%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 18:28:53 evo-x2 memory-emergency-guard-check[3597702]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2834, zone 6) — top io since last trip: system.slice/io.stat +33580MB, system.slice/nix-daemon.service/io.stat +13671MB, system.slice/forgejo.service/io.stat +12892MB
Oct 12 18:28:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:29:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:31:24 evo-x2 memory-emergency-guard-check[3701664]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.67% sustained (max disk busy 100.0%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (151s < 600s, 449s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:37:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:38:58 evo-x2 memory-emergency-guard-check[3888576]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 18:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:41:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:44:00 evo-x2 memory-emergency-guard-check[4175719]: MEMORY EMERGENCY: I/O PSI some avg60=42.29% sustained (max disk busy 61.9%, MemAvailable=17.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 18:44:00 evo-x2 memory-emergency-guard-check[4175719]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2835, zone 6) — top io since last trip: user.slice/io.stat +48108MB, user.slice/user-1000.slice/io.stat +47997MB, system.slice/io.stat +38732MB
Oct 12 18:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:45:00 evo-x2 memory-emergency-guard-check[40039]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.95% sustained (max disk busy 79.9%, MemAvailable=28.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:54:02 evo-x2 memory-emergency-guard-check[364775]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 18:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:56:02 evo-x2 memory-emergency-guard-check[438634]: MEMORY EMERGENCY: I/O PSI some avg60=41.69% sustained (max disk busy 85.9%, MemAvailable=27.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 18:56:03 evo-x2 memory-emergency-guard-check[438634]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2836, zone 6) — top io since last trip: system.slice/io.stat +52970MB, system.slice/nix-daemon.service/io.stat +22502MB, user.slice/io.stat +18415MB
Oct 12 18:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:56:32 evo-x2 memory-emergency-guard-check[462257]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.60% sustained (max disk busy 60.4%, MemAvailable=30.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 18:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 18:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:06:03 evo-x2 memory-emergency-guard-check[789072]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 19:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:06:33 evo-x2 memory-emergency-guard-check[795640]: MEMORY EMERGENCY: I/O PSI some avg60=47.43% sustained (max disk busy 57.9%, MemAvailable=32.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 19:06:34 evo-x2 memory-emergency-guard-check[796129]: sort: fflush failed: 'standard output': Broken pipe
Oct 12 19:06:34 evo-x2 memory-emergency-guard-check[796129]: sort: write error
Oct 12 19:06:34 evo-x2 memory-emergency-guard-check[795640]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2837, zone 6) — top io since last trip: system.slice/io.stat +29445MB, user.slice/io.stat +15144MB, user.slice/user-1000.slice/io.stat +14875MB
Oct 12 19:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:09:35 evo-x2 memory-emergency-guard-check[878327]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.79% sustained (max disk busy 21.5%, MemAvailable=32.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (182s < 600s, 418s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 19:09:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:10:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:13:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:15:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:16:38 evo-x2 memory-emergency-guard-check[1024169]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 19:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:18:09 evo-x2 memory-emergency-guard-check[1079828]: MEMORY EMERGENCY: I/O PSI some avg60=50.51% sustained (max disk busy 40.0%, MemAvailable=60.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 19:18:10 evo-x2 memory-emergency-guard-check[1079828]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2838, zone 6) — top io since last trip: system.slice/io.stat +30243MB, system.slice/nix-daemon.service/io.stat +6780MB, user.slice/io.stat +6544MB
Oct 12 19:18:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:19:40 evo-x2 memory-emergency-guard-check[1108559]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.41% sustained (max disk busy 100.0%, MemAvailable=42.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 19:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:20:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:28:15 evo-x2 memory-emergency-guard-check[1321730]: MEMORY EMERGENCY: I/O PSI some avg60=41.12% sustained (max disk busy 68.7%, MemAvailable=29.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 19:28:16 evo-x2 memory-emergency-guard-check[1321730]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2839, zone 6) — top io since last trip: user.slice/io.stat +45891MB, user.slice/user-1000.slice/io.stat +45562MB, user.slice/user-1000.slice/user@1000.service/io.stat +30028MB
Oct 12 19:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:34:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:38:17 evo-x2 memory-emergency-guard-check[1679852]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 19:38:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:38:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:39:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:39:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:40:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:47:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:48:19 evo-x2 memory-emergency-guard-check[1808511]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 19:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:51:20 evo-x2 memory-emergency-guard-check[1854965]: MEMORY EMERGENCY: I/O PSI some avg60=50.54% sustained (max disk busy 44.4%, MemAvailable=28.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 19:51:21 evo-x2 memory-emergency-guard-check[1854965]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2840, zone 6) — top io since last trip: system.slice/io.stat +58894MB, user.slice/io.stat +18490MB, user.slice/user-1000.slice/io.stat +16514MB
Oct 12 19:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:51:51 evo-x2 memory-emergency-guard-check[1876191]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.25% sustained (max disk busy 39.5%, MemAvailable=28.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 19:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 19:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:01:26 evo-x2 memory-emergency-guard-check[2163478]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 20:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:04:27 evo-x2 memory-emergency-guard-check[2229632]: MEMORY EMERGENCY: I/O PSI some avg60=46.79% sustained (max disk busy 25.0%, MemAvailable=59.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:04:27 evo-x2 memory-emergency-guard-check[2229632]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2841, zone 6) — top io since last trip: system.slice/io.stat +7080MB, user.slice/io.stat +5956MB, user.slice/user-1000.slice/io.stat +5433MB
Oct 12 20:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:04:58 evo-x2 memory-emergency-guard-check[2272461]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.26% sustained (max disk busy 54.5%, MemAvailable=57.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:12:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:13:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:14:31 evo-x2 memory-emergency-guard-check[2548438]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 20:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:15:31 evo-x2 memory-emergency-guard-check[2591666]: MEMORY EMERGENCY: I/O PSI some avg60=41.38% sustained (max disk busy 51.0%, MemAvailable=42.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:15:32 evo-x2 memory-emergency-guard-check[2591666]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2842, zone 6) — top io since last trip: user.slice/io.stat +10223MB, user.slice/user-1000.slice/io.stat +10201MB, system.slice/io.stat +5301MB
Oct 12 20:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:16:02 evo-x2 memory-emergency-guard-check[2649926]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.79% sustained (max disk busy 85.3%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:25:33 evo-x2 memory-emergency-guard-check[3185748]: MEMORY EMERGENCY: I/O PSI some avg60=62.10% sustained (max disk busy 100.0%, MemAvailable=57.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:25:34 evo-x2 memory-emergency-guard-check[3185748]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2843, zone 6) — top io since last trip: system.slice/io.stat +12005MB, user.slice/io.stat +9362MB, user.slice/user-1000.slice/io.stat +9307MB
Oct 12 20:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:26:04 evo-x2 memory-emergency-guard-check[3197141]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.29% sustained (max disk busy 98.6%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:27:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:27:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:31:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:32:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:35:38 evo-x2 memory-emergency-guard-check[3521984]: MEMORY EMERGENCY: I/O PSI some avg60=59.14% sustained (max disk busy 100.0%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:35:38 evo-x2 memory-emergency-guard-check[3521984]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2844, zone 6) — top io since last trip: user.slice/io.stat +7905MB, user.slice/user-1000.slice/io.stat +7904MB, system.slice/io.stat +4204MB
Oct 12 20:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:36:09 evo-x2 memory-emergency-guard-check[3573560]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.10% sustained (max disk busy 100.0%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:45:43 evo-x2 memory-emergency-guard-check[4097772]: MEMORY EMERGENCY: I/O PSI some avg60=44.69% sustained (max disk busy 75.5%, MemAvailable=45.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:45:44 evo-x2 memory-emergency-guard-check[4097772]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2845, zone 6) — top io since last trip: user.slice/io.stat +15467MB, user.slice/user-1000.slice/io.stat +15461MB, system.slice/io.stat +9127MB
Oct 12 20:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:46:14 evo-x2 memory-emergency-guard-check[4132364]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.12% sustained (max disk busy 99.7%, MemAvailable=47.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:48:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:52:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:55:48 evo-x2 memory-emergency-guard-check[196434]: MEMORY EMERGENCY: I/O PSI some avg60=45.33% sustained (max disk busy 27.9%, MemAvailable=38.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 20:55:49 evo-x2 memory-emergency-guard-check[197708]: sort: write failed: 'standard output': Broken pipe
Oct 12 20:55:49 evo-x2 memory-emergency-guard-check[197708]: sort: write error
Oct 12 20:55:49 evo-x2 memory-emergency-guard-check[196434]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2846, zone 6) — top io since last trip: system.slice/io.stat +38854MB, user.slice/io.stat +36950MB, user.slice/user-1000.slice/io.stat +36121MB
Oct 12 20:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:56:18 evo-x2 memory-emergency-guard-check[225700]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.91% sustained (max disk busy 91.0%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 20:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:56:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 20:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:05:52 evo-x2 memory-emergency-guard-check[1053373]: MEMORY EMERGENCY: I/O PSI some avg60=41.31% sustained (max disk busy 93.7%, MemAvailable=49.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 21:05:53 evo-x2 memory-emergency-guard-check[1053373]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2847, zone 6) — top io since last trip: system.slice/io.stat +69177MB, system.slice/nix-daemon.service/io.stat +40410MB, user.slice/io.stat +31494MB
Oct 12 21:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:07:22 evo-x2 memory-emergency-guard-check[1139785]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.63% sustained (max disk busy 100.0%, MemAvailable=33.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 21:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 151ms CPU time over 280ms wall clock time, 7.8M memory peak, 1M read from disk, 4K written to disk.
Oct 12 21:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:15:56 evo-x2 memory-emergency-guard-check[1475224]: MEMORY EMERGENCY: I/O PSI some avg60=64.17% sustained (max disk busy 99.5%, MemAvailable=40.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 21:15:57 evo-x2 memory-emergency-guard-check[1475224]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2848, zone 6) — top io since last trip: system.slice/io.stat +53075MB, user.slice/io.stat +33865MB, user.slice/user-1000.slice/io.stat +33076MB
Oct 12 21:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:17:27 evo-x2 memory-emergency-guard-check[1515774]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.83% sustained (max disk busy 91.9%, MemAvailable=41.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 21:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:25:59 evo-x2 memory-emergency-guard-check[1910062]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 21:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:29:31 evo-x2 memory-emergency-guard-check[2026912]: MEMORY EMERGENCY: I/O PSI some avg60=47.14% sustained (max disk busy 97.6%, MemAvailable=15.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 21:29:32 evo-x2 memory-emergency-guard-check[2026912]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2849, zone 6) — top io since last trip: system.slice/io.stat +57530MB, user.slice/io.stat +48418MB, user.slice/user-1000.slice/io.stat +47719MB
Oct 12 21:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:30:01 evo-x2 memory-emergency-guard-check[2062618]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.86% sustained (max disk busy 100.0%, MemAvailable=14.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 21:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:39:32 evo-x2 memory-emergency-guard-check[2413381]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 21:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:48:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 193ms wall clock time, 6.3M memory peak, 1M read from disk, 4K written to disk.
Oct 12 21:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:50:04 evo-x2 memory-emergency-guard-check[2709022]: MEMORY EMERGENCY: I/O PSI some avg60=44.56% sustained (max disk busy 48.6%, MemAvailable=42.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 21:50:05 evo-x2 memory-emergency-guard-check[2709022]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2850, zone 6) — top io since last trip: system.slice/io.stat +143443MB, user.slice/io.stat +56478MB, user.slice/user-1000.slice/io.stat +54724MB
Oct 12 21:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:50:34 evo-x2 memory-emergency-guard-check[2743025]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.60% sustained (max disk busy 69.7%, MemAvailable=48.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 21:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:52:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:53:39 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 21:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 21:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:00:07 evo-x2 memory-emergency-guard-check[2985987]: MEMORY EMERGENCY: I/O PSI some avg60=40.13% sustained (max disk busy 60.7%, MemAvailable=33.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:00:08 evo-x2 memory-emergency-guard-check[2985987]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2851, zone 6) — top io since last trip: system.slice/io.stat +149617MB, user.slice/io.stat +54879MB, user.slice/user-1000.slice/io.stat +53209MB
Oct 12 22:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:07:39 evo-x2 memory-emergency-guard-check[3155092]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.36% sustained (max disk busy 79.5%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (452s < 600s, 148s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:10:09 evo-x2 memory-emergency-guard-check[3187945]: MEMORY EMERGENCY: I/O PSI some avg60=66.43% sustained (max disk busy 100.0%, MemAvailable=21.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:10:09 evo-x2 memory-emergency-guard-check[3187945]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2852, zone 6) — top io since last trip: system.slice/io.stat +60364MB, user.slice/io.stat +53461MB, user.slice/user-1000.slice/io.stat +52589MB
Oct 12 22:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:17:41 evo-x2 memory-emergency-guard-check[3353682]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.75% sustained (max disk busy 100.0%, MemAvailable=62.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (452s < 600s, 148s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:18:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:19:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:20:11 evo-x2 memory-emergency-guard-check[3466002]: MEMORY EMERGENCY: I/O PSI some avg60=52.50% sustained (max disk busy 99.7%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:20:12 evo-x2 memory-emergency-guard-check[3466002]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2853, zone 6) — top io since last trip: system.slice/io.stat +31345MB, user.slice/io.stat +23565MB, user.slice/user-1000.slice/io.stat +22637MB
Oct 12 22:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:26:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:26:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:27:43 evo-x2 memory-emergency-guard-check[3822788]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.89% sustained (max disk busy 27.1%, MemAvailable=6.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (452s < 600s, 148s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:30:13 evo-x2 memory-emergency-guard-check[3853821]: MEMORY EMERGENCY: MemAvailable=4.0% below absolute floor — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:30:14 evo-x2 memory-emergency-guard-check[3853821]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2854, zone 1) — top io since last trip: system.slice/io.stat +41764MB, user.slice/io.stat +32557MB, user.slice/user-1000.slice/io.stat +32554MB
Oct 12 22:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:38:03 evo-x2 memory-emergency-guard-check[3973795]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.88% sustained (max disk busy 72.4%, MemAvailable=12.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (470s < 600s, 130s remaining; last trip zone=1) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:40:33 evo-x2 memory-emergency-guard-check[4011630]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 22:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:41:33 evo-x2 memory-emergency-guard-check[4031103]: MEMORY EMERGENCY: I/O PSI some avg60=49.67% sustained (max disk busy 53.2%, MemAvailable=65.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:41:34 evo-x2 memory-emergency-guard-check[4031103]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2855, zone 6) — top io since last trip: user.slice/io.stat +59188MB, user.slice/user-1000.slice/io.stat +57942MB, user.slice/user-1000.slice/user@1000.service/io.stat +47123MB
Oct 12 22:41:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:42:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:42:11 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 22:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:44:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:46:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:47:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:48:36 evo-x2 memory-emergency-guard-check[4132835]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.40% sustained (max disk busy 29.1%, MemAvailable=63.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (423s < 600s, 177s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:51:37 evo-x2 memory-emergency-guard-check[4160140]: MEMORY EMERGENCY: I/O PSI some avg60=60.45% sustained (max disk busy 67.0%, MemAvailable=26.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 22:51:37 evo-x2 memory-emergency-guard-check[4160140]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2856, zone 6) — top io since last trip: user.slice/io.stat +28840MB, user.slice/user-1000.slice/io.stat +27949MB, system.slice/io.stat +27027MB
Oct 12 22:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:58:38 evo-x2 memory-emergency-guard-check[70129]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.92% sustained (max disk busy 25.8%, MemAvailable=56.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (421s < 600s, 179s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 22:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 22:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:01:39 evo-x2 memory-emergency-guard-check[96890]: MEMORY EMERGENCY: I/O PSI some avg60=58.91% sustained (max disk busy 96.8%, MemAvailable=62.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:01:40 evo-x2 memory-emergency-guard-check[96890]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2857, zone 6) — top io since last trip: system.slice/io.stat +16337MB, user.slice/io.stat +4524MB, user.slice/user-1000.slice/io.stat +4237MB
Oct 12 23:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:09:10 evo-x2 memory-emergency-guard-check[200715]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.62% sustained (max disk busy 21.5%, MemAvailable=60.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (450s < 600s, 150s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:11:40 evo-x2 memory-emergency-guard-check[217550]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 12 23:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:13:10 evo-x2 memory-emergency-guard-check[228351]: MEMORY EMERGENCY: I/O PSI some avg60=61.03% sustained (max disk busy 20.2%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:13:10 evo-x2 memory-emergency-guard-check[228351]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2858, zone 6) — top io since last trip: system.slice/io.stat +14657MB, system.slice/inboxclean-web.service/io.stat +3777MB, user.slice/io.stat +2129MB
Oct 12 23:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:17:46 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 12 23:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:18:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:19:11 evo-x2 memory-emergency-guard-check[291801]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.64% sustained (max disk busy 24.6%, MemAvailable=61.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:19:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:20:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:21:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:23:12 evo-x2 memory-emergency-guard-check[327437]: MEMORY EMERGENCY: I/O PSI some avg60=76.92% sustained (max disk busy 22.8%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:23:12 evo-x2 memory-emergency-guard-check[327437]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2859, zone 6) — top io since last trip: system.slice/io.stat +29959MB, system.slice/inboxclean-web.service/io.stat +11651MB, system.slice/forgejo.service/io.stat +10659MB
Oct 12 23:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:24:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:25:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:28:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:29:12 evo-x2 memory-emergency-guard-check[427692]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.29% sustained (max disk busy 25.3%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:29:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:32:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:33:13 evo-x2 memory-emergency-guard-check[459992]: MEMORY EMERGENCY: I/O PSI some avg60=77.43% sustained (max disk busy 32.2%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:33:13 evo-x2 memory-emergency-guard-check[459992]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2860, zone 6) — top io since last trip: system.slice/io.stat +7020MB, system.slice/inboxclean-web.service/io.stat +5783MB, system.slice/clickhouse.service/io.stat +829MB
Oct 12 23:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:38:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:39:16 evo-x2 memory-emergency-guard-check[512947]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.44% sustained (max disk busy 35.6%, MemAvailable=62.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (363s < 600s, 237s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:40:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:40:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:41:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:41:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:43:18 evo-x2 memory-emergency-guard-check[543149]: MEMORY EMERGENCY: I/O PSI some avg60=77.53% sustained (max disk busy 26.9%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:43:18 evo-x2 memory-emergency-guard-check[543149]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2861, zone 6) — top io since last trip: system.slice/io.stat +8531MB, system.slice/inboxclean-web.service/io.stat +7268MB, system.slice/clickhouse.service/io.stat +875MB
Oct 12 23:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:44:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:47:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:49:19 evo-x2 memory-emergency-guard-check[592221]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.28% sustained (max disk busy 49.3%, MemAvailable=62.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:51:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:52:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:53:21 evo-x2 memory-emergency-guard-check[622305]: MEMORY EMERGENCY: I/O PSI some avg60=79.57% sustained (max disk busy 28.8%, MemAvailable=61.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 12 23:53:21 evo-x2 memory-emergency-guard-check[622305]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2862, zone 6) — top io since last trip: system.slice/io.stat +2447MB, system.slice/inboxclean-web.service/io.stat +1159MB, system.slice/clickhouse.service/io.stat +821MB
Oct 12 23:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:57:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:57:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:58:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:59:22 evo-x2 memory-emergency-guard-check[670771]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.60% sustained (max disk busy 52.5%, MemAvailable=62.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 12 23:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 12 23:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:00:32 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 13 00:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:03:23 evo-x2 memory-emergency-guard-check[717797]: MEMORY EMERGENCY: I/O PSI some avg60=49.57% sustained (max disk busy 35.4%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 00:03:23 evo-x2 memory-emergency-guard-check[717797]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2863, zone 6) — top io since last trip: system.slice/io.stat +21721MB, system.slice/inboxclean-web.service/io.stat +3759MB, system.slice/clickhouse.service/io.stat +2480MB
Oct 13 00:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:04:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:09:55 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; MEMORY GUARD DEAD" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | memory-emergency-guard metrics are missing/stale (302s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard".
Oct 13 00:14:25 evo-x2 gatus[2826693]: 2026/10/13 00:14:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 00:14:25 evo-x2 gatus[2826693]: 2026/10/13 00:14:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 00:26:30 evo-x2 memory-emergency-guard-check[745953]: MEMORY EMERGENCY io drained (io PSI some avg60=39.10% < 40%) — churn units re-armed (re-arm #4)
Oct 13 00:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:27:30 evo-x2 memory-emergency-guard-check[1091876]: MEMORY EMERGENCY: I/O PSI some avg60=40.07% sustained (max disk busy 99.5%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 00:27:30 evo-x2 memory-emergency-guard-check[1091876]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2864, zone 6) — top io since last trip: system.slice/io.stat +462239MB, system.slice/tq-agent-pool.service/io.stat +388425MB, system.slice/inboxclean-web.service/io.stat +15119MB
Oct 13 00:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:31:00 evo-x2 memory-emergency-guard-check[1130054]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.25% sustained (max disk busy 99.8%, MemAvailable=61.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (210s < 600s, 390s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 00:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:37:32 evo-x2 memory-emergency-guard-check[1197507]: MEMORY EMERGENCY: I/O PSI some avg60=54.46% sustained (max disk busy 99.4%, MemAvailable=57.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 00:37:33 evo-x2 memory-emergency-guard-check[1197507]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2865, zone 6) — top io since last trip: system.slice/io.stat +98549MB, system.slice/tq-agent-pool.service/io.stat +91016MB, system.slice/inboxclean-web.service/io.stat +3692MB
Oct 13 00:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:41:03 evo-x2 memory-emergency-guard-check[1257944]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.41% sustained (max disk busy 99.6%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (211s < 600s, 389s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 00:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:41:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:42:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:43:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:44:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:45:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:47:36 evo-x2 memory-emergency-guard-check[1458716]: MEMORY EMERGENCY: I/O PSI some avg60=44.33% sustained (max disk busy 99.5%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 00:47:36 evo-x2 memory-emergency-guard-check[1458716]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2866, zone 6) — top io since last trip: system.slice/io.stat +20744MB, system.slice/tq-agent-pool.service/io.stat +17560MB, system.slice/inboxclean-web.service/io.stat +1858MB
Oct 13 00:47:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:51:08 evo-x2 memory-emergency-guard-check[1540476]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.60% sustained (max disk busy 99.6%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (211s < 600s, 389s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 00:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:54:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:55:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:57:38 evo-x2 memory-emergency-guard-check[1701313]: MEMORY EMERGENCY: I/O PSI some avg60=42.35% sustained (max disk busy 27.1%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 00:57:38 evo-x2 memory-emergency-guard-check[1701313]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2867, zone 6) — top io since last trip: system.slice/io.stat +74147MB, system.slice/tq-agent-pool.service/io.stat +63611MB, system.slice/inboxclean-web.service/io.stat +4780MB
Oct 13 00:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 00:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:04:38 evo-x2 memory-emergency-guard-check[1784437]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.75% sustained (max disk busy 44.4%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (420s < 600s, 180s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:07:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:08:09 evo-x2 memory-emergency-guard-check[1824219]: MEMORY EMERGENCY: I/O PSI some avg60=41.13% sustained (max disk busy 61.0%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:08:09 evo-x2 memory-emergency-guard-check[1824219]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2868, zone 6) — top io since last trip: system.slice/io.stat +289472MB, system.slice/tq-agent-pool.service/io.stat +282442MB, system.slice/inboxclean-web.service/io.stat +5569MB
Oct 13 01:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:14:39 evo-x2 memory-emergency-guard-check[1939465]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.07% sustained (max disk busy 81.2%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (391s < 600s, 209s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:18:09 evo-x2 memory-emergency-guard-check[2002435]: MEMORY EMERGENCY: I/O PSI some avg60=57.18% sustained (max disk busy 27.3%, MemAvailable=59.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:18:10 evo-x2 memory-emergency-guard-check[2002435]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2869, zone 6) — top io since last trip: system.slice/io.stat +24588MB, system.slice/tq-agent-pool.service/io.stat +16731MB, system.slice/papdashboard.service/io.stat +1598MB
Oct 13 01:18:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:20:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:22:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:24:41 evo-x2 memory-emergency-guard-check[2195977]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.20% sustained (max disk busy 35.4%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (392s < 600s, 208s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:24:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:28:11 evo-x2 memory-emergency-guard-check[2310240]: MEMORY EMERGENCY: I/O PSI some avg60=48.97% sustained (max disk busy 25.0%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:28:11 evo-x2 memory-emergency-guard-check[2310240]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2870, zone 6) — top io since last trip: system.slice/io.stat +23658MB, system.slice/tq-agent-pool.service/io.stat +12119MB, system.slice/inboxclean-web.service/io.stat +7704MB
Oct 13 01:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:34:41 evo-x2 memory-emergency-guard-check[2421053]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.74% sustained (max disk busy 55.5%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (390s < 600s, 210s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:38:11 evo-x2 memory-emergency-guard-check[2459330]: MEMORY EMERGENCY: I/O PSI some avg60=55.29% sustained (max disk busy 20.1%, MemAvailable=52.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:38:11 evo-x2 memory-emergency-guard-check[2459514]: sort: write failed: 'standard output': Broken pipe
Oct 13 01:38:11 evo-x2 memory-emergency-guard-check[2459514]: sort: write error
Oct 13 01:38:11 evo-x2 memory-emergency-guard-check[2459330]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2871, zone 6) — top io since last trip: system.slice/io.stat +253886MB, system.slice/tq-agent-pool.service/io.stat +246476MB, system.slice/inboxclean-web.service/io.stat +3676MB
Oct 13 01:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:44:42 evo-x2 memory-emergency-guard-check[2524965]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.52% sustained (max disk busy 33.1%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (391s < 600s, 209s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:48:12 evo-x2 memory-emergency-guard-check[2600022]: MEMORY EMERGENCY: I/O PSI some avg60=57.55% sustained (max disk busy 26.5%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:48:13 evo-x2 memory-emergency-guard-check[2600022]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2872, zone 6) — top io since last trip: system.slice/io.stat +64231MB, system.slice/tq-agent-pool.service/io.stat +55576MB, system.slice/inboxclean-web.service/io.stat +7457MB
Oct 13 01:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:49:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:51:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:54:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:54:43 evo-x2 memory-emergency-guard-check[2657712]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.37% sustained (max disk busy 34.7%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (391s < 600s, 209s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 01:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:58:43 evo-x2 memory-emergency-guard-check[2694104]: MEMORY EMERGENCY: I/O PSI some avg60=46.32% sustained (max disk busy 43.2%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 01:58:43 evo-x2 memory-emergency-guard-check[2694104]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2873, zone 6) — top io since last trip: system.slice/io.stat +249530MB, system.slice/tq-agent-pool.service/io.stat +228686MB, system.slice/forgejo.service/io.stat +10589MB
Oct 13 01:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:59:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 01:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:00:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:01:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:03:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:04:44 evo-x2 memory-emergency-guard-check[2749817]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.87% sustained (max disk busy 25.2%, MemAvailable=61.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:05:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:08:45 evo-x2 memory-emergency-guard-check[2783038]: MEMORY EMERGENCY cleared (MemAvailable=61.7%, zram=50.3%, PSI some avg10=0.02%, PSI some avg60=0.19%, 602s since last trip, restore #109 today: 1) — sacrifice sockets restored
Oct 13 02:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:09:15 evo-x2 memory-emergency-guard-check[2786201]: MEMORY EMERGENCY: I/O PSI some avg60=62.28% sustained (max disk busy 54.8%, MemAvailable=43.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:09:17 evo-x2 memory-emergency-guard-check[2786201]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2874, zone 6) — top io since last trip: system.slice/io.stat +64957MB, system.slice/tq-agent-pool.service/io.stat +50517MB, system.slice/inboxclean-web.service/io.stat +6324MB
Oct 13 02:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:09:51 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 13 02:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:14:48 evo-x2 memory-emergency-guard-check[2849799]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.93% sustained (max disk busy 23.0%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (333s < 600s, 267s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:19:18 evo-x2 memory-emergency-guard-check[2887236]: MEMORY EMERGENCY: I/O PSI some avg60=51.26% sustained (max disk busy 40.9%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:19:18 evo-x2 memory-emergency-guard-check[2887236]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2875, zone 6) — top io since last trip: system.slice/io.stat +86730MB, system.slice/tq-agent-pool.service/io.stat +80667MB, system.slice/inboxclean-web.service/io.stat +3583MB
Oct 13 02:19:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:24:48 evo-x2 memory-emergency-guard-check[2946442]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.29% sustained (max disk busy 45.9%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (330s < 600s, 270s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:29:20 evo-x2 memory-emergency-guard-check[3005832]: MEMORY EMERGENCY: I/O PSI some avg60=53.34% sustained (max disk busy 50.9%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:29:20 evo-x2 memory-emergency-guard-check[3005832]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2876, zone 6) — top io since last trip: system.slice/io.stat +235091MB, system.slice/tq-agent-pool.service/io.stat +229448MB, system.slice/inboxclean-web.service/io.stat +4604MB
Oct 13 02:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:34:50 evo-x2 memory-emergency-guard-check[3058322]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.94% sustained (max disk busy 30.8%, MemAvailable=52.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (330s < 600s, 270s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:39:20 evo-x2 memory-emergency-guard-check[3099895]: MEMORY EMERGENCY: I/O PSI some avg60=44.17% sustained (max disk busy 50.1%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:39:21 evo-x2 memory-emergency-guard-check[3099895]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2877, zone 6) — top io since last trip: system.slice/io.stat +252044MB, system.slice/tq-agent-pool.service/io.stat +247952MB, system.slice/inboxclean-web.service/io.stat +3117MB
Oct 13 02:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:45:21 evo-x2 memory-emergency-guard-check[3177338]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.59% sustained (max disk busy 31.4%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:49:21 evo-x2 memory-emergency-guard-check[3207118]: MEMORY EMERGENCY: I/O PSI some avg60=46.37% sustained (max disk busy 55.6%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:49:22 evo-x2 memory-emergency-guard-check[3207118]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2878, zone 6) — top io since last trip: system.slice/io.stat +198313MB, system.slice/tq-agent-pool.service/io.stat +193163MB, system.slice/inboxclean-web.service/io.stat +4248MB
Oct 13 02:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:55:22 evo-x2 memory-emergency-guard-check[3327849]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.94% sustained (max disk busy 26.6%, MemAvailable=61.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 02:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:59:24 evo-x2 memory-emergency-guard-check[3368442]: MEMORY EMERGENCY: I/O PSI some avg60=69.81% sustained (max disk busy 49.2%, MemAvailable=61.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 02:59:24 evo-x2 memory-emergency-guard-check[3368442]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2879, zone 6) — top io since last trip: system.slice/io.stat +128088MB, system.slice/tq-agent-pool.service/io.stat +115507MB, system.slice/inboxclean-web.service/io.stat +7418MB
Oct 13 02:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 02:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:02:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:04:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:04:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:05:25 evo-x2 memory-emergency-guard-check[3438193]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.49% sustained (max disk busy 98.9%, MemAvailable=58.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:05:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:06:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:06:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:07:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:09:27 evo-x2 memory-emergency-guard-check[3485978]: MEMORY EMERGENCY: I/O PSI some avg60=63.33% sustained (max disk busy 52.9%, MemAvailable=56.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:09:27 evo-x2 memory-emergency-guard-check[3485978]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2880, zone 6) — top io since last trip: system.slice/io.stat +37526MB, system.slice/system-immich.slice/io.stat +12230MB, system.slice/clickhouse.service/io.stat +10429MB
Oct 13 03:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:10:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:11:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:11:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:12:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:13:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:15:29 evo-x2 memory-emergency-guard-check[3563947]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.64% sustained (max disk busy 28.9%, MemAvailable=59.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:19:29 evo-x2 memory-emergency-guard-check[3606512]: MEMORY EMERGENCY: I/O PSI some avg60=50.09% sustained (max disk busy 50.8%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:19:29 evo-x2 memory-emergency-guard-check[3606512]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2881, zone 6) — top io since last trip: system.slice/io.stat +58083MB, system.slice/tq-agent-pool.service/io.stat +52597MB, system.slice/inboxclean-web.service/io.stat +4330MB
Oct 13 03:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:25:29 evo-x2 memory-emergency-guard-check[3664655]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.43% sustained (max disk busy 28.7%, MemAvailable=51.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (360s < 600s, 240s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:29:29 evo-x2 memory-emergency-guard-check[3706258]: MEMORY EMERGENCY: I/O PSI some avg60=53.10% sustained (max disk busy 56.7%, MemAvailable=59.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:29:30 evo-x2 memory-emergency-guard-check[3706258]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2882, zone 6) — top io since last trip: system.slice/io.stat +239333MB, system.slice/tq-agent-pool.service/io.stat +226140MB, system.slice/inboxclean-web.service/io.stat +7918MB
Oct 13 03:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:34:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:35:31 evo-x2 memory-emergency-guard-check[3775734]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.16% sustained (max disk busy 26.3%, MemAvailable=60.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:39:33 evo-x2 memory-emergency-guard-check[3857968]: MEMORY EMERGENCY: I/O PSI some avg60=55.29% sustained (max disk busy 57.6%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:39:33 evo-x2 memory-emergency-guard-check[3857968]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2883, zone 6) — top io since last trip: system.slice/io.stat +14760MB, system.slice/inboxclean-web.service/io.stat +8137MB, system.slice/tq-agent-pool.service/io.stat +3631MB
Oct 13 03:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:45:33 evo-x2 memory-emergency-guard-check[3925633]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.26% sustained (max disk busy 30.2%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:49:33 evo-x2 memory-emergency-guard-check[3978287]: MEMORY EMERGENCY: I/O PSI some avg60=43.40% sustained (max disk busy 54.4%, MemAvailable=51.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:49:33 evo-x2 memory-emergency-guard-check[3978287]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2884, zone 6) — top io since last trip: system.slice/io.stat +322960MB, system.slice/tq-agent-pool.service/io.stat +265661MB, system.slice/inboxclean-web.service/io.stat +5123MB
Oct 13 03:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:54:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:55:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:55:34 evo-x2 memory-emergency-guard-check[4072247]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.08% sustained (max disk busy 26.7%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 03:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:56:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 03:59:35 evo-x2 memory-emergency-guard-check[4162964]: MEMORY EMERGENCY: I/O PSI some avg60=43.40% sustained (max disk busy 56.1%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 03:59:35 evo-x2 memory-emergency-guard-check[4162964]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2885, zone 6) — top io since last trip: system.slice/io.stat +96757MB, system.slice/tq-agent-pool.service/io.stat +88614MB, system.slice/inboxclean-web.service/io.stat +6201MB
Oct 13 03:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:05:35 evo-x2 memory-emergency-guard-check[26889]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.70% sustained (max disk busy 27.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (360s < 600s, 240s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 04:05:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:09:35 evo-x2 memory-emergency-guard-check[61547]: MEMORY EMERGENCY: I/O PSI some avg60=56.05% sustained (max disk busy 50.3%, MemAvailable=50.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:09:36 evo-x2 memory-emergency-guard-check[61547]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2886, zone 6) — top io since last trip: system.slice/io.stat +257041MB, system.slice/tq-agent-pool.service/io.stat +244431MB, system.slice/inboxclean-web.service/io.stat +5848MB
Oct 13 04:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:10:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:13:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:15:36 evo-x2 memory-emergency-guard-check[150479]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.69% sustained (max disk busy 24.0%, MemAvailable=59.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 04:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:19:37 evo-x2 memory-emergency-guard-check[181047]: MEMORY EMERGENCY: I/O PSI some avg60=77.56% sustained (max disk busy 48.8%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:19:37 evo-x2 memory-emergency-guard-check[181047]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2887, zone 6) — top io since last trip: system.slice/io.stat +55176MB, system.slice/tq-agent-pool.service/io.stat +45959MB, system.slice/inboxclean-web.service/io.stat +8112MB
Oct 13 04:19:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:26:38 evo-x2 memory-emergency-guard-check[238649]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.63% sustained (max disk busy 20.7%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (421s < 600s, 179s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 04:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:29:38 evo-x2 memory-emergency-guard-check[258941]: MEMORY EMERGENCY: I/O PSI some avg60=77.05% sustained (max disk busy 43.0%, MemAvailable=59.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:29:39 evo-x2 memory-emergency-guard-check[258941]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2888, zone 6) — top io since last trip: system.slice/io.stat +19393MB, system.slice/forgejo.service/io.stat +9963MB, system.slice/inboxclean-web.service/io.stat +8309MB
Oct 13 04:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:39:39 evo-x2 memory-emergency-guard-check[343258]: MEMORY EMERGENCY: I/O PSI some avg60=78.84% sustained (max disk busy 38.9%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:39:39 evo-x2 memory-emergency-guard-check[343258]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2889, zone 6) — top io since last trip: system.slice/io.stat +24155MB, system.slice/inboxclean-web.service/io.stat +8000MB, system.slice/clickhouse.service/io.stat +620MB
Oct 13 04:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:44:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:44:40 evo-x2 memory-emergency-guard-check[390127]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.53% sustained (max disk busy 38.1%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 04:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:49:41 evo-x2 memory-emergency-guard-check[429678]: MEMORY EMERGENCY: I/O PSI some avg60=78.15% sustained (max disk busy 34.2%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:49:41 evo-x2 memory-emergency-guard-check[429678]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2890, zone 6) — top io since last trip: system.slice/io.stat +9437MB, system.slice/inboxclean-web.service/io.stat +8350MB, system.slice/clickhouse.service/io.stat +671MB
Oct 13 04:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:54:41 evo-x2 memory-emergency-guard-check[475588]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.61% sustained (max disk busy 44.1%, MemAvailable=60.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 04:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:57:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 04:59:42 evo-x2 memory-emergency-guard-check[513451]: MEMORY EMERGENCY: I/O PSI some avg60=77.62% sustained (max disk busy 29.5%, MemAvailable=60.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 04:59:42 evo-x2 memory-emergency-guard-check[513451]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2891, zone 6) — top io since last trip: system.slice/io.stat +5192MB, system.slice/inboxclean-web.service/io.stat +3986MB, system.slice/clickhouse.service/io.stat +690MB
Oct 13 04:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:00:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:00:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:04:42 evo-x2 memory-emergency-guard-check[560216]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.68% sustained (max disk busy 28.1%, MemAvailable=60.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:09:43 evo-x2 memory-emergency-guard-check[606599]: MEMORY EMERGENCY: I/O PSI some avg60=79.50% sustained (max disk busy 25.4%, MemAvailable=59.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 05:09:44 evo-x2 memory-emergency-guard-check[606599]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2892, zone 6) — top io since last trip: system.slice/io.stat +9330MB, system.slice/inboxclean-web.service/io.stat +8193MB, system.slice/clickhouse.service/io.stat +718MB
Oct 13 05:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:10:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:14:45 evo-x2 memory-emergency-guard-check[649992]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.35% sustained (max disk busy 21.7%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:19:48 evo-x2 memory-emergency-guard-check[688834]: MEMORY EMERGENCY cleared (MemAvailable=59.7%, zram=51.3%, PSI some avg10=0.02%, PSI some avg60=0.18%, 605s since last trip, restore #110 today: 2) — sacrifice sockets restored
Oct 13 05:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:20:18 evo-x2 memory-emergency-guard-check[693690]: MEMORY EMERGENCY: I/O PSI some avg60=78.96% sustained (max disk busy 26.6%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 05:20:18 evo-x2 memory-emergency-guard-check[693690]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2893, zone 6) — top io since last trip: system.slice/io.stat +10085MB, system.slice/inboxclean-web.service/io.stat +8753MB, system.slice/clickhouse.service/io.stat +700MB
Oct 13 05:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:20:53 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 13 05:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:24:50 evo-x2 memory-emergency-guard-check[745603]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.99% sustained (max disk busy 100.0%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (272s < 600s, 328s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:28:22 evo-x2 gatus[2826693]: 2026/10/13 05:28:22 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 13 05:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:28:22 evo-x2 gatus[2826693]: 2026/10/13 05:28:22 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 13 05:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:29:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:30:23 evo-x2 memory-emergency-guard-check[804877]: MEMORY EMERGENCY: I/O PSI some avg60=77.08% sustained (max disk busy 26.5%, MemAvailable=61.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 05:30:24 evo-x2 memory-emergency-guard-check[804877]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2894, zone 6) — top io since last trip: system.slice/io.stat +15710MB, system.slice/forgejo.service/io.stat +4846MB, system.slice/inboxclean-web.service/io.stat +3819MB
Oct 13 05:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:30:25 evo-x2 gatus[2826693]: 2026/10/13 05:30:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 05:30:25 evo-x2 gatus[2826693]: 2026/10/13 05:30:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 05:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:35:26 evo-x2 memory-emergency-guard-check[850610]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.58% sustained (max disk busy 25.5%, MemAvailable=60.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (303s < 600s, 297s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:37:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:40:27 evo-x2 memory-emergency-guard-check[890397]: MEMORY EMERGENCY: I/O PSI some avg60=77.09% sustained (max disk busy 26.4%, MemAvailable=60.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 05:40:28 evo-x2 memory-emergency-guard-check[890397]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2895, zone 6) — top io since last trip: system.slice/io.stat +10234MB, system.slice/inboxclean-web.service/io.stat +8222MB, system.slice/clickhouse.service/io.stat +745MB
Oct 13 05:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:45:29 evo-x2 memory-emergency-guard-check[933899]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.12% sustained (max disk busy 27.8%, MemAvailable=59.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:50:31 evo-x2 memory-emergency-guard-check[972322]: MEMORY EMERGENCY: I/O PSI some avg60=65.13% sustained (max disk busy 31.3%, MemAvailable=59.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 05:50:31 evo-x2 memory-emergency-guard-check[972322]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2896, zone 6) — top io since last trip: system.slice/io.stat +11322MB, system.slice/inboxclean-web.service/io.stat +8193MB, user.slice/io.stat +1888MB
Oct 13 05:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:54:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:55:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:55:32 evo-x2 memory-emergency-guard-check[1015326]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.76% sustained (max disk busy 28.4%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 05:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 05:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:00:32 evo-x2 memory-emergency-guard-check[1053549]: MEMORY EMERGENCY: I/O PSI some avg60=77.43% sustained (max disk busy 36.6%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:00:33 evo-x2 memory-emergency-guard-check[1053549]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2897, zone 6) — top io since last trip: system.slice/io.stat +63243MB, system.slice/inboxclean-web.service/io.stat +7460MB, system.slice/forgejo.service/io.stat +4642MB
Oct 13 06:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:05:36 evo-x2 memory-emergency-guard-check[1093825]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.45% sustained (max disk busy 26.1%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (304s < 600s, 296s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:08:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:10:37 evo-x2 memory-emergency-guard-check[1132570]: MEMORY EMERGENCY: I/O PSI some avg60=76.64% sustained (max disk busy 25.5%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:10:37 evo-x2 memory-emergency-guard-check[1132570]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2898, zone 6) — top io since last trip: system.slice/io.stat +3333MB, system.slice/inboxclean-web.service/io.stat +2344MB, user.slice/io.stat +690MB
Oct 13 06:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:14:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:17:38 evo-x2 memory-emergency-guard-check[1188173]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.01% sustained (max disk busy 20.5%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (422s < 600s, 178s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:18:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:20:38 evo-x2 memory-emergency-guard-check[1210991]: MEMORY EMERGENCY: I/O PSI some avg60=77.10% sustained (max disk busy 22.1%, MemAvailable=57.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:20:39 evo-x2 memory-emergency-guard-check[1210991]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2899, zone 6) — top io since last trip: system.slice/io.stat +9326MB, system.slice/inboxclean-web.service/io.stat +8091MB, system.slice/clickhouse.service/io.stat +593MB
Oct 13 06:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:27:39 evo-x2 memory-emergency-guard-check[1265910]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.31% sustained (max disk busy 20.9%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (421s < 600s, 179s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:30:39 evo-x2 memory-emergency-guard-check[1288557]: MEMORY EMERGENCY cleared (MemAvailable=58.2%, zram=51.3%, PSI some avg10=0.00%, PSI some avg60=0.05%, 601s since last trip, restore #111 today: 3) — sacrifice sockets restored
Oct 13 06:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:31:09 evo-x2 memory-emergency-guard-check[1291689]: MEMORY EMERGENCY: I/O PSI some avg60=78.21% sustained (max disk busy 23.9%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:31:10 evo-x2 memory-emergency-guard-check[1291689]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2900, zone 6) — top io since last trip: system.slice/io.stat +14661MB, system.slice/inboxclean-web.service/io.stat +2724MB, system.slice/forgejo.service/io.stat +915MB
Oct 13 06:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:31:48 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 13 06:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:34:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:38:11 evo-x2 memory-emergency-guard-check[1345393]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.42% sustained (max disk busy 25.4%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (422s < 600s, 178s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:41:11 evo-x2 memory-emergency-guard-check[1367427]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 06:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:42:11 evo-x2 memory-emergency-guard-check[1373365]: MEMORY EMERGENCY: I/O PSI some avg60=79.13% sustained (max disk busy 24.2%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:42:11 evo-x2 memory-emergency-guard-check[1373365]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2901, zone 6) — top io since last trip: system.slice/io.stat +3041MB, system.slice/inboxclean-web.service/io.stat +2046MB, system.slice/clickhouse.service/io.stat +564MB
Oct 13 06:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:48:12 evo-x2 memory-emergency-guard-check[1420093]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.97% sustained (max disk busy 25.6%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:50:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:50:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:51:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:52:12 evo-x2 memory-emergency-guard-check[1451026]: MEMORY EMERGENCY: I/O PSI some avg60=77.42% sustained (max disk busy 25.2%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 06:52:13 evo-x2 memory-emergency-guard-check[1451026]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2902, zone 6) — top io since last trip: system.slice/io.stat +16165MB, system.slice/forgejo.service/io.stat +10521MB, system.slice/inboxclean-web.service/io.stat +4676MB
Oct 13 06:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:52:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:53:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:53:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:58:13 evo-x2 memory-emergency-guard-check[1498424]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.28% sustained (max disk busy 34.0%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 06:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 06:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:02:15 evo-x2 memory-emergency-guard-check[1529829]: MEMORY EMERGENCY: I/O PSI some avg60=79.25% sustained (max disk busy 27.0%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:02:15 evo-x2 memory-emergency-guard-check[1529829]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2903, zone 6) — top io since last trip: system.slice/io.stat +4869MB, system.slice/inboxclean-web.service/io.stat +3720MB, system.slice/clickhouse.service/io.stat +689MB
Oct 13 07:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:07:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:08:17 evo-x2 memory-emergency-guard-check[1584729]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.89% sustained (max disk busy 26.7%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:12:18 evo-x2 memory-emergency-guard-check[1615603]: MEMORY EMERGENCY: I/O PSI some avg60=69.08% sustained (max disk busy 26.1%, MemAvailable=57.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:12:19 evo-x2 memory-emergency-guard-check[1615603]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2904, zone 6) — top io since last trip: system.slice/io.stat +9981MB, system.slice/inboxclean-web.service/io.stat +8178MB, system.slice/clickhouse.service/io.stat +649MB
Oct 13 07:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:13:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:15:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:18:21 evo-x2 memory-emergency-guard-check[1665136]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.21% sustained (max disk busy 32.0%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (363s < 600s, 237s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:18:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:19:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:19:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:22:22 evo-x2 memory-emergency-guard-check[1693972]: MEMORY EMERGENCY: I/O PSI some avg60=78.30% sustained (max disk busy 31.6%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:22:23 evo-x2 memory-emergency-guard-check[1693972]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2905, zone 6) — top io since last trip: system.slice/io.stat +4523MB, system.slice/inboxclean-web.service/io.stat +2789MB, system.slice/clickhouse.service/io.stat +578MB
Oct 13 07:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:22:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:24:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:27:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:28:24 evo-x2 memory-emergency-guard-check[1741854]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.98% sustained (max disk busy 34.9%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:28:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:29:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:31:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:32:25 evo-x2 memory-emergency-guard-check[1770552]: MEMORY EMERGENCY: I/O PSI some avg60=78.40% sustained (max disk busy 28.7%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:32:25 evo-x2 memory-emergency-guard-check[1770552]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2906, zone 6) — top io since last trip: system.slice/io.stat +1963MB, system.slice/inboxclean-web.service/io.stat +952MB, system.slice/clickhouse.service/io.stat +599MB
Oct 13 07:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:34:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:38:27 evo-x2 memory-emergency-guard-check[1816361]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.14% sustained (max disk busy 27.7%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:42:28 evo-x2 memory-emergency-guard-check[1846816]: MEMORY EMERGENCY: I/O PSI some avg60=79.17% sustained (max disk busy 27.9%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:42:29 evo-x2 memory-emergency-guard-check[1846816]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2907, zone 6) — top io since last trip: system.slice/io.stat +8619MB, system.slice/inboxclean-web.service/io.stat +7498MB, system.slice/clickhouse.service/io.stat +707MB
Oct 13 07:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:48:31 evo-x2 memory-emergency-guard-check[1897492]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.42% sustained (max disk busy 26.8%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (363s < 600s, 237s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:52:32 evo-x2 memory-emergency-guard-check[1928416]: MEMORY EMERGENCY: I/O PSI some avg60=76.64% sustained (max disk busy 26.1%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 07:52:33 evo-x2 memory-emergency-guard-check[1928416]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2908, zone 6) — top io since last trip: system.slice/io.stat +13753MB, system.slice/inboxclean-web.service/io.stat +8126MB, system.slice/forgejo.service/io.stat +4369MB
Oct 13 07:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:58:35 evo-x2 memory-emergency-guard-check[1976870]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.84% sustained (max disk busy 26.0%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (363s < 600s, 237s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 07:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 07:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:02:36 evo-x2 memory-emergency-guard-check[2008783]: MEMORY EMERGENCY: I/O PSI some avg60=76.61% sustained (max disk busy 25.1%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:02:36 evo-x2 memory-emergency-guard-check[2008783]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2909, zone 6) — top io since last trip: system.slice/io.stat +9585MB, system.slice/inboxclean-web.service/io.stat +8257MB, system.slice/clickhouse.service/io.stat +827MB
Oct 13 08:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:09:37 evo-x2 memory-emergency-guard-check[2070083]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.25% sustained (max disk busy 44.4%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (421s < 600s, 179s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:12:38 evo-x2 memory-emergency-guard-check[2096200]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 08:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:14:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:14:38 evo-x2 memory-emergency-guard-check[2111121]: MEMORY EMERGENCY: I/O PSI some avg60=77.24% sustained (max disk busy 43.1%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:14:38 evo-x2 memory-emergency-guard-check[2111121]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2910, zone 6) — top io since last trip: system.slice/io.stat +11647MB, system.slice/inboxclean-web.service/io.stat +10197MB, system.slice/clickhouse.service/io.stat +858MB
Oct 13 08:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:19:39 evo-x2 memory-emergency-guard-check[2156848]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.10% sustained (max disk busy 44.1%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:19:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:24:39 evo-x2 memory-emergency-guard-check[2201102]: MEMORY EMERGENCY: I/O PSI some avg60=79.19% sustained (max disk busy 43.3%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:24:39 evo-x2 memory-emergency-guard-check[2201102]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2911, zone 6) — top io since last trip: system.slice/io.stat +7337MB, system.slice/forgejo.service/io.stat +4501MB, system.slice/inboxclean-web.service/io.stat +1461MB
Oct 13 08:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:29:40 evo-x2 memory-emergency-guard-check[2244838]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.73% sustained (max disk busy 45.3%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:30:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:34:41 evo-x2 memory-emergency-guard-check[2283518]: MEMORY EMERGENCY: I/O PSI some avg60=78.75% sustained (max disk busy 41.5%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:34:41 evo-x2 memory-emergency-guard-check[2283518]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2912, zone 6) — top io since last trip: system.slice/io.stat +3615MB, system.slice/inboxclean-web.service/io.stat +2292MB, system.slice/clickhouse.service/io.stat +895MB
Oct 13 08:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:39:41 evo-x2 memory-emergency-guard-check[2325340]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.83% sustained (max disk busy 31.6%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:44:42 evo-x2 memory-emergency-guard-check[2364820]: MEMORY EMERGENCY: I/O PSI some avg60=77.81% sustained (max disk busy 34.5%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:44:42 evo-x2 memory-emergency-guard-check[2364820]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2913, zone 6) — top io since last trip: system.slice/io.stat +9296MB, system.slice/inboxclean-web.service/io.stat +8299MB, system.slice/clickhouse.service/io.stat +550MB
Oct 13 08:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:49:43 evo-x2 memory-emergency-guard-check[2417339]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.83% sustained (max disk busy 26.8%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:52:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:52:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:54:44 evo-x2 memory-emergency-guard-check[2462741]: MEMORY EMERGENCY: I/O PSI some avg60=79.06% sustained (max disk busy 22.8%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 08:54:45 evo-x2 memory-emergency-guard-check[2462741]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2914, zone 6) — top io since last trip: system.slice/io.stat +10323MB, system.slice/inboxclean-web.service/io.stat +8321MB, system.slice/forgejo.service/io.stat +916MB
Oct 13 08:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:56:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:58:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:59:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 08:59:46 evo-x2 memory-emergency-guard-check[2509139]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.32% sustained (max disk busy 22.8%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 08:59:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:00:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:00:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:01:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:01:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:02:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:02:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:03:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:03:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:04:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:04:48 evo-x2 memory-emergency-guard-check[2550150]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 09:04:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:05:18 evo-x2 memory-emergency-guard-check[2553501]: MEMORY EMERGENCY: I/O PSI some avg60=79.87% sustained (max disk busy 34.5%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:05:19 evo-x2 memory-emergency-guard-check[2553501]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2915, zone 6) — top io since last trip: system.slice/io.stat +4325MB, system.slice/inboxclean-web.service/io.stat +2302MB, system.slice/clickhouse.service/io.stat +621MB
Oct 13 09:05:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:05:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:07:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:08:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:08:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:10:21 evo-x2 memory-emergency-guard-check[2595250]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.89% sustained (max disk busy 27.3%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (303s < 600s, 297s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 09:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:10:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:11:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:11:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:14:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:15:24 evo-x2 memory-emergency-guard-check[2630756]: MEMORY EMERGENCY: I/O PSI some avg60=78.33% sustained (max disk busy 31.3%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:15:24 evo-x2 memory-emergency-guard-check[2630756]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2916, zone 6) — top io since last trip: system.slice/io.stat +8201MB, system.slice/inboxclean-web.service/io.stat +4212MB, system.slice/clickhouse.service/io.stat +504MB
Oct 13 09:15:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:15:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:16:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:19:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:20:26 evo-x2 memory-emergency-guard-check[2673951]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.21% sustained (max disk busy 26.3%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 09:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:21:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:25:29 evo-x2 memory-emergency-guard-check[2718864]: MEMORY EMERGENCY: I/O PSI some avg60=75.85% sustained (max disk busy 25.2%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:25:29 evo-x2 memory-emergency-guard-check[2718864]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2917, zone 6) — top io since last trip: system.slice/io.stat +21189MB, system.slice/forgejo.service/io.stat +11069MB, system.slice/inboxclean-web.service/io.stat +8360MB
Oct 13 09:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:29:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:30:32 evo-x2 memory-emergency-guard-check[2760419]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.79% sustained (max disk busy 30.7%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 09:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:32:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:35:33 evo-x2 memory-emergency-guard-check[2794439]: MEMORY EMERGENCY: I/O PSI some avg60=78.78% sustained (max disk busy 29.0%, MemAvailable=58.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:35:33 evo-x2 memory-emergency-guard-check[2794439]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2918, zone 6) — top io since last trip: system.slice/io.stat +8310MB, system.slice/inboxclean-web.service/io.stat +7333MB, system.slice/clickhouse.service/io.stat +537MB
Oct 13 09:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:38:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:40:37 evo-x2 memory-emergency-guard-check[2834938]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.72% sustained (max disk busy 25.7%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (304s < 600s, 296s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 09:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:41:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:45:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:45:38 evo-x2 memory-emergency-guard-check[2871576]: MEMORY EMERGENCY: I/O PSI some avg60=78.41% sustained (max disk busy 20.9%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:45:38 evo-x2 memory-emergency-guard-check[2871576]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2919, zone 6) — top io since last trip: system.slice/io.stat +2030MB, system.slice/inboxclean-web.service/io.stat +1005MB, system.slice/clickhouse.service/io.stat +629MB
Oct 13 09:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:50:38 evo-x2 memory-emergency-guard-check[2920360]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.17% sustained (max disk busy 24.5%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 09:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:55:39 evo-x2 memory-emergency-guard-check[2954756]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 09:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:56:09 evo-x2 memory-emergency-guard-check[2957966]: MEMORY EMERGENCY: I/O PSI some avg60=80.44% sustained (max disk busy 31.5%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 09:56:09 evo-x2 memory-emergency-guard-check[2957966]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2920, zone 6) — top io since last trip: system.slice/io.stat +8545MB, system.slice/inboxclean-web.service/io.stat +7290MB, system.slice/clickhouse.service/io.stat +574MB
Oct 13 09:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 09:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:00:39 evo-x2 memory-emergency-guard-check[2995251]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.10% sustained (max disk busy 26.2%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (270s < 600s, 330s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:06:10 evo-x2 memory-emergency-guard-check[3037048]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 10:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:08:11 evo-x2 memory-emergency-guard-check[3054355]: MEMORY EMERGENCY: I/O PSI some avg60=81.04% sustained (max disk busy 20.8%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:08:11 evo-x2 memory-emergency-guard-check[3054355]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2921, zone 6) — top io since last trip: system.slice/io.stat +11341MB, system.slice/inboxclean-web.service/io.stat +9933MB, system.slice/clickhouse.service/io.stat +758MB
Oct 13 10:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:12:11 evo-x2 memory-emergency-guard-check[3091092]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.51% sustained (max disk busy 20.1%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (240s < 600s, 360s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:18:12 evo-x2 memory-emergency-guard-check[3137278]: MEMORY EMERGENCY: I/O PSI some avg60=79.38% sustained (max disk busy 25.1%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:18:12 evo-x2 memory-emergency-guard-check[3137278]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2922, zone 6) — top io since last trip: system.slice/io.stat +5444MB, system.slice/inboxclean-web.service/io.stat +4222MB, system.slice/clickhouse.service/io.stat +540MB
Oct 13 10:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:22:12 evo-x2 memory-emergency-guard-check[3173918]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.01% sustained (max disk busy 25.8%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:26:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:28:14 evo-x2 memory-emergency-guard-check[3217972]: MEMORY EMERGENCY: I/O PSI some avg60=79.99% sustained (max disk busy 27.6%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:28:15 evo-x2 memory-emergency-guard-check[3217972]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2923, zone 6) — top io since last trip: system.slice/io.stat +8553MB, system.slice/forgejo.service/io.stat +4333MB, system.slice/inboxclean-web.service/io.stat +3172MB
Oct 13 10:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:32:17 evo-x2 memory-emergency-guard-check[3250734]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.60% sustained (max disk busy 29.0%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (243s < 600s, 357s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:38:19 evo-x2 memory-emergency-guard-check[3293950]: MEMORY EMERGENCY: I/O PSI some avg60=80.16% sustained (max disk busy 26.7%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:38:19 evo-x2 memory-emergency-guard-check[3293950]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2924, zone 6) — top io since last trip: system.slice/io.stat +3310MB, system.slice/inboxclean-web.service/io.stat +2292MB, system.slice/clickhouse.service/io.stat +640MB
Oct 13 10:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:42:21 evo-x2 memory-emergency-guard-check[3326949]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.95% sustained (max disk busy 28.2%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:48:23 evo-x2 memory-emergency-guard-check[3372067]: MEMORY EMERGENCY: I/O PSI some avg60=78.67% sustained (max disk busy 26.8%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:48:24 evo-x2 memory-emergency-guard-check[3372067]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2925, zone 6) — top io since last trip: system.slice/io.stat +9476MB, system.slice/inboxclean-web.service/io.stat +8391MB, system.slice/clickhouse.service/io.stat +702MB
Oct 13 10:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:48:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:52:24 evo-x2 memory-emergency-guard-check[3408206]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.81% sustained (max disk busy 31.9%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 10:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:55:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:56:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:58:25 evo-x2 memory-emergency-guard-check[3452966]: MEMORY EMERGENCY: I/O PSI some avg60=78.31% sustained (max disk busy 33.2%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 10:58:25 evo-x2 memory-emergency-guard-check[3452966]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2926, zone 6) — top io since last trip: system.slice/io.stat +13930MB, system.slice/inboxclean-web.service/io.stat +8461MB, system.slice/forgejo.service/io.stat +4324MB
Oct 13 10:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 10:59:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:02:27 evo-x2 memory-emergency-guard-check[3487325]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.98% sustained (max disk busy 26.6%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:08:29 evo-x2 memory-emergency-guard-check[3537536]: MEMORY EMERGENCY: I/O PSI some avg60=76.51% sustained (max disk busy 28.1%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:08:30 evo-x2 memory-emergency-guard-check[3537536]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2927, zone 6) — top io since last trip: system.slice/io.stat +9427MB, system.slice/inboxclean-web.service/io.stat +8302MB, system.slice/clickhouse.service/io.stat +685MB
Oct 13 11:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:11:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:12:32 evo-x2 memory-emergency-guard-check[3573772]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.39% sustained (max disk busy 30.9%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (243s < 600s, 357s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:18:34 evo-x2 memory-emergency-guard-check[3620334]: MEMORY EMERGENCY: I/O PSI some avg60=77.11% sustained (max disk busy 26.0%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:18:34 evo-x2 memory-emergency-guard-check[3620334]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2928, zone 6) — top io since last trip: system.slice/io.stat +9523MB, system.slice/inboxclean-web.service/io.stat +8417MB, system.slice/clickhouse.service/io.stat +638MB
Oct 13 11:18:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:19:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:22:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:22:35 evo-x2 memory-emergency-guard-check[3656154]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.47% sustained (max disk busy 27.4%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:22:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:28:37 evo-x2 memory-emergency-guard-check[3701380]: MEMORY EMERGENCY: I/O PSI some avg60=80.81% sustained (max disk busy 27.1%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:28:37 evo-x2 memory-emergency-guard-check[3701380]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2929, zone 6) — top io since last trip: system.slice/io.stat +10237MB, system.slice/inboxclean-web.service/io.stat +8381MB, system.slice/forgejo.service/io.stat +934MB
Oct 13 11:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:34:38 evo-x2 memory-emergency-guard-check[3750966]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.14% sustained (max disk busy 48.0%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (361s < 600s, 239s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:37:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:38:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:38:38 evo-x2 memory-emergency-guard-check[3780742]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 11:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:39:39 evo-x2 memory-emergency-guard-check[3787230]: MEMORY EMERGENCY: I/O PSI some avg60=77.45% sustained (max disk busy 41.7%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:39:39 evo-x2 memory-emergency-guard-check[3787230]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2930, zone 6) — top io since last trip: system.slice/io.stat +11020MB, system.slice/inboxclean-web.service/io.stat +9812MB, system.slice/clickhouse.service/io.stat +757MB
Oct 13 11:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:44:39 evo-x2 memory-emergency-guard-check[3831300]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.64% sustained (max disk busy 44.4%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:47:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:49:40 evo-x2 memory-emergency-guard-check[3870965]: MEMORY EMERGENCY: I/O PSI some avg60=79.02% sustained (max disk busy 40.4%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:49:40 evo-x2 memory-emergency-guard-check[3870965]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2931, zone 6) — top io since last trip: system.slice/io.stat +5684MB, system.slice/inboxclean-web.service/io.stat +4580MB, system.slice/clickhouse.service/io.stat +686MB
Oct 13 11:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:50:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:54:41 evo-x2 memory-emergency-guard-check[3923681]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.55% sustained (max disk busy 50.6%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 11:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:57:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 11:59:41 evo-x2 memory-emergency-guard-check[3962267]: MEMORY EMERGENCY: I/O PSI some avg60=77.46% sustained (max disk busy 36.5%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 11:59:41 evo-x2 memory-emergency-guard-check[3962267]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2932, zone 6) — top io since last trip: system.slice/io.stat +14880MB, system.slice/forgejo.service/io.stat +10980MB, system.slice/inboxclean-web.service/io.stat +2923MB
Oct 13 11:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:04:41 evo-x2 memory-emergency-guard-check[4009105]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.90% sustained (max disk busy 40.0%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (300s < 600s, 300s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:09:42 evo-x2 memory-emergency-guard-check[4048269]: MEMORY EMERGENCY: I/O PSI some avg60=73.45% sustained (max disk busy 38.9%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 12:09:43 evo-x2 memory-emergency-guard-check[4048269]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2933, zone 6) — top io since last trip: system.slice/io.stat +1995MB, system.slice/inboxclean-web.service/io.stat +872MB, system.slice/clickhouse.service/io.stat +593MB
Oct 13 12:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:14:45 evo-x2 memory-emergency-guard-check[4106639]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.95% sustained (max disk busy 53.0%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (303s < 600s, 297s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:19:47 evo-x2 memory-emergency-guard-check[73565]: MEMORY EMERGENCY: I/O PSI some avg60=45.89% sustained (max disk busy 62.3%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 12:19:47 evo-x2 memory-emergency-guard-check[73565]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2934, zone 6) — top io since last trip: user.slice/io.stat +9201MB, user.slice/user-1000.slice/io.stat +9146MB, system.slice/io.stat +8295MB
Oct 13 12:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:24:49 evo-x2 memory-emergency-guard-check[280044]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.50% sustained (max disk busy 42.7%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:29:49 evo-x2 memory-emergency-guard-check[345839]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 12:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:30:19 evo-x2 memory-emergency-guard-check[349356]: MEMORY EMERGENCY: I/O PSI some avg60=71.54% sustained (max disk busy 26.7%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 12:30:20 evo-x2 memory-emergency-guard-check[349356]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2935, zone 6) — top io since last trip: system.slice/io.stat +10698MB, system.slice/inboxclean-web.service/io.stat +8386MB, user.slice/io.stat +7338MB
Oct 13 12:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:35:21 evo-x2 memory-emergency-guard-check[404122]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.76% sustained (max disk busy 29.3%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (302s < 600s, 298s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:38:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:40:24 evo-x2 memory-emergency-guard-check[453682]: MEMORY EMERGENCY: I/O PSI some avg60=72.89% sustained (max disk busy 27.1%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 12:40:24 evo-x2 memory-emergency-guard-check[453682]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2936, zone 6) — top io since last trip: system.slice/io.stat +6038MB, system.slice/inboxclean-web.service/io.stat +4537MB, user.slice/io.stat +631MB
Oct 13 12:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:42:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:45:25 evo-x2 memory-emergency-guard-check[515813]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.12% sustained (max disk busy 26.9%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:45:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:46:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:50:27 evo-x2 memory-emergency-guard-check[555347]: MEMORY EMERGENCY: I/O PSI some avg60=72.57% sustained (max disk busy 32.9%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 12:50:27 evo-x2 memory-emergency-guard-check[555347]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2937, zone 6) — top io since last trip: system.slice/io.stat +10092MB, system.slice/inboxclean-web.service/io.stat +8229MB, system.slice/nix-daemon.service/io.stat +782MB
Oct 13 12:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:53:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:54:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:55:28 evo-x2 memory-emergency-guard-check[604281]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.59% sustained (max disk busy 25.6%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (301s < 600s, 299s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 12:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 12:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:00:29 evo-x2 memory-emergency-guard-check[737321]: MEMORY EMERGENCY: I/O PSI some avg60=42.80% sustained (max disk busy 25.7%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:00:30 evo-x2 memory-emergency-guard-check[737321]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2938, zone 6) — top io since last trip: system.slice/io.stat +16424MB, system.slice/inboxclean-web.service/io.stat +7806MB, system.slice/forgejo.service/io.stat +4610MB
Oct 13 13:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:03:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:05:32 evo-x2 memory-emergency-guard-check[832737]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.08% sustained (max disk busy 27.0%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (303s < 600s, 297s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:08:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:09:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:10:34 evo-x2 memory-emergency-guard-check[1073022]: MEMORY EMERGENCY: I/O PSI some avg60=73.16% sustained (max disk busy 100.0%, MemAvailable=27.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:10:34 evo-x2 memory-emergency-guard-check[1073022]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2939, zone 6) — top io since last trip: system.slice/io.stat +67626MB, user.slice/io.stat +43217MB, user.slice/user-1000.slice/io.stat +41284MB
Oct 13 13:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:11:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:17:36 evo-x2 memory-emergency-guard-check[1224152]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.85% sustained (max disk busy 72.7%, MemAvailable=13.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (422s < 600s, 178s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:20:36 evo-x2 memory-emergency-guard-check[1257541]: MEMORY EMERGENCY: I/O PSI some avg60=41.83% sustained (max disk busy 87.5%, MemAvailable=12.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:20:37 evo-x2 memory-emergency-guard-check[1257541]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2940, zone 6) — top io since last trip: system.slice/io.stat +60402MB, user.slice/io.stat +35849MB, user.slice/user-1000.slice/io.stat +33893MB
Oct 13 13:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:27:49 evo-x2 memory-emergency-guard-check[1405558]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.76% sustained (max disk busy 99.6%, MemAvailable=31.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (433s < 600s, 167s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:30:50 evo-x2 memory-emergency-guard-check[1442779]: MEMORY EMERGENCY: I/O PSI some avg60=46.89% sustained (max disk busy 82.8%, MemAvailable=36.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:30:50 evo-x2 memory-emergency-guard-check[1442779]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2941, zone 6) — top io since last trip: user.slice/io.stat +43860MB, user.slice/user-1000.slice/io.stat +42677MB, system.slice/io.stat +36597MB
Oct 13 13:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 442ms CPU time over 494ms wall clock time, 12.9M memory peak, 1.6M read from disk, 4K written to disk.
Oct 13 13:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:37:52 evo-x2 memory-emergency-guard-check[1558916]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.87% sustained (max disk busy 100.0%, MemAvailable=31.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (422s < 600s, 178s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:37:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:38:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:39:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:40:52 evo-x2 memory-emergency-guard-check[1607253]: MEMORY EMERGENCY: I/O PSI some avg60=40.95% sustained (max disk busy 99.2%, MemAvailable=32.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:40:53 evo-x2 memory-emergency-guard-check[1607253]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2942, zone 6) — top io since last trip: system.slice/io.stat +40659MB, user.slice/io.stat +26291MB, user.slice/user-1000.slice/io.stat +25194MB
Oct 13 13:40:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:46:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:47:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:47:55 evo-x2 memory-emergency-guard-check[1769600]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.43% sustained (max disk busy 45.7%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (423s < 600s, 177s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:50:56 evo-x2 memory-emergency-guard-check[1838789]: MEMORY EMERGENCY: I/O PSI some avg60=53.82% sustained (max disk busy 98.1%, MemAvailable=59.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 13:50:56 evo-x2 memory-emergency-guard-check[1838789]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2943, zone 6) — top io since last trip: system.slice/io.stat +29633MB, system.slice/nix-daemon.service/io.stat +10929MB, user.slice/io.stat +4620MB
Oct 13 13:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:51:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:52:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:57:59 evo-x2 memory-emergency-guard-check[1941005]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.90% sustained (max disk busy 41.1%, MemAvailable=58.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (422s < 600s, 178s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 13:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 13:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:01:00 evo-x2 memory-emergency-guard-check[2008927]: MEMORY EMERGENCY: I/O PSI some avg60=47.65% sustained (max disk busy 80.8%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 14:01:00 evo-x2 memory-emergency-guard-check[2008927]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2944, zone 6) — top io since last trip: system.slice/io.stat +13439MB, system.slice/inboxclean-web.service/io.stat +6573MB, user.slice/io.stat +5319MB
Oct 13 14:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:10:02 evo-x2 memory-emergency-guard-check[2394563]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.45% sustained (max disk busy 100.0%, MemAvailable=39.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (542s < 600s, 58s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 14:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:10:32 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 13 14:11:02 evo-x2 memory-emergency-guard-check[2461815]: MEMORY EMERGENCY: I/O PSI some avg60=45.39% sustained (max disk busy 97.2%, MemAvailable=38.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 14:11:06 evo-x2 memory-emergency-guard-check[2461815]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2945, zone 6) — top io since last trip: system.slice/io.stat +39939MB, system.slice/nix-daemon.service/io.stat +15606MB, user.slice/io.stat +9813MB
Oct 13 14:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:15:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:21:03 evo-x2 memory-emergency-guard-check[3075113]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 14:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:27:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:27:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:28:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:30:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:30:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:31:05 evo-x2 memory-emergency-guard-check[3537737]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 14:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:32:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:33:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:37:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:40:37 evo-x2 memory-emergency-guard-check[3867972]: MEMORY EMERGENCY: I/O PSI some avg60=42.34% sustained (max disk busy 100.0%, MemAvailable=47.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 14:40:37 evo-x2 memory-emergency-guard-check[3867972]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2946, zone 6) — top io since last trip: system.slice/io.stat +92061MB, system.slice/nix-daemon.service/io.stat +41673MB, user.slice/io.stat +24546MB
Oct 13 14:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:41:07 evo-x2 memory-emergency-guard-check[3886234]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.23% sustained (max disk busy 89.4%, MemAvailable=44.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 14:41:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:50:38 evo-x2 memory-emergency-guard-check[4175451]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 14:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:56:09 evo-x2 memory-emergency-guard-check[205125]: MEMORY EMERGENCY: I/O PSI some avg60=41.78% sustained (max disk busy 100.0%, MemAvailable=36.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 14:56:11 evo-x2 memory-emergency-guard-check[205125]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2947, zone 6) — top io since last trip: system.slice/io.stat +50109MB, user.slice/io.stat +18389MB, user.slice/user-1000.slice/io.stat +17698MB
Oct 13 14:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:56:39 evo-x2 memory-emergency-guard-check[222896]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.28% sustained (max disk busy 99.9%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 14:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:56:43 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 13 14:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 14:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:06:11 evo-x2 memory-emergency-guard-check[466134]: MEMORY EMERGENCY: I/O PSI some avg60=42.82% sustained (max disk busy 21.9%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 15:06:11 evo-x2 memory-emergency-guard-check[466134]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2948, zone 6) — top io since last trip: system.slice/io.stat +13455MB, user.slice/io.stat +3970MB, user.slice/user-1000.slice/io.stat +3471MB
Oct 13 15:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:07:11 evo-x2 memory-emergency-guard-check[486196]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.80% sustained (max disk busy 24.7%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 15:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:16:12 evo-x2 memory-emergency-guard-check[695418]: MEMORY EMERGENCY: I/O PSI some avg60=41.23% sustained (max disk busy 99.0%, MemAvailable=35.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 15:16:14 evo-x2 memory-emergency-guard-check[695418]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2949, zone 6) — top io since last trip: system.slice/io.stat +8902MB, system.slice/nix-daemon.service/io.stat +3380MB, user.slice/io.stat +3337MB
Oct 13 15:16:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:17:12 evo-x2 memory-emergency-guard-check[713430]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.78% sustained (max disk busy 30.3%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 15:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:22:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:24:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:27:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:31:47 evo-x2 memory-emergency-guard-check[986426]: MEMORY EMERGENCY: I/O PSI some avg60=40.49% sustained (max disk busy 85.2%, MemAvailable=34.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 15:31:49 evo-x2 memory-emergency-guard-check[986426]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2950, zone 6) — top io since last trip: system.slice/io.stat +73970MB, user.slice/io.stat +10970MB, user.slice/user-1000.slice/io.stat +10394MB
Oct 13 15:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:32:17 evo-x2 memory-emergency-guard-check[999830]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.59% sustained (max disk busy 27.0%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 15:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:32:28 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 13 15:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:34:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:41:51 evo-x2 memory-emergency-guard-check[1163125]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 15:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:42:22 evo-x2 memory-emergency-guard-check[1167388]: MEMORY EMERGENCY: I/O PSI some avg60=52.74% sustained (max disk busy 25.5%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 15:42:22 evo-x2 memory-emergency-guard-check[1167388]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2951, zone 6) — top io since last trip: system.slice/io.stat +18291MB, system.slice/nix-daemon.service/io.stat +11829MB, system.slice/inboxclean-web.service/io.stat +2840MB
Oct 13 15:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:43:23 evo-x2 memory-emergency-guard-check[1183834]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.98% sustained (max disk busy 27.5%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 15:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:52:25 evo-x2 memory-emergency-guard-check[1279242]: MEMORY EMERGENCY: I/O PSI some avg60=53.43% sustained (max disk busy 26.5%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 15:52:25 evo-x2 memory-emergency-guard-check[1279242]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2952, zone 6) — top io since last trip: system.slice/io.stat +14309MB, system.slice/inboxclean-web.service/io.stat +8079MB, system.slice/forgejo.service/io.stat +4773MB
Oct 13 15:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:53:25 evo-x2 memory-emergency-guard-check[1302458]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.14% sustained (max disk busy 97.5%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 15:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:54:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:55:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 15:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:02:28 evo-x2 memory-emergency-guard-check[1798517]: MEMORY EMERGENCY: I/O PSI some avg60=44.90% sustained (max disk busy 100.0%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 16:02:29 evo-x2 memory-emergency-guard-check[1798517]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2953, zone 6) — top io since last trip: system.slice/io.stat +19269MB, user.slice/io.stat +9865MB, user.slice/user-1000.slice/io.stat +9821MB
Oct 13 16:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:02:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:12:33 evo-x2 memory-emergency-guard-check[2278335]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 16:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:21:38 evo-x2 memory-emergency-guard-check[2515494]: MEMORY EMERGENCY: I/O PSI some avg60=48.80% sustained (max disk busy 42.2%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 16:21:38 evo-x2 memory-emergency-guard-check[2515494]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2954, zone 6) — top io since last trip: system.slice/io.stat +35556MB, system.slice/nix-daemon.service/io.stat +17458MB, user.slice/io.stat +12847MB
Oct 13 16:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:22:08 evo-x2 memory-emergency-guard-check[2540968]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.23% sustained (max disk busy 81.4%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 16:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:31:39 evo-x2 memory-emergency-guard-check[2664966]: MEMORY EMERGENCY: I/O PSI some avg60=59.94% sustained (max disk busy 37.4%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 16:31:40 evo-x2 memory-emergency-guard-check[2664966]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2955, zone 6) — top io since last trip: system.slice/io.stat +47542MB, system.slice/nix-daemon.service/io.stat +14247MB, system.slice/inboxclean-web.service/io.stat +5639MB
Oct 13 16:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:32:09 evo-x2 memory-emergency-guard-check[2673802]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.44% sustained (max disk busy 21.5%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 16:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:40:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:41:40 evo-x2 memory-emergency-guard-check[2786724]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 16:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:44:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:44:40 evo-x2 memory-emergency-guard-check[2820624]: MEMORY EMERGENCY: I/O PSI some avg60=60.70% sustained (max disk busy 37.8%, MemAvailable=57.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 16:44:40 evo-x2 memory-emergency-guard-check[2820624]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2956, zone 6) — top io since last trip: system.slice/io.stat +21231MB, system.slice/nix-daemon.service/io.stat +7947MB, system.slice/inboxclean-web.service/io.stat +6068MB
Oct 13 16:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:46:11 evo-x2 memory-emergency-guard-check[2846260]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.64% sustained (max disk busy 20.1%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 16:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:53:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:54:42 evo-x2 memory-emergency-guard-check[3023682]: MEMORY EMERGENCY: I/O PSI some avg60=52.61% sustained (max disk busy 31.8%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 16:54:43 evo-x2 memory-emergency-guard-check[3023682]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2957, zone 6) — top io since last trip: system.slice/io.stat +19806MB, system.slice/inboxclean-web.service/io.stat +8025MB, system.slice/forgejo.service/io.stat +7158MB
Oct 13 16:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:56:12 evo-x2 memory-emergency-guard-check[3069343]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.78% sustained (max disk busy 25.0%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 16:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:59:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 16:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:00:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:01:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:04:44 evo-x2 memory-emergency-guard-check[3307916]: MEMORY EMERGENCY: I/O PSI some avg60=47.90% sustained (max disk busy 81.1%, MemAvailable=56.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 17:04:44 evo-x2 memory-emergency-guard-check[3307916]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2958, zone 6) — top io since last trip: system.slice/io.stat +8148MB, system.slice/inboxclean-web.service/io.stat +5736MB, user.slice/io.stat +5054MB
Oct 13 17:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:05:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:06:15 evo-x2 memory-emergency-guard-check[3413190]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.22% sustained (max disk busy 97.9%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 17:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:14:47 evo-x2 memory-emergency-guard-check[3948230]: MEMORY EMERGENCY: I/O PSI some avg60=67.88% sustained (max disk busy 99.8%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 17:14:47 evo-x2 memory-emergency-guard-check[3948230]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2959, zone 6) — top io since last trip: user.slice/io.stat +18715MB, user.slice/user-1000.slice/io.stat +18592MB, system.slice/io.stat +17203MB
Oct 13 17:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:16:18 evo-x2 memory-emergency-guard-check[4120599]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.97% sustained (max disk busy 100.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 17:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:20:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:21:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:24:52 evo-x2 memory-emergency-guard-check[384803]: MEMORY EMERGENCY: I/O PSI some avg60=41.98% sustained (max disk busy 100.0%, MemAvailable=46.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 17:24:54 evo-x2 memory-emergency-guard-check[384803]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2960, zone 6) — top io since last trip: system.slice/io.stat +36239MB, user.slice/io.stat +14754MB, user.slice/user-1000.slice/io.stat +14053MB
Oct 13 17:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:26:23 evo-x2 memory-emergency-guard-check[453629]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.18% sustained (max disk busy 100.0%, MemAvailable=38.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 17:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:35:16 evo-x2 memory-emergency-guard-check[890905]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 17:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:45:17 evo-x2 memory-emergency-guard-check[1397450]: MEMORY EMERGENCY: I/O PSI some avg60=40.36% sustained (max disk busy 100.0%, MemAvailable=47.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 17:45:20 evo-x2 memory-emergency-guard-check[1397450]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2961, zone 6) — top io since last trip: system.slice/io.stat +52246MB, user.slice/io.stat +23891MB, user.slice/user-1000.slice/io.stat +23317MB
Oct 13 17:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:45:47 evo-x2 memory-emergency-guard-check[1424077]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.10% sustained (max disk busy 100.0%, MemAvailable=45.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 17:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:51:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:55:38 evo-x2 memory-emergency-guard-check[1690742]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 17:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:59:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 17:59:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:00:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:05:41 evo-x2 memory-emergency-guard-check[2147699]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 18:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:12:10 evo-x2 memory-emergency-guard-check[2730012]: MEMORY EMERGENCY: I/O PSI some avg60=44.62% sustained (max disk busy 99.7%, MemAvailable=45.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 18:12:11 evo-x2 memory-emergency-guard-check[2730012]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2962, zone 6) — top io since last trip: system.slice/io.stat +114752MB, system.slice/nix-daemon.service/io.stat +52911MB, user.slice/io.stat +30310MB
Oct 13 18:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:12:40 evo-x2 memory-emergency-guard-check[2785957]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.19% sustained (max disk busy 100.0%, MemAvailable=43.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 18:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:15:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:18:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:20:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:21:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:22:11 evo-x2 memory-emergency-guard-check[3296442]: MEMORY EMERGENCY: I/O PSI some avg60=44.51% sustained (max disk busy 100.0%, MemAvailable=45.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 18:22:11 evo-x2 memory-emergency-guard-check[3296442]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2963, zone 6) — top io since last trip: system.slice/io.stat +62700MB, system.slice/nix-daemon.service/io.stat +23312MB, user.slice/io.stat +18050MB
Oct 13 18:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:22:41 evo-x2 memory-emergency-guard-check[3317295]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.11% sustained (max disk busy 96.3%, MemAvailable=45.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 18:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:24:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:28:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:32:11 evo-x2 memory-emergency-guard-check[3864666]: MEMORY EMERGENCY: I/O PSI some avg60=40.17% sustained (max disk busy 99.9%, MemAvailable=48.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 18:32:12 evo-x2 memory-emergency-guard-check[3864666]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2964, zone 6) — top io since last trip: system.slice/io.stat +79529MB, system.slice/nix-daemon.service/io.stat +45417MB, user.slice/io.stat +28060MB
Oct 13 18:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:32:41 evo-x2 memory-emergency-guard-check[3907040]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.63% sustained (max disk busy 100.0%, MemAvailable=47.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 18:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:38:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:42:12 evo-x2 memory-emergency-guard-check[195846]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 18:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:44:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:45:13 evo-x2 memory-emergency-guard-check[347542]: MEMORY EMERGENCY: I/O PSI some avg60=41.20% sustained (max disk busy 100.0%, MemAvailable=47.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 18:45:14 evo-x2 memory-emergency-guard-check[347542]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2965, zone 6) — top io since last trip: system.slice/io.stat +35983MB, system.slice/nix-daemon.service/io.stat +24294MB, user.slice/io.stat +14722MB
Oct 13 18:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:45:43 evo-x2 memory-emergency-guard-check[393646]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.74% sustained (max disk busy 100.0%, MemAvailable=46.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 18:45:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:46:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:55:16 evo-x2 memory-emergency-guard-check[1011689]: MEMORY EMERGENCY: I/O PSI some avg60=45.16% sustained (max disk busy 41.1%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 18:55:17 evo-x2 memory-emergency-guard-check[1011689]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2966, zone 6) — top io since last trip: system.slice/io.stat +24993MB, user.slice/io.stat +16843MB, user.slice/user-1000.slice/io.stat +16204MB
Oct 13 18:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:56:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:58:17 evo-x2 memory-emergency-guard-check[1170687]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.12% sustained (max disk busy 82.7%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (181s < 600s, 419s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 18:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:59:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 18:59:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:00:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:02:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:03:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:03:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:05:20 evo-x2 memory-emergency-guard-check[1385412]: MEMORY EMERGENCY: I/O PSI some avg60=67.31% sustained (max disk busy 100.0%, MemAvailable=50.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:05:21 evo-x2 memory-emergency-guard-check[1385412]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2967, zone 6) — top io since last trip: system.slice/io.stat +13829MB, user.slice/io.stat +11773MB, user.slice/user-1000.slice/io.stat +11759MB
Oct 13 19:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:05:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:08:21 evo-x2 memory-emergency-guard-check[1440976]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.86% sustained (max disk busy 28.2%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (181s < 600s, 419s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:08:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:14:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:15:26 evo-x2 memory-emergency-guard-check[1564769]: MEMORY EMERGENCY: I/O PSI some avg60=68.50% sustained (max disk busy 37.9%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:15:27 evo-x2 memory-emergency-guard-check[1564769]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2968, zone 6) — top io since last trip: system.slice/io.stat +12945MB, system.slice/inboxclean-web.service/io.stat +7571MB, user.slice/io.stat +5448MB
Oct 13 19:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:15:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:18:28 evo-x2 memory-emergency-guard-check[1614194]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.09% sustained (max disk busy 28.2%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (182s < 600s, 418s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:25:31 evo-x2 memory-emergency-guard-check[1919581]: MEMORY EMERGENCY: I/O PSI some avg60=43.89% sustained (max disk busy 51.0%, MemAvailable=50.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:25:32 evo-x2 memory-emergency-guard-check[1919581]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2969, zone 6) — top io since last trip: system.slice/io.stat +20442MB, system.slice/forgejo.service/io.stat +7773MB, system.slice/inboxclean-web.service/io.stat +6949MB
Oct 13 19:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:28:33 evo-x2 memory-emergency-guard-check[2059521]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.32% sustained (max disk busy 99.2%, MemAvailable=47.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (182s < 600s, 418s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:29:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:30:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:32:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:33:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:35:35 evo-x2 memory-emergency-guard-check[2267732]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 19:35:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:37:37 evo-x2 memory-emergency-guard-check[2295648]: MEMORY EMERGENCY: I/O PSI some avg60=47.32% sustained (max disk busy 37.3%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:37:37 evo-x2 memory-emergency-guard-check[2295648]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2970, zone 6) — top io since last trip: system.slice/io.stat +19510MB, user.slice/io.stat +13064MB, user.slice/user-1000.slice/io.stat +12216MB
Oct 13 19:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:38:38 evo-x2 memory-emergency-guard-check[2311904]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.99% sustained (max disk busy 28.6%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:42:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:43:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:45:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:47:38 evo-x2 memory-emergency-guard-check[2438766]: MEMORY EMERGENCY: I/O PSI some avg60=61.37% sustained (max disk busy 22.9%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:47:39 evo-x2 memory-emergency-guard-check[2438766]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2971, zone 6) — top io since last trip: system.slice/io.stat +10557MB, system.slice/inboxclean-web.service/io.stat +7908MB, user.slice/io.stat +1734MB
Oct 13 19:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:49:09 evo-x2 memory-emergency-guard-check[2463763]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.34% sustained (max disk busy 29.9%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:57:39 evo-x2 memory-emergency-guard-check[2566643]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 19:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:58:09 evo-x2 memory-emergency-guard-check[2571258]: MEMORY EMERGENCY: I/O PSI some avg60=72.01% sustained (max disk busy 30.2%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 19:58:10 evo-x2 memory-emergency-guard-check[2571258]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2972, zone 6) — top io since last trip: system.slice/io.stat +4620MB, system.slice/inboxclean-web.service/io.stat +2693MB, user.slice/io.stat +2117MB
Oct 13 19:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 19:59:39 evo-x2 memory-emergency-guard-check[2601364]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.66% sustained (max disk busy 74.1%, MemAvailable=53.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 19:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:08:11 evo-x2 memory-emergency-guard-check[2735293]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 20:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:09:11 evo-x2 memory-emergency-guard-check[2746363]: MEMORY EMERGENCY: I/O PSI some avg60=78.31% sustained (max disk busy 22.9%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:09:11 evo-x2 memory-emergency-guard-check[2746363]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2973, zone 6) — top io since last trip: system.slice/io.stat +12316MB, system.slice/inboxclean-web.service/io.stat +8974MB, user.slice/io.stat +3268MB
Oct 13 20:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:09:41 evo-x2 memory-emergency-guard-check[2756235]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.29% sustained (max disk busy 32.3%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 20:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:18:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:19:13 evo-x2 memory-emergency-guard-check[2967207]: MEMORY EMERGENCY: I/O PSI some avg60=54.01% sustained (max disk busy 100.0%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:19:17 evo-x2 memory-emergency-guard-check[2967207]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2974, zone 6) — top io since last trip: system.slice/io.stat +14408MB, system.slice/inboxclean-web.service/io.stat +7796MB, user.slice/io.stat +5219MB
Oct 13 20:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:19:44 evo-x2 memory-emergency-guard-check[2995264]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.58% sustained (max disk busy 63.0%, MemAvailable=40.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 20:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:29:15 evo-x2 memory-emergency-guard-check[3601955]: MEMORY EMERGENCY: I/O PSI some avg60=48.96% sustained (max disk busy 89.7%, MemAvailable=50.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:29:15 evo-x2 memory-emergency-guard-check[3601955]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2975, zone 6) — top io since last trip: system.slice/io.stat +40656MB, system.slice/nix-daemon.service/io.stat +28973MB, user.slice/io.stat +15204MB
Oct 13 20:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:29:45 evo-x2 memory-emergency-guard-check[3626789]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.30% sustained (max disk busy 96.5%, MemAvailable=48.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 20:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:34:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:39:18 evo-x2 memory-emergency-guard-check[3925139]: MEMORY EMERGENCY: I/O PSI some avg60=52.75% sustained (max disk busy 41.5%, MemAvailable=50.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:39:18 evo-x2 memory-emergency-guard-check[3925139]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2976, zone 6) — top io since last trip: system.slice/io.stat +13242MB, user.slice/io.stat +9577MB, user.slice/user-1000.slice/io.stat +9170MB
Oct 13 20:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:39:48 evo-x2 memory-emergency-guard-check[3945140]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.62% sustained (max disk busy 30.6%, MemAvailable=50.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 20:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:49:21 evo-x2 memory-emergency-guard-check[51783]: MEMORY EMERGENCY: I/O PSI some avg60=55.33% sustained (max disk busy 57.8%, MemAvailable=50.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:49:21 evo-x2 memory-emergency-guard-check[52267]: sort: fflush failed: 'standard output': Broken pipe
Oct 13 20:49:21 evo-x2 memory-emergency-guard-check[52267]: sort: write error
Oct 13 20:49:21 evo-x2 memory-emergency-guard-check[51783]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2977, zone 6) — top io since last trip: system.slice/io.stat +22477MB, system.slice/nix-daemon.service/io.stat +10283MB, system.slice/inboxclean-web.service/io.stat +7641MB
Oct 13 20:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:49:51 evo-x2 memory-emergency-guard-check[78459]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.78% sustained (max disk busy 23.6%, MemAvailable=50.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 20:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:59:24 evo-x2 memory-emergency-guard-check[404319]: MEMORY EMERGENCY: I/O PSI some avg60=67.41% sustained (max disk busy 52.7%, MemAvailable=50.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 20:59:25 evo-x2 memory-emergency-guard-check[404319]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2978, zone 6) — top io since last trip: system.slice/io.stat +28865MB, system.slice/nix-daemon.service/io.stat +13877MB, system.slice/inboxclean-web.service/io.stat +7342MB
Oct 13 20:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 20:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:00:24 evo-x2 memory-emergency-guard-check[423851]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.99% sustained (max disk busy 33.5%, MemAvailable=50.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:01:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:09:30 evo-x2 memory-emergency-guard-check[624026]: MEMORY EMERGENCY: I/O PSI some avg60=59.28% sustained (max disk busy 67.3%, MemAvailable=51.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:09:30 evo-x2 memory-emergency-guard-check[624026]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2979, zone 6) — top io since last trip: system.slice/io.stat +7969MB, system.slice/inboxclean-web.service/io.stat +6001MB, user.slice/io.stat +2962MB
Oct 13 21:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:10:30 evo-x2 memory-emergency-guard-check[661267]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.61% sustained (max disk busy 31.0%, MemAvailable=51.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:12:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:13:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:19:33 evo-x2 memory-emergency-guard-check[1070608]: MEMORY EMERGENCY: I/O PSI some avg60=57.41% sustained (max disk busy 54.2%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:19:33 evo-x2 memory-emergency-guard-check[1070608]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2980, zone 6) — top io since last trip: system.slice/io.stat +30558MB, system.slice/nix-daemon.service/io.stat +15821MB, user.slice/io.stat +7996MB
Oct 13 21:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:20:33 evo-x2 memory-emergency-guard-check[1143246]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.43% sustained (max disk busy 29.4%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:23:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:29:37 evo-x2 memory-emergency-guard-check[1375272]: MEMORY EMERGENCY: I/O PSI some avg60=52.08% sustained (max disk busy 55.9%, MemAvailable=48.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:29:37 evo-x2 memory-emergency-guard-check[1375272]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2981, zone 6) — top io since last trip: system.slice/io.stat +35434MB, user.slice/io.stat +8650MB, user.slice/user-1000.slice/io.stat +7816MB
Oct 13 21:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:30:37 evo-x2 memory-emergency-guard-check[1414041]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.14% sustained (max disk busy 32.3%, MemAvailable=44.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:39:40 evo-x2 memory-emergency-guard-check[1670493]: MEMORY EMERGENCY: I/O PSI some avg60=63.56% sustained (max disk busy 34.7%, MemAvailable=54.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:39:41 evo-x2 memory-emergency-guard-check[1670493]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2982, zone 6) — top io since last trip: system.slice/io.stat +9171MB, user.slice/io.stat +3006MB, user.slice/user-1000.slice/io.stat +2786MB
Oct 13 21:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:40:41 evo-x2 memory-emergency-guard-check[1687152]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.57% sustained (max disk busy 20.1%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:49:41 evo-x2 memory-emergency-guard-check[1844684]: MEMORY EMERGENCY: I/O PSI some avg60=61.83% sustained (max disk busy 32.5%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:49:41 evo-x2 memory-emergency-guard-check[1844684]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2983, zone 6) — top io since last trip: system.slice/io.stat +11312MB, system.slice/inboxclean-web.service/io.stat +7986MB, user.slice/io.stat +839MB
Oct 13 21:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:51:11 evo-x2 memory-emergency-guard-check[1871634]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.31% sustained (max disk busy 22.5%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 21:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:57:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 21:59:42 evo-x2 memory-emergency-guard-check[1968471]: MEMORY EMERGENCY: I/O PSI some avg60=75.07% sustained (max disk busy 27.4%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 21:59:43 evo-x2 memory-emergency-guard-check[1968471]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2984, zone 6) — top io since last trip: system.slice/io.stat +20099MB, system.slice/forgejo.service/io.stat +10264MB, system.slice/inboxclean-web.service/io.stat +8116MB
Oct 13 21:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:00:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:01:13 evo-x2 memory-emergency-guard-check[1995579]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.22% sustained (max disk busy 25.4%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:01:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:04:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:05:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:06:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:09:45 evo-x2 memory-emergency-guard-check[2096040]: MEMORY EMERGENCY: I/O PSI some avg60=73.81% sustained (max disk busy 27.4%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 22:09:45 evo-x2 memory-emergency-guard-check[2096040]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2985, zone 6) — top io since last trip: system.slice/io.stat +11109MB, system.slice/inboxclean-web.service/io.stat +8119MB, system.slice/papdashboard.service/io.stat +1696MB
Oct 13 22:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:11:15 evo-x2 memory-emergency-guard-check[2123882]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.85% sustained (max disk busy 34.8%, MemAvailable=52.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:19:49 evo-x2 memory-emergency-guard-check[2216952]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 22:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:20:20 evo-x2 memory-emergency-guard-check[2223158]: MEMORY EMERGENCY: I/O PSI some avg60=73.14% sustained (max disk busy 29.4%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 22:20:20 evo-x2 memory-emergency-guard-check[2223158]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2986, zone 6) — top io since last trip: system.slice/io.stat +2484MB, system.slice/inboxclean-web.service/io.stat +1126MB, system.slice/clickhouse.service/io.stat +831MB
Oct 13 22:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:21:20 evo-x2 memory-emergency-guard-check[2244639]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.58% sustained (max disk busy 48.9%, MemAvailable=52.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:25:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:30:25 evo-x2 memory-emergency-guard-check[2450691]: MEMORY EMERGENCY: I/O PSI some avg60=59.75% sustained (max disk busy 84.1%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 22:30:25 evo-x2 memory-emergency-guard-check[2450691]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2987, zone 6) — top io since last trip: system.slice/io.stat +7876MB, system.slice/inboxclean-web.service/io.stat +3406MB, user.slice/io.stat +3158MB
Oct 13 22:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:31:28 evo-x2 memory-emergency-guard-check[2485247]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.62% sustained (max disk busy 99.8%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (63s < 600s, 537s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:33:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:40:33 evo-x2 memory-emergency-guard-check[2668394]: MEMORY EMERGENCY: I/O PSI some avg60=64.74% sustained (max disk busy 26.2%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 22:40:33 evo-x2 memory-emergency-guard-check[2668394]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2988, zone 6) — top io since last trip: system.slice/io.stat +12011MB, system.slice/inboxclean-web.service/io.stat +5979MB, user.slice/io.stat +4304MB
Oct 13 22:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:41:33 evo-x2 memory-emergency-guard-check[2689763]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.91% sustained (max disk busy 37.7%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:42:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:45:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:50:38 evo-x2 memory-emergency-guard-check[2796328]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 13 22:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:52:38 evo-x2 memory-emergency-guard-check[2838690]: MEMORY EMERGENCY: I/O PSI some avg60=60.44% sustained (max disk busy 25.7%, MemAvailable=52.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 22:52:38 evo-x2 memory-emergency-guard-check[2838690]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2989, zone 6) — top io since last trip: system.slice/io.stat +15798MB, system.slice/inboxclean-web.service/io.stat +9607MB, system.slice/forgejo.service/io.stat +4581MB
Oct 13 22:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:53:38 evo-x2 memory-emergency-guard-check[2904053]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.26% sustained (max disk busy 23.6%, MemAvailable=51.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 22:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:54:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:55:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 22:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:02:39 evo-x2 memory-emergency-guard-check[3098741]: MEMORY EMERGENCY: I/O PSI some avg60=73.18% sustained (max disk busy 97.9%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 23:02:40 evo-x2 memory-emergency-guard-check[3098741]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2990, zone 6) — top io since last trip: system.slice/io.stat +13396MB, user.slice/io.stat +8496MB, user.slice/user-1000.slice/io.stat +8460MB
Oct 13 23:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:04:09 evo-x2 memory-emergency-guard-check[3144107]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.17% sustained (max disk busy 69.9%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 23:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:12:41 evo-x2 memory-emergency-guard-check[3576978]: MEMORY EMERGENCY: I/O PSI some avg60=50.06% sustained (max disk busy 61.9%, MemAvailable=51.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 23:12:41 evo-x2 memory-emergency-guard-check[3576978]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2991, zone 6) — top io since last trip: system.slice/io.stat +35761MB, user.slice/io.stat +13420MB, user.slice/user-1000.slice/io.stat +12758MB
Oct 13 23:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:18:51 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; MEMORY GUARD DEAD" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (309s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard".
Oct 13 23:24:25 evo-x2 gatus[2826693]: 2026/10/13 23:24:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 23:24:26 evo-x2 gatus[2826693]: 2026/10/13 23:24:26 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 13 23:47:05 evo-x2 memory-emergency-guard-check[3714210]: MEMORY EMERGENCY io drained (io PSI some avg60=39.48% < 40%) — churn units re-armed (re-arm #5)
Oct 13 23:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:47:05 evo-x2 memory-emergency-guard-check[673512]: MEMORY EMERGENCY: I/O PSI some avg60=50.01% sustained (max disk busy 94.7%, MemAvailable=55.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 23:47:06 evo-x2 memory-emergency-guard-check[673512]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2992, zone 6) — top io since last trip: system.slice/io.stat +132561MB, user.slice/io.stat +47395MB, user.slice/user-1000.slice/io.stat +46132MB
Oct 13 23:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:47:36 evo-x2 memory-emergency-guard-check[708622]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.83% sustained (max disk busy 48.2%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 23:47:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:47:38 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 13 23:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:57:08 evo-x2 memory-emergency-guard-check[1137408]: MEMORY EMERGENCY: I/O PSI some avg60=72.76% sustained (max disk busy 99.9%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 13 23:57:08 evo-x2 memory-emergency-guard-check[1137408]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2993, zone 6) — top io since last trip: system.slice/io.stat +37601MB, system.slice/nix-daemon.service/io.stat +10607MB, user.slice/io.stat +8972MB
Oct 13 23:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:57:38 evo-x2 memory-emergency-guard-check[1151553]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.30% sustained (max disk busy 100.0%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 13 23:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 13 23:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:00:10 evo-x2 systemd[2238]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 14 00:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:00:42 evo-x2 nix-gc-start[1246958]: deleting '/nix/store/cbxaym96rb8q78d1s7sf392rz3yk0f2b-memory-emergency-guard.nix'
Oct 14 00:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:07:09 evo-x2 memory-emergency-guard-check[1533261]: MEMORY EMERGENCY: I/O PSI some avg60=50.91% sustained (max disk busy 99.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 14 00:07:10 evo-x2 memory-emergency-guard-check[1533261]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2994, zone 6) — top io since last trip: system.slice/io.stat +24460MB, user.slice/io.stat +6954MB, system.slice/inboxclean-web.service/io.stat +6338MB
Oct 14 00:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:07:39 evo-x2 memory-emergency-guard-check[1551746]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.80% sustained (max disk busy 40.7%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 14 00:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 14 00:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 12 13:22:16 evo-x2 thermal-pstate-guard-check[206412]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 12 15:05:16 evo-x2 thermal-pstate-guard-check[2940207]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=63C(hi:95/lo:80)
Oct 12 15:15:00 evo-x2 thermal-pstate-guard-check[3196441]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 12 15:29:32 evo-x2 thermal-pstate-guard-check[3631597]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=71C(hi:95/lo:80)
Oct 12 15:31:34 evo-x2 thermal-pstate-guard-check[3689274]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 12 16:30:47 evo-x2 thermal-pstate-guard-check[826857]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Oct 12 16:33:51 evo-x2 thermal-pstate-guard-check[860442]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 12 16:38:47 evo-x2 thermal-pstate-guard-check[918589]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=76C(hi:95/lo:80)
Oct 12 17:16:00 evo-x2 thermal-pstate-guard-check[1275206]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 12 18:02:23 evo-x2 thermal-pstate-guard-check[2412118]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=76C(hi:95/lo:80)
Oct 12 18:03:13 evo-x2 thermal-pstate-guard-check[2440600]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 12 22:33:53 evo-x2 thermal-pstate-guard-check[3907679]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
Oct 12 22:34:43 evo-x2 thermal-pstate-guard-check[3925618]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 12 22:44:32 evo-x2 thermal-pstate-guard-check[4091179]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Oct 13 00:23:10 evo-x2 thermal-pstate-guard-check[1038283]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 00:44:12 evo-x2 thermal-pstate-guard-check[1347518]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=67C(hi:95/lo:80)
Oct 13 05:52:52 evo-x2 thermal-pstate-guard-check[997257]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 05:58:27 evo-x2 thermal-pstate-guard-check[1038396]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=62C(hi:95/lo:80)
Oct 13 06:23:39 evo-x2 thermal-pstate-guard-check[1236535]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 13 06:26:41 evo-x2 thermal-pstate-guard-check[1258928]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=59C(hi:95/lo:80)
Oct 13 12:16:25 evo-x2 thermal-pstate-guard-check[4180884]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 12:30:30 evo-x2 thermal-pstate-guard-check[358870]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=65C(hi:95/lo:80)
Oct 13 12:59:16 evo-x2 thermal-pstate-guard-check[696358]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 13 13:15:46 evo-x2 thermal-pstate-guard-check[1169377]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
Oct 13 13:17:08 evo-x2 thermal-pstate-guard-check[1221502]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 13 13:36:25 evo-x2 thermal-pstate-guard-check[1530603]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=78C(hi:95/lo:80)
Oct 13 13:44:11 evo-x2 thermal-pstate-guard-check[1676640]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 13:53:59 evo-x2 thermal-pstate-guard-check[1881547]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=71C(hi:95/lo:80)
Oct 13 14:00:35 evo-x2 thermal-pstate-guard-check[1997332]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 16:57:28 evo-x2 thermal-pstate-guard-check[3098679]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
Oct 13 17:03:26 evo-x2 thermal-pstate-guard-check[3234078]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=99C(hi:95/lo:80)
Oct 13 19:58:24 evo-x2 thermal-pstate-guard-check[2580177]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=70C(hi:95/lo:80)
Oct 13 20:20:53 evo-x2 thermal-pstate-guard-check[3081735]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 13 21:57:21 evo-x2 thermal-pstate-guard-check[1944826]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
Oct 13 22:27:12 evo-x2 thermal-pstate-guard-check[2336683]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 12 13:05:41 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/i8ycx8pfdgb07s7d54zl0d9br215bb62-nixos-system-evo-x2-26.11.20261008.e7439b6/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 12 13:05:41 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/i8ycx8pfdgb07s7d54zl0d9br215bb62-nixos-system-evo-x2-26.11.20261008.e7439b6/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 12 13:05:41 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 12 13:05:43 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
