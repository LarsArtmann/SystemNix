# Boot evidence pull: id8 3caf5548 (full: 3caf554823784ad98bacdb97c962c750)

Pulled 2026-10-27 23:57 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-27 10:04:43 -> 2026-10-28 00:40:38 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 3caf5548 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 27 10:04:43 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Oct 27 10:04:43 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/83klzcdbh1q19dxc87xn45gjrw6z08g4-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 27 10:04:43 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 28 00:40:28 evo-x2 geometrikks-server[1635137]: 2026-10-27T23:39:21.234000Z [info     ] Running job "Refresh GeoLocation.last_hit timestamps (trigger: interval[0:10:00], next run at: 2026-10-28 00:49:21 CET)" (scheduled at 2026-10-28 00:39:21.232466+01:00) [apscheduler.executors.default]
Oct 28 00:40:28 evo-x2 geometrikks-server[1635137]: 2026-10-27T23:39:21.235765Z [info     ] Running job "Poll CrowdSec decision stream (trigger: interval[0:00:15], next run at: 2026-10-28 00:39:36 CET)" (scheduled at 2026-10-28 00:39:21.233127+01:00) [apscheduler.executors.default]
Oct 28 00:40:28 evo-x2 geometrikks-server[1635137]: 2026-10-27T23:39:21.242760Z [info     ] HTTP Request: GET http://127.0.0.1:8082/v1/decisions/stream "HTTP/1.1 200 OK" [httpx2]
Oct 28 00:40:28 evo-x2 geometrikks-server[1635137]: 2026-10-27T23:39:21.245796Z [info     ] Job "Poll CrowdSec decision stream (trigger: interval[0:00:15], next run at: 2026-10-28 00:39:36 CET)" executed successfully [apscheduler.executors.default]
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:09.828526578+01:00","level":"INFO","msg":"traces export: exporter export timeout: rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 127.0.0.1:4317: connect: connection refused\""}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:28.85274803+01:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":41489,"request_id":"01M5ZVQBPM5YHMTK2SM4008EZC"}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:28.883766976+01:00","level":"INFO","msg":"http request","method":"GET","path":"/login","status":302,"duration":30739,"request_id":"01M5ZVQBQK1TXSBCK3SR008EZD"}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:28.934871199+01:00","level":"INFO","msg":"usermgmt: oauth_login_begin","event":"oauth_login_begin","user_id":null,"provider":"pocket-id"}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:28.934946867+01:00","level":"INFO","msg":"http request","method":"GET","path":"/auth/oauth/pocket-id/begin","status":302,"duration":125266,"request_id":"01M5ZVQBS6XRGG91H9NR008EZE"}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:35.176656317+01:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":200,"duration":76602376,"user_id":"01M000JA6P0VR4Q1BNEPSJN3ME","request_id":"01M5ZVQHSV6SQCA1PRAR008EZF"}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:39.829940612+01:00","level":"INFO","msg":"traces export: exporter export timeout: rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 127.0.0.1:4317: connect: connection refused\""}
Oct 28 00:40:38 evo-x2 browser-history-server[1629288]: {"time":"2026-10-28T00:39:54.831222858+01:00","level":"INFO","msg":"traces export: exporter export timeout: rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 127.0.0.1:4317: connect: connection refused\""}
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 2157
- thermal-THROTTLE-lines: 9
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 27 10:07:14 evo-x2 memory-emergency-guard-check[21058]: MEMORY EMERGENCY io drained (io PSI some avg60=32.77% < 40%) — churn units re-armed (re-arm #515)
Oct 27 10:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:07:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:12:03 evo-x2 btrfs-gc-admission[64971]: REFUSE: nix-build-cleanup — memory-emergency-guard tripped 15 min ago (window 60 min).
Oct 27 10:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:20:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:21:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:21:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 98ms CPU time over 129ms wall clock time, 11.3M memory peak, 1.3M read from disk, 4K written to disk.
Oct 27 10:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:22:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 105ms CPU time over 147ms wall clock time, 9.5M memory peak, 1.1M read from disk, 4K written to disk.
Oct 27 10:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:24:50 evo-x2 memory-emergency-guard-check[389176]: MEMORY EMERGENCY: I/O PSI some avg60=40.07% sustained (max disk busy 100.0%, MemAvailable=37.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 10:24:55 evo-x2 memory-emergency-guard-check[389176]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4448, zone 6) — top io since last trip: system.slice/monitor365-server.service/io.stat +28760MB
Oct 27 10:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 5.411s wall clock time, 10.1M memory peak, 2.7M read from disk, 36.4M written to disk.
Oct 27 10:25:56 evo-x2 memory-emergency-guard-check[407626]: MEMORY EMERGENCY io drained (io PSI some avg60=28.43% < 40%) — churn units re-armed (re-arm #516)
Oct 27 10:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:26:04 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 3 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 10:26:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:28:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:28:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:29:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:29:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:34:41 evo-x2 btrfs-gc-admission[644187]: REFUSE: btrfs-compsize — memory-emergency-guard tripped 9 min ago (window 60 min).
Oct 27 10:35:05 evo-x2 memory-emergency-guard-check[647860]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 10:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:35:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:45:09 evo-x2 memory-emergency-guard-check[932578]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 10:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:50:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:51:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:52:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:53:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:55:17 evo-x2 memory-emergency-guard-check[1088025]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 10:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 10:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:04:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:04:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:05:25 evo-x2 memory-emergency-guard-check[1287651]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 11:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:05:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:06:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:14:00 evo-x2 memory-emergency-guard-check[1421189]: awk: (FILENAME=/var/lib/memory-emergency-guard/trip-history FNR=1) warning: error writing standard output: No space left on device
Oct 27 11:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:14:30 evo-x2 memory-emergency-guard-check[1424829]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:14:30 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:14:30 evo-x2 memory-emergency-guard.service[1424891]: Scheduled task failed — check journalctl -u memory-emergency-guard.service
Oct 27 11:14:30 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:14:30 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:15:00 evo-x2 memory-emergency-guard-check[1428630]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:15:00 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:15:00 evo-x2 memory-emergency-guard.service[1428666]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:15:00 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:15:00 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:15:30 evo-x2 memory-emergency-guard-check[1431876]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:15:30 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:15:30 evo-x2 memory-emergency-guard.service[1431910]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:15:30 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:15:30 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:16:30 evo-x2 memory-emergency-guard-check[1439142]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 11:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:17:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:18:30 evo-x2 memory-emergency-guard-check[1474160]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:18:30 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:18:30 evo-x2 memory-emergency-guard.service[1474196]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:18:30 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:18:30 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:19:00 evo-x2 memory-emergency-guard-check[1483442]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:19:00 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:19:00 evo-x2 memory-emergency-guard.service[1483477]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:19:00 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:19:00 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:19:30 evo-x2 memory-emergency-guard-check[1490020]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:19:30 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:19:30 evo-x2 memory-emergency-guard.service[1490090]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:19:30 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:19:30 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:20:00 evo-x2 memory-emergency-guard-check[1497036]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:20:00 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:20:00 evo-x2 memory-emergency-guard.service[1497107]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:20:00 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:20:00 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:20:30 evo-x2 memory-emergency-guard-check[1504940]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:20:30 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:20:30 evo-x2 memory-emergency-guard.service[1504998]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:20:30 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:20:30 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:21:00 evo-x2 memory-emergency-guard-check[1510294]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:21:00 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:21:00 evo-x2 memory-emergency-guard.service[1510327]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:21:00 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:21:00 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:21:32 evo-x2 memory-emergency-guard-check[1513945]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:21:32 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:21:32 evo-x2 memory-emergency-guard.service[1514000]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:21:32 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:21:32 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:22:02 evo-x2 memory-emergency-guard-check[1518084]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:22:02 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:22:02 evo-x2 memory-emergency-guard.service[1518138]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:22:02 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:22:02 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:22:32 evo-x2 memory-emergency-guard-check[1521348]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:22:32 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:22:32 evo-x2 memory-emergency-guard.service[1521402]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:22:32 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:22:32 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:23:02 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: FLM RESTORE CAPPED; MEMORY GUARD DEAD; UNIT CRASH LOOP" "FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (302s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 11:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:24:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:25:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:26:38 evo-x2 memory-emergency-guard-check[1553014]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 11:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:29:40 evo-x2 memory-emergency-guard-check[1605959]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:29:40 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:29:40 evo-x2 memory-emergency-guard.service[1606078]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:29:40 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:29:40 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:30:10 evo-x2 memory-emergency-guard-check[1608986]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:30:10 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:30:11 evo-x2 memory-emergency-guard.service[1609055]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:30:11 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:30:11 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:30:41 evo-x2 memory-emergency-guard-check[1612001]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:30:41 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:30:41 evo-x2 memory-emergency-guard.service[1612048]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:30:41 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:30:41 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:30:42 evo-x2 service-health-check[1612253]:   memory-emergency-guard.service (failed)
Oct 27 11:31:11 evo-x2 memory-emergency-guard-check[1615247]: /nix/store/f0fps5zs7avixq4bg7k5jiqgxvq6s36k-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 154: echo: write error: No space left on device
Oct 27 11:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Main process exited, code=exited, status=1/FAILURE
Oct 27 11:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Failed with result 'exit-code'.
Oct 27 11:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Triggering OnFailure= dependencies.
Oct 27 11:31:11 evo-x2 systemd[1]: Starting Notify on failure of memory-emergency-guard.service...
Oct 27 11:31:11 evo-x2 memory-emergency-guard.service[1615317]: Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u memory-emergency-guard.service
Oct 27 11:31:11 evo-x2 systemd[1]: notify-failure@memory-emergency-guard.service.service: Deactivated successfully.
Oct 27 11:31:11 evo-x2 systemd[1]: Finished Notify on failure of memory-emergency-guard.service.
Oct 27 11:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:35:54 evo-x2 memory-emergency-guard-check[1758793]: MEMORY EMERGENCY: I/O PSI some avg60=42.38% sustained (max disk busy 100.0%, MemAvailable=44.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 11:35:57 evo-x2 memory-emergency-guard-check[1758793]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4449, zone 6) — top io since last trip: system.slice/io.stat +760356MB, system.slice/tq-agent-pool.service/io.stat +390439MB, user.slice/io.stat +78016MB
Oct 27 11:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.003s CPU time over 3.663s wall clock time, 10.2M memory peak, 10.4M read from disk, 72.8M written to disk.
Oct 27 11:36:24 evo-x2 memory-emergency-guard-check[1776163]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.79% sustained (max disk busy 99.8%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 11:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:36:31 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 11:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:37:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:41:49 evo-x2 gatus[24757]: 2026/10/27 11:41:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 11:41:49 evo-x2 gatus[24757]: 2026/10/27 11:41:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 11:41:51 evo-x2 memory-emergency-guard-check[1987660]: MEMORY EMERGENCY io drained (io PSI some avg60=38.99% < 40%) — churn units re-armed (re-arm #517)
Oct 27 11:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:48:21 evo-x2 memory-emergency-guard-check[2452742]: MEMORY EMERGENCY: I/O PSI some avg60=43.92% sustained (max disk busy 100.0%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 11:48:41 evo-x2 memory-emergency-guard-check[2452742]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4450, zone 6) — top io since last trip: system.slice/io.stat +342285MB, system.slice/tq-agent-pool.service/io.stat +256417MB, system.slice/monitor365-server.service/io.stat +41573MB
Oct 27 11:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 19.462s wall clock time, 10.7M memory peak, 736K read from disk, 30.1M written to disk.
Oct 27 11:48:52 evo-x2 memory-emergency-guard-check[2471756]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.20% sustained (max disk busy 97.8%, MemAvailable=42.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 11:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:49:19 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; SYSTEM MONITORING STALE; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 2 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | system_health metrics missing/stale (-1s old). Most Gatus conditions are phantom right now. systemctl status system-health-metrics | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 11:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:53:30 evo-x2 memory-emergency-guard-check[2593575]: MEMORY EMERGENCY io drained (io PSI some avg60=33.55% < 40%) — churn units re-armed (re-arm #518)
Oct 27 11:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:58:38 evo-x2 memory-emergency-guard-check[2737522]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 11:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 11:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:09:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:13:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:13:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:14:12 evo-x2 memory-emergency-guard-check[3072496]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 12:14:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:27:49 evo-x2 memory-emergency-guard-check[3248353]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 12:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:37:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:51:55 evo-x2 memory-emergency-guard-check[3647277]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 12:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 12:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:13:30 evo-x2 memory-emergency-guard-check[3955091]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 13:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:19:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:23:38 evo-x2 memory-emergency-guard-check[7284]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 13:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:33:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:33:42 evo-x2 memory-emergency-guard-check[154285]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 13:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:43:50 evo-x2 memory-emergency-guard-check[250613]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 13:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:49:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:55:58 evo-x2 memory-emergency-guard-check[395516]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 27 13:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:58:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:59:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 13:59:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:00:01 evo-x2 memory-emergency-guard-check[501499]: MEMORY EMERGENCY: I/O PSI some avg60=46.97% sustained (max disk busy 99.0%, MemAvailable=47.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:01:03 evo-x2 memory-emergency-guard-check[501499]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4451, zone 6) — top io since last trip: system.slice/io.stat +2299231MB, system.slice/tq-agent-pool.service/io.stat +1327623MB, system.slice/monitor365-server.service/io.stat +139230MB
Oct 27 14:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 1min 2.373s wall clock time, 10.5M memory peak, 32K read from disk, 118.3M written to disk.
Oct 27 14:01:03 evo-x2 memory-emergency-guard-check[525160]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.35% sustained (max disk busy 100.0%, MemAvailable=42.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (62s < 600s, 538s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:01:07 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 14:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:05:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:05:53 evo-x2 gatus[24757]: 2026/10/27 14:05:53 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 14:05:53 evo-x2 gatus[24757]: 2026/10/27 14:05:53 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 14:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:09:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:10:05 evo-x2 memory-emergency-guard-check[910807]: MEMORY EMERGENCY: I/O PSI some avg60=60.93% sustained (max disk busy 85.3%, MemAvailable=44.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:10:07 evo-x2 memory-emergency-guard-check[910807]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4452, zone 6) — top io since last trip: system.slice/io.stat +120784MB, system.slice/monitor365-server.service/io.stat +75253MB, system.slice/nix-daemon.service/io.stat +20210MB
Oct 27 14:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 505ms CPU time over 2.366s wall clock time, 9.4M memory peak, 80K read from disk, 22.6M written to disk.
Oct 27 14:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:11:05 evo-x2 memory-emergency-guard-check[931275]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.64% sustained (max disk busy 66.7%, MemAvailable=48.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:16:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:17:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:20:08 evo-x2 memory-emergency-guard-check[1255625]: MEMORY EMERGENCY: I/O PSI some avg60=57.18% sustained (max disk busy 100.0%, MemAvailable=45.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:20:09 evo-x2 memory-emergency-guard-check[1255625]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4453, zone 6) — top io since last trip: system.slice/io.stat +77330MB, system.slice/nix-daemon.service/io.stat +29089MB, user.slice/io.stat +20280MB
Oct 27 14:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 850ms CPU time over 1.999s wall clock time, 7.5M memory peak, 2M read from disk, 31.2M written to disk.
Oct 27 14:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:21:08 evo-x2 memory-emergency-guard-check[1305954]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.43% sustained (max disk busy 84.7%, MemAvailable=47.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:24:17 evo-x2 memory-emergency-guard-check[1399506]: MEMORY EMERGENCY io drained (io PSI some avg60=38.91% < 40%) — churn units re-armed (re-arm #519)
Oct 27 14:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:24:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:26:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 228ms wall clock time, 11.3M memory peak, 4.3M read from disk, 4K written to disk.
Oct 27 14:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:30:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:30:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:31:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:31:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:32:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 151ms CPU time over 253ms wall clock time, 8.2M memory peak, 1.9M read from disk, 4K written to disk.
Oct 27 14:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:34:20 evo-x2 memory-emergency-guard-check[1908595]: MEMORY EMERGENCY: I/O PSI some avg60=44.84% sustained (max disk busy 91.0%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:34:42 evo-x2 memory-emergency-guard-check[1908595]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4454, zone 6) — top io since last trip: system.slice/io.stat +128829MB, system.slice/monitor365-server.service/io.stat +54390MB, system.slice/nix-daemon.service/io.stat +27399MB
Oct 27 14:34:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:34:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 21.783s wall clock time, 10.3M memory peak, 6.5M read from disk, 14.1M written to disk.
Oct 27 14:34:50 evo-x2 memory-emergency-guard-check[1927038]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.56% sustained (max disk busy 90.7%, MemAvailable=52.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:36:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:39:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:45:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:45:55 evo-x2 memory-emergency-guard-check[2097740]: MEMORY EMERGENCY: I/O PSI some avg60=69.83% sustained (max disk busy 80.5%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:46:19 evo-x2 memory-emergency-guard-check[2097740]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4455, zone 6) — top io since last trip: system.slice/io.stat +126722MB, system.slice/monitor365-server.service/io.stat +90485MB, user.slice/io.stat +6103MB
Oct 27 14:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 511ms CPU time over 24.092s wall clock time, 11.9M memory peak, 1M read from disk, 41.6M written to disk.
Oct 27 14:46:25 evo-x2 memory-emergency-guard-check[2108108]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.77% sustained (max disk busy 79.5%, MemAvailable=51.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:46:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:46:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:47:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:51:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 102ms CPU time over 138ms wall clock time, 10.6M memory peak, 1.6M read from disk, 4K written to disk.
Oct 27 14:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:56:27 evo-x2 memory-emergency-guard-check[2310420]: MEMORY EMERGENCY: I/O PSI some avg60=70.50% sustained (max disk busy 59.2%, MemAvailable=48.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 14:56:33 evo-x2 memory-emergency-guard-check[2310420]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4456, zone 6) — top io since last trip: system.slice/io.stat +97494MB, system.slice/monitor365-server.service/io.stat +74560MB, user.slice/io.stat +6422MB
Oct 27 14:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 424ms CPU time over 6.502s wall clock time, 10.7M memory peak, 144K read from disk, 7.5M written to disk.
Oct 27 14:56:57 evo-x2 memory-emergency-guard-check[2326195]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.58% sustained (max disk busy 25.3%, MemAvailable=46.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 14:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 14:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:06:29 evo-x2 memory-emergency-guard-check[2554937]: MEMORY EMERGENCY: I/O PSI some avg60=52.11% sustained (max disk busy 25.9%, MemAvailable=51.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 15:06:30 evo-x2 memory-emergency-guard-check[2554937]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4457, zone 6) — top io since last trip: system.slice/io.stat +101348MB, system.slice/monitor365-server.service/io.stat +96594MB, user.slice/io.stat +8405MB
Oct 27 15:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 663ms CPU time over 1.549s wall clock time, 9.5M memory peak, 4.7M read from disk, 42.4M written to disk.
Oct 27 15:07:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:07:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:08:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:08:30 evo-x2 memory-emergency-guard-check[2598776]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.69% sustained (max disk busy 23.1%, MemAvailable=46.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 600s, 479s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 15:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:11:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:16:32 evo-x2 memory-emergency-guard-check[2712527]: MEMORY EMERGENCY: I/O PSI some avg60=71.09% sustained (max disk busy 68.9%, MemAvailable=49.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 15:16:34 evo-x2 memory-emergency-guard-check[2712527]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4458, zone 6) — top io since last trip: system.slice/io.stat +48013MB, system.slice/monitor365-server.service/io.stat +45516MB, user.slice/io.stat +4966MB
Oct 27 15:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 507ms CPU time over 2.355s wall clock time, 10.9M memory peak, 432K read from disk, 24.2M written to disk.
Oct 27 15:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:18:33 evo-x2 memory-emergency-guard-check[2758355]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.30% sustained (max disk busy 22.8%, MemAvailable=50.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 15:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:24:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:25:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:27:05 evo-x2 memory-emergency-guard-check[2918052]: MEMORY EMERGENCY: I/O PSI some avg60=56.09% sustained (max disk busy 32.8%, MemAvailable=43.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 15:27:38 evo-x2 memory-emergency-guard-check[2918052]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4459, zone 6) — top io since last trip: system.slice/io.stat +101353MB, system.slice/monitor365-server.service/io.stat +96633MB, user.slice/io.stat +5224MB
Oct 27 15:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 750ms CPU time over 32.560s wall clock time, 11.4M memory peak, 3.4M read from disk, 84M written to disk.
Oct 27 15:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:29:38 evo-x2 memory-emergency-guard-check[2962811]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.60% sustained (max disk busy 48.5%, MemAvailable=47.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (153s < 600s, 447s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 15:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:31:51 evo-x2 gatus[24757]: 2026/10/27 15:31:51 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 15:31:51 evo-x2 gatus[24757]: 2026/10/27 15:31:51 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 15:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:34:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:37:10 evo-x2 memory-emergency-guard-check[3090236]: MEMORY EMERGENCY: I/O PSI some avg60=70.56% sustained (max disk busy 58.9%, MemAvailable=50.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 15:37:12 evo-x2 memory-emergency-guard-check[3090236]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4460, zone 6) — top io since last trip: system.slice/io.stat +46444MB, system.slice/forgejo.service/io.stat +9712MB, user.slice/io.stat +3952MB
Oct 27 15:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 542ms CPU time over 1.995s wall clock time, 11.1M memory peak, 1M read from disk, 33.8M written to disk.
Oct 27 15:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:41:41 evo-x2 memory-emergency-guard-check[3169890]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.19% sustained (max disk busy 34.2%, MemAvailable=49.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (271s < 600s, 329s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 15:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 106ms CPU time over 168ms wall clock time, 9.5M memory peak, 3.2M read from disk, 4K written to disk.
Oct 27 15:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:49:13 evo-x2 memory-emergency-guard-check[3318090]: MEMORY EMERGENCY: I/O PSI some avg60=69.07% sustained (max disk busy 84.8%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 15:49:16 evo-x2 memory-emergency-guard-check[3318090]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4461, zone 6) — top io since last trip: system.slice/io.stat +65694MB, system.slice/monitor365-server.service/io.stat +45897MB, system.slice/nix-daemon.service/io.stat +9317MB
Oct 27 15:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 556ms CPU time over 3.050s wall clock time, 11.1M memory peak, 3.6M read from disk, 37.9M written to disk.
Oct 27 15:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:52:15 evo-x2 memory-emergency-guard-check[3420747]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.34% sustained (max disk busy 77.5%, MemAvailable=48.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (182s < 600s, 418s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 15:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:56:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 15:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:01:20 evo-x2 memory-emergency-guard-check[3682233]: MEMORY EMERGENCY: I/O PSI some avg60=55.87% sustained (max disk busy 98.4%, MemAvailable=46.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:01:21 evo-x2 memory-emergency-guard-check[3682233]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4462, zone 6) — top io since last trip: system.slice/io.stat +76220MB, user.slice/io.stat +16442MB, user.slice/user-1000.slice/io.stat +16031MB
Oct 27 16:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 546ms CPU time over 1.735s wall clock time, 9.7M memory peak, 2.9M read from disk, 24.8M written to disk.
Oct 27 16:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:02:20 evo-x2 memory-emergency-guard-check[3711986]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.46% sustained (max disk busy 72.2%, MemAvailable=33.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:03:40 evo-x2 memory-emergency-guard-check[3722851]: MEMORY EMERGENCY io drained (io PSI some avg60=39.90% < 40%) — churn units re-armed (re-arm #520)
Oct 27 16:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:05:49 evo-x2 gatus[24757]: 2026/10/27 16:05:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 16:05:49 evo-x2 gatus[24757]: 2026/10/27 16:05:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 16:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:10:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:11:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:11:43 evo-x2 memory-emergency-guard-check[3909316]: MEMORY EMERGENCY: I/O PSI some avg60=85.26% sustained (max disk busy 100.0%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:11:46 evo-x2 memory-emergency-guard-check[3909316]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4463, zone 6) — top io since last trip: system.slice/io.stat +71925MB, user.slice/io.stat +25948MB, user.slice/user-1000.slice/io.stat +25668MB
Oct 27 16:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 2.578s wall clock time, 8.8M memory peak, 11.1M read from disk, 57.4M written to disk.
Oct 27 16:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:12:44 evo-x2 memory-emergency-guard-check[3978012]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.16% sustained (max disk busy 88.0%, MemAvailable=46.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:15:49 evo-x2 gatus[24757]: 2026/10/27 16:15:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 16:15:49 evo-x2 gatus[24757]: 2026/10/27 16:15:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 16:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:22:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:22:49 evo-x2 memory-emergency-guard-check[176450]: MEMORY EMERGENCY: I/O PSI some avg60=66.35% sustained (max disk busy 52.4%, MemAvailable=49.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:22:53 evo-x2 memory-emergency-guard-check[176450]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4464, zone 6) — top io since last trip: system.slice/io.stat +52708MB, system.slice/monitor365-server.service/io.stat +43783MB, user.slice/io.stat +9902MB
Oct 27 16:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 537ms CPU time over 4.778s wall clock time, 10.7M memory peak, 384K read from disk, 31.8M written to disk.
Oct 27 16:23:19 evo-x2 memory-emergency-guard-check[225886]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.84% sustained (max disk busy 21.4%, MemAvailable=44.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:32:49 evo-x2 memory-emergency-guard-check[398416]: MEMORY EMERGENCY: I/O PSI some avg60=76.09% sustained (max disk busy 99.1%, MemAvailable=50.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:32:51 evo-x2 memory-emergency-guard-check[398416]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4465, zone 6) — top io since last trip: system.slice/io.stat +96046MB, system.slice/monitor365-server.service/io.stat +91240MB, user.slice/io.stat +4513MB
Oct 27 16:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 451ms CPU time over 1.514s wall clock time, 11.4M memory peak, 240K read from disk, 13.7M written to disk.
Oct 27 16:33:19 evo-x2 memory-emergency-guard-check[409519]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.50% sustained (max disk busy 98.0%, MemAvailable=49.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:34:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:44:53 evo-x2 memory-emergency-guard-check[597832]: MEMORY EMERGENCY: I/O PSI some avg60=75.22% sustained (max disk busy 30.3%, MemAvailable=48.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:45:09 evo-x2 memory-emergency-guard-check[597832]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4466, zone 6) — top io since last trip: system.slice/io.stat +49840MB, user.slice/io.stat +7910MB, user.slice/user-1000.slice/io.stat +7842MB
Oct 27 16:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 467ms CPU time over 16.219s wall clock time, 11.4M memory peak, 624K read from disk, 58.9M written to disk.
Oct 27 16:45:23 evo-x2 memory-emergency-guard-check[613427]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.99% sustained (max disk busy 53.8%, MemAvailable=44.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:52:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:55:57 evo-x2 memory-emergency-guard-check[810662]: MEMORY EMERGENCY: I/O PSI some avg60=66.25% sustained (max disk busy 64.9%, MemAvailable=41.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 16:56:02 evo-x2 memory-emergency-guard-check[810662]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4467, zone 6) — top io since last trip: system.slice/io.stat +73302MB, system.slice/monitor365-server.service/io.stat +62539MB, user.slice/io.stat +3706MB
Oct 27 16:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 4.832s wall clock time, 8.3M memory peak, 4.4M read from disk, 46.2M written to disk.
Oct 27 16:56:27 evo-x2 memory-emergency-guard-check[865537]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.15% sustained (max disk busy 81.8%, MemAvailable=33.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 16:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 16:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:00:28 evo-x2 memory-emergency-guard-check[947964]: MEMORY EMERGENCY io drained (io PSI some avg60=39.89% < 40%) — churn units re-armed (re-arm #521)
Oct 27 17:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:08:02 evo-x2 memory-emergency-guard-check[1190032]: MEMORY EMERGENCY: I/O PSI some avg60=71.66% sustained (max disk busy 30.0%, MemAvailable=45.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 17:08:04 evo-x2 memory-emergency-guard-check[1190032]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4468, zone 6) — top io since last trip: system.slice/io.stat +50477MB, system.slice/monitor365-server.service/io.stat +39697MB, user.slice/io.stat +7742MB
Oct 27 17:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 510ms CPU time over 1.923s wall clock time, 10.3M memory peak, 2.4M read from disk, 28.5M written to disk.
Oct 27 17:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:09:02 evo-x2 memory-emergency-guard-check[1208642]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.89% sustained (max disk busy 25.3%, MemAvailable=45.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 17:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:18:05 evo-x2 memory-emergency-guard-check[1359648]: MEMORY EMERGENCY: I/O PSI some avg60=91.41% sustained (max disk busy 100.0%, MemAvailable=44.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 17:18:06 evo-x2 memory-emergency-guard-check[1359648]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4469, zone 6) — top io since last trip: system.slice/io.stat +50551MB, user.slice/io.stat +14370MB, user.slice/user-1000.slice/io.stat +14348MB
Oct 27 17:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 527ms CPU time over 741ms wall clock time, 11.1M memory peak, 816K read from disk, 13.5M written to disk.
Oct 27 17:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:19:06 evo-x2 memory-emergency-guard-check[1377345]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.95% sustained (max disk busy 100.0%, MemAvailable=43.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 17:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:21:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:26:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:27:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:28:10 evo-x2 memory-emergency-guard-check[1604093]: MEMORY EMERGENCY: I/O PSI some avg60=61.30% sustained (max disk busy 87.3%, MemAvailable=43.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 17:28:18 evo-x2 memory-emergency-guard-check[1604093]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4470, zone 6) — top io since last trip: system.slice/io.stat +56224MB, system.slice/monitor365-server.service/io.stat +37467MB, user.slice/io.stat +15001MB
Oct 27 17:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 8.204s wall clock time, 8.6M memory peak, 1.2M read from disk, 49.7M written to disk.
Oct 27 17:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:29:40 evo-x2 memory-emergency-guard-check[1639924]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.35% sustained (max disk busy 52.5%, MemAvailable=45.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 17:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:35:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:36:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:36:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:38:12 evo-x2 memory-emergency-guard-check[1857517]: MEMORY EMERGENCY: I/O PSI some avg60=80.81% sustained (max disk busy 100.0%, MemAvailable=36.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 17:38:13 evo-x2 memory-emergency-guard-check[1857517]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4471, zone 6) — top io since last trip: system.slice/io.stat +65434MB, user.slice/io.stat +12923MB, user.slice/user-1000.slice/io.stat +12896MB
Oct 27 17:38:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:38:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 529ms CPU time over 867ms wall clock time, 13.5M memory peak, 3.3M read from disk, 24.6M written to disk.
Oct 27 17:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:39:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:39:43 evo-x2 memory-emergency-guard-check[1926709]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.70% sustained (max disk busy 81.9%, MemAvailable=33.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 600s, 509s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 17:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:41:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:41:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:42:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:42:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:43:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:43:49 evo-x2 gatus[24757]: 2026/10/27 17:43:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 17:43:49 evo-x2 gatus[24757]: 2026/10/27 17:43:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 17:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:49:46 evo-x2 memory-emergency-guard-check[2312164]: MEMORY EMERGENCY: I/O PSI some avg60=42.20% sustained (max disk busy 27.9%, MemAvailable=26.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 17:50:06 evo-x2 memory-emergency-guard-check[2312164]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4472, zone 6) — top io since last trip: system.slice/io.stat +66262MB, system.slice/monitor365-server.service/io.stat +41338MB, user.slice/io.stat +15389MB
Oct 27 17:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 721ms CPU time over 19.926s wall clock time, 21.4M memory peak, 3.3M read from disk, 67.5M written to disk.
Oct 27 17:50:16 evo-x2 memory-emergency-guard-check[2340992]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.62% sustained (max disk busy 69.2%, MemAvailable=23.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 17:50:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:51:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:52:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:55:49 evo-x2 gatus[24757]: 2026/10/27 17:55:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 17:55:49 evo-x2 gatus[24757]: 2026/10/27 17:55:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 17:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 17:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:00:20 evo-x2 memory-emergency-guard-check[2667147]: MEMORY EMERGENCY: I/O PSI some avg60=62.50% sustained (max disk busy 69.5%, MemAvailable=36.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:00:30 evo-x2 memory-emergency-guard-check[2667147]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4473, zone 6) — top io since last trip: system.slice/io.stat +55815MB, system.slice/monitor365-server.service/io.stat +32316MB, user.slice/io.stat +9990MB
Oct 27 18:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 505ms CPU time over 9.530s wall clock time, 17.6M memory peak, 768K read from disk, 28.2M written to disk.
Oct 27 18:00:50 evo-x2 memory-emergency-guard-check[2688462]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.91% sustained (max disk busy 39.3%, MemAvailable=30.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:05:56 evo-x2 gatus[24757]: 2026/10/27 18:05:56 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 18:05:56 evo-x2 gatus[24757]: 2026/10/27 18:05:56 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 18:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:09:15 evo-x2 memory-emergency-guard-check[3011730]: MEMORY EMERGENCY io drained (io PSI some avg60=39.29% < 40%) — churn units re-armed (re-arm #522)
Oct 27 18:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:10:46 evo-x2 memory-emergency-guard-check[3274398]: MEMORY EMERGENCY: I/O PSI some avg60=83.16% sustained (max disk busy 99.0%, MemAvailable=32.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:10:52 evo-x2 memory-emergency-guard-check[3274398]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4474, zone 6) — top io since last trip: system.slice/io.stat +83979MB, system.slice/nix-daemon.service/io.stat +29744MB, user.slice/io.stat +25601MB
Oct 27 18:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.238s CPU time over 6.567s wall clock time, 9.3M memory peak, 16.6M read from disk, 54M written to disk.
Oct 27 18:11:16 evo-x2 memory-emergency-guard-check[3298157]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.38% sustained (max disk busy 100.0%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:20:50 evo-x2 memory-emergency-guard-check[3706497]: MEMORY EMERGENCY: I/O PSI some avg60=94.88% sustained (max disk busy 100.0%, MemAvailable=43.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:20:52 evo-x2 memory-emergency-guard-check[3706497]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4475, zone 6) — top io since last trip: user.slice/io.stat +25655MB, system.slice/io.stat +24874MB, user.slice/user-1000.slice/io.stat +24689MB
Oct 27 18:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 2.593s wall clock time, 10.1M memory peak, 4.3M read from disk, 30.2M written to disk.
Oct 27 18:21:21 evo-x2 memory-emergency-guard-check[3730735]: MEMORY EMERGENCY still active (I/O PSI some avg60=96.44% sustained (max disk busy 99.4%, MemAvailable=31.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:22:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:24:02 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=23.80%, MemAvailable=6.4%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 27 18:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:28:30 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; MEMORY STALL SUSTAINED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | Memory-stall freeze precursor, 2026-08-31 class (avg60=50.85%, avg10-episode bucket=2). Stop heavy builds / VM tests NOW; the guard is (about to be) sacrificing FastFlowLM. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=86.25%, MemAvailable=9.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 27 18:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:29:31 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 18:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:30:52 evo-x2 memory-emergency-guard-check[3914876]: MEMORY EMERGENCY: I/O PSI some avg60=92.52% sustained (max disk busy 99.6%, MemAvailable=37.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:30:56 evo-x2 memory-emergency-guard-check[3914876]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4476, zone 6) — top io since last trip: system.slice/io.stat +118190MB, user.slice/io.stat +57495MB, user.slice/user-1000.slice/io.stat +56436MB
Oct 27 18:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.111s CPU time over 3.817s wall clock time, 8.5M memory peak, 18.9M read from disk, 55.9M written to disk.
Oct 27 18:31:22 evo-x2 memory-emergency-guard-check[3942365]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.31% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:35:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:35:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:40:54 evo-x2 memory-emergency-guard-check[99143]: MEMORY EMERGENCY: I/O PSI some avg60=66.09% sustained (max disk busy 100.0%, MemAvailable=34.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:40:58 evo-x2 memory-emergency-guard-check[99143]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4477, zone 6) — top io since last trip: system.slice/io.stat +56608MB, user.slice/io.stat +17280MB, user.slice/user-1000.slice/io.stat +17263MB
Oct 27 18:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.403s CPU time over 4.621s wall clock time, 7.9M memory peak, 12.8M read from disk, 60.2M written to disk.
Oct 27 18:41:24 evo-x2 memory-emergency-guard-check[135496]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.07% sustained (max disk busy 100.0%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:43:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:45:38 evo-x2 memory-emergency-guard-check[254862]: MEMORY EMERGENCY io drained (io PSI some avg60=39.24% < 40%) — churn units re-armed (re-arm #523)
Oct 27 18:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:47:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:51:09 evo-x2 memory-emergency-guard-check[550931]: MEMORY EMERGENCY: I/O PSI some avg60=61.00% sustained (max disk busy 100.0%, MemAvailable=31.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 18:51:13 evo-x2 memory-emergency-guard-check[554457]: sort: write failed: 'standard output': Broken pipe
Oct 27 18:51:13 evo-x2 memory-emergency-guard-check[554457]: sort: write error
Oct 27 18:51:13 evo-x2 memory-emergency-guard-check[550931]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4478, zone 6) — top io since last trip: system.slice/io.stat +78140MB, system.slice/monitor365-server.service/io.stat +27249MB, user.slice/io.stat +18857MB
Oct 27 18:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.034s CPU time over 3.754s wall clock time, 7.7M memory peak, 9.2M read from disk, 47.6M written to disk.
Oct 27 18:51:39 evo-x2 memory-emergency-guard-check[574102]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.59% sustained (max disk busy 99.8%, MemAvailable=33.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 18:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:57:29 evo-x2 memory-emergency-guard-check[779394]: MEMORY EMERGENCY io drained (io PSI some avg60=37.51% < 40%) — churn units re-armed (re-arm #524)
Oct 27 18:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 18:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:13:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:15:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:18:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:31:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:31:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 198ms CPU time over 1.098s wall clock time, 13M memory peak, 4.7M read from disk, 4K written to disk.
Oct 27 19:35:45 evo-x2 memory-emergency-guard-check[2824362]: MEMORY EMERGENCY: I/O PSI some avg60=44.77% sustained (max disk busy 98.4%, MemAvailable=47.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 19:35:53 evo-x2 memory-emergency-guard-check[2824362]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4479, zone 6) — top io since last trip: system.slice/io.stat +133814MB, user.slice/io.stat +43429MB, user.slice/user-1000.slice/io.stat +42918MB
Oct 27 19:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 907ms CPU time over 7.976s wall clock time, 7.4M memory peak, 6.5M read from disk, 75.1M written to disk.
Oct 27 19:36:15 evo-x2 memory-emergency-guard-check[2851906]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.89% sustained (max disk busy 97.5%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 19:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:36:19 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 3 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 19:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:41:49 evo-x2 gatus[24757]: 2026/10/27 19:41:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 19:41:49 evo-x2 gatus[24757]: 2026/10/27 19:41:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 27 19:42:25 evo-x2 memory-emergency-guard-check[3063442]: MEMORY EMERGENCY io drained (io PSI some avg60=39.05% < 40%) — churn units re-armed (re-arm #525)
Oct 27 19:42:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:42:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:46:26 evo-x2 memory-emergency-guard-check[3311051]: MEMORY EMERGENCY: I/O PSI some avg60=42.46% sustained (max disk busy 79.6%, MemAvailable=22.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 19:46:29 evo-x2 memory-emergency-guard-check[3311051]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4480, zone 6) — top io since last trip: system.slice/io.stat +39136MB, user.slice/io.stat +37757MB, user.slice/user-1000.slice/io.stat +37367MB
Oct 27 19:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.058s CPU time over 3.787s wall clock time, 13.7M memory peak, 13.5M read from disk, 48.3M written to disk.
Oct 27 19:48:50 evo-x2 gatus[24757]: 2026/10/27 19:48:50 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 27 19:48:50 evo-x2 gatus[24757]: 2026/10/27 19:48:50 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 27 19:49:21 evo-x2 memory-emergency-guard-check[3338679]: MEMORY EMERGENCY io drained (io PSI some avg60=38.59% < 40%) — churn units re-armed (re-arm #526)
Oct 27 19:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:49:23 evo-x2 memory-emergency-guard-check[3524672]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.74% sustained (max disk busy 70.0%, MemAvailable=13.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (175s < 600s, 425s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 19:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 23.482s wall clock time, 5.9M memory peak, 1.6M read from disk, 4K written to disk.
Oct 27 19:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 191ms CPU time over 1.968s wall clock time, 5.7M memory peak, 1.8M read from disk, 4K written to disk.
Oct 27 19:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 194ms CPU time over 1.876s wall clock time, 8.6M memory peak, 5M read from disk, 4K written to disk.
Oct 27 19:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:57:53 evo-x2 memory-emergency-guard-check[3961405]: MEMORY EMERGENCY: I/O PSI some avg60=40.85% sustained (max disk busy 97.2%, MemAvailable=50.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 19:57:57 evo-x2 memory-emergency-guard-check[3961405]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4481, zone 6) — top io since last trip: user.slice/io.stat +144858MB, user.slice/user-1000.slice/io.stat +144010MB, system.slice/io.stat +84922MB
Oct 27 19:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 982ms CPU time over 5.566s wall clock time, 7.1M memory peak, 9.2M read from disk, 58.3M written to disk.
Oct 27 19:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:59:23 evo-x2 memory-emergency-guard-check[4042298]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.77% sustained (max disk busy 44.6%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 19:59:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 19:59:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:02:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:06:13 evo-x2 memory-emergency-guard-check[158743]: MEMORY EMERGENCY io drained (io PSI some avg60=39.72% < 40%) — churn units re-armed (re-arm #527)
Oct 27 20:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:09:24 evo-x2 memory-emergency-guard-check[340416]: MEMORY EMERGENCY: I/O PSI some avg60=42.14% sustained (max disk busy 70.7%, MemAvailable=38.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 20:09:30 evo-x2 memory-emergency-guard-check[340416]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4482, zone 6) — top io since last trip: system.slice/io.stat +38498MB, user.slice/io.stat +12003MB, user.slice/user-1000.slice/io.stat +11994MB
Oct 27 20:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.126s CPU time over 5.945s wall clock time, 8.8M memory peak, 7.7M read from disk, 59.2M written to disk.
Oct 27 20:10:23 evo-x2 memory-emergency-guard-check[373833]: MEMORY EMERGENCY io drained (io PSI some avg60=36.56% < 40%) — churn units re-armed (re-arm #528)
Oct 27 20:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:11:24 evo-x2 memory-emergency-guard-check[477184]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.32% sustained (max disk busy 99.9%, MemAvailable=31.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 600s, 480s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 20:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:17:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:17:29 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 27 20:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:20:05 evo-x2 gatus[24757]: 2026/10/27 20:20:05 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 27 20:20:25 evo-x2 memory-emergency-guard-check[1040560]: MEMORY EMERGENCY: I/O PSI some avg60=41.07% sustained (max disk busy 81.5%, MemAvailable=52.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 20:20:32 evo-x2 memory-emergency-guard-check[1040560]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4483, zone 6) — top io since last trip: system.slice/io.stat +23478MB, system.slice/nix-daemon.service/io.stat +14927MB, user.slice/io.stat +14750MB
Oct 27 20:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.041s CPU time over 7.443s wall clock time, 7.7M memory peak, 13.2M read from disk, 46.7M written to disk.
Oct 27 20:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:21:25 evo-x2 memory-emergency-guard-check[1118098]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.38% sustained (max disk busy 99.9%, MemAvailable=51.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 20:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:25:33 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 20:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:30:27 evo-x2 memory-emergency-guard-check[1724369]: MEMORY EMERGENCY: I/O PSI some avg60=43.89% sustained (max disk busy 95.1%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 20:30:29 evo-x2 memory-emergency-guard-check[1724369]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4484, zone 6) — top io since last trip: system.slice/io.stat +50022MB, user.slice/io.stat +13946MB, user.slice/user-1000.slice/io.stat +13841MB
Oct 27 20:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 928ms CPU time over 3.073s wall clock time, 7.7M memory peak, 784K read from disk, 24.3M written to disk.
Oct 27 20:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:31:27 evo-x2 memory-emergency-guard-check[1783770]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.80% sustained (max disk busy 99.7%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 20:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:32:33 evo-x2 memory-emergency-guard-check[1843004]: MEMORY EMERGENCY io drained (io PSI some avg60=39.16% < 40%) — churn units re-armed (re-arm #529)
Oct 27 20:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:35:49 evo-x2 gatus[1483659]: 2026/10/27 20:35:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:35:49 evo-x2 gatus[1483659]: 2026/10/27 20:35:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:40:30 evo-x2 memory-emergency-guard-check[2249959]: MEMORY EMERGENCY: I/O PSI some avg60=52.44% sustained (max disk busy 97.1%, MemAvailable=38.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 20:40:41 evo-x2 memory-emergency-guard-check[2249959]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4485, zone 6) — top io since last trip: system.slice/io.stat +22709MB, user.slice/io.stat +17073MB, user.slice/user-1000.slice/io.stat +17002MB
Oct 27 20:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.189s CPU time over 11.287s wall clock time, 9.3M memory peak, 18.3M read from disk, 94.8M written to disk.
Oct 27 20:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:41:31 evo-x2 memory-emergency-guard-check[2328248]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.85% sustained (max disk busy 100.0%, MemAvailable=32.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 600s, 539s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 20:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:45:49 evo-x2 gatus[1483659]: 2026/10/27 20:45:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:45:49 evo-x2 gatus[1483659]: 2026/10/27 20:45:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:50:32 evo-x2 memory-emergency-guard-check[2704435]: MEMORY EMERGENCY: I/O PSI some avg60=70.10% sustained (max disk busy 100.0%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 20:50:36 evo-x2 memory-emergency-guard-check[2704435]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4486, zone 6) — top io since last trip: system.slice/io.stat +56371MB, user.slice/io.stat +35318MB, user.slice/user-1000.slice/io.stat +34856MB
Oct 27 20:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.043s CPU time over 3.826s wall clock time, 7.5M memory peak, 8.9M read from disk, 10.4M written to disk.
Oct 27 20:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:51:33 evo-x2 memory-emergency-guard-check[2734248]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.99% sustained (max disk busy 100.0%, MemAvailable=30.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 20:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:55:49 evo-x2 gatus[1483659]: 2026/10/27 20:55:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:55:49 evo-x2 gatus[1483659]: 2026/10/27 20:55:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 20:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 20:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:00:33 evo-x2 memory-emergency-guard-check[3040663]: MEMORY EMERGENCY: I/O PSI some avg60=67.73% sustained (max disk busy 100.0%, MemAvailable=33.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:00:36 evo-x2 memory-emergency-guard-check[3040663]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4487, zone 6) — top io since last trip: system.slice/io.stat +66142MB, user.slice/io.stat +30140MB, user.slice/user-1000.slice/io.stat +29730MB
Oct 27 21:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 946ms CPU time over 3.048s wall clock time, 7.8M memory peak, 4.5M read from disk, 10.5M written to disk.
Oct 27 21:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:01:33 evo-x2 memory-emergency-guard-check[3076083]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.02% sustained (max disk busy 99.9%, MemAvailable=33.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:10:34 evo-x2 memory-emergency-guard-check[3429916]: MEMORY EMERGENCY: I/O PSI some avg60=92.37% sustained (max disk busy 100.0%, MemAvailable=32.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:10:41 evo-x2 memory-emergency-guard-check[3429916]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4488, zone 6) — top io since last trip: system.slice/io.stat +66879MB, user.slice/io.stat +29827MB, user.slice/user-1000.slice/io.stat +28780MB
Oct 27 21:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.271s CPU time over 6.858s wall clock time, 7M memory peak, 9.7M read from disk, 53.3M written to disk.
Oct 27 21:11:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:11:34 evo-x2 memory-emergency-guard-check[3478935]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.33% sustained (max disk busy 99.8%, MemAvailable=35.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:19:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:20:37 evo-x2 memory-emergency-guard-check[3772388]: MEMORY EMERGENCY: I/O PSI some avg60=86.38% sustained (max disk busy 99.8%, MemAvailable=31.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:21:03 evo-x2 memory-emergency-guard-check[3772388]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4489, zone 6) — top io since last trip: system.slice/io.stat +51159MB, user.slice/io.stat +26828MB, user.slice/user-1000.slice/io.stat +25673MB
Oct 27 21:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.270s CPU time over 27.136s wall clock time, 7.6M memory peak, 17.1M read from disk, 3.6M written to disk.
Oct 27 21:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:21:37 evo-x2 memory-emergency-guard-check[3808817]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.58% sustained (max disk busy 100.0%, MemAvailable=28.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:29:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:30:21 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 21:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:31:02 evo-x2 memory-emergency-guard-check[4131176]: MEMORY EMERGENCY: I/O PSI some avg60=83.09% sustained (max disk busy 99.8%, MemAvailable=35.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:31:10 evo-x2 memory-emergency-guard-check[4131176]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4490, zone 6) — top io since last trip: system.slice/io.stat +124233MB, user.slice/io.stat +50701MB, user.slice/user-1000.slice/io.stat +49701MB
Oct 27 21:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.326s CPU time over 8.818s wall clock time, 6.3M memory peak, 7.7M read from disk, 24.1M written to disk.
Oct 27 21:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:32:02 evo-x2 memory-emergency-guard-check[4178504]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.20% sustained (max disk busy 100.0%, MemAvailable=34.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:32:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:37:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:41:24 evo-x2 memory-emergency-guard-check[250118]: MEMORY EMERGENCY: I/O PSI some avg60=90.84% sustained (max disk busy 99.3%, MemAvailable=34.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:41:50 evo-x2 memory-emergency-guard-check[250118]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4491, zone 6) — top io since last trip: system.slice/io.stat +106977MB, user.slice/io.stat +35568MB, user.slice/user-1000.slice/io.stat +34577MB
Oct 27 21:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.026s CPU time over 27.298s wall clock time, 9.1M memory peak, 1.8M read from disk, 10.6M written to disk.
Oct 27 21:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:41:55 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; MEMORY GUARD DEAD; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (-1s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 21:42:24 evo-x2 memory-emergency-guard-check[288571]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.96% sustained (max disk busy 99.0%, MemAvailable=34.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:46:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:47:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:50:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:51:31 evo-x2 memory-emergency-guard-check[570281]: MEMORY EMERGENCY: I/O PSI some avg60=67.80% sustained (max disk busy 100.0%, MemAvailable=29.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 21:52:24 evo-x2 memory-emergency-guard-check[570281]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4492, zone 6) — top io since last trip: system.slice/io.stat +41617MB, user.slice/io.stat +24315MB, user.slice/user-1000.slice/io.stat +23673MB
Oct 27 21:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.215s CPU time over 59.687s wall clock time, 6.4M memory peak, 1.8M read from disk, 112.7M written to disk.
Oct 27 21:52:25 evo-x2 memory-emergency-guard-check[604098]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.42% sustained (max disk busy 93.7%, MemAvailable=26.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 21:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:56:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:57:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 21:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:00:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:01:41 evo-x2 memory-emergency-guard-check[960858]: MEMORY EMERGENCY: I/O PSI some avg60=65.43% sustained (max disk busy 99.3%, MemAvailable=32.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:01:44 evo-x2 memory-emergency-guard-check[960858]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4493, zone 6) — top io since last trip: system.slice/io.stat +51055MB, user.slice/io.stat +18378MB, user.slice/user-1000.slice/io.stat +17989MB
Oct 27 22:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 914ms CPU time over 3.684s wall clock time, 7.2M memory peak, 2.3M read from disk, 11.8M written to disk.
Oct 27 22:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:02:42 evo-x2 memory-emergency-guard-check[1010569]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.06% sustained (max disk busy 99.2%, MemAvailable=32.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:07:27 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 27 22:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 220ms CPU time over 1.507s wall clock time, 5.1M memory peak, 2.1M read from disk, 4K written to disk.
Oct 27 22:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 208ms CPU time over 2.135s wall clock time, 5.6M memory peak, 1.2M read from disk, 4K written to disk.
Oct 27 22:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:09:33 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=18.83%, MemAvailable=21.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 27 22:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 216ms CPU time over 2.248s wall clock time, 5M memory peak, 1.5M read from disk, 4K written to disk.
Oct 27 22:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:12:52 evo-x2 memory-emergency-guard-check[1312505]: MEMORY EMERGENCY: I/O PSI some avg60=75.21% sustained (max disk busy 100.0%, MemAvailable=14.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:13:22 evo-x2 memory-emergency-guard-check[1340858]: sort: write failed: 'standard output': Broken pipe
Oct 27 22:13:22 evo-x2 memory-emergency-guard-check[1340858]: sort: write error
Oct 27 22:13:22 evo-x2 memory-emergency-guard-check[1312505]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4494, zone 6) — top io since last trip: system.slice/io.stat +122728MB, user.slice/io.stat +37730MB, user.slice/user-1000.slice/io.stat +36227MB
Oct 27 22:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.363s CPU time over 30.973s wall clock time, 7.6M memory peak, 3.2M read from disk, 131M written to disk.
Oct 27 22:13:22 evo-x2 memory-emergency-guard-check[1342792]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.94% sustained (max disk busy 97.1%, MemAvailable=34.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:15:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:23:19 evo-x2 memory-emergency-guard-check[1784644]: MEMORY EMERGENCY: I/O PSI some avg60=90.32% sustained (max disk busy 97.9%, MemAvailable=29.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:24:02 evo-x2 memory-emergency-guard-check[1784644]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4495, zone 6) — top io since last trip: system.slice/io.stat +67791MB, user.slice/io.stat +26241MB, user.slice/user-1000.slice/io.stat +25155MB
Oct 27 22:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.058s CPU time over 44.465s wall clock time, 7.1M memory peak, 3M read from disk, 10.2M written to disk.
Oct 27 22:24:02 evo-x2 memory-emergency-guard-check[1822524]: MEMORY EMERGENCY still active (I/O PSI some avg60=91.38% sustained (max disk busy 100.0%, MemAvailable=32.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (44s < 600s, 556s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 257ms CPU time over 585ms wall clock time, 8.1M memory peak, 3.7M read from disk, 4K written to disk.
Oct 27 22:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:27:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:27:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 212ms CPU time over 448ms wall clock time, 6.9M memory peak, 1.3M read from disk, 4K written to disk.
Oct 27 22:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 211ms CPU time over 510ms wall clock time, 6.6M memory peak, 1.3M read from disk, 4K written to disk.
Oct 27 22:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 223ms CPU time over 484ms wall clock time, 6.5M memory peak, 3M read from disk, 4K written to disk.
Oct 27 22:29:49 evo-x2 gatus[1483659]: 2026/10/27 22:29:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 22:29:49 evo-x2 gatus[1483659]: 2026/10/27 22:29:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 22:30:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:33:37 evo-x2 memory-emergency-guard-check[2259329]: MEMORY EMERGENCY: I/O PSI some avg60=84.96% sustained (max disk busy 99.7%, MemAvailable=35.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:33:42 evo-x2 memory-emergency-guard-check[2259329]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4496, zone 6) — top io since last trip: system.slice/io.stat +44710MB, user.slice/io.stat +20488MB, user.slice/user-1000.slice/io.stat +19391MB
Oct 27 22:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.139s CPU time over 5.373s wall clock time, 7.2M memory peak, 6.5M read from disk, 24M written to disk.
Oct 27 22:34:08 evo-x2 memory-emergency-guard-check[2281585]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.88% sustained (max disk busy 100.0%, MemAvailable=35.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 213ms CPU time over 435ms wall clock time, 8.5M memory peak, 3.1M read from disk, 4K written to disk.
Oct 27 22:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:37:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:43:39 evo-x2 memory-emergency-guard-check[2684006]: MEMORY EMERGENCY: I/O PSI some avg60=91.00% sustained (max disk busy 100.0%, MemAvailable=38.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:43:45 evo-x2 memory-emergency-guard-check[2684006]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4497, zone 6) — top io since last trip: system.slice/io.stat +41380MB, user.slice/io.stat +15717MB, user.slice/user-1000.slice/io.stat +14510MB
Oct 27 22:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.079s CPU time over 5.905s wall clock time, 7.3M memory peak, 31.4M read from disk, 11.4M written to disk.
Oct 27 22:44:09 evo-x2 memory-emergency-guard-check[2708815]: MEMORY EMERGENCY still active (I/O PSI some avg60=88.97% sustained (max disk busy 100.0%, MemAvailable=37.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:53:41 evo-x2 memory-emergency-guard-check[3077781]: MEMORY EMERGENCY: I/O PSI some avg60=93.65% sustained (max disk busy 100.0%, MemAvailable=36.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 22:53:46 evo-x2 memory-emergency-guard-check[3077781]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4498, zone 6) — top io since last trip: system.slice/io.stat +40151MB, user.slice/io.stat +13471MB, user.slice/user-1000.slice/io.stat +13245MB
Oct 27 22:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.152s CPU time over 5.370s wall clock time, 8.3M memory peak, 5.5M read from disk, 18.6M written to disk.
Oct 27 22:54:11 evo-x2 memory-emergency-guard-check[3111531]: MEMORY EMERGENCY still active (I/O PSI some avg60=93.91% sustained (max disk busy 100.0%, MemAvailable=36.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 22:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 22:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:00:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:01:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 187ms CPU time over 364ms wall clock time, 7.7M memory peak, 3.7M read from disk, 4K written to disk.
Oct 27 23:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:03:45 evo-x2 memory-emergency-guard-check[3507970]: MEMORY EMERGENCY: I/O PSI some avg60=89.67% sustained (max disk busy 100.0%, MemAvailable=31.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 23:03:52 evo-x2 memory-emergency-guard-check[3507970]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4499, zone 6) — top io since last trip: system.slice/io.stat +55664MB, system.slice/nix-daemon.service/io.stat +15314MB, user.slice/io.stat +12923MB
Oct 27 23:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.544s CPU time over 7.430s wall clock time, 7.5M memory peak, 31.2M read from disk, 119M written to disk.
Oct 27 23:04:15 evo-x2 memory-emergency-guard-check[3538954]: MEMORY EMERGENCY still active (I/O PSI some avg60=92.26% sustained (max disk busy 100.0%, MemAvailable=34.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 23:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:09:49 evo-x2 gatus[1483659]: 2026/10/27 23:09:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 23:09:49 evo-x2 gatus[1483659]: 2026/10/27 23:09:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 27 23:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:13:45 evo-x2 memory-emergency-guard-check[3966519]: MEMORY EMERGENCY: I/O PSI some avg60=96.84% sustained (max disk busy 100.0%, MemAvailable=37.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 23:13:50 evo-x2 memory-emergency-guard-check[3966519]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4500, zone 6) — top io since last trip: system.slice/io.stat +49125MB, user.slice/io.stat +17336MB, user.slice/user-1000.slice/io.stat +16364MB
Oct 27 23:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.194s CPU time over 4.698s wall clock time, 8M memory peak, 25.5M read from disk, 27.7M written to disk.
Oct 27 23:14:15 evo-x2 memory-emergency-guard-check[3988243]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.86% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 23:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:18:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:18:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:22:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:23:45 evo-x2 memory-emergency-guard-check[109170]: MEMORY EMERGENCY: I/O PSI some avg60=92.91% sustained (max disk busy 100.0%, MemAvailable=37.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 23:23:47 evo-x2 memory-emergency-guard-check[109170]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4501, zone 6) — top io since last trip: system.slice/io.stat +47872MB, user.slice/io.stat +11287MB, user.slice/user-1000.slice/io.stat +10547MB
Oct 27 23:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 2.029s wall clock time, 10.1M memory peak, 29M read from disk, 55.9M written to disk.
Oct 27 23:24:16 evo-x2 memory-emergency-guard-check[123124]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.10% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 23:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 203ms CPU time over 353ms wall clock time, 7.1M memory peak, 2.3M read from disk, 4K written to disk.
Oct 27 23:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:33:48 evo-x2 memory-emergency-guard-check[532688]: MEMORY EMERGENCY: I/O PSI some avg60=74.10% sustained (max disk busy 100.0%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 23:33:52 evo-x2 memory-emergency-guard-check[532688]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4502, zone 6) — top io since last trip: system.slice/io.stat +42637MB, user.slice/io.stat +10703MB, user.slice/user-1000.slice/io.stat +10642MB
Oct 27 23:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.113s CPU time over 4.888s wall clock time, 8.2M memory peak, 24.4M read from disk, 49.8M written to disk.
Oct 27 23:34:18 evo-x2 memory-emergency-guard-check[562428]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.59% sustained (max disk busy 100.0%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 23:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:42:02 evo-x2 memory-emergency-guard-check[923726]: MEMORY EMERGENCY io drained (io PSI some avg60=38.92% < 40%) — churn units re-armed (re-arm #530)
Oct 27 23:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:44:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 319ms wall clock time, 8.6M memory peak, 3.8M read from disk, 4K written to disk.
Oct 27 23:45:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:46:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:48:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 202ms CPU time over 483ms wall clock time, 6.1M memory peak, 1.5M read from disk, 4K written to disk.
Oct 27 23:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:50:36 evo-x2 memory-emergency-guard-check[1388430]: MEMORY EMERGENCY: I/O PSI some avg60=48.02% sustained (max disk busy 99.8%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 27 23:50:39 evo-x2 memory-emergency-guard-check[1388430]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4503, zone 6) — top io since last trip: system.slice/io.stat +50490MB, user.slice/io.stat +22280MB, user.slice/user-1000.slice/io.stat +21464MB
Oct 27 23:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.098s CPU time over 3.062s wall clock time, 7.9M memory peak, 4.5M read from disk, 21.2M written to disk.
Oct 27 23:51:06 evo-x2 memory-emergency-guard-check[1425341]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.24% sustained (max disk busy 99.7%, MemAvailable=32.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 27 23:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:52:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:55:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:56:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:57:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:57:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:58:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:58:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:59:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 27 23:59:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:00:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:00:23 evo-x2 systemd[2022]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 28 00:00:46 evo-x2 memory-emergency-guard-check[1753016]: MEMORY EMERGENCY: I/O PSI some avg60=40.63% sustained (max disk busy 99.8%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:00:48 evo-x2 memory-emergency-guard-check[1753016]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4504, zone 6) — top io since last trip: system.slice/io.stat +48188MB, system.slice/nix-daemon.service/io.stat +14596MB, user.slice/io.stat +9359MB
Oct 28 00:00:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:00:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 959ms CPU time over 2.369s wall clock time, 8.3M memory peak, 15.4M read from disk, 38.9M written to disk.
Oct 28 00:01:16 evo-x2 memory-emergency-guard-check[1774520]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.70% sustained (max disk busy 100.0%, MemAvailable=34.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:01:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:01:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:02:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:03:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:03:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:05:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:09:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:09:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:13:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:15:19 evo-x2 memory-emergency-guard-check[2482254]: MEMORY EMERGENCY: I/O PSI some avg60=40.38% sustained (max disk busy 100.0%, MemAvailable=35.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:15:26 evo-x2 memory-emergency-guard-check[2482254]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4505, zone 6) — top io since last trip: system.slice/io.stat +41567MB, system.slice/nix-daemon.service/io.stat +9092MB, user.slice/io.stat +8283MB
Oct 28 00:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.132s CPU time over 7.072s wall clock time, 8.8M memory peak, 7.2M read from disk, 45.8M written to disk.
Oct 28 00:15:50 evo-x2 memory-emergency-guard-check[2514483]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.20% sustained (max disk busy 100.0%, MemAvailable=35.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:20:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:25:22 evo-x2 memory-emergency-guard-check[3014447]: MEMORY EMERGENCY: I/O PSI some avg60=53.60% sustained (max disk busy 100.0%, MemAvailable=34.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:25:25 evo-x2 memory-emergency-guard-check[3014447]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4506, zone 6) — top io since last trip: system.slice/io.stat +76155MB, system.slice/monitor365-server.service/io.stat +18798MB, user.slice/io.stat +12168MB
Oct 28 00:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.154s CPU time over 3.526s wall clock time, 8.5M memory peak, 21.2M read from disk, 7.2M written to disk.
Oct 28 00:25:52 evo-x2 memory-emergency-guard-check[3045908]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.54% sustained (max disk busy 100.0%, MemAvailable=31.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:29:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 194ms CPU time over 329ms wall clock time, 5M memory peak, 1.2M read from disk, 4K written to disk.
Oct 28 00:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:35:35 evo-x2 memory-emergency-guard-check[3394373]: MEMORY EMERGENCY: I/O PSI some avg60=66.86% sustained (max disk busy 100.0%, MemAvailable=21.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:35:35 evo-x2 memory-emergency-guard-check[3394373]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4507, zone 6) — top io since last trip: system.slice/io.stat +80631MB, system.slice/tq-agent-pool.service/io.stat +27123MB, user.slice/io.stat +16687MB
Oct 28 00:36:20 evo-x2 memory-emergency-guard-check[3418763]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.42% sustained (max disk busy 100.0%, MemAvailable=19.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.588s CPU time over 4.593s wall clock time, 7.3M memory peak, 24M read from disk, 83M written to disk.
```

## THERMAL THROTTLE lines
```
Oct 27 10:22:52 evo-x2 thermal-pstate-guard-check[267309]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 27 11:24:46 evo-x2 thermal-pstate-guard-check[1538983]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=50C(hi:95/lo:80)
Oct 27 11:36:21 evo-x2 thermal-pstate-guard-check[1775374]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 27 13:24:49 evo-x2 thermal-pstate-guard-check[16601]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=54C(hi:95/lo:80)
Oct 27 13:43:29 evo-x2 thermal-pstate-guard-check[249231]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 27 13:51:03 evo-x2 thermal-pstate-guard-check[339353]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=79C(hi:95/lo:80)
Oct 27 14:00:47 evo-x2 thermal-pstate-guard-check[518204]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 27 16:43:31 evo-x2 thermal-pstate-guard-check[577310]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)
Oct 27 16:56:06 evo-x2 thermal-pstate-guard-check[829178]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 27 10:04:43 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/83klzcdbh1q19dxc87xn45gjrw6z08g4-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 27 10:04:43 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/83klzcdbh1q19dxc87xn45gjrw6z08g4-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 27 10:04:43 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 27 10:04:45 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
