# Boot evidence pull: id8 705a6fcd (full: 705a6fcde1e24af9845a9ce83acb0233)

Pulled 2026-11-02 17:41 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-02 14:43:39 -> 2026-11-02 15:16:15 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 705a6fcd — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 02 14:43:39 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 02 14:43:39 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/x17510yjs95xnas3z9bkpysgk2vra3w9-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 02 14:43:39 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 02 15:16:13 evo-x2 systemd[1]: Starting System health metrics collector for node_exporter textfile...
Nov 02 15:16:13 evo-x2 server[1659]: INFO request method=GET path=/api/health status=200 duration=1.166624ms client_ip=::1 request_id=6ae89b2d0000030d0a01a3b83386eef7
Nov 02 15:16:13 evo-x2 dnsblockd[4165]: time=2026-11-02T15:16:13.496+01:00 level=ERROR msg="dispatch error" command=TRACK_METRICS error="dispatching command (type=TRACK_METRICS): incrementing request metric (bucketTime=2026-11-02 15:16:00 +0100 CET, httpMethod=GET): context deadline exceeded"
Nov 02 15:16:13 evo-x2 dnsblockd[4165]: time=2026-11-02T15:16:13.593+01:00 level=ERROR msg="dispatch error" command=TRACK_METRICS error="dispatching command (type=TRACK_METRICS): incrementing request metric (bucketTime=2026-11-02 15:16:00 +0100 CET, httpMethod=GET): context deadline exceeded"
Nov 02 15:16:13 evo-x2 node_exporter[2021]: time=2026-11-02T15:16:13.672+01:00 level=ERROR source=textfile.go:242 msg="failed to collect textfile data" collector=textfile file=crush_events.prom err="failed to open textfile data file \"/var/lib/prometheus-node-exporter/textfile_collectors/crush_events.prom\": open /var/lib/prometheus-node-exporter/textfile_collectors/crush_events.prom: permission denied"
Nov 02 15:16:14 evo-x2 dms[22919]:   WARN qml: [WeatherService:690] Weather fetch failed: HTTP 503
Nov 02 15:16:14 evo-x2 (sd-pam)[1315789]: pam_unix(login:session): session closed for user lars
Nov 02 15:16:14 evo-x2 (sd-pam)[1315905]: pam_unix(login:session): session closed for user lars
Nov 02 15:16:14 evo-x2 nsfw-server[1323]: 2026/11/02 15:16:14 INFO  request method=GET path=/health status=200 duration=152.95µs client_ip=127.0.0.1
Nov 02 15:16:14 evo-x2 file-renamer[7283]: 2026-11-02T15:16:14+01:00 INFO  watcher: request method=GET path=/health status=200 duration=120.921µs client_ip=127.0.0.1 request_id=6ae89b2e00000331aa57c8f3f3e32d42
Nov 02 15:16:14 evo-x2 file-renamer[2004]: 2026-11-02T15:16:14+01:00 INFO  watcher: request method=GET path=/health status=200 duration=124.461µs client_ip=127.0.0.1 request_id=6ae89b2e000002f76b8c9c17589bbdac
Nov 02 15:16:14 evo-x2 (sd-pam)[1315961]: pam_unix(login:session): session closed for user lars
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 84
- thermal-THROTTLE-lines: 1
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
```
```

