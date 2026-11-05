# Boot evidence pull: id8 91b4a3a2 (full: 91b4a3a2c801491d9a434b1285f09aaf)

Pulled 2026-11-05 02:52 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-04 19:06:04 -> 2026-11-05 03:03:12 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 91b4a3a2 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 04 19:06:04 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 04 19:06:04 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/ly95anmg9hw2hi052kjfvcg1dxy5fqfi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 04 19:06:04 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 05 03:03:08 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:08.316+01:00 level=INFO msg=request method=PATCH path=/rest/opportunities/01M35EE7446EMB8GGH8G0004VH status=200 duration=58µs
Nov 05 03:03:08 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:08.317+01:00 level=INFO msg=request method=PATCH path=/rest/opportunities/01M40ZMA4FWXRJC9206G0005VM status=200 duration=36µs
Nov 05 03:03:08 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:08.317+01:00 level=INFO msg=request method=PATCH path=/rest/opportunities/01M40ZMBEZ8Z7097BYS00005Z4 status=200 duration=28µs
Nov 05 03:03:09 evo-x2 file-renamer[1692035]: 2026-11-05T03:03:09+01:00 INFO  watcher: request method=GET path=/health status=200 duration=143.655µs client_ip=127.0.0.1 request_id=6aebe3dd00003445f3d164ea81d19c5d
Nov 05 03:03:09 evo-x2 file-renamer[1692218]: 2026-11-05T03:03:09+01:00 INFO  watcher: request method=GET path=/health status=200 duration=149.126µs client_ip=127.0.0.1 request_id=6aebe3dd0000373006eac49fc4ca89e5
Nov 05 03:03:11 evo-x2 file-renamer[1692035]: 2026-11-05T03:03:11+01:00 INFO  watcher: request method=GET path=/health status=200 duration=122.276µs client_ip=127.0.0.1 request_id=6aebe3df00003446ff1b7339670a29ad
Nov 05 03:03:11 evo-x2 file-renamer[1692218]: 2026-11-05T03:03:11+01:00 INFO  watcher: request method=GET path=/health status=200 duration=143.885µs client_ip=127.0.0.1 request_id=6aebe3df000037317298e81d798d54f1
Nov 05 03:03:12 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:12.228+01:00 level=ERROR msg="api request failed" err="system: find \"contact-views\": typed reader scan contact-views: context canceled" path=/api/contacts/by-phone
Nov 05 03:03:12 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:12.228+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=500 duration=3.000163s
Nov 05 03:03:12 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:12.229+01:00 level=ERROR msg="api request failed" err="system: find \"contact-views\": typed reader scan contact-views: context canceled" path=/api/contacts/by-phone
Nov 05 03:03:12 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:12.229+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=500 duration=3.000223s
Nov 05 03:03:12 evo-x2 crm-server[2823184]: time=2026-11-05T03:03:12.882+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=651.364ms
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 1259
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
Nov 04 19:11:47 evo-x2 memory-emergency-guard-check[29256]: MEMORY EMERGENCY IO-PAUSE (trip #6729, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 979ms CPU time over 3min 44.875s wall clock time, 12.5M memory peak, 3.3M read from disk, 49.8M written to disk.
Nov 04 19:11:53 evo-x2 memory-emergency-guard-check[114687]: MEMORY EMERGENCY IO-PAUSE (trip #6730, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 573ms CPU time over 5.818s wall clock time, 13.5M memory peak, 16K read from disk, 21.5M written to disk.
Nov 04 19:12:17 evo-x2 memory-emergency-guard-check[136374]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.26% sustained (max disk busy 100.0%, MemAvailable=47.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 19:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:14:29 evo-x2 memory-emergency-guard-check[188954]: MEMORY EMERGENCY IO-PAUSE (trip #6731, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 12.108s wall clock time, 14.1M memory peak, 336K read from disk, 28.1M written to disk.
Nov 04 19:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:17:19 evo-x2 memory-emergency-guard-check[335087]: MEMORY EMERGENCY IO-PAUSE (trip #6732, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 32.352s wall clock time, 11.6M memory peak, 7M read from disk, 43.9M written to disk.
Nov 04 19:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:19:35 evo-x2 memory-emergency-guard-check[509905]: MEMORY EMERGENCY IO-PAUSE (trip #6733, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.032s CPU time over 15.925s wall clock time, 10.9M memory peak, 7M read from disk, 25.4M written to disk.
Nov 04 19:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:22:16 evo-x2 memory-emergency-guard-check[708998]: MEMORY EMERGENCY IO-PAUSE (trip #6734, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 987ms CPU time over 26.667s wall clock time, 11.9M memory peak, 12.3M read from disk, 23.2M written to disk.
Nov 04 19:22:20 evo-x2 memory-emergency-guard-check[738486]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.66% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 19:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:23:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:24:44 evo-x2 memory-emergency-guard-check[886668]: MEMORY EMERGENCY IO-PAUSE (trip #6735, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.068s CPU time over 24.967s wall clock time, 12.1M memory peak, 13.7M read from disk, 16.1M written to disk.
Nov 04 19:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:26:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:27:14 evo-x2 memory-emergency-guard-check[1052491]: MEMORY EMERGENCY IO-PAUSE (trip #6736, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 888ms CPU time over 24.687s wall clock time, 10.1M memory peak, 1.6M read from disk, 24.5M written to disk.
Nov 04 19:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:29:38 evo-x2 memory-emergency-guard-check[1212233]: sort: fflush failed: 'standard output': Broken pipe
Nov 04 19:29:38 evo-x2 memory-emergency-guard-check[1212233]: sort: write error
Nov 04 19:29:38 evo-x2 memory-emergency-guard-check[1191807]: MEMORY EMERGENCY IO-PAUSE (trip #6737, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.285s CPU time over 18.568s wall clock time, 8.7M memory peak, 17.9M read from disk, 7.7M written to disk.
Nov 04 19:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:32:24 evo-x2 memory-emergency-guard-check[1360209]: MEMORY EMERGENCY IO-PAUSE (trip #6738, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.186s CPU time over 34.710s wall clock time, 8.7M memory peak, 27.6M read from disk, 16.6M written to disk.
Nov 04 19:32:25 evo-x2 memory-emergency-guard-check[1418595]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.16% sustained (max disk busy 100.0%, MemAvailable=38.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (34s < 150s, 116s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 19:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:36:19 evo-x2 memory-emergency-guard-check[1586946]: MEMORY EMERGENCY IO-PAUSE (trip #6739, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.396s CPU time over 1min 54.332s wall clock time, 9.1M memory peak, 66.1M read from disk, 20.5M written to disk.
Nov 04 19:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:37:31 evo-x2 memory-emergency-guard-check[1761598]: MEMORY EMERGENCY IO-PAUSE (trip #6740, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 796ms CPU time over 10.148s wall clock time, 10.5M memory peak, 3M read from disk, 22.2M written to disk.
Nov 04 19:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:40:01 evo-x2 memory-emergency-guard-check[1903246]: MEMORY EMERGENCY IO-PAUSE (trip #6741, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 902ms CPU time over 10.081s wall clock time, 9.5M memory peak, 2.5M read from disk, 13.4M written to disk.
Nov 04 19:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:43:02 evo-x2 memory-emergency-guard-check[2062595]: MEMORY EMERGENCY IO-PAUSE (trip #6742, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.225s CPU time over 40.555s wall clock time, 9.2M memory peak, 17M read from disk, 21.4M written to disk.
Nov 04 19:43:02 evo-x2 memory-emergency-guard-check[2115712]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.11% sustained (max disk busy 99.2%, MemAvailable=33.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (41s < 150s, 109s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 19:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:45:44 evo-x2 memory-emergency-guard-check[2208927]: MEMORY EMERGENCY IO-PAUSE (trip #6743, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.049s CPU time over 42.404s wall clock time, 10.7M memory peak, 37.8M read from disk, 5.6M written to disk.
Nov 04 19:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:48:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 146ms wall clock time, 10M memory peak, 1.7M read from disk, 4K written to disk.
Nov 04 19:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:50:51 evo-x2 memory-emergency-guard-check[2453289]: MEMORY EMERGENCY IO-PAUSE (trip #6744, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 775ms CPU time over 37.528s wall clock time, 9.8M memory peak, 20.6M read from disk, 9.9M written to disk.
Nov 04 19:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:53:22 evo-x2 memory-emergency-guard-check[2614207]: MEMORY EMERGENCY IO-PAUSE (trip #6745, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 30.696s wall clock time, 12M memory peak, 2.2M read from disk, 1.3M written to disk.
Nov 04 19:53:23 evo-x2 memory-emergency-guard-check[2636410]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.65% sustained (max disk busy 99.1%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 19:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:53:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:58:33 evo-x2 memory-emergency-guard-check[2893951]: MEMORY EMERGENCY IO-PAUSE (trip #6746, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 19:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 861ms CPU time over 1min 10.432s wall clock time, 13.6M memory peak, 22.8M read from disk, 48M written to disk.
Nov 04 19:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:01:05 evo-x2 memory-emergency-guard-check[3018477]: MEMORY EMERGENCY IO-PAUSE (trip #6747, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 844ms CPU time over 1min 2.420s wall clock time, 10.7M memory peak, 19.2M read from disk, 5M written to disk.
Nov 04 20:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:03:38 evo-x2 memory-emergency-guard-check[3158920]: MEMORY EMERGENCY IO-PAUSE (trip #6748, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 986ms CPU time over 2.357s wall clock time, 9.7M memory peak, 4.3M read from disk, 29.1M written to disk.
Nov 04 20:04:06 evo-x2 memory-emergency-guard-check[3211514]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.12% sustained (max disk busy 100.0%, MemAvailable=31.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:06:10 evo-x2 memory-emergency-guard-check[3349491]: MEMORY EMERGENCY IO-PAUSE (trip #6749, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.051s CPU time over 4.065s wall clock time, 11.3M memory peak, 19.6M read from disk, 84.1M written to disk.
Nov 04 20:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:08:40 evo-x2 memory-emergency-guard-check[3531791]: MEMORY EMERGENCY IO-PAUSE (trip #6750, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 938ms CPU time over 4.246s wall clock time, 12.1M memory peak, 9.4M read from disk, 69.4M written to disk.
Nov 04 20:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:11:23 evo-x2 memory-emergency-guard-check[3625119]: MEMORY EMERGENCY IO-PAUSE (trip #6751, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 17.515s wall clock time, 8.7M memory peak, 8.6M read from disk, 37.2M written to disk.
Nov 04 20:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 183ms CPU time over 458ms wall clock time, 6.2M memory peak, 1.5M read from disk, 4K written to disk.
Nov 04 20:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:13:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 123ms CPU time over 176ms wall clock time, 9.1M memory peak, 1.2M read from disk, 4K written to disk.
Nov 04 20:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:17:15 evo-x2 memory-emergency-guard-check[3943028]: MEMORY EMERGENCY IO-PAUSE (trip #6752, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 794ms CPU time over 9.205s wall clock time, 9.4M memory peak, 18.8M read from disk, 17.6M written to disk.
Nov 04 20:17:36 evo-x2 memory-emergency-guard-check[3960947]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.10% sustained (max disk busy 99.9%, MemAvailable=31.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:21:45 evo-x2 memory-emergency-guard-check[4039084]: MEMORY EMERGENCY IO-PAUSE (trip #6753, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.288s CPU time over 2min 9.057s wall clock time, 9.1M memory peak, 28.1M read from disk, 45.3M written to disk.
Nov 04 20:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:22:20 evo-x2 memory-emergency-guard-check[4144046]: MEMORY EMERGENCY IO-PAUSE (trip #6754, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 954ms CPU time over 4.737s wall clock time, 8.5M memory peak, 5.4M read from disk, 23.1M written to disk.
Nov 04 20:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:25:39 evo-x2 memory-emergency-guard-check[138037]: MEMORY EMERGENCY IO-PAUSE (trip #6755, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 53.827s wall clock time, 10.8M memory peak, 19.7M read from disk, 14.5M written to disk.
Nov 04 20:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:27:45 evo-x2 memory-emergency-guard-check[310290]: MEMORY EMERGENCY IO-PAUSE (trip #6756, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:27:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:27:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 6.241s wall clock time, 10.3M memory peak, 8.8M read from disk, 29.9M written to disk.
Nov 04 20:28:09 evo-x2 memory-emergency-guard-check[346259]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.04% sustained (max disk busy 97.2%, MemAvailable=28.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:30:32 evo-x2 memory-emergency-guard-check[427767]: MEMORY EMERGENCY IO-PAUSE (trip #6757, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 806ms CPU time over 23.465s wall clock time, 11.3M memory peak, 14.2M read from disk, 8.5M written to disk.
Nov 04 20:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:32:52 evo-x2 memory-emergency-guard-check[509943]: MEMORY EMERGENCY IO-PAUSE (trip #6758, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 12.645s wall clock time, 10.5M memory peak, 19.6M read from disk, 36M written to disk.
Nov 04 20:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 1.083s wall clock time, 7.5M memory peak, 1.5M read from disk, 4K written to disk.
Nov 04 20:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:37:43 evo-x2 memory-emergency-guard-check[769287]: MEMORY EMERGENCY IO-PAUSE (trip #6759, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.072s CPU time over 34.452s wall clock time, 12M memory peak, 26.8M read from disk, 15.6M written to disk.
Nov 04 20:37:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:38:14 evo-x2 memory-emergency-guard-check[846492]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.64% sustained (max disk busy 98.6%, MemAvailable=43.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (65s < 150s, 85s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 164ms CPU time over 747ms wall clock time, 7.9M memory peak, 2.8M read from disk, 4K written to disk.
Nov 04 20:38:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:39:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:43:49 evo-x2 memory-emergency-guard-check[933413]: MEMORY EMERGENCY IO-PAUSE (trip #6760, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 993ms CPU time over 4min 5.153s wall clock time, 14.2M memory peak, 72K memory swap peak, 26.1M read from disk, 27M written to disk.
Nov 04 20:44:56 evo-x2 memory-emergency-guard-check[1247932]: MEMORY EMERGENCY IO-PAUSE (trip #6761, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 926ms CPU time over 1min 7.394s wall clock time, 14.5M memory peak, 15.8M read from disk, 40.7M written to disk.
Nov 04 20:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:46:57 evo-x2 memory-emergency-guard-check[1381988]: MEMORY EMERGENCY IO-PAUSE (trip #6762, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.109s CPU time over 31.154s wall clock time, 14M memory peak, 27.6M read from disk, 592K written to disk.
Nov 04 20:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:47:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:48:28 evo-x2 memory-emergency-guard-check[1494237]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.21% sustained (max disk busy 100.0%, MemAvailable=41.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:48:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:48:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 132ms CPU time over 488ms wall clock time, 11M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 20:49:41 evo-x2 memory-emergency-guard-check[1508049]: MEMORY EMERGENCY IO-PAUSE (trip #6763, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 812ms CPU time over 43.924s wall clock time, 14M memory peak, 21.6M read from disk, 22.6M written to disk.
Nov 04 20:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:52:06 evo-x2 memory-emergency-guard-check[1625294]: MEMORY EMERGENCY IO-PAUSE (trip #6764, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 778ms CPU time over 24.715s wall clock time, 12.7M memory peak, 14.9M read from disk, 8.7M written to disk.
Nov 04 20:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:52:47 evo-x2 gatus[48475]: 2026/11/04 20:52:47 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Nov 04 20:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:54:20 evo-x2 memory-emergency-guard-check[1758636]: MEMORY EMERGENCY IO-PAUSE (trip #6765, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:54:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:54:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 949ms CPU time over 8.390s wall clock time, 12.8M memory peak, 24.1M read from disk, 67.8M written to disk.
Nov 04 20:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:57:08 evo-x2 memory-emergency-guard-check[1886273]: MEMORY EMERGENCY IO-PAUSE (trip #6766, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 764ms CPU time over 26.307s wall clock time, 11.4M memory peak, 3.8M read from disk, 15M written to disk.
Nov 04 20:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:57:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:58:42 evo-x2 memory-emergency-guard-check[1989073]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.75% sustained (max disk busy 100.0%, MemAvailable=36.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 20:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:59:36 evo-x2 memory-emergency-guard-check[2016847]: MEMORY EMERGENCY IO-PAUSE (trip #6767, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 20:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 20:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.056s CPU time over 24.326s wall clock time, 10.2M memory peak, 22.8M read from disk, 6.1M written to disk.
Nov 04 20:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:00:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:00:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:02:00 evo-x2 memory-emergency-guard-check[2156906]: MEMORY EMERGENCY IO-PAUSE (trip #6768, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.163s CPU time over 18.260s wall clock time, 9.6M memory peak, 25.8M read from disk, 38.8M written to disk.
Nov 04 21:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:02:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:04:19 evo-x2 memory-emergency-guard-check[2288329]: MEMORY EMERGENCY IO-PAUSE (trip #6769, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 808ms CPU time over 7.475s wall clock time, 12M memory peak, 6.6M read from disk, 37M written to disk.
Nov 04 21:04:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:05:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:07:10 evo-x2 memory-emergency-guard-check[2368630]: MEMORY EMERGENCY IO-PAUSE (trip #6770, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 27.302s wall clock time, 18.2M memory peak, 17.5M read from disk, 18.8M written to disk.
Nov 04 21:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:08:43 evo-x2 memory-emergency-guard-check[2426797]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.12% sustained (max disk busy 99.8%, MemAvailable=13.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 21:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:09:17 evo-x2 memory-emergency-guard-check[2441073]: MEMORY EMERGENCY IO-PAUSE (trip #6771, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 774ms CPU time over 4.256s wall clock time, 12.8M memory peak, 18M read from disk, 18.1M written to disk.
Nov 04 21:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:10:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:11:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:11:53 evo-x2 memory-emergency-guard-check[2507807]: MEMORY EMERGENCY IO-PAUSE (trip #6772, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 732ms CPU time over 10.176s wall clock time, 12.8M memory peak, 4.2M read from disk, 26.2M written to disk.
Nov 04 21:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:13:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:13:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:14:16 evo-x2 memory-emergency-guard-check[2567456]: MEMORY EMERGENCY IO-PAUSE (trip #6773, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 648ms CPU time over 2.922s wall clock time, 11.1M memory peak, 14.7M read from disk, 29.4M written to disk.
Nov 04 21:14:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:15:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:15:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:16:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:16:55 evo-x2 memory-emergency-guard-check[2653532]: MEMORY EMERGENCY IO-PAUSE (trip #6774, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 12.225s wall clock time, 12M memory peak, 5.8M read from disk, 11M written to disk.
Nov 04 21:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:18:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:18:43 evo-x2 memory-emergency-guard-check[2690423]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.44% sustained (max disk busy 100.0%, MemAvailable=31.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 21:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:19:26 evo-x2 memory-emergency-guard-check[2700635]: MEMORY EMERGENCY IO-PAUSE (trip #6775, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 583ms CPU time over 13.689s wall clock time, 12.5M memory peak, 21.8M read from disk, 3.1M written to disk.
Nov 04 21:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:22:04 evo-x2 memory-emergency-guard-check[2738772]: MEMORY EMERGENCY IO-PAUSE (trip #6776, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 548ms CPU time over 20.914s wall clock time, 11.6M memory peak, 9.7M read from disk, 27.5M written to disk.
Nov 04 21:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:24:22 evo-x2 memory-emergency-guard-check[2791881]: MEMORY EMERGENCY IO-PAUSE (trip #6777, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 519ms CPU time over 9.170s wall clock time, 11.6M memory peak, 5.4M read from disk, 4.9M written to disk.
Nov 04 21:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:26:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:26:56 evo-x2 memory-emergency-guard-check[2825840]: MEMORY EMERGENCY IO-PAUSE (trip #6778, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 615ms CPU time over 12.826s wall clock time, 11.7M memory peak, 2.1M read from disk, 43.5M written to disk.
Nov 04 21:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:28:43 evo-x2 memory-emergency-guard-check[2854133]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.54% sustained (max disk busy 100.0%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 21:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:29:22 evo-x2 memory-emergency-guard-check[2861155]: MEMORY EMERGENCY IO-PAUSE (trip #6779, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 996ms CPU time over 9.244s wall clock time, 11.3M memory peak, 6.3M read from disk, 20.1M written to disk.
Nov 04 21:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:32:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:32:46 evo-x2 memory-emergency-guard-check[2903981]: MEMORY EMERGENCY IO-PAUSE (trip #6780, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 3.231s wall clock time, 10.5M memory peak, 3.2M read from disk, 25.8M written to disk.
Nov 04 21:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:35:16 evo-x2 memory-emergency-guard-check[2956808]: MEMORY EMERGENCY IO-PAUSE (trip #6781, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 3.340s wall clock time, 11.9M memory peak, 6.2M read from disk, 64M written to disk.
Nov 04 21:35:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:36:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:37:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:38:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:38:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:39:16 evo-x2 memory-emergency-guard-check[3005051]: MEMORY EMERGENCY IO-PAUSE (trip #6782, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 2.324s wall clock time, 11M memory peak, 5.1M read from disk, 56.2M written to disk.
Nov 04 21:39:43 evo-x2 memory-emergency-guard-check[3016190]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.06% sustained (max disk busy 44.1%, MemAvailable=36.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 21:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:41:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:44:16 evo-x2 memory-emergency-guard-check[3081844]: MEMORY EMERGENCY IO-PAUSE (trip #6783, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 21:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 2.542s wall clock time, 11.6M memory peak, 6.5M read from disk, 48M written to disk.
Nov 04 21:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:48:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:50:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:52:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:52:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:54:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:55:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:55:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:56:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:57:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:57:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 21:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:00:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:01:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:02:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:02:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:03:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:05:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:06:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:06:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:07:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:15:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:15:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:16:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:16:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:17:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:22:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:48:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:52:23 evo-x2 memory-emergency-guard-check[4079288]: MEMORY EMERGENCY IO-PAUSE (trip #6784, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 22:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 973ms CPU time over 8.383s wall clock time, 11.5M memory peak, 10.2M read from disk, 40.2M written to disk.
Nov 04 22:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:56:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:57:52 evo-x2 gatus[1694023]: 2026/11/04 22:57:52 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Nov 04 22:57:52 evo-x2 gatus[1694023]: 2026/11/04 22:57:52 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Nov 04 22:58:50 evo-x2 memory-emergency-guard-check[4182829]: MEMORY EMERGENCY IO-PAUSE (trip #6785, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 22:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 728ms CPU time over 35.959s wall clock time, 10.3M memory peak, 17M read from disk, 50.8M written to disk.
Nov 04 22:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:59:21 evo-x2 memory-emergency-guard-check[17221]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.41% sustained (max disk busy 100.0%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (66s < 150s, 84s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 22:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 22:59:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:00:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:01:31 evo-x2 memory-emergency-guard-check[51673]: MEMORY EMERGENCY IO-PAUSE (trip #6786, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 823ms CPU time over 39.403s wall clock time, 13.5M memory peak, 14.8M read from disk, 77.9M written to disk.
Nov 04 23:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:02:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:03:39 evo-x2 memory-emergency-guard-check[138649]: MEMORY EMERGENCY IO-PAUSE (trip #6787, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 8.379s wall clock time, 14.1M memory peak, 1.2M read from disk, 33.9M written to disk.
Nov 04 23:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:09:04 evo-x2 memory-emergency-guard-check[273498]: MEMORY EMERGENCY IO-PAUSE (trip #6788, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 783ms CPU time over 3.143s wall clock time, 9.9M memory peak, 14M read from disk, 38.7M written to disk.
Nov 04 23:09:31 evo-x2 memory-emergency-guard-check[307320]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.29% sustained (max disk busy 96.1%, MemAvailable=38.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 23:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:11:37 evo-x2 memory-emergency-guard-check[356062]: MEMORY EMERGENCY IO-PAUSE (trip #6789, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 784ms CPU time over 6.367s wall clock time, 10.9M memory peak, 11.3M read from disk, 50.3M written to disk.
Nov 04 23:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 136ms wall clock time, 9.1M memory peak, 1.7M read from disk, 4K written to disk.
Nov 04 23:12:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:13:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:14:10 evo-x2 memory-emergency-guard-check[425014]: MEMORY EMERGENCY IO-PAUSE (trip #6790, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 723ms CPU time over 9.339s wall clock time, 11.3M memory peak, 4.8M read from disk, 27.6M written to disk.
Nov 04 23:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:15:52 evo-x2 gatus[1694023]: 2026/11/04 23:15:52 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Nov 04 23:15:52 evo-x2 gatus[1694023]: 2026/11/04 23:15:52 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Nov 04 23:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:17:08 evo-x2 memory-emergency-guard-check[526119]: MEMORY EMERGENCY IO-PAUSE (trip #6791, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 804ms CPU time over 6.762s wall clock time, 10.8M memory peak, 21.3M read from disk, 71.5M written to disk.
Nov 04 23:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:18:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:19:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:20:09 evo-x2 memory-emergency-guard-check[586009]: MEMORY EMERGENCY IO-PAUSE (trip #6792, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.083s CPU time over 38.008s wall clock time, 8.3M memory peak, 23.6M read from disk, 40.7M written to disk.
Nov 04 23:20:09 evo-x2 memory-emergency-guard-check[631968]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.15% sustained (max disk busy 100.0%, MemAvailable=35.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (38s < 150s, 112s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 23:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:20:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:24:34 evo-x2 memory-emergency-guard-check[761454]: MEMORY EMERGENCY IO-PAUSE (trip #6793, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 772ms CPU time over 1min 54.343s wall clock time, 11.3M memory peak, 3.3M read from disk, 4.9M written to disk.
Nov 04 23:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:25:51 evo-x2 memory-emergency-guard-check[843132]: MEMORY EMERGENCY IO-PAUSE (trip #6794, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 16.890s wall clock time, 10.3M memory peak, 12.9M read from disk, 20.3M written to disk.
Nov 04 23:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:28:19 evo-x2 memory-emergency-guard-check[952342]: MEMORY EMERGENCY IO-PAUSE (trip #6795, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 13.846s wall clock time, 10.8M memory peak, 10M read from disk, 21M written to disk.
Nov 04 23:28:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:30:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:30:57 evo-x2 memory-emergency-guard-check[1026525]: MEMORY EMERGENCY IO-PAUSE (trip #6796, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 722ms CPU time over 21.977s wall clock time, 12.9M memory peak, 15.1M read from disk, 2.5M written to disk.
Nov 04 23:31:05 evo-x2 memory-emergency-guard-check[1051558]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.04% sustained (max disk busy 99.7%, MemAvailable=34.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 23:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:32:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:33:33 evo-x2 memory-emergency-guard-check[1105929]: MEMORY EMERGENCY IO-PAUSE (trip #6797, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 923ms CPU time over 28.177s wall clock time, 10.5M memory peak, 16.8M read from disk, 47.3M written to disk.
Nov 04 23:33:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:35:42 evo-x2 memory-emergency-guard-check[1214735]: MEMORY EMERGENCY IO-PAUSE (trip #6798, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:35:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:35:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 884ms CPU time over 6.918s wall clock time, 9.9M memory peak, 4.5M read from disk, 22.2M written to disk.
Nov 04 23:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:40:50 evo-x2 memory-emergency-guard-check[1308613]: MEMORY EMERGENCY IO-PAUSE (trip #6799, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.009s CPU time over 2min 45.671s wall clock time, 9.1M memory peak, 8.1M read from disk, 6.4M written to disk.
Nov 04 23:40:57 evo-x2 memory-emergency-guard-check[1416485]: MEMORY EMERGENCY IO-PAUSE (trip #6800, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 891ms CPU time over 6.451s wall clock time, 9.4M memory peak, 1.4M read from disk, 8.5M written to disk.
Nov 04 23:41:21 evo-x2 memory-emergency-guard-check[1439531]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.15% sustained (max disk busy 100.0%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 23:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:43:38 evo-x2 memory-emergency-guard-check[1488131]: MEMORY EMERGENCY IO-PAUSE (trip #6801, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:43:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:43:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.296s CPU time over 17.113s wall clock time, 9M memory peak, 4.1M read from disk, 60.2M written to disk.
Nov 04 23:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 185ms CPU time over 373ms wall clock time, 5.1M memory peak, 1.3M read from disk, 4K written to disk.
Nov 04 23:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 235ms CPU time over 415ms wall clock time, 5.7M memory peak, 1.8M read from disk, 4K written to disk.
Nov 04 23:46:05 evo-x2 memory-emergency-guard-check[1588103]: MEMORY EMERGENCY IO-PAUSE (trip #6802, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.019s CPU time over 14.667s wall clock time, 9.1M memory peak, 20.9M read from disk, 3.9M written to disk.
Nov 04 23:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 197ms CPU time over 425ms wall clock time, 6.4M memory peak, 2.5M read from disk, 4K written to disk.
Nov 04 23:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 184ms CPU time over 312ms wall clock time, 5.6M memory peak, 1.3M read from disk, 4K written to disk.
Nov 04 23:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:48:27 evo-x2 memory-emergency-guard-check[1634228]: MEMORY EMERGENCY IO-PAUSE (trip #6803, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:48:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:48:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.074s CPU time over 5.828s wall clock time, 14.1M memory peak, 38.1M read from disk, 33.8M written to disk.
Nov 04 23:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:50:54 evo-x2 memory-emergency-guard-check[1684715]: sort: write failed: 'standard output': Broken pipe
Nov 04 23:50:54 evo-x2 memory-emergency-guard-check[1684715]: sort: write error
Nov 04 23:50:54 evo-x2 memory-emergency-guard-check[1683434]: MEMORY EMERGENCY IO-PAUSE (trip #6804, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.208s CPU time over 2.896s wall clock time, 8.2M memory peak, 13.9M read from disk, 47.5M written to disk.
Nov 04 23:51:21 evo-x2 memory-emergency-guard-check[1708618]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.79% sustained (max disk busy 99.9%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 23:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 217ms CPU time over 409ms wall clock time, 6.2M memory peak, 1.6M read from disk, 4K written to disk.
Nov 04 23:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:53:29 evo-x2 memory-emergency-guard-check[1780415]: MEMORY EMERGENCY IO-PAUSE (trip #6805, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.132s CPU time over 7.704s wall clock time, 7.5M memory peak, 16.9M read from disk, 46.7M written to disk.
Nov 04 23:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 209ms CPU time over 424ms wall clock time, 5M memory peak, 2.3M read from disk, 4K written to disk.
Nov 04 23:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:55:55 evo-x2 memory-emergency-guard-check[1878447]: sort: write failed: 'standard output': Broken pipe
Nov 04 23:55:55 evo-x2 memory-emergency-guard-check[1878447]: sort: write error
Nov 04 23:55:55 evo-x2 memory-emergency-guard-check[1875636]: MEMORY EMERGENCY IO-PAUSE (trip #6806, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.137s CPU time over 4.488s wall clock time, 8.7M memory peak, 21.1M read from disk, 64.7M written to disk.
Nov 04 23:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:57:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:57:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:58:23 evo-x2 memory-emergency-guard-check[1972975]: MEMORY EMERGENCY IO-PAUSE (trip #6807, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 23:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 930ms CPU time over 2.309s wall clock time, 8.1M memory peak, 20.6M read from disk, 31.4M written to disk.
Nov 04 23:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 23:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 212ms CPU time over 519ms wall clock time, 7.7M memory peak, 4.6M read from disk, 4K written to disk.
Nov 05 00:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 185ms CPU time over 391ms wall clock time, 11M memory peak, 5.7M read from disk, 4K written to disk.
Nov 05 00:00:53 evo-x2 memory-emergency-guard-check[2072731]: MEMORY EMERGENCY IO-PAUSE (trip #6808, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 931ms CPU time over 2.299s wall clock time, 8.3M memory peak, 2M read from disk, 11M written to disk.
Nov 05 00:01:21 evo-x2 memory-emergency-guard-check[2095967]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.21% sustained (max disk busy 96.6%, MemAvailable=12.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 00:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 185ms CPU time over 377ms wall clock time, 6.9M memory peak, 1.5M read from disk, 4K written to disk.
Nov 05 00:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:03:59 evo-x2 memory-emergency-guard-check[2190097]: MEMORY EMERGENCY IO-PAUSE (trip #6809, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.548s CPU time over 7.533s wall clock time, 11.3M memory peak, 70.8M read from disk, 85.8M written to disk.
Nov 05 00:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:04:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:06:26 evo-x2 memory-emergency-guard-check[2325200]: MEMORY EMERGENCY IO-PAUSE (trip #6810, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:06:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:06:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.388s CPU time over 4.533s wall clock time, 12.2M memory peak, 27.7M read from disk, 50.4M written to disk.
Nov 05 00:06:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:07:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:08:58 evo-x2 memory-emergency-guard-check[2461493]: MEMORY EMERGENCY IO-PAUSE (trip #6811, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 988ms CPU time over 7.221s wall clock time, 9.4M memory peak, 11.8M read from disk, 67.4M written to disk.
Nov 05 00:09:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:11:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:11:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 407ms wall clock time, 7.4M memory peak, 2.6M read from disk, 4K written to disk.
Nov 05 00:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 241ms CPU time over 832ms wall clock time, 6.3M memory peak, 1M read from disk, 4K written to disk.
Nov 05 00:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:13:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:14:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:14:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:15:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:15:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:16:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:16:55 evo-x2 memory-emergency-guard-check[2687474]: MEMORY EMERGENCY IO-PAUSE (trip #6812, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 764ms CPU time over 3.422s wall clock time, 10M memory peak, 14.3M read from disk, 20.7M written to disk.
Nov 05 00:17:22 evo-x2 memory-emergency-guard-check[2707706]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.19% sustained (max disk busy 99.6%, MemAvailable=37.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 00:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:19:26 evo-x2 memory-emergency-guard-check[2773915]: MEMORY EMERGENCY IO-PAUSE (trip #6813, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 984ms CPU time over 4.356s wall clock time, 12.9M memory peak, 22.9M read from disk, 57.6M written to disk.
Nov 05 00:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:22:10 evo-x2 memory-emergency-guard-check[2882954]: MEMORY EMERGENCY IO-PAUSE (trip #6814, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 962ms CPU time over 18.344s wall clock time, 11M memory peak, 20.1M read from disk, 29.4M written to disk.
Nov 05 00:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:22:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:24:49 evo-x2 memory-emergency-guard-check[2973872]: MEMORY EMERGENCY IO-PAUSE (trip #6815, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 815ms CPU time over 27.280s wall clock time, 12.2M memory peak, 26.9M read from disk, 58.9M written to disk.
Nov 05 00:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 161ms wall clock time, 11.1M memory peak, 3.3M read from disk, 4K written to disk.
Nov 05 00:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:26:56 evo-x2 memory-emergency-guard-check[3076417]: MEMORY EMERGENCY IO-PAUSE (trip #6816, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 608ms CPU time over 3.860s wall clock time, 10.2M memory peak, 416K read from disk, 16M written to disk.
Nov 05 00:27:22 evo-x2 memory-emergency-guard-check[3112262]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.54% sustained (max disk busy 100.0%, MemAvailable=36.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 00:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:29:27 evo-x2 memory-emergency-guard-check[3178391]: MEMORY EMERGENCY IO-PAUSE (trip #6817, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 5.136s wall clock time, 8.9M memory peak, 2.9M read from disk, 22.4M written to disk.
Nov 05 00:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:29:54 evo-x2 gatus[1694023]: 2026/11/05 00:29:54 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 05 00:29:54 evo-x2 gatus[1694023]: 2026/11/05 00:29:54 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 05 00:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:32:05 evo-x2 memory-emergency-guard-check[3303162]: MEMORY EMERGENCY IO-PAUSE (trip #6818, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.152s CPU time over 13.077s wall clock time, 10.6M memory peak, 18.4M read from disk, 68.5M written to disk.
Nov 05 00:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:35:34 evo-x2 memory-emergency-guard-check[3520761]: MEMORY EMERGENCY IO-PAUSE (trip #6819, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.145s CPU time over 11.645s wall clock time, 9.4M memory peak, 8.1M read from disk, 43.4M written to disk.
Nov 05 00:35:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:37:22 evo-x2 memory-emergency-guard-check[3629920]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.39% sustained (max disk busy 100.0%, MemAvailable=38.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 00:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:38:07 evo-x2 memory-emergency-guard-check[3649661]: MEMORY EMERGENCY IO-PAUSE (trip #6820, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 14.831s wall clock time, 10.6M memory peak, 16.3M read from disk, 1.7M written to disk.
Nov 05 00:38:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:39:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:40:27 evo-x2 memory-emergency-guard-check[3788956]: MEMORY EMERGENCY IO-PAUSE (trip #6821, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 5.417s wall clock time, 11.4M memory peak, 6.8M read from disk, 41M written to disk.
Nov 05 00:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:43:41 evo-x2 memory-emergency-guard-check[3895602]: MEMORY EMERGENCY IO-PAUSE (trip #6822, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 819ms CPU time over 49.089s wall clock time, 10.8M memory peak, 3.1M read from disk, 39.8M written to disk.
Nov 05 00:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:45:54 evo-x2 memory-emergency-guard-check[3990586]: MEMORY EMERGENCY IO-PAUSE (trip #6823, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 12.758s wall clock time, 10.5M memory peak, 3.1M read from disk, 9.8M written to disk.
Nov 05 00:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:47:41 evo-x2 memory-emergency-guard-check[4036578]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.62% sustained (max disk busy 100.0%, MemAvailable=35.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 00:48:19 evo-x2 memory-emergency-guard-check[4044984]: MEMORY EMERGENCY IO-PAUSE (trip #6824, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 630ms CPU time over 8.181s wall clock time, 12.2M memory peak, 1.8M read from disk, 24.4M written to disk.
Nov 05 00:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:50:48 evo-x2 memory-emergency-guard-check[4116131]: MEMORY EMERGENCY IO-PAUSE (trip #6825, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 6.291s wall clock time, 11.2M memory peak, 2.5M read from disk, 17.1M written to disk.
Nov 05 00:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 141ms wall clock time, 12.6M memory peak, 3.4M read from disk, 4K written to disk.
Nov 05 00:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:53:15 evo-x2 memory-emergency-guard-check[4194295]: MEMORY EMERGENCY IO-PAUSE (trip #6826, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 3.639s wall clock time, 10.4M memory peak, 17M read from disk, 69.9M written to disk.
Nov 05 00:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 168ms wall clock time, 9.7M memory peak, 1.5M read from disk, 4K written to disk.
Nov 05 00:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:55:46 evo-x2 memory-emergency-guard-check[74013]: MEMORY EMERGENCY IO-PAUSE (trip #6827, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 00:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 980ms CPU time over 4.985s wall clock time, 9.9M memory peak, 16M read from disk, 71.3M written to disk.
Nov 05 00:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 164ms wall clock time, 10.3M memory peak, 3.5M read from disk, 4K written to disk.
Nov 05 00:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 161ms CPU time over 224ms wall clock time, 7.5M memory peak, 1.2M read from disk, 4K written to disk.
Nov 05 00:57:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 00:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:00:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:00:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 169ms wall clock time, 11.5M memory peak, 5M read from disk, 4K written to disk.
Nov 05 01:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:09:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:13:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:13:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:14:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:19:47 evo-x2 memory-emergency-guard-check[954559]: MEMORY EMERGENCY IO-PAUSE (trip #6828, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 871ms CPU time over 4.962s wall clock time, 11.2M memory peak, 9.2M read from disk, 54.3M written to disk.
Nov 05 01:20:12 evo-x2 memory-emergency-guard-check[980301]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.35% sustained (max disk busy 99.5%, MemAvailable=34.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 01:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:24:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:25:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:28:54 evo-x2 memory-emergency-guard-check[1271824]: MEMORY EMERGENCY IO-PAUSE (trip #6829, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:28:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:28:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 755ms CPU time over 11.973s wall clock time, 11.8M memory peak, 1.4M read from disk, 58.4M written to disk.
Nov 05 01:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:29:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:33:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:34:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:34:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:35:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:36:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:36:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:38:20 evo-x2 memory-emergency-guard-check[1535493]: MEMORY EMERGENCY IO-PAUSE (trip #6830, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 944ms CPU time over 7.409s wall clock time, 9.7M memory peak, 8.1M read from disk, 30.7M written to disk.
Nov 05 01:38:42 evo-x2 memory-emergency-guard-check[1550794]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.98% sustained (max disk busy 99.8%, MemAvailable=58.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 01:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:41:20 evo-x2 memory-emergency-guard-check[1586103]: MEMORY EMERGENCY IO-PAUSE (trip #6831, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 630ms CPU time over 37.215s wall clock time, 11.4M memory peak, 2.3M read from disk, 50.1M written to disk.
Nov 05 01:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:43:30 evo-x2 memory-emergency-guard-check[1659069]: MEMORY EMERGENCY IO-PAUSE (trip #6832, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 836ms CPU time over 2.261s wall clock time, 10.1M memory peak, 2.7M read from disk, 19.3M written to disk.
Nov 05 01:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:46:40 evo-x2 memory-emergency-guard-check[1721931]: MEMORY EMERGENCY IO-PAUSE (trip #6833, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 41.557s wall clock time, 11.7M memory peak, 13.6M read from disk, 22.3M written to disk.
Nov 05 01:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:49:27 evo-x2 memory-emergency-guard-check[1816877]: MEMORY EMERGENCY IO-PAUSE (trip #6834, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 759ms CPU time over 47.130s wall clock time, 11M memory peak, 2.1M read from disk, 61.4M written to disk.
Nov 05 01:49:27 evo-x2 memory-emergency-guard-check[1842574]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.26% sustained (max disk busy 100.0%, MemAvailable=49.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (47s < 150s, 103s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 01:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:51:33 evo-x2 memory-emergency-guard-check[1920815]: MEMORY EMERGENCY IO-PAUSE (trip #6835, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 826ms CPU time over 5.816s wall clock time, 8.8M memory peak, 2.5M read from disk, 14.5M written to disk.
Nov 05 01:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 111ms CPU time over 144ms wall clock time, 14.6M memory peak, 3.9M read from disk, 4K written to disk.
Nov 05 01:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 146ms wall clock time, 10.1M memory peak, 2.3M read from disk, 4K written to disk.
Nov 05 01:54:07 evo-x2 memory-emergency-guard-check[2019675]: MEMORY EMERGENCY IO-PAUSE (trip #6836, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 9.699s wall clock time, 10M memory peak, 16.3M read from disk, 2.4M written to disk.
Nov 05 01:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:56:38 evo-x2 memory-emergency-guard-check[2117730]: MEMORY EMERGENCY IO-PAUSE (trip #6837, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 730ms CPU time over 11.321s wall clock time, 11.5M memory peak, 11.9M read from disk, 7.1M written to disk.
Nov 05 01:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:59:04 evo-x2 memory-emergency-guard-check[2242924]: MEMORY EMERGENCY IO-PAUSE (trip #6838, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 01:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 7.205s wall clock time, 12.4M memory peak, 772K read from disk, 22.4M written to disk.
Nov 05 01:59:27 evo-x2 memory-emergency-guard-check[2259213]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.62% sustained (max disk busy 99.9%, MemAvailable=23.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 01:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 143ms wall clock time, 13.8M memory peak, 3.5M read from disk, 4K written to disk.
Nov 05 01:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 01:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 213ms CPU time over 427ms wall clock time, 11.6M memory peak, 5.4M read from disk, 4K written to disk.
Nov 05 02:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:02:12 evo-x2 memory-emergency-guard-check[2307640]: MEMORY EMERGENCY IO-PAUSE (trip #6839, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 852ms CPU time over 44.996s wall clock time, 10.2M memory peak, 19.8M read from disk, 58.7M written to disk.
Nov 05 02:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:04:26 evo-x2 memory-emergency-guard-check[2374951]: MEMORY EMERGENCY IO-PAUSE (trip #6840, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 14.345s wall clock time, 13M memory peak, 21.6M read from disk, 676K written to disk.
Nov 05 02:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 171ms wall clock time, 8.6M memory peak, 1.4M read from disk, 4K written to disk.
Nov 05 02:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:07:56 evo-x2 memory-emergency-guard-check[2440888]: MEMORY EMERGENCY IO-PAUSE (trip #6841, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 789ms CPU time over 1min 13.481s wall clock time, 14M memory peak, 23.3M read from disk, 34.6M written to disk.
Nov 05 02:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:08:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:09:55 evo-x2 memory-emergency-guard-check[2511582]: MEMORY EMERGENCY IO-PAUSE (trip #6842, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 843ms CPU time over 28.998s wall clock time, 11.3M memory peak, 29.2M read from disk, 47.4M written to disk.
Nov 05 02:09:56 evo-x2 memory-emergency-guard-check[2542750]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.04% sustained (max disk busy 100.0%, MemAvailable=45.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 02:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:12:06 evo-x2 memory-emergency-guard-check[2633641]: MEMORY EMERGENCY IO-PAUSE (trip #6843, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 806ms CPU time over 10.053s wall clock time, 9.8M memory peak, 8.7M read from disk, 31.6M written to disk.
Nov 05 02:12:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:13:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:14:38 evo-x2 memory-emergency-guard-check[2765612]: MEMORY EMERGENCY IO-PAUSE (trip #6844, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 11.498s wall clock time, 10.7M memory peak, 10.5M read from disk, 4.8M written to disk.
Nov 05 02:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:15:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:16:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:16:57 evo-x2 memory-emergency-guard-check[2837720]: MEMORY EMERGENCY IO-PAUSE (trip #6845, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 832ms CPU time over 1.044s wall clock time, 11M memory peak, 6.2M read from disk, 46.6M written to disk.
Nov 05 02:17:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:17:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:18:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:18:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:19:30 evo-x2 memory-emergency-guard-check[2966314]: sort: fflush failed: 'standard output': Broken pipe
Nov 05 02:19:30 evo-x2 memory-emergency-guard-check[2966314]: sort: write error
Nov 05 02:19:30 evo-x2 memory-emergency-guard-check[2955696]: MEMORY EMERGENCY IO-PAUSE (trip #6846, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 666ms CPU time over 4.282s wall clock time, 11.5M memory peak, 1.4M read from disk, 27.5M written to disk.
Nov 05 02:19:56 evo-x2 memory-emergency-guard-check[2993191]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.22% sustained (max disk busy 97.0%, MemAvailable=47.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 02:19:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:22:02 evo-x2 memory-emergency-guard-check[3084284]: MEMORY EMERGENCY IO-PAUSE (trip #6847, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 6.334s wall clock time, 10.6M memory peak, 2.4M read from disk, 7.7M written to disk.
Nov 05 02:22:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:24:28 evo-x2 memory-emergency-guard-check[3203473]: MEMORY EMERGENCY IO-PAUSE (trip #6848, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 1.734s wall clock time, 10.6M memory peak, 288K read from disk, 15.6M written to disk.
Nov 05 02:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:27:31 evo-x2 memory-emergency-guard-check[3346559]: MEMORY EMERGENCY IO-PAUSE (trip #6849, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 828ms CPU time over 4.839s wall clock time, 11.6M memory peak, 25.6M read from disk, 87.4M written to disk.
Nov 05 02:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:29:59 evo-x2 memory-emergency-guard-check[3451574]: MEMORY EMERGENCY IO-PAUSE (trip #6850, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 667ms CPU time over 2.241s wall clock time, 11.9M memory peak, 3.4M read from disk, 29.4M written to disk.
Nov 05 02:30:26 evo-x2 memory-emergency-guard-check[3484198]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.54% sustained (max disk busy 23.0%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 02:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:32:28 evo-x2 memory-emergency-guard-check[3559805]: MEMORY EMERGENCY IO-PAUSE (trip #6851, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 1.938s wall clock time, 11.6M memory peak, 1.8M read from disk, 46.8M written to disk.
Nov 05 02:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:34:59 evo-x2 memory-emergency-guard-check[3667232]: MEMORY EMERGENCY IO-PAUSE (trip #6852, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 880ms CPU time over 2.664s wall clock time, 9.4M memory peak, 2.4M read from disk, 41M written to disk.
Nov 05 02:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 147ms wall clock time, 10.4M memory peak, 1.2M read from disk, 4K written to disk.
Nov 05 02:37:29 evo-x2 memory-emergency-guard-check[3736258]: MEMORY EMERGENCY IO-PAUSE (trip #6853, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 2.126s wall clock time, 11.2M memory peak, 2.7M read from disk, 41.3M written to disk.
Nov 05 02:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:39:58 evo-x2 memory-emergency-guard-check[3807105]: MEMORY EMERGENCY IO-PAUSE (trip #6854, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 1.909s wall clock time, 11.2M memory peak, 3.4M read from disk, 48.3M written to disk.
Nov 05 02:40:27 evo-x2 memory-emergency-guard-check[3820643]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.31% sustained (max disk busy 44.0%, MemAvailable=41.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 02:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:41:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:42:59 evo-x2 memory-emergency-guard-check[3874040]: MEMORY EMERGENCY IO-PAUSE (trip #6855, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 705ms CPU time over 2.850s wall clock time, 12.1M memory peak, 5.5M read from disk, 60.5M written to disk.
Nov 05 02:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:45:29 evo-x2 memory-emergency-guard-check[3913057]: MEMORY EMERGENCY IO-PAUSE (trip #6856, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 2.636s wall clock time, 10.9M memory peak, 2.8M read from disk, 31.3M written to disk.
Nov 05 02:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:47:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:48:29 evo-x2 memory-emergency-guard-check[3968031]: MEMORY EMERGENCY IO-PAUSE (trip #6857, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 1.989s wall clock time, 10.2M memory peak, 976K read from disk, 40.3M written to disk.
Nov 05 02:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:50:27 evo-x2 memory-emergency-guard-check[4026910]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.00% sustained (max disk busy 23.3%, MemAvailable=40.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 02:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:53:58 evo-x2 memory-emergency-guard-check[4131343]: MEMORY EMERGENCY IO-PAUSE (trip #6858, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 587ms CPU time over 1.640s wall clock time, 10.7M memory peak, 1.9M read from disk, 20.1M written to disk.
Nov 05 02:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:56:29 evo-x2 memory-emergency-guard-check[4193787]: MEMORY EMERGENCY IO-PAUSE (trip #6859, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 757ms CPU time over 2.303s wall clock time, 10.9M memory peak, 2.8M read from disk, 25.9M written to disk.
Nov 05 02:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:59:04 evo-x2 memory-emergency-guard-check[130009]: MEMORY EMERGENCY IO-PAUSE (trip #6860, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 02:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 820ms CPU time over 7.411s wall clock time, 10.9M memory peak, 13.6M read from disk, 44.4M written to disk.
Nov 05 02:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 02:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:00:27 evo-x2 memory-emergency-guard-check[209828]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.58% sustained (max disk busy 99.9%, MemAvailable=43.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 03:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:01:41 evo-x2 memory-emergency-guard-check[235811]: MEMORY EMERGENCY IO-PAUSE (trip #6861, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 03:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 13.742s wall clock time, 11M memory peak, 22.4M read from disk, 31.7M written to disk.
Nov 05 03:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 04 19:09:10 evo-x2 thermal-pstate-guard-check[55745]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 04 19:06:04 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/ly95anmg9hw2hi052kjfvcg1dxy5fqfi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 04 19:06:04 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/ly95anmg9hw2hi052kjfvcg1dxy5fqfi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 04 19:06:04 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 04 19:06:06 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793844192000000000 -> 1793844344000000000 epoch-ns UTC (2026-11-05 02:03:12 -> 2026-11-05 02:05:44 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