## memory-emergency-guard lines (all)
```
Nov 02 14:47:35 evo-x2 memory-emergency-guard-check[29543]: MEMORY EMERGENCY IO-PAUSE (trip #6077, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 14:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 1min 57.487s wall clock time, 7.7M memory peak, 12.7M read from disk, 6.8M written to disk.
Nov 02 14:47:35 evo-x2 memory-emergency-guard-check[137170]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.01% sustained (max disk busy 96.8%, MemAvailable=39.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (118s < 150s, 32s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 02 14:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:48:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:48:55 evo-x2 memory-emergency-guard-check[212405]: MEMORY EMERGENCY IO-PAUSE (trip #6078, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 14:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 879ms CPU time over 20.273s wall clock time, 9.9M memory peak, 5.2M read from disk, 6.1M written to disk.
Nov 02 14:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 162ms CPU time over 319ms wall clock time, 9.3M memory peak, 1.6M read from disk, 4K written to disk.
Nov 02 14:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:50:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:52:03 evo-x2 memory-emergency-guard-check[325913]: MEMORY EMERGENCY IO-PAUSE (trip #6079, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 14:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 955ms CPU time over 58.281s wall clock time, 10.8M memory peak, 12.5M read from disk, 15.4M written to disk.
Nov 02 14:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 138ms CPU time over 274ms wall clock time, 10.4M memory peak, 1.1M read from disk, 4K written to disk.
Nov 02 14:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:55:26 evo-x2 memory-emergency-guard-check[543373]: MEMORY EMERGENCY IO-PAUSE (trip #6080, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 14:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.088s CPU time over 1min 22.958s wall clock time, 12M memory peak, 61.2M read from disk, 37.3M written to disk.
Nov 02 14:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:55:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 293ms CPU time over 3.284s wall clock time, 8M memory peak, 2.8M read from disk, 4K written to disk.
Nov 02 14:58:27 evo-x2 memory-emergency-guard-check[673999]: MEMORY EMERGENCY IO-PAUSE (trip #6081, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 14:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 996ms CPU time over 1min 1.270s wall clock time, 11.9M memory peak, 25.3M read from disk, 6.4M written to disk.
Nov 02 14:58:28 evo-x2 memory-emergency-guard-check[725915]: MEMORY EMERGENCY still active (I/O PSI some avg60=91.86% sustained (max disk busy 100.0%, MemAvailable=9.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 02 14:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:58:33 evo-x2 systemd[1608]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 20 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Nov 02 14:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 14:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:01:09 evo-x2 memory-emergency-guard-check[762042]: MEMORY EMERGENCY IO-PAUSE (trip #6082, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.036s CPU time over 1min 12.009s wall clock time, 10.7M memory peak, 24.2M read from disk, 8.1M written to disk.
Nov 02 15:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:03:28 evo-x2 memory-emergency-guard-check[845541]: MEMORY EMERGENCY IO-PAUSE (trip #6083, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 960ms CPU time over 48.780s wall clock time, 12.8M memory peak, 32.8M read from disk, 9.1M written to disk.
Nov 02 15:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 164ms CPU time over 471ms wall clock time, 8.9M memory peak, 1.9M read from disk, 4K written to disk.
Nov 02 15:06:09 evo-x2 memory-emergency-guard-check[948496]: MEMORY EMERGENCY IO-PAUSE (trip #6084, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.227s CPU time over 40.413s wall clock time, 10.6M memory peak, 34.7M read from disk, 10.4M written to disk.
Nov 02 15:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 141ms CPU time over 399ms wall clock time, 8.3M memory peak, 1.6M read from disk, 4K written to disk.
Nov 02 15:06:40 evo-x2 systemd[1608]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 19 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=31.20%, MemAvailable=17.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Nov 02 15:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:08:54 evo-x2 memory-emergency-guard-check[1059129]: MEMORY EMERGENCY IO-PAUSE (trip #6085, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 45.369s wall clock time, 13.1M memory peak, 12.8M read from disk, 4.2M written to disk.
Nov 02 15:08:55 evo-x2 memory-emergency-guard-check[1086937]: MEMORY EMERGENCY still active (I/O PSI some avg60=99.00% sustained (max disk busy 100.0%, MemAvailable=21.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (45s < 150s, 105s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 02 15:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 177ms CPU time over 303ms wall clock time, 9.3M memory peak, 2M read from disk, 4K written to disk.
Nov 02 15:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:11:51 evo-x2 memory-emergency-guard-check[1136247]: MEMORY EMERGENCY IO-PAUSE (trip #6086, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 864ms CPU time over 56.875s wall clock time, 11.8M memory peak, 23.2M read from disk, 15.2M written to disk.
Nov 02 15:11:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:14:23 evo-x2 memory-emergency-guard-check[1235188]: MEMORY EMERGENCY IO-PAUSE (trip #6087, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 02 15:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 31.506s wall clock time, 10.4M memory peak, 22.9M read from disk, 14.1M written to disk.
Nov 02 15:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 02 15:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 02 14:46:33 evo-x2 thermal-pstate-guard-check[60555]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 02 14:43:39 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/x17510yjs95xnas3z9bkpysgk2vra3w9-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 02 14:43:39 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/x17510yjs95xnas3z9bkpysgk2vra3w9-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 02 14:43:39 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 02 14:43:41 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793628975000000000 -> 1793629072000000000 epoch-ns UTC (2026-11-02 14:16:15 -> 2026-11-02 14:17:52 UTC)
Pipeline ALIVE in this window — newest row: 1793628978455151467 (2026-11-02 14:16:18 UTC); rows fetched: 20 (last 20 by timestamp DESC). Per M22 pull BOTH sources: ClickHouse is fresher than the journal cut by the flush lag.

Last rows (timestamp<TAB>body, newest first):
```
1793628978455151467	batch writer: flush took longer than flush interval
1793628978321605721	local zone miss, returning NXDOMAIN
1793628978321290611	local zone miss, returning NXDOMAIN
1793628978319106215	local zone miss, returning NXDOMAIN
1793628978316258557	local zone miss, returning NXDOMAIN
1793628978310099970	local zone miss, returning NXDOMAIN
1793628978309527648	local zone miss, returning NXDOMAIN
1793628978309264328	local zone miss, returning NXDOMAIN
1793628978303513892	local zone miss, returning NXDOMAIN
1793628978299636421	local zone miss, returning NXDOMAIN
1793628978287840169	local zone miss, returning NXDOMAIN
1793628978254774518	local zone miss, returning NXDOMAIN
1793628978223374843	local zone miss, returning NXDOMAIN
1793628978212402983	local zone miss, returning NXDOMAIN
1793628978197388451	local zone miss, returning NXDOMAIN
1793628978196857210	local zone miss, returning NXDOMAIN
1793628978195915147	dispatch error
1793628978192965749	local zone miss, returning NXDOMAIN
1793628978192931229	local zone miss, returning NXDOMAIN
1793628978190590593	local zone miss, returning NXDOMAIN
```
