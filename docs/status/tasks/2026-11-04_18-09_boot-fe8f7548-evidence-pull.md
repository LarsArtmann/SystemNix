# Boot evidence pull: id8 fe8f7548 (full: fe8f7548e7b3425fa9ae37c594b1d5ff)

Pulled 2026-11-04 18:09 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-03 21:44:34 -> 2026-11-04 19:04:30 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 fe8f7548 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 03 21:44:34 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 03 21:44:34 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/6nz9id10qkf5cg7972iqbqb3958hi04y-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 21:44:34 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 04 19:04:30 evo-x2 systemd-coredump[275647]: Removed old coredump core.dmesg.966.fe8f7548e7b3425fa9ae37c594b1d5ff.2426048.1793812696000000.zst.
Nov 04 19:04:30 evo-x2 systemd-coredump[275647]: Removed old coredump core.flm-real.1000.fe8f7548e7b3425fa9ae37c594b1d5ff.1388161.1793812162000000.zst.
Nov 04 19:04:30 evo-x2 systemd-coredump[275647]: Process 275609 (dmesg) of user 966 dumped core.
                                                 
                                                 Module libncursesw.so.6 without build-id.
                                                 Stack trace of thread 275609:
                                                 #0  0x00007df48792d3bb klogctl (libc.so.6 + 0x12d3bb)
                                                 #1  0x0000564ea9b485b4 main (dmesg + 0x65b4)
                                                 #2  0x00007df48782b391 __libc_start_call_main (libc.so.6 + 0x2b391)
                                                 #3  0x00007df48782b4a8 __libc_start_main@@GLIBC_2.34 (libc.so.6 + 0x2b4a8)
                                                 #4  0x0000564ea9b48a55 _start (dmesg + 0x6a55)
                                                 ELF object binary architecture: AMD x86-64
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 3606
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
Nov 03 21:47:18 evo-x2 memory-emergency-guard-check[21842]: MEMORY EMERGENCY IO-PAUSE (trip #6275, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 742ms CPU time over 46.053s wall clock time, 11M memory peak, 32.8M read from disk, 183.3M written to disk.
Nov 03 21:47:18 evo-x2 memory-emergency-guard-check[36978]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.30% sustained (max disk busy 100.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (46s < 150s, 104s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 21:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:50:02 evo-x2 memory-emergency-guard-check[110228]: MEMORY EMERGENCY IO-PAUSE (trip #6276, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 535ms CPU time over 44.159s wall clock time, 12.6M memory peak, 1.1M read from disk, 24.5M written to disk.
Nov 03 21:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:52:13 evo-x2 memory-emergency-guard-check[244039]: MEMORY EMERGENCY IO-PAUSE (trip #6277, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 804ms CPU time over 10.978s wall clock time, 10.3M memory peak, 2.3M read from disk, 52.4M written to disk.
Nov 03 21:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:54:35 evo-x2 memory-emergency-guard-check[375212]: MEMORY EMERGENCY IO-PAUSE (trip #6278, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 3.054s wall clock time, 8.9M memory peak, 8.6M read from disk, 44.2M written to disk.
Nov 03 21:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:57:05 evo-x2 memory-emergency-guard-check[489514]: MEMORY EMERGENCY IO-PAUSE (trip #6279, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 750ms CPU time over 2.382s wall clock time, 9.9M memory peak, 11.5M read from disk, 71.1M written to disk.
Nov 03 21:57:32 evo-x2 memory-emergency-guard-check[508530]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.94% sustained (max disk busy 100.0%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 21:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:59:45 evo-x2 memory-emergency-guard-check[598153]: MEMORY EMERGENCY IO-PAUSE (trip #6280, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 21:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 21:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.015s CPU time over 12.475s wall clock time, 8M memory peak, 7.1M read from disk, 73.5M written to disk.
Nov 03 22:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:02:24 evo-x2 memory-emergency-guard-check[722131]: MEMORY EMERGENCY IO-PAUSE (trip #6281, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 814ms CPU time over 20.619s wall clock time, 9.3M memory peak, 22.9M read from disk, 8.8M written to disk.
Nov 03 22:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:06:40 evo-x2 memory-emergency-guard-check[785672]: MEMORY EMERGENCY IO-PAUSE (trip #6282, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.037s CPU time over 2min 7.758s wall clock time, 11.6M memory peak, 33.7M read from disk, 32.6M written to disk.
Nov 03 22:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:07:20 evo-x2 memory-emergency-guard-check[850932]: MEMORY EMERGENCY IO-PAUSE (trip #6283, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 656ms CPU time over 9.507s wall clock time, 11.6M memory peak, 8.5M read from disk, 6.6M written to disk.
Nov 03 22:07:40 evo-x2 memory-emergency-guard-check[872172]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.91% sustained (max disk busy 100.0%, MemAvailable=37.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 22:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:09:57 evo-x2 memory-emergency-guard-check[947868]: MEMORY EMERGENCY IO-PAUSE (trip #6284, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 759ms CPU time over 2.507s wall clock time, 11.4M memory peak, 6.8M read from disk, 27.1M written to disk.
Nov 03 22:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:12:28 evo-x2 memory-emergency-guard-check[1089709]: MEMORY EMERGENCY IO-PAUSE (trip #6285, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 3.518s wall clock time, 12.3M memory peak, 28.6M read from disk, 51.7M written to disk.
Nov 03 22:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:16:19 evo-x2 memory-emergency-guard-check[1182002]: MEMORY EMERGENCY IO-PAUSE (trip #6286, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 901ms CPU time over 1min 24.313s wall clock time, 12.9M memory peak, 14.8M read from disk, 21.7M written to disk.
Nov 03 22:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:18:04 evo-x2 memory-emergency-guard-check[1356094]: MEMORY EMERGENCY IO-PAUSE (trip #6287, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 779ms CPU time over 15.271s wall clock time, 13.8M memory peak, 13.5M read from disk, 6.4M written to disk.
Nov 03 22:18:19 evo-x2 memory-emergency-guard-check[1381152]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.99% sustained (max disk busy 99.9%, MemAvailable=36.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 22:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:20:52 evo-x2 memory-emergency-guard-check[1478817]: MEMORY EMERGENCY IO-PAUSE (trip #6288, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.217s CPU time over 32.947s wall clock time, 11.6M memory peak, 26.3M read from disk, 7M written to disk.
Nov 03 22:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:22:56 evo-x2 memory-emergency-guard-check[1615176]: MEMORY EMERGENCY IO-PAUSE (trip #6289, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.101s CPU time over 3.940s wall clock time, 15.4M memory peak, 32.7M read from disk, 68.9M written to disk.
Nov 03 22:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:25:27 evo-x2 memory-emergency-guard-check[1760713]: MEMORY EMERGENCY IO-PAUSE (trip #6290, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.144s CPU time over 5.175s wall clock time, 8.3M memory peak, 9.1M read from disk, 17.2M written to disk.
Nov 03 22:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:28:37 evo-x2 memory-emergency-guard-check[1896221]: MEMORY EMERGENCY IO-PAUSE (trip #6291, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.168s CPU time over 45.691s wall clock time, 12M memory peak, 33.1M read from disk, 916K written to disk.
Nov 03 22:28:38 evo-x2 memory-emergency-guard-check[1966938]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.46% sustained (max disk busy 99.2%, MemAvailable=38.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (46s < 150s, 104s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 22:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:32:40 evo-x2 memory-emergency-guard-check[2126963]: MEMORY EMERGENCY IO-PAUSE (trip #6292, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.261s CPU time over 2min 2.207s wall clock time, 12.8M memory peak, 25.5M read from disk, 34M written to disk.
Nov 03 22:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:33:14 evo-x2 memory-emergency-guard-check[2296619]: MEMORY EMERGENCY IO-PAUSE (trip #6293, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 876ms CPU time over 4.568s wall clock time, 12.4M memory peak, 660K read from disk, 23.8M written to disk.
Nov 03 22:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:34:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:35:51 evo-x2 memory-emergency-guard-check[2455996]: MEMORY EMERGENCY IO-PAUSE (trip #6294, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.126s CPU time over 10.872s wall clock time, 10.3M memory peak, 5.2M read from disk, 42.4M written to disk.
Nov 03 22:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:38:31 evo-x2 memory-emergency-guard-check[2568459]: MEMORY EMERGENCY IO-PAUSE (trip #6295, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 940ms CPU time over 20.867s wall clock time, 14.5M memory peak, 21.7M read from disk, 46.8M written to disk.
Nov 03 22:38:40 evo-x2 memory-emergency-guard-check[2592254]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.28% sustained (max disk busy 100.0%, MemAvailable=18.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 22:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 175ms wall clock time, 9M memory peak, 2.9M read from disk, 4K written to disk.
Nov 03 22:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:40:43 evo-x2 memory-emergency-guard-check[2669334]: MEMORY EMERGENCY IO-PAUSE (trip #6296, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 958ms CPU time over 2.579s wall clock time, 10.3M memory peak, 15.1M read from disk, 41.8M written to disk.
Nov 03 22:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 194ms CPU time over 342ms wall clock time, 6.5M memory peak, 1M read from disk, 4K written to disk.
Nov 03 22:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:43:43 evo-x2 memory-emergency-guard-check[2808745]: MEMORY EMERGENCY IO-PAUSE (trip #6297, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 848ms CPU time over 33.258s wall clock time, 11.8M memory peak, 17.1M read from disk, 15M written to disk.
Nov 03 22:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:45:55 evo-x2 memory-emergency-guard-check[2930717]: MEMORY EMERGENCY IO-PAUSE (trip #6298, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.181s CPU time over 11.710s wall clock time, 11.7M memory peak, 10.9M read from disk, 11.6M written to disk.
Nov 03 22:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 160ms CPU time over 363ms wall clock time, 8.9M memory peak, 3.5M read from disk, 4K written to disk.
Nov 03 22:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:48:51 evo-x2 memory-emergency-guard-check[3049487]: MEMORY EMERGENCY IO-PAUSE (trip #6299, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 863ms CPU time over 37.985s wall clock time, 12.8M memory peak, 18.7M read from disk, 47.3M written to disk.
Nov 03 22:48:52 evo-x2 memory-emergency-guard-check[3088736]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.52% sustained (max disk busy 99.8%, MemAvailable=34.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (38s < 150s, 112s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 22:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:51:04 evo-x2 memory-emergency-guard-check[3204605]: MEMORY EMERGENCY IO-PAUSE (trip #6300, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 853ms CPU time over 13.063s wall clock time, 10.7M memory peak, 35M read from disk, 5.7M written to disk.
Nov 03 22:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:52:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:53:41 evo-x2 memory-emergency-guard-check[3375350]: MEMORY EMERGENCY IO-PAUSE (trip #6301, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:53:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.040s CPU time over 18.922s wall clock time, 8.8M memory peak, 15.1M read from disk, 44.6M written to disk.
Nov 03 22:53:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:56:14 evo-x2 memory-emergency-guard-check[3532971]: MEMORY EMERGENCY IO-PAUSE (trip #6302, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.232s CPU time over 21.159s wall clock time, 8M memory peak, 28.8M read from disk, 41.6M written to disk.
Nov 03 22:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 116ms CPU time over 361ms wall clock time, 12M memory peak, 3.6M read from disk, 4K written to disk.
Nov 03 22:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 138ms CPU time over 891ms wall clock time, 9.3M memory peak, 3.8M read from disk, 4K written to disk.
Nov 03 22:59:55 evo-x2 memory-emergency-guard-check[3841794]: MEMORY EMERGENCY IO-PAUSE (trip #6303, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 22:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 22:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.216s CPU time over 2.349s wall clock time, 16.9M memory peak, 15.5M read from disk, 30.7M written to disk.
Nov 03 23:00:23 evo-x2 memory-emergency-guard-check[3876590]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.21% sustained (max disk busy 79.7%, MemAvailable=53.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:02:36 evo-x2 memory-emergency-guard-check[3945840]: MEMORY EMERGENCY IO-PAUSE (trip #6304, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 828ms CPU time over 13.486s wall clock time, 12.1M memory peak, 15.3M read from disk, 26.3M written to disk.
Nov 03 23:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 210ms CPU time over 484ms wall clock time, 10.4M memory peak, 4.5M read from disk, 4K written to disk.
Nov 03 23:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:05:36 evo-x2 memory-emergency-guard-check[4049037]: MEMORY EMERGENCY IO-PAUSE (trip #6305, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 824ms CPU time over 43.462s wall clock time, 14.1M memory peak, 20.1M read from disk, 47.2M written to disk.
Nov 03 23:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:07:46 evo-x2 memory-emergency-guard-check[4161042]: MEMORY EMERGENCY IO-PAUSE (trip #6306, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 9.400s wall clock time, 15.2M memory peak, 7.4M read from disk, 31.6M written to disk.
Nov 03 23:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 328ms wall clock time, 12.6M memory peak, 5.3M read from disk, 4K written to disk.
Nov 03 23:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:10:21 evo-x2 memory-emergency-guard-check[185462]: MEMORY EMERGENCY IO-PAUSE (trip #6307, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 788ms CPU time over 14.760s wall clock time, 13.3M memory peak, 7.7M read from disk, 25.1M written to disk.
Nov 03 23:10:37 evo-x2 memory-emergency-guard-check[206267]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.27% sustained (max disk busy 99.8%, MemAvailable=37.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:13:57 evo-x2 memory-emergency-guard-check[254158]: MEMORY EMERGENCY IO-PAUSE (trip #6308, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.191s CPU time over 1min 20.680s wall clock time, 12.5M memory peak, 508K memory swap peak, 48.1M read from disk, 5.4M written to disk.
Nov 03 23:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 190ms CPU time over 497ms wall clock time, 5.7M memory peak, 1.1M read from disk, 4K written to disk.
Nov 03 23:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 154ms CPU time over 1.078s wall clock time, 7.7M memory peak, 6M read from disk, 4K written to disk.
Nov 03 23:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 152ms CPU time over 1.672s wall clock time, 12.3M memory peak, 9.6M read from disk, 4K written to disk.
Nov 03 23:16:45 evo-x2 memory-emergency-guard-check[320134]: MEMORY EMERGENCY IO-PAUSE (trip #6309, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 981ms CPU time over 1min 18.151s wall clock time, 15.3M memory peak, 62.1M read from disk, 11.6M written to disk.
Nov 03 23:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:17:18 evo-x2 gatus[33393]: 2026/11/03 23:17:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 03 23:17:18 evo-x2 gatus[33393]: 2026/11/03 23:17:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 03 23:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:18:42 evo-x2 memory-emergency-guard-check[419763]: MEMORY EMERGENCY IO-PAUSE (trip #6310, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.366s CPU time over 26.421s wall clock time, 10.9M memory peak, 26.9M read from disk, 54.4M written to disk.
Nov 03 23:18:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:21:10 evo-x2 memory-emergency-guard-check[537418]: MEMORY EMERGENCY IO-PAUSE (trip #6311, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 879ms CPU time over 24.545s wall clock time, 11.3M memory peak, 19.5M read from disk, 14.6M written to disk.
Nov 03 23:21:16 evo-x2 memory-emergency-guard-check[561333]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.77% sustained (max disk busy 99.9%, MemAvailable=35.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 180ms wall clock time, 9.4M memory peak, 1.4M read from disk, 4K written to disk.
Nov 03 23:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:23:48 evo-x2 memory-emergency-guard-check[634913]: MEMORY EMERGENCY IO-PAUSE (trip #6312, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 808ms CPU time over 32.964s wall clock time, 11.1M memory peak, 23.4M read from disk, 8.3M written to disk.
Nov 03 23:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:26:32 evo-x2 memory-emergency-guard-check[816893]: MEMORY EMERGENCY IO-PAUSE (trip #6313, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 810ms CPU time over 43.205s wall clock time, 12.3M memory peak, 15.5M read from disk, 22.2M written to disk.
Nov 03 23:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:29:45 evo-x2 memory-emergency-guard-check[1051608]: MEMORY EMERGENCY IO-PAUSE (trip #6314, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 935ms CPU time over 1min 13.330s wall clock time, 12.7M memory peak, 21.2M read from disk, 2.1M written to disk.
Nov 03 23:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:30:21 evo-x2 systemd[1916]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (fastflowlm) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u fastflowlm -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Nov 03 23:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:31:33 evo-x2 memory-emergency-guard-check[1262737]: MEMORY EMERGENCY IO-PAUSE (trip #6315, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 984ms CPU time over 18.332s wall clock time, 10.9M memory peak, 12.1M read from disk, 11.8M written to disk.
Nov 03 23:31:45 evo-x2 memory-emergency-guard-check[1296369]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.99% sustained (max disk busy 100.0%, MemAvailable=47.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:33:50 evo-x2 memory-emergency-guard-check[1482275]: MEMORY EMERGENCY IO-PAUSE (trip #6316, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 759ms CPU time over 5.171s wall clock time, 10.1M memory peak, 10.7M read from disk, 46.2M written to disk.
Nov 03 23:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:37:02 evo-x2 memory-emergency-guard-check[1599334]: MEMORY EMERGENCY IO-PAUSE (trip #6317, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 948ms CPU time over 47.046s wall clock time, 11.4M memory peak, 25M read from disk, 2.4M written to disk.
Nov 03 23:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:39:10 evo-x2 memory-emergency-guard-check[1719069]: MEMORY EMERGENCY IO-PAUSE (trip #6318, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 803ms CPU time over 8.276s wall clock time, 13.3M memory peak, 9.9M read from disk, 35.9M written to disk.
Nov 03 23:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:41:56 evo-x2 memory-emergency-guard-check[1864880]: MEMORY EMERGENCY IO-PAUSE (trip #6319, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 853ms CPU time over 23.989s wall clock time, 12.5M memory peak, 14M read from disk, 6.9M written to disk.
Nov 03 23:42:02 evo-x2 memory-emergency-guard-check[1912685]: MEMORY EMERGENCY still active (I/O PSI some avg60=93.89% sustained (max disk busy 100.0%, MemAvailable=44.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:44:23 evo-x2 memory-emergency-guard-check[2005709]: MEMORY EMERGENCY IO-PAUSE (trip #6320, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 818ms CPU time over 20.847s wall clock time, 11.4M memory peak, 30.6M read from disk, 3.2M written to disk.
Nov 03 23:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:46:39 evo-x2 memory-emergency-guard-check[2142237]: MEMORY EMERGENCY IO-PAUSE (trip #6321, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 6.543s wall clock time, 11.2M memory peak, 8.9M read from disk, 17.2M written to disk.
Nov 03 23:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:49:12 evo-x2 memory-emergency-guard-check[2262831]: MEMORY EMERGENCY IO-PAUSE (trip #6322, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 788ms CPU time over 9.992s wall clock time, 15.4M memory peak, 14.9M read from disk, 21.2M written to disk.
Nov 03 23:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:51:38 evo-x2 memory-emergency-guard-check[2342246]: MEMORY EMERGENCY IO-PAUSE (trip #6323, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.124s CPU time over 5.639s wall clock time, 9M memory peak, 7.3M read from disk, 45.9M written to disk.
Nov 03 23:52:03 evo-x2 memory-emergency-guard-check[2370514]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.55% sustained (max disk busy 85.0%, MemAvailable=50.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 23:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:58:35 evo-x2 memory-emergency-guard-check[2711602]: MEMORY EMERGENCY IO-PAUSE (trip #6324, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 23:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.181s CPU time over 2.840s wall clock time, 8.5M memory peak, 14M read from disk, 57M written to disk.
Nov 03 23:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 23:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:01:07 evo-x2 memory-emergency-guard-check[2822619]: MEMORY EMERGENCY IO-PAUSE (trip #6325, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 897ms CPU time over 4.630s wall clock time, 8.6M memory peak, 16K read from disk, 12.7M written to disk.
Nov 04 00:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:08:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:09:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 281ms wall clock time, 8.3M memory peak, 2M read from disk, 4K written to disk.
Nov 04 00:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:15:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:20:38 evo-x2 memory-emergency-guard-check[3610126]: MEMORY EMERGENCY IO-PAUSE (trip #6326, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.290s CPU time over 5.311s wall clock time, 9.5M memory peak, 19.3M read from disk, 78.5M written to disk.
Nov 04 00:21:04 evo-x2 memory-emergency-guard-check[3641184]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.65% sustained (max disk busy 99.9%, MemAvailable=43.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 00:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:23:12 evo-x2 memory-emergency-guard-check[3723487]: MEMORY EMERGENCY IO-PAUSE (trip #6327, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.338s CPU time over 9.260s wall clock time, 8.9M memory peak, 9.2M read from disk, 72.6M written to disk.
Nov 04 00:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:25:37 evo-x2 memory-emergency-guard-check[3871907]: MEMORY EMERGENCY IO-PAUSE (trip #6328, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 4.062s wall clock time, 12.5M memory peak, 4M read from disk, 41.1M written to disk.
Nov 04 00:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:28:06 evo-x2 memory-emergency-guard-check[4008063]: MEMORY EMERGENCY IO-PAUSE (trip #6329, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.134s CPU time over 2.703s wall clock time, 11.2M memory peak, 5.8M read from disk, 51.1M written to disk.
Nov 04 00:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:29:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:30:36 evo-x2 memory-emergency-guard-check[4138957]: MEMORY EMERGENCY IO-PAUSE (trip #6330, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 977ms CPU time over 2.506s wall clock time, 11.3M memory peak, 6M read from disk, 40.8M written to disk.
Nov 04 00:31:04 evo-x2 memory-emergency-guard-check[4164491]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.15% sustained (max disk busy 100.0%, MemAvailable=46.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 00:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:33:11 evo-x2 memory-emergency-guard-check[48828]: MEMORY EMERGENCY IO-PAUSE (trip #6331, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.201s CPU time over 7.441s wall clock time, 13.9M memory peak, 15.5M read from disk, 52.6M written to disk.
Nov 04 00:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:36:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:37:09 evo-x2 memory-emergency-guard-check[229098]: MEMORY EMERGENCY IO-PAUSE (trip #6332, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.074s CPU time over 5.898s wall clock time, 9.8M memory peak, 22.4M read from disk, 26.2M written to disk.
Nov 04 00:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:38:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:38:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:39:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:39:35 evo-x2 memory-emergency-guard-check[373443]: MEMORY EMERGENCY IO-PAUSE (trip #6333, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:39:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:39:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.073s CPU time over 1.749s wall clock time, 9.1M memory peak, 10.4M read from disk, 66M written to disk.
Nov 04 00:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:40:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:41:04 evo-x2 memory-emergency-guard-check[430848]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.32% sustained (max disk busy 97.2%, MemAvailable=48.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 00:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:41:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:42:05 evo-x2 memory-emergency-guard-check[468425]: MEMORY EMERGENCY IO-PAUSE (trip #6334, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 927ms CPU time over 1.247s wall clock time, 9.7M memory peak, 7.4M read from disk, 64.9M written to disk.
Nov 04 00:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:44:35 evo-x2 memory-emergency-guard-check[550203]: MEMORY EMERGENCY IO-PAUSE (trip #6335, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.196s CPU time over 1.531s wall clock time, 9M memory peak, 6.7M read from disk, 70.6M written to disk.
Nov 04 00:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:45:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:46:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:47:05 evo-x2 memory-emergency-guard-check[632110]: MEMORY EMERGENCY IO-PAUSE (trip #6336, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 996ms CPU time over 1.431s wall clock time, 10.4M memory peak, 9.5M read from disk, 84.9M written to disk.
Nov 04 00:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:48:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:49:34 evo-x2 memory-emergency-guard-check[704626]: MEMORY EMERGENCY IO-PAUSE (trip #6337, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 714ms CPU time over 864ms wall clock time, 10.2M memory peak, 1.8M read from disk, 57.6M written to disk.
Nov 04 00:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:52:37 evo-x2 memory-emergency-guard-check[750051]: MEMORY EMERGENCY IO-PAUSE (trip #6338, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 751ms CPU time over 3.799s wall clock time, 17.1M memory peak, 4.1M read from disk, 36.5M written to disk.
Nov 04 00:53:04 evo-x2 memory-emergency-guard-check[761957]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.90% sustained (max disk busy 47.3%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 00:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:53:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:54:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:55:07 evo-x2 memory-emergency-guard-check[789277]: MEMORY EMERGENCY IO-PAUSE (trip #6339, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 3.330s wall clock time, 11.5M memory peak, 6M read from disk, 53.9M written to disk.
Nov 04 00:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:57:36 evo-x2 memory-emergency-guard-check[833227]: MEMORY EMERGENCY IO-PAUSE (trip #6340, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 00:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 2.018s wall clock time, 11.2M memory peak, 752K read from disk, 36.6M written to disk.
Nov 04 00:58:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:58:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 00:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:00:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:01:36 evo-x2 memory-emergency-guard-check[897522]: MEMORY EMERGENCY IO-PAUSE (trip #6341, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 1.820s wall clock time, 12.2M memory peak, 1.1M read from disk, 34.4M written to disk.
Nov 04 01:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:03:04 evo-x2 memory-emergency-guard-check[923227]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.02% sustained (max disk busy 63.9%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:04:06 evo-x2 memory-emergency-guard-check[937267]: MEMORY EMERGENCY IO-PAUSE (trip #6342, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 2.452s wall clock time, 10.9M memory peak, 7.2M read from disk, 68.1M written to disk.
Nov 04 01:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:07:35 evo-x2 memory-emergency-guard-check[994380]: MEMORY EMERGENCY IO-PAUSE (trip #6343, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 918ms wall clock time, 12.3M memory peak, 1.1M read from disk, 54M written to disk.
Nov 04 01:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:10:35 evo-x2 memory-emergency-guard-check[1044084]: MEMORY EMERGENCY IO-PAUSE (trip #6344, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 659ms wall clock time, 10.7M memory peak, 816K read from disk, 37.2M written to disk.
Nov 04 01:11:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:13:35 evo-x2 memory-emergency-guard-check[1090907]: MEMORY EMERGENCY IO-PAUSE (trip #6345, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 767ms CPU time over 1.120s wall clock time, 11.2M memory peak, 6.1M read from disk, 13.7M written to disk.
Nov 04 01:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:14:34 evo-x2 memory-emergency-guard-check[1109227]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.18% sustained (max disk busy 30.4%, MemAvailable=55.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:16:05 evo-x2 memory-emergency-guard-check[1129574]: MEMORY EMERGENCY IO-PAUSE (trip #6346, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 597ms CPU time over 1.377s wall clock time, 12.9M memory peak, 912K read from disk, 36.8M written to disk.
Nov 04 01:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:18:36 evo-x2 memory-emergency-guard-check[1181491]: MEMORY EMERGENCY IO-PAUSE (trip #6347, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 1.582s wall clock time, 12.7M memory peak, 384K read from disk, 32.5M written to disk.
Nov 04 01:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:19:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:22:10 evo-x2 memory-emergency-guard-check[1237617]: MEMORY EMERGENCY IO-PAUSE (trip #6348, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 730ms CPU time over 5.651s wall clock time, 12.2M memory peak, 1M read from disk, 20M written to disk.
Nov 04 01:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:23:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:24:35 evo-x2 memory-emergency-guard-check[1278372]: MEMORY EMERGENCY IO-PAUSE (trip #6349, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:24:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:24:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 790ms wall clock time, 11.5M memory peak, 384K read from disk, 22.1M written to disk.
Nov 04 01:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:27:07 evo-x2 memory-emergency-guard-check[1319682]: MEMORY EMERGENCY IO-PAUSE (trip #6350, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 3.219s wall clock time, 12M memory peak, 656K read from disk, 60.2M written to disk.
Nov 04 01:27:34 evo-x2 memory-emergency-guard-check[1334989]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.28% sustained (max disk busy 37.7%, MemAvailable=49.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:27:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:28:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:29:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:29:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:30:12 evo-x2 memory-emergency-guard-check[1369875]: MEMORY EMERGENCY IO-PAUSE (trip #6351, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 540ms CPU time over 7.468s wall clock time, 11.8M memory peak, 304K read from disk, 2.5M written to disk.
Nov 04 01:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:32:37 evo-x2 memory-emergency-guard-check[1411573]: MEMORY EMERGENCY IO-PAUSE (trip #6352, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 2.476s wall clock time, 12.1M memory peak, 1.2M read from disk, 52M written to disk.
Nov 04 01:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:35:06 evo-x2 memory-emergency-guard-check[1452445]: MEMORY EMERGENCY IO-PAUSE (trip #6353, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 554ms CPU time over 1.837s wall clock time, 14.6M memory peak, 7.2M read from disk, 9.3M written to disk.
Nov 04 01:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:36:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:37:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:37:37 evo-x2 memory-emergency-guard-check[1495560]: MEMORY EMERGENCY IO-PAUSE (trip #6354, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 2.739s wall clock time, 11.4M memory peak, 6.4M read from disk, 53.8M written to disk.
Nov 04 01:38:04 evo-x2 memory-emergency-guard-check[1508910]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.06% sustained (max disk busy 31.1%, MemAvailable=50.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:38:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:38:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:39:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:39:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:40:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:40:37 evo-x2 memory-emergency-guard-check[1545138]: MEMORY EMERGENCY IO-PAUSE (trip #6355, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 775ms CPU time over 2.986s wall clock time, 11.3M memory peak, 2.6M read from disk, 71.9M written to disk.
Nov 04 01:41:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:41:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:42:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:43:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:43:36 evo-x2 memory-emergency-guard-check[1597132]: MEMORY EMERGENCY IO-PAUSE (trip #6356, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 584ms CPU time over 1.235s wall clock time, 11.6M memory peak, 2.2M read from disk, 33.1M written to disk.
Nov 04 01:44:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:45:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:46:07 evo-x2 memory-emergency-guard-check[1635858]: MEMORY EMERGENCY IO-PAUSE (trip #6357, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 615ms CPU time over 3.032s wall clock time, 10.2M memory peak, 1.5M read from disk, 47M written to disk.
Nov 04 01:46:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:48:05 evo-x2 memory-emergency-guard-check[1671972]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.01% sustained (max disk busy 29.8%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:48:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:49:35 evo-x2 memory-emergency-guard-check[1691997]: MEMORY EMERGENCY IO-PAUSE (trip #6358, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 934ms wall clock time, 11.1M memory peak, 640K read from disk, 62M written to disk.
Nov 04 01:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:50:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:51:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:51:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:52:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:52:42 evo-x2 memory-emergency-guard-check[1736898]: MEMORY EMERGENCY IO-PAUSE (trip #6359, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:52:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:52:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 7.809s wall clock time, 11.8M memory peak, 4M read from disk, 25.3M written to disk.
Nov 04 01:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:55:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:56:11 evo-x2 memory-emergency-guard-check[1787128]: MEMORY EMERGENCY IO-PAUSE (trip #6360, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 610ms CPU time over 6.563s wall clock time, 11.5M memory peak, 3.1M read from disk, 6.8M written to disk.
Nov 04 01:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:58:05 evo-x2 memory-emergency-guard-check[1823911]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.38% sustained (max disk busy 47.4%, MemAvailable=52.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 01:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:58:36 evo-x2 memory-emergency-guard-check[1829823]: MEMORY EMERGENCY IO-PAUSE (trip #6361, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 01:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 1.587s wall clock time, 12.9M memory peak, 1.2M read from disk, 53.6M written to disk.
Nov 04 01:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 01:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:01:07 evo-x2 memory-emergency-guard-check[1869694]: MEMORY EMERGENCY IO-PAUSE (trip #6362, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 783ms CPU time over 2.310s wall clock time, 11.1M memory peak, 2.5M read from disk, 55.1M written to disk.
Nov 04 02:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:03:38 evo-x2 memory-emergency-guard-check[1922598]: MEMORY EMERGENCY IO-PAUSE (trip #6363, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 3.037s wall clock time, 11.2M memory peak, 1.3M read from disk, 41.2M written to disk.
Nov 04 02:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:05:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:06:07 evo-x2 memory-emergency-guard-check[2010467]: MEMORY EMERGENCY IO-PAUSE (trip #6364, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 774ms CPU time over 1.904s wall clock time, 10M memory peak, 4.2M read from disk, 41.3M written to disk.
Nov 04 02:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:08:05 evo-x2 memory-emergency-guard-check[2077906]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.93% sustained (max disk busy 54.7%, MemAvailable=49.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:08:39 evo-x2 memory-emergency-guard-check[2085607]: MEMORY EMERGENCY IO-PAUSE (trip #6365, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 896ms CPU time over 4.199s wall clock time, 11.4M memory peak, 6.6M read from disk, 68.1M written to disk.
Nov 04 02:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:09:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:10:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:11:08 evo-x2 memory-emergency-guard-check[2198065]: MEMORY EMERGENCY IO-PAUSE (trip #6366, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.076s CPU time over 3.297s wall clock time, 10.5M memory peak, 1.7M read from disk, 47.1M written to disk.
Nov 04 02:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:13:38 evo-x2 memory-emergency-guard-check[2284204]: MEMORY EMERGENCY IO-PAUSE (trip #6367, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 734ms CPU time over 3.335s wall clock time, 10.6M memory peak, 1.6M read from disk, 42M written to disk.
Nov 04 02:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:15:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:16:07 evo-x2 memory-emergency-guard-check[2339085]: MEMORY EMERGENCY IO-PAUSE (trip #6368, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 1.803s wall clock time, 9.6M memory peak, 2.1M read from disk, 50.3M written to disk.
Nov 04 02:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:18:05 evo-x2 memory-emergency-guard-check[2379925]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.07% sustained (max disk busy 28.2%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:18:37 evo-x2 memory-emergency-guard-check[2387580]: MEMORY EMERGENCY IO-PAUSE (trip #6369, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 2.357s wall clock time, 10.8M memory peak, 1.9M read from disk, 51.8M written to disk.
Nov 04 02:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:21:06 evo-x2 memory-emergency-guard-check[2481748]: MEMORY EMERGENCY IO-PAUSE (trip #6370, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 1.071s wall clock time, 10.6M memory peak, 5.9M read from disk, 69.8M written to disk.
Nov 04 02:21:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:22:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:22:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:23:38 evo-x2 memory-emergency-guard-check[2605528]: MEMORY EMERGENCY IO-PAUSE (trip #6371, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 972ms CPU time over 2.367s wall clock time, 10.8M memory peak, 1.7M read from disk, 85.3M written to disk.
Nov 04 02:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 227ms CPU time over 318ms wall clock time, 10M memory peak, 2.8M read from disk, 4K written to disk.
Nov 04 02:25:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:26:37 evo-x2 memory-emergency-guard-check[2689720]: MEMORY EMERGENCY IO-PAUSE (trip #6372, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 1.668s wall clock time, 10.4M memory peak, 1.2M read from disk, 41.5M written to disk.
Nov 04 02:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:28:05 evo-x2 memory-emergency-guard-check[2726879]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.91% sustained (max disk busy 36.5%, MemAvailable=50.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:28:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:29:06 evo-x2 memory-emergency-guard-check[2740740]: MEMORY EMERGENCY IO-PAUSE (trip #6373, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 880ms wall clock time, 10.7M memory peak, 3.4M read from disk, 48.5M written to disk.
Nov 04 02:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:30:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:30:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:32:38 evo-x2 memory-emergency-guard-check[2822695]: MEMORY EMERGENCY IO-PAUSE (trip #6374, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 840ms CPU time over 2.853s wall clock time, 9.3M memory peak, 1.2M read from disk, 53.2M written to disk.
Nov 04 02:33:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:33:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:34:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:35:12 evo-x2 memory-emergency-guard-check[2954688]: MEMORY EMERGENCY IO-PAUSE (trip #6375, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 776ms CPU time over 6.632s wall clock time, 13.7M memory peak, 6.3M read from disk, 18.8M written to disk.
Nov 04 02:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:37:37 evo-x2 memory-emergency-guard-check[3068512]: MEMORY EMERGENCY IO-PAUSE (trip #6376, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 921ms CPU time over 1.668s wall clock time, 10.1M memory peak, 45M read from disk, 86.2M written to disk.
Nov 04 02:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:39:06 evo-x2 memory-emergency-guard-check[3168661]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.45% sustained (max disk busy 69.5%, MemAvailable=52.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:40:08 evo-x2 memory-emergency-guard-check[3230341]: MEMORY EMERGENCY IO-PAUSE (trip #6377, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 931ms CPU time over 2.670s wall clock time, 9.4M memory peak, 25.8M read from disk, 43.4M written to disk.
Nov 04 02:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:42:38 evo-x2 memory-emergency-guard-check[3313766]: MEMORY EMERGENCY IO-PAUSE (trip #6378, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 728ms CPU time over 2.337s wall clock time, 11.8M memory peak, 18.5M read from disk, 63.8M written to disk.
Nov 04 02:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:44:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:45:07 evo-x2 memory-emergency-guard-check[3377024]: MEMORY EMERGENCY IO-PAUSE (trip #6379, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 716ms CPU time over 1.829s wall clock time, 10.7M memory peak, 4M read from disk, 38.8M written to disk.
Nov 04 02:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:47:38 evo-x2 memory-emergency-guard-check[3457480]: MEMORY EMERGENCY IO-PAUSE (trip #6380, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 843ms CPU time over 2.262s wall clock time, 10M memory peak, 10.5M read from disk, 53.8M written to disk.
Nov 04 02:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:49:06 evo-x2 memory-emergency-guard-check[3495264]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.64% sustained (max disk busy 40.6%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:50:08 evo-x2 memory-emergency-guard-check[3512749]: MEMORY EMERGENCY IO-PAUSE (trip #6381, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 843ms CPU time over 2.685s wall clock time, 9.8M memory peak, 9.7M read from disk, 73.4M written to disk.
Nov 04 02:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:53:36 evo-x2 memory-emergency-guard-check[3650732]: MEMORY EMERGENCY IO-PAUSE (trip #6382, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 805ms wall clock time, 12M memory peak, 3.9M read from disk, 28M written to disk.
Nov 04 02:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:56:08 evo-x2 memory-emergency-guard-check[3725921]: MEMORY EMERGENCY IO-PAUSE (trip #6383, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 2.224s wall clock time, 9.6M memory peak, 1.6M read from disk, 23M written to disk.
Nov 04 02:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:57:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:58:38 evo-x2 memory-emergency-guard-check[3775448]: MEMORY EMERGENCY IO-PAUSE (trip #6384, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 02:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 1.829s wall clock time, 11.3M memory peak, 3.9M read from disk, 47.3M written to disk.
Nov 04 02:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 02:59:36 evo-x2 memory-emergency-guard-check[3807888]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.04% sustained (max disk busy 51.3%, MemAvailable=48.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 02:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:01:07 evo-x2 memory-emergency-guard-check[3827824]: MEMORY EMERGENCY IO-PAUSE (trip #6385, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 1.096s wall clock time, 10.5M memory peak, 8.6M read from disk, 55.9M written to disk.
Nov 04 03:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:03:37 evo-x2 memory-emergency-guard-check[3882670]: MEMORY EMERGENCY IO-PAUSE (trip #6386, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 849ms CPU time over 1.429s wall clock time, 9M memory peak, 496K read from disk, 23.1M written to disk.
Nov 04 03:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:06:08 evo-x2 memory-emergency-guard-check[3994138]: MEMORY EMERGENCY IO-PAUSE (trip #6387, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 935ms CPU time over 2.281s wall clock time, 9.5M memory peak, 8.8M read from disk, 33.7M written to disk.
Nov 04 03:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 218ms CPU time over 325ms wall clock time, 6.4M memory peak, 2.3M read from disk, 4K written to disk.
Nov 04 03:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:08:38 evo-x2 memory-emergency-guard-check[4062526]: MEMORY EMERGENCY IO-PAUSE (trip #6388, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 1.600s wall clock time, 11.3M memory peak, 4.5M read from disk, 29.9M written to disk.
Nov 04 03:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:09:36 evo-x2 memory-emergency-guard-check[4098528]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.03% sustained (max disk busy 30.1%, MemAvailable=51.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 03:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:11:08 evo-x2 memory-emergency-guard-check[4135131]: MEMORY EMERGENCY IO-PAUSE (trip #6389, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 673ms CPU time over 2.440s wall clock time, 16.2M memory peak, 8.5M read from disk, 39.9M written to disk.
Nov 04 03:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:13:37 evo-x2 memory-emergency-guard-check[58427]: MEMORY EMERGENCY IO-PAUSE (trip #6390, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 940ms wall clock time, 11M memory peak, 7M read from disk, 46.3M written to disk.
Nov 04 03:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:17:49 evo-x2 memory-emergency-guard-check[220484]: MEMORY EMERGENCY IO-PAUSE (trip #6391, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 611ms CPU time over 13.319s wall clock time, 10.8M memory peak, 4.7M read from disk, 14.9M written to disk.
Nov 04 03:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:19:36 evo-x2 memory-emergency-guard-check[270335]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.92% sustained (max disk busy 75.4%, MemAvailable=52.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 03:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:20:09 evo-x2 memory-emergency-guard-check[287319]: MEMORY EMERGENCY IO-PAUSE (trip #6392, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 821ms CPU time over 2.781s wall clock time, 9.9M memory peak, 5.1M read from disk, 62.1M written to disk.
Nov 04 03:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:22:38 evo-x2 memory-emergency-guard-check[402915]: MEMORY EMERGENCY IO-PAUSE (trip #6393, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 678ms CPU time over 1.973s wall clock time, 10.7M memory peak, 7.1M read from disk, 59.1M written to disk.
Nov 04 03:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:23:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:24:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:26:09 evo-x2 memory-emergency-guard-check[554109]: MEMORY EMERGENCY IO-PAUSE (trip #6394, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 977ms CPU time over 2.573s wall clock time, 9.7M memory peak, 1.9M read from disk, 33.1M written to disk.
Nov 04 03:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:29:02 evo-x2 memory-emergency-guard-check[637891]: MEMORY EMERGENCY IO-PAUSE (trip #6395, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.232s CPU time over 25.455s wall clock time, 11.4M memory peak, 5.1M read from disk, 141.7M written to disk.
Nov 04 03:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:30:36 evo-x2 memory-emergency-guard-check[728263]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.16% sustained (max disk busy 37.6%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 03:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:31:07 evo-x2 memory-emergency-guard-check[758660]: MEMORY EMERGENCY IO-PAUSE (trip #6396, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 975ms wall clock time, 11.8M memory peak, 1.8M read from disk, 68.4M written to disk.
Nov 04 03:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:33:38 evo-x2 memory-emergency-guard-check[863668]: MEMORY EMERGENCY IO-PAUSE (trip #6397, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 932ms CPU time over 1.711s wall clock time, 10.7M memory peak, 4.8M read from disk, 79.2M written to disk.
Nov 04 03:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:35:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:36:08 evo-x2 memory-emergency-guard-check[942772]: MEMORY EMERGENCY IO-PAUSE (trip #6398, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 1.433s wall clock time, 11M memory peak, 288K read from disk, 25.2M written to disk.
Nov 04 03:36:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:38:39 evo-x2 memory-emergency-guard-check[1027528]: MEMORY EMERGENCY IO-PAUSE (trip #6399, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.047s CPU time over 2.601s wall clock time, 9.4M memory peak, 11.2M read from disk, 40.7M written to disk.
Nov 04 03:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:40:37 evo-x2 memory-emergency-guard-check[1126303]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.19% sustained (max disk busy 99.9%, MemAvailable=48.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 03:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:41:10 evo-x2 memory-emergency-guard-check[1169914]: MEMORY EMERGENCY IO-PAUSE (trip #6400, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.334s CPU time over 3.968s wall clock time, 9.3M memory peak, 7.6M read from disk, 47.5M written to disk.
Nov 04 03:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:43:41 evo-x2 memory-emergency-guard-check[1299563]: MEMORY EMERGENCY IO-PAUSE (trip #6401, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.060s CPU time over 4.189s wall clock time, 11M memory peak, 38.3M read from disk, 87.5M written to disk.
Nov 04 03:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:46:08 evo-x2 memory-emergency-guard-check[1411934]: MEMORY EMERGENCY IO-PAUSE (trip #6402, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 1.407s wall clock time, 11M memory peak, 19.5M read from disk, 72M written to disk.
Nov 04 03:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:48:39 evo-x2 memory-emergency-guard-check[1562189]: MEMORY EMERGENCY IO-PAUSE (trip #6403, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 947ms CPU time over 2.255s wall clock time, 8.3M memory peak, 12.1M read from disk, 36.6M written to disk.
Nov 04 03:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:50:37 evo-x2 memory-emergency-guard-check[1643783]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.31% sustained (max disk busy 100.0%, MemAvailable=49.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 03:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:51:08 evo-x2 memory-emergency-guard-check[1662130]: MEMORY EMERGENCY IO-PAUSE (trip #6404, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 923ms CPU time over 1.810s wall clock time, 8.2M memory peak, 3.6M read from disk, 39.7M written to disk.
Nov 04 03:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:53:38 evo-x2 memory-emergency-guard-check[1773141]: MEMORY EMERGENCY IO-PAUSE (trip #6405, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 810ms CPU time over 1.088s wall clock time, 12.9M memory peak, 4.7M read from disk, 41M written to disk.
Nov 04 03:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 227ms CPU time over 370ms wall clock time, 7.5M memory peak, 2.5M read from disk, 4K written to disk.
Nov 04 03:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:56:09 evo-x2 memory-emergency-guard-check[1882542]: MEMORY EMERGENCY IO-PAUSE (trip #6406, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 919ms CPU time over 2.393s wall clock time, 12.4M memory peak, 30.9M read from disk, 49.9M written to disk.
Nov 04 03:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:58:41 evo-x2 memory-emergency-guard-check[2022259]: MEMORY EMERGENCY IO-PAUSE (trip #6407, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 03:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.285s CPU time over 4.565s wall clock time, 9.3M memory peak, 19.8M read from disk, 64.5M written to disk.
Nov 04 03:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 03:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:00:37 evo-x2 memory-emergency-guard-check[2101356]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.05% sustained (max disk busy 99.9%, MemAvailable=51.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 155ms wall clock time, 8.8M memory peak, 1.1M read from disk, 4K written to disk.
Nov 04 04:01:09 evo-x2 memory-emergency-guard-check[2121193]: MEMORY EMERGENCY IO-PAUSE (trip #6408, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.416s CPU time over 1.908s wall clock time, 10.3M memory peak, 6.9M read from disk, 50.8M written to disk.
Nov 04 04:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:03:39 evo-x2 memory-emergency-guard-check[2258236]: MEMORY EMERGENCY IO-PAUSE (trip #6409, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 920ms CPU time over 1.641s wall clock time, 10.6M memory peak, 2.5M read from disk, 37.2M written to disk.
Nov 04 04:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:06:08 evo-x2 memory-emergency-guard-check[2332654]: MEMORY EMERGENCY IO-PAUSE (trip #6410, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 764ms CPU time over 1.146s wall clock time, 10.2M memory peak, 3M read from disk, 44M written to disk.
Nov 04 04:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:08:57 evo-x2 memory-emergency-guard-check[2458006]: MEMORY EMERGENCY IO-PAUSE (trip #6411, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 815ms CPU time over 19.914s wall clock time, 11.9M memory peak, 13.7M read from disk, 60.2M written to disk.
Nov 04 04:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:10:37 evo-x2 memory-emergency-guard-check[2508968]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.51% sustained (max disk busy 100.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:11:09 evo-x2 memory-emergency-guard-check[2524234]: MEMORY EMERGENCY IO-PAUSE (trip #6412, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 855ms CPU time over 1.903s wall clock time, 11.2M memory peak, 12.6M read from disk, 48.8M written to disk.
Nov 04 04:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:12:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:13:56 evo-x2 memory-emergency-guard-check[2613204]: MEMORY EMERGENCY IO-PAUSE (trip #6413, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 974ms CPU time over 19.315s wall clock time, 10.5M memory peak, 20.6M read from disk, 85.2M written to disk.
Nov 04 04:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:15:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:16:10 evo-x2 memory-emergency-guard-check[2753483]: MEMORY EMERGENCY IO-PAUSE (trip #6414, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 2.956s wall clock time, 10.5M memory peak, 64.8M read from disk, 9.4M written to disk.
Nov 04 04:16:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:17:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:18:40 evo-x2 memory-emergency-guard-check[2819220]: MEMORY EMERGENCY IO-PAUSE (trip #6415, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 783ms CPU time over 2.693s wall clock time, 11M memory peak, 30.5M read from disk, 20.5M written to disk.
Nov 04 04:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:19:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:20:37 evo-x2 memory-emergency-guard-check[2914764]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.67% sustained (max disk busy 94.8%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:21:09 evo-x2 memory-emergency-guard-check[2943353]: MEMORY EMERGENCY IO-PAUSE (trip #6416, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.039s CPU time over 1.796s wall clock time, 8.4M memory peak, 8.6M read from disk, 39.8M written to disk.
Nov 04 04:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:23:39 evo-x2 memory-emergency-guard-check[3091027]: MEMORY EMERGENCY IO-PAUSE (trip #6417, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.111s CPU time over 1.693s wall clock time, 9.8M memory peak, 6M read from disk, 48.7M written to disk.
Nov 04 04:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:26:12 evo-x2 memory-emergency-guard-check[3209265]: MEMORY EMERGENCY IO-PAUSE (trip #6418, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.598s CPU time over 4.948s wall clock time, 7.9M memory peak, 10.7M read from disk, 79.3M written to disk.
Nov 04 04:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:28:50 evo-x2 memory-emergency-guard-check[3342879]: MEMORY EMERGENCY IO-PAUSE (trip #6419, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.033s CPU time over 12.749s wall clock time, 9.3M memory peak, 7.1M read from disk, 19.5M written to disk.
Nov 04 04:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:30:38 evo-x2 memory-emergency-guard-check[3450710]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.85% sustained (max disk busy 99.9%, MemAvailable=47.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:31:09 evo-x2 memory-emergency-guard-check[3470583]: MEMORY EMERGENCY IO-PAUSE (trip #6420, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 1.282s wall clock time, 11M memory peak, 5.3M read from disk, 9.5M written to disk.
Nov 04 04:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:33:53 evo-x2 memory-emergency-guard-check[3587687]: MEMORY EMERGENCY IO-PAUSE (trip #6421, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 944ms CPU time over 15.771s wall clock time, 12.2M memory peak, 1.9M read from disk, 40.2M written to disk.
Nov 04 04:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:37:07 evo-x2 memory-emergency-guard-check[3690652]: MEMORY EMERGENCY IO-PAUSE (trip #6422, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 59.488s wall clock time, 11.5M memory peak, 10.3M read from disk, 1.4M written to disk.
Nov 04 04:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:39:09 evo-x2 memory-emergency-guard-check[3760748]: MEMORY EMERGENCY IO-PAUSE (trip #6423, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.223s CPU time over 2.191s wall clock time, 9.2M memory peak, 2.7M read from disk, 26.8M written to disk.
Nov 04 04:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:40:37 evo-x2 memory-emergency-guard-check[3830740]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.69% sustained (max disk busy 95.7%, MemAvailable=47.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:41:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:41:40 evo-x2 memory-emergency-guard-check[3880405]: MEMORY EMERGENCY IO-PAUSE (trip #6424, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 3.117s wall clock time, 12.1M memory peak, 7.1M read from disk, 36M written to disk.
Nov 04 04:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:44:13 evo-x2 memory-emergency-guard-check[4024968]: MEMORY EMERGENCY IO-PAUSE (trip #6425, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.120s CPU time over 6.049s wall clock time, 12.1M memory peak, 19.3M read from disk, 44.4M written to disk.
Nov 04 04:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:46:41 evo-x2 memory-emergency-guard-check[4114774]: MEMORY EMERGENCY IO-PAUSE (trip #6426, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 949ms CPU time over 3.472s wall clock time, 12M memory peak, 9.5M read from disk, 59.6M written to disk.
Nov 04 04:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:49:11 evo-x2 memory-emergency-guard-check[65969]: MEMORY EMERGENCY IO-PAUSE (trip #6427, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 716ms CPU time over 3.711s wall clock time, 10.7M memory peak, 656K read from disk, 32.9M written to disk.
Nov 04 04:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:50:37 evo-x2 memory-emergency-guard-check[133545]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.22% sustained (max disk busy 100.0%, MemAvailable=51.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 04:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:51:39 evo-x2 memory-emergency-guard-check[157270]: MEMORY EMERGENCY IO-PAUSE (trip #6428, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 1.583s wall clock time, 10.7M memory peak, 4.3M read from disk, 13.9M written to disk.
Nov 04 04:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:54:10 evo-x2 memory-emergency-guard-check[296472]: MEMORY EMERGENCY IO-PAUSE (trip #6429, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 966ms CPU time over 2.718s wall clock time, 10.9M memory peak, 19.7M read from disk, 63M written to disk.
Nov 04 04:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:56:39 evo-x2 memory-emergency-guard-check[420080]: MEMORY EMERGENCY IO-PAUSE (trip #6430, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 887ms CPU time over 1.269s wall clock time, 10.2M memory peak, 15.2M read from disk, 69.1M written to disk.
Nov 04 04:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:59:11 evo-x2 memory-emergency-guard-check[519930]: MEMORY EMERGENCY IO-PAUSE (trip #6431, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 04:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 04:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 954ms CPU time over 3.359s wall clock time, 11M memory peak, 7.7M read from disk, 64.8M written to disk.
Nov 04 04:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:00:38 evo-x2 memory-emergency-guard-check[579158]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.31% sustained (max disk busy 100.0%, MemAvailable=48.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:01:54 evo-x2 memory-emergency-guard-check[598636]: MEMORY EMERGENCY IO-PAUSE (trip #6432, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 16.694s wall clock time, 10.7M memory peak, 12M read from disk, 3.1M written to disk.
Nov 04 05:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:04:12 evo-x2 memory-emergency-guard-check[687876]: MEMORY EMERGENCY IO-PAUSE (trip #6433, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.732s CPU time over 4.720s wall clock time, 10.1M memory peak, 12M read from disk, 106.1M written to disk.
Nov 04 05:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:06:39 evo-x2 memory-emergency-guard-check[775210]: MEMORY EMERGENCY IO-PAUSE (trip #6434, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 1.547s wall clock time, 10.5M memory peak, 1.5M read from disk, 42.2M written to disk.
Nov 04 05:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:07:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:09:10 evo-x2 memory-emergency-guard-check[890529]: MEMORY EMERGENCY IO-PAUSE (trip #6435, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 874ms CPU time over 2.396s wall clock time, 10.5M memory peak, 7.1M read from disk, 64.7M written to disk.
Nov 04 05:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:10:38 evo-x2 memory-emergency-guard-check[942605]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.93% sustained (max disk busy 100.0%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:11:39 evo-x2 memory-emergency-guard-check[982724]: MEMORY EMERGENCY IO-PAUSE (trip #6436, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 785ms CPU time over 1.178s wall clock time, 11.6M memory peak, 25.2M read from disk, 41.5M written to disk.
Nov 04 05:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:14:11 evo-x2 memory-emergency-guard-check[1107725]: MEMORY EMERGENCY IO-PAUSE (trip #6437, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.062s CPU time over 3.257s wall clock time, 11.6M memory peak, 44.1M read from disk, 87M written to disk.
Nov 04 05:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:16:39 evo-x2 memory-emergency-guard-check[1207794]: MEMORY EMERGENCY IO-PAUSE (trip #6438, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:16:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:16:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 840ms CPU time over 1.789s wall clock time, 10.9M memory peak, 7M read from disk, 8.1M written to disk.
Nov 04 05:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:18:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:19:09 evo-x2 memory-emergency-guard-check[1291814]: MEMORY EMERGENCY IO-PAUSE (trip #6439, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 807ms CPU time over 989ms wall clock time, 12.4M memory peak, 2.3M read from disk, 31.6M written to disk.
Nov 04 05:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:20:38 evo-x2 memory-emergency-guard-check[1368568]: MEMORY EMERGENCY still active (I/O PSI some avg60=91.17% sustained (max disk busy 100.0%, MemAvailable=45.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:21:39 evo-x2 memory-emergency-guard-check[1395218]: MEMORY EMERGENCY IO-PAUSE (trip #6440, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 767ms CPU time over 1.667s wall clock time, 13M memory peak, 2M read from disk, 45.5M written to disk.
Nov 04 05:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:24:09 evo-x2 memory-emergency-guard-check[1573723]: MEMORY EMERGENCY IO-PAUSE (trip #6441, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 819ms CPU time over 1.139s wall clock time, 10.9M memory peak, 10.6M read from disk, 54.7M written to disk.
Nov 04 05:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:26:43 evo-x2 memory-emergency-guard-check[1658272]: MEMORY EMERGENCY IO-PAUSE (trip #6442, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:26:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:26:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.200s CPU time over 5.098s wall clock time, 10M memory peak, 16.9M read from disk, 47.5M written to disk.
Nov 04 05:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:29:11 evo-x2 memory-emergency-guard-check[1814770]: MEMORY EMERGENCY IO-PAUSE (trip #6443, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.107s CPU time over 3.206s wall clock time, 10.2M memory peak, 17.3M read from disk, 77.1M written to disk.
Nov 04 05:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:30:38 evo-x2 memory-emergency-guard-check[1933367]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.37% sustained (max disk busy 91.1%, MemAvailable=48.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:31:39 evo-x2 memory-emergency-guard-check[2006280]: MEMORY EMERGENCY IO-PAUSE (trip #6444, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 889ms CPU time over 1.272s wall clock time, 12.3M memory peak, 8.9M read from disk, 48.9M written to disk.
Nov 04 05:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:34:13 evo-x2 memory-emergency-guard-check[2092916]: MEMORY EMERGENCY IO-PAUSE (trip #6445, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 975ms CPU time over 4.772s wall clock time, 10.5M memory peak, 8.4M read from disk, 71M written to disk.
Nov 04 05:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:36:41 evo-x2 memory-emergency-guard-check[2171397]: MEMORY EMERGENCY IO-PAUSE (trip #6446, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 796ms CPU time over 2.900s wall clock time, 10.1M memory peak, 9.5M read from disk, 41M written to disk.
Nov 04 05:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:37:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:38:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 145ms CPU time over 253ms wall clock time, 14.8M memory peak, 7.5M read from disk, 4K written to disk.
Nov 04 05:39:11 evo-x2 memory-emergency-guard-check[2233955]: MEMORY EMERGENCY IO-PAUSE (trip #6447, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 922ms CPU time over 2.650s wall clock time, 10M memory peak, 9.6M read from disk, 53.5M written to disk.
Nov 04 05:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:40:38 evo-x2 memory-emergency-guard-check[2307273]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.26% sustained (max disk busy 99.9%, MemAvailable=48.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:41:41 evo-x2 memory-emergency-guard-check[2348273]: MEMORY EMERGENCY IO-PAUSE (trip #6448, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.168s CPU time over 2.489s wall clock time, 8.1M memory peak, 2.1M read from disk, 29.8M written to disk.
Nov 04 05:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 184ms CPU time over 285ms wall clock time, 7.7M memory peak, 2.3M read from disk, 4K written to disk.
Nov 04 05:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:43:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:44:12 evo-x2 memory-emergency-guard-check[2491084]: MEMORY EMERGENCY IO-PAUSE (trip #6449, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.079s CPU time over 3.576s wall clock time, 8.7M memory peak, 14.4M read from disk, 67.8M written to disk.
Nov 04 05:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:46:40 evo-x2 memory-emergency-guard-check[2632008]: MEMORY EMERGENCY IO-PAUSE (trip #6450, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 2.148s wall clock time, 10.6M memory peak, 10M read from disk, 12.7M written to disk.
Nov 04 05:47:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:49:10 evo-x2 memory-emergency-guard-check[2729957]: MEMORY EMERGENCY IO-PAUSE (trip #6451, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 998ms CPU time over 1.742s wall clock time, 9M memory peak, 9.5M read from disk, 44.5M written to disk.
Nov 04 05:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:50:39 evo-x2 memory-emergency-guard-check[2778883]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.27% sustained (max disk busy 100.0%, MemAvailable=47.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 05:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:51:44 evo-x2 memory-emergency-guard-check[2807069]: MEMORY EMERGENCY IO-PAUSE (trip #6452, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.228s CPU time over 5.690s wall clock time, 11M memory peak, 22.7M read from disk, 27.2M written to disk.
Nov 04 05:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:54:12 evo-x2 memory-emergency-guard-check[2866394]: MEMORY EMERGENCY IO-PAUSE (trip #6453, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.275s CPU time over 3.175s wall clock time, 9.9M memory peak, 22.3M read from disk, 68M written to disk.
Nov 04 05:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:56:43 evo-x2 memory-emergency-guard-check[2932346]: MEMORY EMERGENCY IO-PAUSE (trip #6454, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.334s CPU time over 4.263s wall clock time, 11M memory peak, 39.1M read from disk, 74.3M written to disk.
Nov 04 05:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 178ms CPU time over 226ms wall clock time, 12.3M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 05:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:59:10 evo-x2 memory-emergency-guard-check[2992676]: MEMORY EMERGENCY IO-PAUSE (trip #6455, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 05:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 05:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.060s CPU time over 1.689s wall clock time, 10.9M memory peak, 29.1M read from disk, 62.9M written to disk.
Nov 04 05:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:00:39 evo-x2 memory-emergency-guard-check[3034025]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.16% sustained (max disk busy 100.0%, MemAvailable=45.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:01:40 evo-x2 memory-emergency-guard-check[3067006]: MEMORY EMERGENCY IO-PAUSE (trip #6456, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 1.768s wall clock time, 10.4M memory peak, 11.8M read from disk, 45.6M written to disk.
Nov 04 06:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:04:14 evo-x2 memory-emergency-guard-check[3130232]: MEMORY EMERGENCY IO-PAUSE (trip #6457, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 810ms CPU time over 4.840s wall clock time, 12M memory peak, 22.6M read from disk, 77.3M written to disk.
Nov 04 06:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:06:45 evo-x2 memory-emergency-guard-check[3269303]: MEMORY EMERGENCY IO-PAUSE (trip #6458, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 983ms CPU time over 6.562s wall clock time, 9.9M memory peak, 15.2M read from disk, 46M written to disk.
Nov 04 06:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:09:14 evo-x2 memory-emergency-guard-check[3389260]: MEMORY EMERGENCY IO-PAUSE (trip #6459, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.038s CPU time over 5.671s wall clock time, 9.1M memory peak, 7.7M read from disk, 28.1M written to disk.
Nov 04 06:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:10:39 evo-x2 memory-emergency-guard-check[3466502]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.74% sustained (max disk busy 68.3%, MemAvailable=46.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:11:41 evo-x2 memory-emergency-guard-check[3498396]: MEMORY EMERGENCY IO-PAUSE (trip #6460, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 955ms CPU time over 2.450s wall clock time, 9.6M memory peak, 8.9M read from disk, 55.8M written to disk.
Nov 04 06:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:14:14 evo-x2 memory-emergency-guard-check[3609896]: MEMORY EMERGENCY IO-PAUSE (trip #6461, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.274s CPU time over 5.403s wall clock time, 7.8M memory peak, 6.7M read from disk, 61.6M written to disk.
Nov 04 06:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:16:42 evo-x2 memory-emergency-guard-check[3710978]: MEMORY EMERGENCY IO-PAUSE (trip #6462, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.322s CPU time over 2.839s wall clock time, 10.1M memory peak, 12.2M read from disk, 76.4M written to disk.
Nov 04 06:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:19:13 evo-x2 memory-emergency-guard-check[3830556]: MEMORY EMERGENCY IO-PAUSE (trip #6463, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 940ms CPU time over 4.049s wall clock time, 9.7M memory peak, 14.4M read from disk, 45.8M written to disk.
Nov 04 06:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:20:39 evo-x2 memory-emergency-guard-check[3915556]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.26% sustained (max disk busy 99.5%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 173ms wall clock time, 13.1M memory peak, 4.3M read from disk, 4K written to disk.
Nov 04 06:21:42 evo-x2 memory-emergency-guard-check[3975707]: MEMORY EMERGENCY IO-PAUSE (trip #6464, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.164s CPU time over 2.922s wall clock time, 10.2M memory peak, 14.4M read from disk, 66M written to disk.
Nov 04 06:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:24:11 evo-x2 memory-emergency-guard-check[4088885]: MEMORY EMERGENCY IO-PAUSE (trip #6465, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.004s CPU time over 1.765s wall clock time, 10.9M memory peak, 20.3M read from disk, 43.4M written to disk.
Nov 04 06:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:26:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:26:42 evo-x2 memory-emergency-guard-check[4178875]: MEMORY EMERGENCY IO-PAUSE (trip #6466, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.043s CPU time over 3.019s wall clock time, 12.2M memory peak, 12.4M read from disk, 40.4M written to disk.
Nov 04 06:27:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:29:13 evo-x2 memory-emergency-guard-check[184217]: MEMORY EMERGENCY IO-PAUSE (trip #6467, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.487s CPU time over 3.980s wall clock time, 11M memory peak, 26.2M read from disk, 83.6M written to disk.
Nov 04 06:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 192ms CPU time over 512ms wall clock time, 9.8M memory peak, 5.1M read from disk, 4K written to disk.
Nov 04 06:30:39 evo-x2 memory-emergency-guard-check[266631]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.68% sustained (max disk busy 99.6%, MemAvailable=41.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:31:41 evo-x2 memory-emergency-guard-check[339976]: MEMORY EMERGENCY IO-PAUSE (trip #6468, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.055s CPU time over 2.253s wall clock time, 9.3M memory peak, 4.9M read from disk, 27.3M written to disk.
Nov 04 06:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 172ms CPU time over 244ms wall clock time, 11.7M memory peak, 5.3M read from disk, 4K written to disk.
Nov 04 06:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:34:11 evo-x2 memory-emergency-guard-check[478437]: MEMORY EMERGENCY IO-PAUSE (trip #6469, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.255s CPU time over 1.823s wall clock time, 11.5M memory peak, 12.8M read from disk, 87.3M written to disk.
Nov 04 06:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:38:26 evo-x2 memory-emergency-guard-check[663619]: MEMORY EMERGENCY IO-PAUSE (trip #6470, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.122s CPU time over 1min 46.957s wall clock time, 12.3M memory peak, 37.2M read from disk, 146.1M written to disk.
Nov 04 06:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:40:38 evo-x2 memory-emergency-guard-check[872122]: sort: write failed: 'standard output': Broken pipe
Nov 04 06:40:38 evo-x2 memory-emergency-guard-check[872122]: sort: write error
Nov 04 06:40:38 evo-x2 memory-emergency-guard-check[808015]: MEMORY EMERGENCY IO-PAUSE (trip #6471, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.076s CPU time over 1min 11.786s wall clock time, 10.6M memory peak, 17.3M read from disk, 32.9M written to disk.
Nov 04 06:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:41:09 evo-x2 memory-emergency-guard-check[908949]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.36% sustained (max disk busy 100.0%, MemAvailable=45.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (102s < 150s, 48s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:42:39 evo-x2 memory-emergency-guard-check[980321]: MEMORY EMERGENCY IO-PAUSE (trip #6472, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.324s CPU time over 31.165s wall clock time, 9.1M memory peak, 12.4M read from disk, 49.4M written to disk.
Nov 04 06:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:44:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:44:43 evo-x2 memory-emergency-guard-check[1156841]: MEMORY EMERGENCY IO-PAUSE (trip #6473, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:44:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:44:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.142s CPU time over 3.638s wall clock time, 8.1M memory peak, 11.1M read from disk, 32.2M written to disk.
Nov 04 06:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:47:45 evo-x2 memory-emergency-guard-check[1347609]: MEMORY EMERGENCY IO-PAUSE (trip #6474, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.125s CPU time over 35.636s wall clock time, 9.1M memory peak, 27.3M read from disk, 13.1M written to disk.
Nov 04 06:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:50:04 evo-x2 memory-emergency-guard-check[1444194]: MEMORY EMERGENCY IO-PAUSE (trip #6475, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.148s CPU time over 18.359s wall clock time, 8.8M memory peak, 15M read from disk, 28M written to disk.
Nov 04 06:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:51:15 evo-x2 memory-emergency-guard-check[1531438]: MEMORY EMERGENCY still active (I/O PSI some avg60=89.20% sustained (max disk busy 100.0%, MemAvailable=19.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (89s < 150s, 61s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 06:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:53:02 evo-x2 memory-emergency-guard-check[1584685]: MEMORY EMERGENCY IO-PAUSE (trip #6476, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.346s CPU time over 46.406s wall clock time, 16.2M memory peak, 11M read from disk, 122.3M written to disk.
Nov 04 06:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:55:11 evo-x2 memory-emergency-guard-check[1767398]: sort: write failed: 'standard output': Broken pipe
Nov 04 06:55:11 evo-x2 memory-emergency-guard-check[1767398]: sort: write error
Nov 04 06:55:12 evo-x2 memory-emergency-guard-check[1752803]: MEMORY EMERGENCY IO-PAUSE (trip #6477, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.234s CPU time over 9.928s wall clock time, 13.1M memory peak, 25.4M read from disk, 38.1M written to disk.
Nov 04 06:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 168ms CPU time over 246ms wall clock time, 7.6M memory peak, 1.1M read from disk, 4K written to disk.
Nov 04 06:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 189ms CPU time over 285ms wall clock time, 9.6M memory peak, 2.9M read from disk, 4K written to disk.
Nov 04 06:58:43 evo-x2 memory-emergency-guard-check[1881486]: MEMORY EMERGENCY IO-PAUSE (trip #6478, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 06:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.076s CPU time over 1min 11.381s wall clock time, 19.1M memory peak, 18.7M read from disk, 6M written to disk.
Nov 04 06:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:59:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 06:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:01:04 evo-x2 memory-emergency-guard-check[2041297]: MEMORY EMERGENCY IO-PAUSE (trip #6479, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.202s CPU time over 50.652s wall clock time, 9.4M memory peak, 15.3M read from disk, 8.4M written to disk.
Nov 04 07:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:01:34 evo-x2 memory-emergency-guard-check[2102046]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.59% sustained (max disk busy 100.0%, MemAvailable=45.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (81s < 150s, 69s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 196ms CPU time over 356ms wall clock time, 6.9M memory peak, 2.6M read from disk, 4K written to disk.
Nov 04 07:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:03:27 evo-x2 memory-emergency-guard-check[2172109]: MEMORY EMERGENCY IO-PAUSE (trip #6480, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.082s CPU time over 23.226s wall clock time, 8.6M memory peak, 10.7M read from disk, 34M written to disk.
Nov 04 07:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:05:54 evo-x2 memory-emergency-guard-check[2314503]: MEMORY EMERGENCY IO-PAUSE (trip #6481, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 706ms CPU time over 19.588s wall clock time, 10.9M memory peak, 13.7M read from disk, 4.5M written to disk.
Nov 04 07:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 157ms CPU time over 244ms wall clock time, 7.6M memory peak, 1.3M read from disk, 4K written to disk.
Nov 04 07:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 142ms CPU time over 305ms wall clock time, 9.9M memory peak, 3.6M read from disk, 4K written to disk.
Nov 04 07:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:08:13 evo-x2 memory-emergency-guard-check[2472192]: MEMORY EMERGENCY IO-PAUSE (trip #6482, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.196s CPU time over 9.187s wall clock time, 8.9M memory peak, 21.2M read from disk, 71.5M written to disk.
Nov 04 07:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 374ms wall clock time, 10.6M memory peak, 4.3M read from disk, 4K written to disk.
Nov 04 07:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 193ms CPU time over 355ms wall clock time, 6.8M memory peak, 1.4M read from disk, 4K written to disk.
Nov 04 07:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:11:06 evo-x2 memory-emergency-guard-check[2659033]: MEMORY EMERGENCY IO-PAUSE (trip #6483, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.159s CPU time over 2.372s wall clock time, 10.2M memory peak, 5M read from disk, 36.2M written to disk.
Nov 04 07:11:34 evo-x2 memory-emergency-guard-check[2692340]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.99% sustained (max disk busy 78.0%, MemAvailable=37.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 171ms CPU time over 291ms wall clock time, 6.9M memory peak, 1.8M read from disk, 4K written to disk.
Nov 04 07:14:07 evo-x2 memory-emergency-guard-check[2875183]: MEMORY EMERGENCY IO-PAUSE (trip #6484, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.093s CPU time over 2.761s wall clock time, 10M memory peak, 14.3M read from disk, 56.1M written to disk.
Nov 04 07:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:17:09 evo-x2 memory-emergency-guard-check[3032201]: MEMORY EMERGENCY IO-PAUSE (trip #6485, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.181s CPU time over 34.477s wall clock time, 9M memory peak, 29.3M read from disk, 32.7M written to disk.
Nov 04 07:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:19:16 evo-x2 memory-emergency-guard-check[3196033]: MEMORY EMERGENCY IO-PAUSE (trip #6486, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.290s CPU time over 7.341s wall clock time, 11.9M memory peak, 6.7M read from disk, 31M written to disk.
Nov 04 07:19:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:22:02 evo-x2 memory-emergency-guard-check[3330335]: MEMORY EMERGENCY IO-PAUSE (trip #6487, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.027s CPU time over 23.237s wall clock time, 10.5M memory peak, 14.3M read from disk, 22.6M written to disk.
Nov 04 07:22:09 evo-x2 memory-emergency-guard-check[3361654]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.85% sustained (max disk busy 100.0%, MemAvailable=33.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:24:20 evo-x2 memory-emergency-guard-check[3451688]: MEMORY EMERGENCY IO-PAUSE (trip #6488, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.118s CPU time over 10.918s wall clock time, 9.9M memory peak, 31.4M read from disk, 78.7M written to disk.
Nov 04 07:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:26:42 evo-x2 memory-emergency-guard-check[3606034]: MEMORY EMERGENCY IO-PAUSE (trip #6489, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 913ms CPU time over 3.357s wall clock time, 11.5M memory peak, 12.3M read from disk, 42.5M written to disk.
Nov 04 07:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:28:59 evo-x2 gatus[33393]: 2026/11/04 07:28:59 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Nov 04 07:29:14 evo-x2 memory-emergency-guard-check[3771320]: MEMORY EMERGENCY IO-PAUSE (trip #6490, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.084s CPU time over 4.804s wall clock time, 12.7M memory peak, 39.3M read from disk, 82.1M written to disk.
Nov 04 07:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 218ms CPU time over 277ms wall clock time, 7.7M memory peak, 1.5M read from disk, 4K written to disk.
Nov 04 07:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:31:45 evo-x2 memory-emergency-guard-check[3921136]: MEMORY EMERGENCY IO-PAUSE (trip #6491, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 850ms CPU time over 6.405s wall clock time, 13.2M memory peak, 16.3M read from disk, 46M written to disk.
Nov 04 07:32:09 evo-x2 memory-emergency-guard-check[3958413]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.41% sustained (max disk busy 99.1%, MemAvailable=27.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 169ms CPU time over 211ms wall clock time, 6.9M memory peak, 1.2M read from disk, 4K written to disk.
Nov 04 07:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:35:32 evo-x2 memory-emergency-guard-check[4046551]: MEMORY EMERGENCY IO-PAUSE (trip #6492, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 844ms CPU time over 1min 23.027s wall clock time, 13.3M memory peak, 33.9M read from disk, 20.7M written to disk.
Nov 04 07:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:39:09 evo-x2 memory-emergency-guard-check[4150222]: MEMORY EMERGENCY IO-PAUSE (trip #6493, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.534s CPU time over 2min 6.680s wall clock time, 12.9M memory peak, 288K memory swap peak, 77.7M read from disk, 83.9M written to disk.
Nov 04 07:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 196ms wall clock time, 9.7M memory peak, 2.7M read from disk, 4K written to disk.
Nov 04 07:39:41 evo-x2 memory-emergency-guard-check[27924]: MEMORY EMERGENCY IO-PAUSE (trip #6494, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 803ms CPU time over 1.991s wall clock time, 17.1M memory peak, 10.4M read from disk, 8.1M written to disk.
Nov 04 07:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:41:11 evo-x2 systemd[1916]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=18.88%, MemAvailable=46.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Nov 04 07:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:41:52 evo-x2 systemd[1916]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Nov 04 07:42:19 evo-x2 memory-emergency-guard-check[150153]: MEMORY EMERGENCY IO-PAUSE (trip #6495, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 976ms CPU time over 10.325s wall clock time, 15.9M memory peak, 16.6M read from disk, 46.9M written to disk.
Nov 04 07:42:39 evo-x2 memory-emergency-guard-check[182621]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.29% sustained (max disk busy 99.8%, MemAvailable=30.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 130ms CPU time over 179ms wall clock time, 11.7M memory peak, 2.9M read from disk, 4K written to disk.
Nov 04 07:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 124ms CPU time over 194ms wall clock time, 10.3M memory peak, 1.9M read from disk, 4K written to disk.
Nov 04 07:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:44:40 evo-x2 memory-emergency-guard-check[266481]: MEMORY EMERGENCY IO-PAUSE (trip #6496, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 1.423s wall clock time, 10.8M memory peak, 8.2M read from disk, 27.5M written to disk.
Nov 04 07:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 130ms CPU time over 169ms wall clock time, 10.8M memory peak, 3M read from disk, 4K written to disk.
Nov 04 07:47:12 evo-x2 memory-emergency-guard-check[376037]: MEMORY EMERGENCY IO-PAUSE (trip #6497, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 970ms CPU time over 2.618s wall clock time, 13.7M memory peak, 5.7M read from disk, 17.6M written to disk.
Nov 04 07:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:49:49 evo-x2 memory-emergency-guard-check[467522]: MEMORY EMERGENCY IO-PAUSE (trip #6498, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 10.564s wall clock time, 13.4M memory peak, 14.9M read from disk, 28.9M written to disk.
Nov 04 07:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 211ms wall clock time, 16.2M memory peak, 6.6M read from disk, 4K written to disk.
Nov 04 07:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:52:12 evo-x2 memory-emergency-guard-check[556272]: MEMORY EMERGENCY IO-PAUSE (trip #6499, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 808ms CPU time over 2.922s wall clock time, 12.3M memory peak, 33.6M read from disk, 32.9M written to disk.
Nov 04 07:52:39 evo-x2 memory-emergency-guard-check[575004]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.78% sustained (max disk busy 99.8%, MemAvailable=26.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 07:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 228ms wall clock time, 6M memory peak, 1.1M read from disk, 4K written to disk.
Nov 04 07:54:42 evo-x2 memory-emergency-guard-check[654038]: MEMORY EMERGENCY IO-PAUSE (trip #6500, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 971ms CPU time over 2.825s wall clock time, 11.1M memory peak, 37.6M read from disk, 88.5M written to disk.
Nov 04 07:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 142ms CPU time over 338ms wall clock time, 10.9M memory peak, 4.5M read from disk, 4K written to disk.
Nov 04 07:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 256ms wall clock time, 16.6M memory peak, 8.4M read from disk, 4K written to disk.
Nov 04 07:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 132ms CPU time over 199ms wall clock time, 8.7M memory peak, 1.4M read from disk, 4K written to disk.
Nov 04 07:57:12 evo-x2 memory-emergency-guard-check[722111]: MEMORY EMERGENCY IO-PAUSE (trip #6501, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 769ms CPU time over 2.815s wall clock time, 12.7M memory peak, 44.3M read from disk, 31M written to disk.
Nov 04 07:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:59:42 evo-x2 memory-emergency-guard-check[795697]: MEMORY EMERGENCY IO-PAUSE (trip #6502, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 07:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 07:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 845ms CPU time over 3.299s wall clock time, 19.3M memory peak, 40.4M read from disk, 7.1M written to disk.
Nov 04 08:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 177ms wall clock time, 13M memory peak, 4.4M read from disk, 4K written to disk.
Nov 04 08:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 194ms CPU time over 429ms wall clock time, 16.6M memory peak, 9.5M read from disk, 4K written to disk.
Nov 04 08:02:43 evo-x2 memory-emergency-guard-check[891734]: MEMORY EMERGENCY IO-PAUSE (trip #6503, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 808ms CPU time over 3.718s wall clock time, 10.6M memory peak, 42.6M read from disk, 51.4M written to disk.
Nov 04 08:03:09 evo-x2 memory-emergency-guard-check[910610]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.65% sustained (max disk busy 85.8%, MemAvailable=31.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 152ms CPU time over 303ms wall clock time, 7.8M memory peak, 2.1M read from disk, 4K written to disk.
Nov 04 08:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 147ms CPU time over 244ms wall clock time, 19.3M memory peak, 9.8M read from disk, 4K written to disk.
Nov 04 08:05:16 evo-x2 memory-emergency-guard-check[969563]: MEMORY EMERGENCY IO-PAUSE (trip #6504, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.037s CPU time over 6.633s wall clock time, 10.7M memory peak, 53.7M read from disk, 58.9M written to disk.
Nov 04 08:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 198ms CPU time over 288ms wall clock time, 10.6M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 08:05:43 evo-x2 systemd[1916]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Nov 04 08:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 226ms wall clock time, 8.5M memory peak, 1.2M read from disk, 4K written to disk.
Nov 04 08:07:41 evo-x2 memory-emergency-guard-check[1141522]: MEMORY EMERGENCY IO-PAUSE (trip #6505, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 1.401s wall clock time, 16.2M memory peak, 15.5M read from disk, 6.8M written to disk.
Nov 04 08:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:10:44 evo-x2 memory-emergency-guard-check[1285414]: MEMORY EMERGENCY IO-PAUSE (trip #6506, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 797ms CPU time over 4.994s wall clock time, 11.9M memory peak, 43.8M read from disk, 66.2M written to disk.
Nov 04 08:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 152ms CPU time over 222ms wall clock time, 9M memory peak, 5.4M read from disk, 4K written to disk.
Nov 04 08:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 235ms CPU time over 579ms wall clock time, 14.9M memory peak, 7.5M read from disk, 4K written to disk.
Nov 04 08:14:27 evo-x2 memory-emergency-guard-check[1412888]: MEMORY EMERGENCY IO-PAUSE (trip #6507, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.290s CPU time over 1min 17.435s wall clock time, 9.4M memory peak, 22M read from disk, 33.5M written to disk.
Nov 04 08:14:28 evo-x2 memory-emergency-guard-check[1450058]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.54% sustained (max disk busy 100.0%, MemAvailable=24.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (77s < 150s, 73s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:14:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:16:17 evo-x2 memory-emergency-guard-check[1523606]: MEMORY EMERGENCY IO-PAUSE (trip #6508, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.006s CPU time over 19.823s wall clock time, 10.6M memory peak, 13M read from disk, 1M written to disk.
Nov 04 08:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:17:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:19:24 evo-x2 memory-emergency-guard-check[1618771]: MEMORY EMERGENCY IO-PAUSE (trip #6509, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.153s CPU time over 57.041s wall clock time, 10.4M memory peak, 22.6M read from disk, 5.9M written to disk.
Nov 04 08:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 220ms CPU time over 2.734s wall clock time, 10.1M memory peak, 5.4M read from disk, 4K written to disk.
Nov 04 08:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 142ms CPU time over 750ms wall clock time, 7.5M memory peak, 1.9M read from disk, 4K written to disk.
Nov 04 08:23:48 evo-x2 memory-emergency-guard-check[1742257]: MEMORY EMERGENCY IO-PAUSE (trip #6510, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.227s CPU time over 2min 23.666s wall clock time, 10.1M memory peak, 88K memory swap peak, 30.5M read from disk, 14.3M written to disk.
Nov 04 08:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 201ms CPU time over 311ms wall clock time, 6.6M memory peak, 1.1M read from disk, 4K written to disk.
Nov 04 08:24:29 evo-x2 memory-emergency-guard-check[1822791]: MEMORY EMERGENCY IO-PAUSE (trip #6511, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 778ms CPU time over 10.534s wall clock time, 13.1M memory peak, 19.4M read from disk, 20.7M written to disk.
Nov 04 08:24:49 evo-x2 memory-emergency-guard-check[1847444]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.28% sustained (max disk busy 100.0%, MemAvailable=27.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 157ms CPU time over 284ms wall clock time, 14.2M memory peak, 6.2M read from disk, 4K written to disk.
Nov 04 08:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:26:52 evo-x2 memory-emergency-guard-check[1917925]: MEMORY EMERGENCY IO-PAUSE (trip #6512, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 858ms CPU time over 3.438s wall clock time, 11.9M memory peak, 20.1M read from disk, 26.9M written to disk.
Nov 04 08:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:30:03 evo-x2 memory-emergency-guard-check[2072386]: MEMORY EMERGENCY IO-PAUSE (trip #6513, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 750ms CPU time over 44.270s wall clock time, 11.4M memory peak, 12.4M read from disk, 22M written to disk.
Nov 04 08:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:32:54 evo-x2 memory-emergency-guard-check[2200190]: MEMORY EMERGENCY IO-PAUSE (trip #6514, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 51.022s wall clock time, 11.6M memory peak, 27M read from disk, 33.6M written to disk.
Nov 04 08:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:35:08 evo-x2 memory-emergency-guard-check[2372020]: MEMORY EMERGENCY IO-PAUSE (trip #6515, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 768ms CPU time over 14.424s wall clock time, 13.5M memory peak, 5.7M read from disk, 27.8M written to disk.
Nov 04 08:35:24 evo-x2 memory-emergency-guard-check[2407382]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.71% sustained (max disk busy 99.9%, MemAvailable=16.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:37:29 evo-x2 memory-emergency-guard-check[2467879]: MEMORY EMERGENCY IO-PAUSE (trip #6516, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 5.657s wall clock time, 11M memory peak, 19M read from disk, 23.2M written to disk.
Nov 04 08:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 123ms CPU time over 164ms wall clock time, 10.2M memory peak, 2.2M read from disk, 4K written to disk.
Nov 04 08:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 249ms wall clock time, 11.7M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 08:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:40:04 evo-x2 memory-emergency-guard-check[2538289]: MEMORY EMERGENCY IO-PAUSE (trip #6517, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 674ms CPU time over 10.674s wall clock time, 12.3M memory peak, 6.6M read from disk, 18.7M written to disk.
Nov 04 08:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:42:32 evo-x2 memory-emergency-guard-check[2585652]: MEMORY EMERGENCY IO-PAUSE (trip #6518, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 8.637s wall clock time, 13.2M memory peak, 6.1M read from disk, 12.9M written to disk.
Nov 04 08:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:45:04 evo-x2 memory-emergency-guard-check[2633117]: MEMORY EMERGENCY IO-PAUSE (trip #6519, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 10.611s wall clock time, 13.3M memory peak, 11.1M read from disk, 9M written to disk.
Nov 04 08:45:24 evo-x2 memory-emergency-guard-check[2648610]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.50% sustained (max disk busy 100.0%, MemAvailable=28.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:47:30 evo-x2 memory-emergency-guard-check[2683063]: MEMORY EMERGENCY IO-PAUSE (trip #6520, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 6.211s wall clock time, 13M memory peak, 13.3M read from disk, 41M written to disk.
Nov 04 08:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:50:04 evo-x2 memory-emergency-guard-check[2728968]: MEMORY EMERGENCY IO-PAUSE (trip #6521, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 598ms CPU time over 10.566s wall clock time, 11.5M memory peak, 10.2M read from disk, 19.2M written to disk.
Nov 04 08:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:52:25 evo-x2 memory-emergency-guard-check[2771766]: MEMORY EMERGENCY IO-PAUSE (trip #6522, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 635ms CPU time over 1.417s wall clock time, 11.6M memory peak, 9.7M read from disk, 29.6M written to disk.
Nov 04 08:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:54:58 evo-x2 memory-emergency-guard-check[2813217]: MEMORY EMERGENCY IO-PAUSE (trip #6523, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 3.542s wall clock time, 10.7M memory peak, 12M read from disk, 56.9M written to disk.
Nov 04 08:55:24 evo-x2 memory-emergency-guard-check[2824700]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.35% sustained (max disk busy 99.6%, MemAvailable=26.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 08:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:57:53 evo-x2 memory-emergency-guard-check[2858030]: MEMORY EMERGENCY IO-PAUSE (trip #6524, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 562ms CPU time over 28.788s wall clock time, 12.7M memory peak, 12.6M read from disk, 5.8M written to disk.
Nov 04 08:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 108ms CPU time over 137ms wall clock time, 10.3M memory peak, 1M read from disk, 4K written to disk.
Nov 04 08:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:59:56 evo-x2 memory-emergency-guard-check[2898284]: MEMORY EMERGENCY IO-PAUSE (trip #6525, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 08:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 08:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 2.367s wall clock time, 11.4M memory peak, 4.6M read from disk, 40.8M written to disk.
Nov 04 09:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:02:26 evo-x2 memory-emergency-guard-check[2940321]: MEMORY EMERGENCY IO-PAUSE (trip #6526, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 673ms CPU time over 1.450s wall clock time, 12.5M memory peak, 6.8M read from disk, 36.9M written to disk.
Nov 04 09:02:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:04:56 evo-x2 memory-emergency-guard-check[2991267]: MEMORY EMERGENCY IO-PAUSE (trip #6527, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 2.268s wall clock time, 13.9M memory peak, 27.7M read from disk, 54.5M written to disk.
Nov 04 09:05:24 evo-x2 memory-emergency-guard-check[3010080]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.44% sustained (max disk busy 89.9%, MemAvailable=28.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 156ms wall clock time, 15.1M memory peak, 5.8M read from disk, 4K written to disk.
Nov 04 09:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:07:26 evo-x2 memory-emergency-guard-check[3061398]: MEMORY EMERGENCY IO-PAUSE (trip #6528, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:07:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:07:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 751ms CPU time over 1.771s wall clock time, 12.3M memory peak, 6.1M read from disk, 53.2M written to disk.
Nov 04 09:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:09:57 evo-x2 memory-emergency-guard-check[3109647]: MEMORY EMERGENCY IO-PAUSE (trip #6529, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 2.748s wall clock time, 11.2M memory peak, 3.7M read from disk, 56.1M written to disk.
Nov 04 09:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:12:37 evo-x2 memory-emergency-guard-check[3168058]: MEMORY EMERGENCY IO-PAUSE (trip #6530, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:12:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:12:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 740ms CPU time over 12.348s wall clock time, 11.5M memory peak, 16.2M read from disk, 20.9M written to disk.
Nov 04 09:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:14:59 evo-x2 memory-emergency-guard-check[3207493]: MEMORY EMERGENCY IO-PAUSE (trip #6531, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 4.713s wall clock time, 11.4M memory peak, 8.3M read from disk, 57.7M written to disk.
Nov 04 09:15:24 evo-x2 memory-emergency-guard-check[3218598]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.93% sustained (max disk busy 98.5%, MemAvailable=27.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:17:27 evo-x2 memory-emergency-guard-check[3248083]: MEMORY EMERGENCY IO-PAUSE (trip #6532, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 3.014s wall clock time, 10.3M memory peak, 4.9M read from disk, 62.5M written to disk.
Nov 04 09:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:19:58 evo-x2 memory-emergency-guard-check[3289833]: MEMORY EMERGENCY IO-PAUSE (trip #6533, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 3.977s wall clock time, 12.4M memory peak, 5.4M read from disk, 55.2M written to disk.
Nov 04 09:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:22:27 evo-x2 memory-emergency-guard-check[3330192]: MEMORY EMERGENCY IO-PAUSE (trip #6534, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 705ms CPU time over 2.878s wall clock time, 11M memory peak, 27.1M read from disk, 50.2M written to disk.
Nov 04 09:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:25:07 evo-x2 memory-emergency-guard-check[3374596]: MEMORY EMERGENCY IO-PAUSE (trip #6535, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 12.852s wall clock time, 13.5M memory peak, 2.6M read from disk, 29M written to disk.
Nov 04 09:25:25 evo-x2 memory-emergency-guard-check[3389574]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.40% sustained (max disk busy 96.9%, MemAvailable=27.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:27:25 evo-x2 memory-emergency-guard-check[3420782]: MEMORY EMERGENCY IO-PAUSE (trip #6536, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 910ms wall clock time, 11.9M memory peak, 5.3M read from disk, 46M written to disk.
Nov 04 09:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:29:56 evo-x2 memory-emergency-guard-check[3468825]: MEMORY EMERGENCY IO-PAUSE (trip #6537, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 704ms CPU time over 1.417s wall clock time, 11.7M memory peak, 5.8M read from disk, 40.7M written to disk.
Nov 04 09:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:31:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:32:26 evo-x2 memory-emergency-guard-check[3548946]: MEMORY EMERGENCY IO-PAUSE (trip #6538, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 1.897s wall clock time, 11.2M memory peak, 16.6M read from disk, 39.4M written to disk.
Nov 04 09:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:34:58 evo-x2 memory-emergency-guard-check[3596632]: MEMORY EMERGENCY IO-PAUSE (trip #6539, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 731ms CPU time over 2.901s wall clock time, 11.7M memory peak, 25.2M read from disk, 48.1M written to disk.
Nov 04 09:35:25 evo-x2 memory-emergency-guard-check[3611618]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.16% sustained (max disk busy 96.4%, MemAvailable=25.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:35:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:35:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 149ms wall clock time, 11.2M memory peak, 2.7M read from disk, 4K written to disk.
Nov 04 09:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:36:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:37:28 evo-x2 memory-emergency-guard-check[3642783]: MEMORY EMERGENCY IO-PAUSE (trip #6540, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 3.397s wall clock time, 11.8M memory peak, 18.7M read from disk, 59.8M written to disk.
Nov 04 09:37:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:38:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:39:56 evo-x2 memory-emergency-guard-check[3691213]: MEMORY EMERGENCY IO-PAUSE (trip #6541, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 629ms CPU time over 1.526s wall clock time, 13.2M memory peak, 7.4M read from disk, 51.5M written to disk.
Nov 04 09:40:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 136ms wall clock time, 9.9M memory peak, 1.3M read from disk, 4K written to disk.
Nov 04 09:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:42:27 evo-x2 memory-emergency-guard-check[3734493]: MEMORY EMERGENCY IO-PAUSE (trip #6542, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 2.519s wall clock time, 10.9M memory peak, 4.8M read from disk, 52.7M written to disk.
Nov 04 09:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:43:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:44:57 evo-x2 memory-emergency-guard-check[3794437]: MEMORY EMERGENCY IO-PAUSE (trip #6543, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 676ms CPU time over 1.912s wall clock time, 11.6M memory peak, 15.5M read from disk, 51.6M written to disk.
Nov 04 09:45:25 evo-x2 memory-emergency-guard-check[3806617]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.86% sustained (max disk busy 89.5%, MemAvailable=29.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:45:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:46:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:46:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:47:26 evo-x2 memory-emergency-guard-check[3833764]: MEMORY EMERGENCY IO-PAUSE (trip #6544, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 886ms wall clock time, 11.2M memory peak, 15.2M read from disk, 53.4M written to disk.
Nov 04 09:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:49:57 evo-x2 memory-emergency-guard-check[3875115]: MEMORY EMERGENCY IO-PAUSE (trip #6545, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 703ms CPU time over 2.122s wall clock time, 11.9M memory peak, 16.7M read from disk, 55.8M written to disk.
Nov 04 09:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:52:27 evo-x2 memory-emergency-guard-check[3912505]: MEMORY EMERGENCY IO-PAUSE (trip #6546, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 2.194s wall clock time, 11M memory peak, 4.7M read from disk, 46.2M written to disk.
Nov 04 09:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:54:58 evo-x2 memory-emergency-guard-check[3950201]: MEMORY EMERGENCY IO-PAUSE (trip #6547, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 3.012s wall clock time, 10.9M memory peak, 5.6M read from disk, 57.5M written to disk.
Nov 04 09:55:25 evo-x2 memory-emergency-guard-check[3961686]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.45% sustained (max disk busy 85.0%, MemAvailable=29.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 09:55:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:56:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:57:26 evo-x2 memory-emergency-guard-check[3987137]: MEMORY EMERGENCY IO-PAUSE (trip #6548, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:57:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:57:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 674ms CPU time over 948ms wall clock time, 10.9M memory peak, 19.1M read from disk, 52.2M written to disk.
Nov 04 09:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 108ms CPU time over 141ms wall clock time, 8.9M memory peak, 1M read from disk, 4K written to disk.
Nov 04 09:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:59:58 evo-x2 memory-emergency-guard-check[4027772]: MEMORY EMERGENCY IO-PAUSE (trip #6549, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 09:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 09:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 2.767s wall clock time, 11.8M memory peak, 19.9M read from disk, 48.9M written to disk.
Nov 04 10:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:01:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:02:28 evo-x2 memory-emergency-guard-check[4088385]: MEMORY EMERGENCY IO-PAUSE (trip #6550, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 710ms CPU time over 2.432s wall clock time, 12.3M memory peak, 23.6M read from disk, 56M written to disk.
Nov 04 10:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:04:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:04:58 evo-x2 memory-emergency-guard-check[4132309]: MEMORY EMERGENCY IO-PAUSE (trip #6551, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 2.751s wall clock time, 11.5M memory peak, 6.7M read from disk, 14.9M written to disk.
Nov 04 10:05:25 evo-x2 memory-emergency-guard-check[4146017]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.84% sustained (max disk busy 78.4%, MemAvailable=29.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:05:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:06:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:07:28 evo-x2 memory-emergency-guard-check[4173685]: MEMORY EMERGENCY IO-PAUSE (trip #6552, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 764ms CPU time over 2.604s wall clock time, 11M memory peak, 34.9M read from disk, 62.5M written to disk.
Nov 04 10:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:09:56 evo-x2 memory-emergency-guard-check[22136]: MEMORY EMERGENCY IO-PAUSE (trip #6553, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 1.078s wall clock time, 12.3M memory peak, 23.8M read from disk, 68.4M written to disk.
Nov 04 10:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:12:27 evo-x2 memory-emergency-guard-check[67289]: MEMORY EMERGENCY IO-PAUSE (trip #6554, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 2.214s wall clock time, 11.4M memory peak, 3.1M read from disk, 46M written to disk.
Nov 04 10:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:15:19 evo-x2 memory-emergency-guard-check[118338]: MEMORY EMERGENCY IO-PAUSE (trip #6555, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 23.696s wall clock time, 12M memory peak, 15.6M read from disk, 38.4M written to disk.
Nov 04 10:15:25 evo-x2 memory-emergency-guard-check[129658]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.90% sustained (max disk busy 99.6%, MemAvailable=26.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:17:28 evo-x2 memory-emergency-guard-check[156526]: MEMORY EMERGENCY IO-PAUSE (trip #6556, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:17:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:17:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 2.595s wall clock time, 13.2M memory peak, 20.9M read from disk, 72.7M written to disk.
Nov 04 10:17:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:18:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:18:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:19:57 evo-x2 memory-emergency-guard-check[200631]: MEMORY EMERGENCY IO-PAUSE (trip #6557, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 676ms CPU time over 2.031s wall clock time, 11.7M memory peak, 5.2M read from disk, 45.9M written to disk.
Nov 04 10:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:21:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:22:27 evo-x2 memory-emergency-guard-check[242692]: MEMORY EMERGENCY IO-PAUSE (trip #6558, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 1.742s wall clock time, 12.4M memory peak, 18M read from disk, 42.7M written to disk.
Nov 04 10:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:24:58 evo-x2 memory-emergency-guard-check[284472]: MEMORY EMERGENCY IO-PAUSE (trip #6559, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 692ms CPU time over 2.482s wall clock time, 12.1M memory peak, 6.4M read from disk, 53.2M written to disk.
Nov 04 10:25:26 evo-x2 memory-emergency-guard-check[297068]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.09% sustained (max disk busy 97.7%, MemAvailable=28.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:27:26 evo-x2 memory-emergency-guard-check[323450]: MEMORY EMERGENCY IO-PAUSE (trip #6560, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 801ms wall clock time, 11.7M memory peak, 3M read from disk, 40.3M written to disk.
Nov 04 10:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:30:00 evo-x2 memory-emergency-guard-check[362738]: MEMORY EMERGENCY IO-PAUSE (trip #6561, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 4.152s wall clock time, 12.4M memory peak, 6.5M read from disk, 57.1M written to disk.
Nov 04 10:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:32:28 evo-x2 memory-emergency-guard-check[398879]: MEMORY EMERGENCY IO-PAUSE (trip #6562, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 2.355s wall clock time, 11.2M memory peak, 4M read from disk, 52.5M written to disk.
Nov 04 10:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:33:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:34:59 evo-x2 memory-emergency-guard-check[435770]: MEMORY EMERGENCY IO-PAUSE (trip #6563, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 2.909s wall clock time, 10.7M memory peak, 23.8M read from disk, 44M written to disk.
Nov 04 10:35:26 evo-x2 memory-emergency-guard-check[446934]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.47% sustained (max disk busy 83.1%, MemAvailable=29.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:37:29 evo-x2 memory-emergency-guard-check[474017]: MEMORY EMERGENCY IO-PAUSE (trip #6564, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 710ms CPU time over 3.309s wall clock time, 10.4M memory peak, 13.5M read from disk, 61.6M written to disk.
Nov 04 10:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:39:57 evo-x2 memory-emergency-guard-check[520156]: MEMORY EMERGENCY IO-PAUSE (trip #6565, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 901ms CPU time over 1.078s wall clock time, 10.3M memory peak, 4.4M read from disk, 41M written to disk.
Nov 04 10:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:40:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 226ms wall clock time, 13.3M memory peak, 5M read from disk, 4K written to disk.
Nov 04 10:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 164ms wall clock time, 15.8M memory peak, 6.1M read from disk, 4K written to disk.
Nov 04 10:42:28 evo-x2 memory-emergency-guard-check[564362]: MEMORY EMERGENCY IO-PAUSE (trip #6566, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 746ms CPU time over 2.543s wall clock time, 11.5M memory peak, 36.5M read from disk, 61.8M written to disk.
Nov 04 10:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:44:57 evo-x2 memory-emergency-guard-check[608678]: MEMORY EMERGENCY IO-PAUSE (trip #6567, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 1.010s wall clock time, 12.3M memory peak, 17.6M read from disk, 50.5M written to disk.
Nov 04 10:45:26 evo-x2 memory-emergency-guard-check[623510]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.54% sustained (max disk busy 93.0%, MemAvailable=31.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:47:28 evo-x2 memory-emergency-guard-check[656558]: MEMORY EMERGENCY IO-PAUSE (trip #6568, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 1.928s wall clock time, 11.2M memory peak, 9M read from disk, 49M written to disk.
Nov 04 10:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:49:58 evo-x2 memory-emergency-guard-check[703199]: MEMORY EMERGENCY IO-PAUSE (trip #6569, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 2.159s wall clock time, 12.4M memory peak, 4.1M read from disk, 50.8M written to disk.
Nov 04 10:50:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:51:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:52:28 evo-x2 memory-emergency-guard-check[764914]: MEMORY EMERGENCY IO-PAUSE (trip #6570, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 1.926s wall clock time, 13.6M memory peak, 21.3M read from disk, 43.8M written to disk.
Nov 04 10:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:54:59 evo-x2 memory-emergency-guard-check[809079]: MEMORY EMERGENCY IO-PAUSE (trip #6571, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 753ms CPU time over 3.471s wall clock time, 11.8M memory peak, 16M read from disk, 68.6M written to disk.
Nov 04 10:55:26 evo-x2 memory-emergency-guard-check[823180]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.71% sustained (max disk busy 88.1%, MemAvailable=28.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 10:55:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:55:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:56:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 163ms wall clock time, 17.8M memory peak, 7.3M read from disk, 4K written to disk.
Nov 04 10:56:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:57:27 evo-x2 memory-emergency-guard-check[851817]: MEMORY EMERGENCY IO-PAUSE (trip #6572, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 1.317s wall clock time, 11.6M memory peak, 43.6M read from disk, 81.9M written to disk.
Nov 04 10:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:59:58 evo-x2 memory-emergency-guard-check[922410]: MEMORY EMERGENCY IO-PAUSE (trip #6573, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 10:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 10:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 2.071s wall clock time, 11.2M memory peak, 7.8M read from disk, 51.1M written to disk.
Nov 04 11:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:02:29 evo-x2 memory-emergency-guard-check[963553]: MEMORY EMERGENCY IO-PAUSE (trip #6574, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 2.915s wall clock time, 10.5M memory peak, 15.2M read from disk, 51.8M written to disk.
Nov 04 11:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 106ms CPU time over 131ms wall clock time, 9M memory peak, 1.5M read from disk, 4K written to disk.
Nov 04 11:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:04:58 evo-x2 memory-emergency-guard-check[1002556]: MEMORY EMERGENCY IO-PAUSE (trip #6575, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 1.876s wall clock time, 10.9M memory peak, 7.1M read from disk, 20.8M written to disk.
Nov 04 11:05:26 evo-x2 memory-emergency-guard-check[1014738]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.73% sustained (max disk busy 82.7%, MemAvailable=28.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:05:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:05:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:06:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:06:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:07:28 evo-x2 memory-emergency-guard-check[1040852]: MEMORY EMERGENCY IO-PAUSE (trip #6576, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 1.899s wall clock time, 10.7M memory peak, 40.9M read from disk, 69.8M written to disk.
Nov 04 11:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:08:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:09:57 evo-x2 memory-emergency-guard-check[1079967]: MEMORY EMERGENCY IO-PAUSE (trip #6577, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 605ms CPU time over 862ms wall clock time, 11.2M memory peak, 21M read from disk, 36.3M written to disk.
Nov 04 11:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:12:30 evo-x2 memory-emergency-guard-check[1116940]: MEMORY EMERGENCY IO-PAUSE (trip #6578, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 4.001s wall clock time, 12.7M memory peak, 36.3M read from disk, 19.8M written to disk.
Nov 04 11:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:13:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:15:05 evo-x2 memory-emergency-guard-check[1157078]: MEMORY EMERGENCY IO-PAUSE (trip #6579, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:15:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:15:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 8.715s wall clock time, 11.9M memory peak, 25.3M read from disk, 48.3M written to disk.
Nov 04 11:15:27 evo-x2 memory-emergency-guard-check[1169254]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.50% sustained (max disk busy 99.5%, MemAvailable=28.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 204ms wall clock time, 16.1M memory peak, 9.2M read from disk, 4K written to disk.
Nov 04 11:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:17:50 evo-x2 memory-emergency-guard-check[1198901]: MEMORY EMERGENCY IO-PAUSE (trip #6580, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 600ms CPU time over 23.229s wall clock time, 11.6M memory peak, 15.4M read from disk, 43.9M written to disk.
Nov 04 11:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:19:59 evo-x2 memory-emergency-guard-check[1239287]: MEMORY EMERGENCY IO-PAUSE (trip #6581, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 532ms CPU time over 2.215s wall clock time, 12.5M memory peak, 2.9M read from disk, 5.5M written to disk.
Nov 04 11:20:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:21:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:21:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:22:29 evo-x2 memory-emergency-guard-check[1277163]: MEMORY EMERGENCY IO-PAUSE (trip #6582, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 2.171s wall clock time, 10.8M memory peak, 8.6M read from disk, 47.2M written to disk.
Nov 04 11:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:24:59 evo-x2 memory-emergency-guard-check[1333517]: MEMORY EMERGENCY IO-PAUSE (trip #6583, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 658ms CPU time over 2.140s wall clock time, 11.3M memory peak, 5.9M read from disk, 51.8M written to disk.
Nov 04 11:25:27 evo-x2 memory-emergency-guard-check[1345346]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.16% sustained (max disk busy 28.9%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:25:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:26:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:29:28 evo-x2 memory-emergency-guard-check[1399689]: MEMORY EMERGENCY IO-PAUSE (trip #6584, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:29:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:29:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 872ms wall clock time, 12.1M memory peak, 6.5M read from disk, 40.4M written to disk.
Nov 04 11:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:33:33 evo-x2 memory-emergency-guard-check[1485767]: MEMORY EMERGENCY IO-PAUSE (trip #6585, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 5.993s wall clock time, 11.9M memory peak, 3.2M read from disk, 42M written to disk.
Nov 04 11:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:35:27 evo-x2 memory-emergency-guard-check[1529139]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.86% sustained (max disk busy 38.3%, MemAvailable=29.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:38:57 evo-x2 memory-emergency-guard-check[1591091]: MEMORY EMERGENCY IO-PAUSE (trip #6586, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 554ms CPU time over 697ms wall clock time, 11.1M memory peak, 1.9M read from disk, 30.1M written to disk.
Nov 04 11:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:41:29 evo-x2 memory-emergency-guard-check[1627163]: MEMORY EMERGENCY IO-PAUSE (trip #6587, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 2.267s wall clock time, 10.6M memory peak, 18.2M read from disk, 48.4M written to disk.
Nov 04 11:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:45:29 evo-x2 memory-emergency-guard-check[1683462]: MEMORY EMERGENCY IO-PAUSE (trip #6588, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 2.324s wall clock time, 11.1M memory peak, 36.3M read from disk, 51.1M written to disk.
Nov 04 11:45:57 evo-x2 memory-emergency-guard-check[1696798]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.66% sustained (max disk busy 25.6%, MemAvailable=30.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:47:58 evo-x2 memory-emergency-guard-check[1726078]: MEMORY EMERGENCY IO-PAUSE (trip #6589, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 630ms CPU time over 1.236s wall clock time, 13M memory peak, 6.1M read from disk, 29.4M written to disk.
Nov 04 11:48:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 102ms CPU time over 151ms wall clock time, 16.6M memory peak, 6.4M read from disk, 4K written to disk.
Nov 04 11:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:51:28 evo-x2 memory-emergency-guard-check[1781875]: MEMORY EMERGENCY IO-PAUSE (trip #6590, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 710ms CPU time over 1.047s wall clock time, 12M memory peak, 14.2M read from disk, 61M written to disk.
Nov 04 11:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:54:30 evo-x2 memory-emergency-guard-check[1836544]: MEMORY EMERGENCY IO-PAUSE (trip #6591, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 690ms CPU time over 3.208s wall clock time, 12.4M memory peak, 7M read from disk, 55.2M written to disk.
Nov 04 11:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:55:57 evo-x2 memory-emergency-guard-check[1867014]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.96% sustained (max disk busy 47.1%, MemAvailable=29.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 11:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:58:29 evo-x2 memory-emergency-guard-check[1910378]: MEMORY EMERGENCY IO-PAUSE (trip #6592, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 11:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 2.070s wall clock time, 24.8M memory peak, 28.4M read from disk, 31.7M written to disk.
Nov 04 11:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 11:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:00:58 evo-x2 memory-emergency-guard-check[1955400]: MEMORY EMERGENCY IO-PAUSE (trip #6593, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 739ms CPU time over 1.043s wall clock time, 12.2M memory peak, 8.6M read from disk, 54.1M written to disk.
Nov 04 12:01:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:03:58 evo-x2 memory-emergency-guard-check[2012150]: MEMORY EMERGENCY IO-PAUSE (trip #6594, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 1.022s wall clock time, 11M memory peak, 31.8M read from disk, 56.5M written to disk.
Nov 04 12:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:07:32 evo-x2 memory-emergency-guard-check[2089519]: MEMORY EMERGENCY IO-PAUSE (trip #6595, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 4.402s wall clock time, 11.6M memory peak, 4.7M read from disk, 28.4M written to disk.
Nov 04 12:07:57 evo-x2 memory-emergency-guard-check[2105127]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.95% sustained (max disk busy 27.0%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 12:07:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:09:59 evo-x2 memory-emergency-guard-check[2133724]: MEMORY EMERGENCY IO-PAUSE (trip #6596, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 632ms CPU time over 1.655s wall clock time, 12.4M memory peak, 3.5M read from disk, 44.1M written to disk.
Nov 04 12:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:11:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:12:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:13:28 evo-x2 memory-emergency-guard-check[2206217]: MEMORY EMERGENCY IO-PAUSE (trip #6597, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:13:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:13:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 660ms CPU time over 925ms wall clock time, 10M memory peak, 5.4M read from disk, 28M written to disk.
Nov 04 12:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 149ms wall clock time, 15.6M memory peak, 4.4M read from disk, 4K written to disk.
Nov 04 12:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:15:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:16:16 evo-x2 memory-emergency-guard-check[2265799]: MEMORY EMERGENCY IO-PAUSE (trip #6598, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 541ms CPU time over 18.303s wall clock time, 11.8M memory peak, 6.7M read from disk, 6.9M written to disk.
Nov 04 12:16:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:16:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:17:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:17:58 evo-x2 memory-emergency-guard-check[2298896]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.04% sustained (max disk busy 52.8%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 12:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:18:30 evo-x2 memory-emergency-guard-check[2305648]: MEMORY EMERGENCY IO-PAUSE (trip #6599, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 2.637s wall clock time, 11.8M memory peak, 7.6M read from disk, 50.2M written to disk.
Nov 04 12:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:21:00 evo-x2 memory-emergency-guard-check[2343190]: MEMORY EMERGENCY IO-PAUSE (trip #6600, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 2.519s wall clock time, 11.7M memory peak, 15.4M read from disk, 53.2M written to disk.
Nov 04 12:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:22:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:22:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:23:29 evo-x2 memory-emergency-guard-check[2381826]: MEMORY EMERGENCY IO-PAUSE (trip #6601, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 1.039s wall clock time, 11.5M memory peak, 29.8M read from disk, 46.1M written to disk.
Nov 04 12:23:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 144ms wall clock time, 9.3M memory peak, 1.1M read from disk, 4K written to disk.
Nov 04 12:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:25:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:25:59 evo-x2 memory-emergency-guard-check[2418593]: MEMORY EMERGENCY IO-PAUSE (trip #6602, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 760ms CPU time over 1.387s wall clock time, 13.6M memory peak, 48M read from disk, 87.9M written to disk.
Nov 04 12:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:27:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:28:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:28:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:29:32 evo-x2 memory-emergency-guard-check[2465926]: MEMORY EMERGENCY IO-PAUSE (trip #6603, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 746ms CPU time over 4.585s wall clock time, 11.7M memory peak, 5.9M read from disk, 56.7M written to disk.
Nov 04 12:29:58 evo-x2 memory-emergency-guard-check[2494274]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.41% sustained (max disk busy 33.0%, MemAvailable=31.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 12:29:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:33:32 evo-x2 memory-emergency-guard-check[2550476]: MEMORY EMERGENCY IO-PAUSE (trip #6604, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 972ms CPU time over 4.457s wall clock time, 12.6M memory peak, 4.7M read from disk, 55.5M written to disk.
Nov 04 12:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:36:01 evo-x2 memory-emergency-guard-check[2585385]: MEMORY EMERGENCY IO-PAUSE (trip #6605, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 967ms CPU time over 2.884s wall clock time, 10.3M memory peak, 3.4M read from disk, 63.1M written to disk.
Nov 04 12:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:37:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:40:00 evo-x2 memory-emergency-guard-check[2629728]: MEMORY EMERGENCY IO-PAUSE (trip #6606, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 691ms CPU time over 1.775s wall clock time, 11.6M memory peak, 3.1M read from disk, 59.8M written to disk.
Nov 04 12:40:28 evo-x2 memory-emergency-guard-check[2639127]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.79% sustained (max disk busy 53.1%, MemAvailable=30.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 12:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 151ms wall clock time, 11.5M memory peak, 3.5M read from disk, 4K written to disk.
Nov 04 12:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:44:32 evo-x2 memory-emergency-guard-check[2677171]: MEMORY EMERGENCY IO-PAUSE (trip #6607, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 3.455s wall clock time, 11.9M memory peak, 11.5M read from disk, 42.2M written to disk.
Nov 04 12:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:48:01 evo-x2 memory-emergency-guard-check[2718783]: MEMORY EMERGENCY IO-PAUSE (trip #6608, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 2.636s wall clock time, 12M memory peak, 21.6M read from disk, 64.1M written to disk.
Nov 04 12:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:52:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:53:29 evo-x2 memory-emergency-guard-check[2808268]: MEMORY EMERGENCY IO-PAUSE (trip #6609, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 772ms wall clock time, 12M memory peak, 2.9M read from disk, 36.1M written to disk.
Nov 04 12:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:54:59 evo-x2 memory-emergency-guard-check[2837965]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.85% sustained (max disk busy 47.3%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 12:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:55:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:57:31 evo-x2 memory-emergency-guard-check[2870640]: MEMORY EMERGENCY IO-PAUSE (trip #6610, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 12:57:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:57:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 2.112s wall clock time, 12.8M memory peak, 7.8M read from disk, 48.6M written to disk.
Nov 04 12:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 12:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:00:32 evo-x2 memory-emergency-guard-check[2911567]: MEMORY EMERGENCY IO-PAUSE (trip #6611, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 676ms CPU time over 3.383s wall clock time, 12.5M memory peak, 4.3M read from disk, 46.2M written to disk.
Nov 04 13:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:02:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:05:02 evo-x2 memory-emergency-guard-check[2966964]: MEMORY EMERGENCY IO-PAUSE (trip #6612, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 3.380s wall clock time, 11.8M memory peak, 2.8M read from disk, 36.8M written to disk.
Nov 04 13:05:29 evo-x2 memory-emergency-guard-check[2976479]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.73% sustained (max disk busy 24.2%, MemAvailable=29.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:09:30 evo-x2 memory-emergency-guard-check[3014855]: MEMORY EMERGENCY IO-PAUSE (trip #6613, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 660ms CPU time over 841ms wall clock time, 10.5M memory peak, 1.7M read from disk, 34M written to disk.
Nov 04 13:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:14:01 evo-x2 memory-emergency-guard-check[3070653]: MEMORY EMERGENCY IO-PAUSE (trip #6614, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 1.733s wall clock time, 12.1M memory peak, 6.2M read from disk, 44.9M written to disk.
Nov 04 13:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:15:29 evo-x2 memory-emergency-guard-check[3100600]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.49% sustained (max disk busy 99.7%, MemAvailable=24.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:16:30 evo-x2 memory-emergency-guard-check[3122035]: MEMORY EMERGENCY IO-PAUSE (trip #6615, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 795ms wall clock time, 11.1M memory peak, 2.5M read from disk, 41.8M written to disk.
Nov 04 13:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:19:33 evo-x2 memory-emergency-guard-check[3172843]: MEMORY EMERGENCY IO-PAUSE (trip #6616, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 774ms CPU time over 3.488s wall clock time, 11.1M memory peak, 2.3M read from disk, 82.3M written to disk.
Nov 04 13:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:23:31 evo-x2 memory-emergency-guard-check[3222703]: MEMORY EMERGENCY IO-PAUSE (trip #6617, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 679ms CPU time over 1.423s wall clock time, 12.2M memory peak, 384K read from disk, 45.5M written to disk.
Nov 04 13:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:25:29 evo-x2 memory-emergency-guard-check[3250558]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.61% sustained (max disk busy 51.6%, MemAvailable=30.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:28:31 evo-x2 memory-emergency-guard-check[3302040]: MEMORY EMERGENCY IO-PAUSE (trip #6618, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 684ms CPU time over 1.441s wall clock time, 11.3M memory peak, 21.2M read from disk, 40.9M written to disk.
Nov 04 13:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:30:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:32:31 evo-x2 memory-emergency-guard-check[3349567]: MEMORY EMERGENCY IO-PAUSE (trip #6619, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 1.964s wall clock time, 11.6M memory peak, 2.4M read from disk, 28.9M written to disk.
Nov 04 13:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:35:02 evo-x2 memory-emergency-guard-check[3380571]: MEMORY EMERGENCY IO-PAUSE (trip #6620, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 2.490s wall clock time, 10.5M memory peak, 2.7M read from disk, 44.1M written to disk.
Nov 04 13:35:30 evo-x2 memory-emergency-guard-check[3390672]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.34% sustained (max disk busy 25.2%, MemAvailable=31.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:37:32 evo-x2 memory-emergency-guard-check[3414561]: MEMORY EMERGENCY IO-PAUSE (trip #6621, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 704ms CPU time over 2.722s wall clock time, 11.4M memory peak, 2.1M read from disk, 48.7M written to disk.
Nov 04 13:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:40:31 evo-x2 memory-emergency-guard-check[3465398]: MEMORY EMERGENCY IO-PAUSE (trip #6622, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 897ms CPU time over 1.142s wall clock time, 10.8M memory peak, 12.8M read from disk, 41.9M written to disk.
Nov 04 13:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:43:03 evo-x2 memory-emergency-guard-check[3494840]: MEMORY EMERGENCY IO-PAUSE (trip #6623, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 3.758s wall clock time, 11.7M memory peak, 11.8M read from disk, 70.7M written to disk.
Nov 04 13:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:45:31 evo-x2 memory-emergency-guard-check[3525534]: MEMORY EMERGENCY IO-PAUSE (trip #6624, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 632ms CPU time over 1.854s wall clock time, 10.4M memory peak, 6.8M read from disk, 45M written to disk.
Nov 04 13:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:46:30 evo-x2 memory-emergency-guard-check[3542218]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.86% sustained (max disk busy 21.7%, MemAvailable=31.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:48:01 evo-x2 memory-emergency-guard-check[3559749]: MEMORY EMERGENCY IO-PAUSE (trip #6625, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 1.524s wall clock time, 11.3M memory peak, 7M read from disk, 35.3M written to disk.
Nov 04 13:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:50:31 evo-x2 memory-emergency-guard-check[3592550]: MEMORY EMERGENCY IO-PAUSE (trip #6626, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 660ms CPU time over 1.619s wall clock time, 11.3M memory peak, 3.7M read from disk, 54.2M written to disk.
Nov 04 13:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:55:02 evo-x2 memory-emergency-guard-check[3653615]: MEMORY EMERGENCY IO-PAUSE (trip #6627, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 721ms CPU time over 2.060s wall clock time, 10.3M memory peak, 15.3M read from disk, 53.5M written to disk.
Nov 04 13:55:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:56:30 evo-x2 memory-emergency-guard-check[3675477]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.36% sustained (max disk busy 42.1%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 13:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:57:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:59:33 evo-x2 memory-emergency-guard-check[3704944]: MEMORY EMERGENCY IO-PAUSE (trip #6628, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 13:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 13:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 992ms CPU time over 2.942s wall clock time, 11.5M memory peak, 2.8M read from disk, 59.6M written to disk.
Nov 04 14:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:02:32 evo-x2 memory-emergency-guard-check[3764101]: MEMORY EMERGENCY IO-PAUSE (trip #6629, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 2.376s wall clock time, 10.3M memory peak, 13.7M read from disk, 64.8M written to disk.
Nov 04 14:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:05:01 evo-x2 memory-emergency-guard-check[3802899]: MEMORY EMERGENCY IO-PAUSE (trip #6630, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 889ms wall clock time, 11.4M memory peak, 4.5M read from disk, 62.5M written to disk.
Nov 04 14:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:07:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:07:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:08:01 evo-x2 memory-emergency-guard-check[3840723]: MEMORY EMERGENCY IO-PAUSE (trip #6631, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 523ms CPU time over 1.297s wall clock time, 11.3M memory peak, 1.6M read from disk, 17.5M written to disk.
Nov 04 14:08:30 evo-x2 memory-emergency-guard-check[3857533]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.55% sustained (max disk busy 27.0%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 14:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:12:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:12:32 evo-x2 memory-emergency-guard-check[3917285]: MEMORY EMERGENCY IO-PAUSE (trip #6632, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 636ms CPU time over 2.308s wall clock time, 11.8M memory peak, 1.6M read from disk, 39.8M written to disk.
Nov 04 14:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:15:03 evo-x2 memory-emergency-guard-check[3953244]: MEMORY EMERGENCY IO-PAUSE (trip #6633, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 704ms CPU time over 2.432s wall clock time, 11.8M memory peak, 9.8M read from disk, 56.5M written to disk.
Nov 04 14:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:17:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:18:32 evo-x2 memory-emergency-guard-check[4003721]: MEMORY EMERGENCY IO-PAUSE (trip #6634, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 1.996s wall clock time, 12.8M memory peak, 6.1M read from disk, 63.3M written to disk.
Nov 04 14:19:00 evo-x2 memory-emergency-guard-check[4015790]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.54% sustained (max disk busy 47.2%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 14:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:21:35 evo-x2 memory-emergency-guard-check[4062071]: MEMORY EMERGENCY IO-PAUSE (trip #6635, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 5.261s wall clock time, 11.7M memory peak, 5.3M read from disk, 67.8M written to disk.
Nov 04 14:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:26:32 evo-x2 memory-emergency-guard-check[4125673]: MEMORY EMERGENCY IO-PAUSE (trip #6636, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 2.007s wall clock time, 10.7M memory peak, 2.6M read from disk, 38.5M written to disk.
Nov 04 14:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:29:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:32:04 evo-x2 memory-emergency-guard-check[4192838]: MEMORY EMERGENCY IO-PAUSE (trip #6637, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 4.006s wall clock time, 11.4M memory peak, 3.7M read from disk, 34.9M written to disk.
Nov 04 14:32:31 evo-x2 memory-emergency-guard-check[10487]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.95% sustained (max disk busy 51.4%, MemAvailable=33.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 14:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:34:32 evo-x2 memory-emergency-guard-check[31748]: MEMORY EMERGENCY IO-PAUSE (trip #6638, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 575ms CPU time over 1.544s wall clock time, 11M memory peak, 6M read from disk, 36.5M written to disk.
Nov 04 14:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:37:02 evo-x2 memory-emergency-guard-check[62529]: MEMORY EMERGENCY IO-PAUSE (trip #6639, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 629ms CPU time over 1.872s wall clock time, 11.2M memory peak, 2.4M read from disk, 44.5M written to disk.
Nov 04 14:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:40:32 evo-x2 memory-emergency-guard-check[102324]: MEMORY EMERGENCY IO-PAUSE (trip #6640, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 1.071s wall clock time, 11.4M memory peak, 3.5M read from disk, 51.5M written to disk.
Nov 04 14:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:44:33 evo-x2 memory-emergency-guard-check[164150]: MEMORY EMERGENCY IO-PAUSE (trip #6641, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 995ms CPU time over 2.800s wall clock time, 10.8M memory peak, 3.1M read from disk, 61.1M written to disk.
Nov 04 14:45:01 evo-x2 memory-emergency-guard-check[173530]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.50% sustained (max disk busy 37.5%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 14:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:48:33 evo-x2 memory-emergency-guard-check[207876]: MEMORY EMERGENCY IO-PAUSE (trip #6642, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 958ms CPU time over 2.173s wall clock time, 10.8M memory peak, 2.5M read from disk, 58.4M written to disk.
Nov 04 14:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:54:32 evo-x2 memory-emergency-guard-check[285752]: MEMORY EMERGENCY IO-PAUSE (trip #6643, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 788ms wall clock time, 11.9M memory peak, 4.2M read from disk, 40.4M written to disk.
Nov 04 14:55:01 evo-x2 memory-emergency-guard-check[299514]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.23% sustained (max disk busy 32.2%, MemAvailable=31.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 14:55:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:56:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:57:04 evo-x2 memory-emergency-guard-check[325615]: MEMORY EMERGENCY IO-PAUSE (trip #6644, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 664ms CPU time over 2.788s wall clock time, 13.5M memory peak, 16.4M read from disk, 49.7M written to disk.
Nov 04 14:57:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:58:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:58:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:59:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:59:34 evo-x2 memory-emergency-guard-check[370457]: MEMORY EMERGENCY IO-PAUSE (trip #6645, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 14:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 14:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 3.396s wall clock time, 12.5M memory peak, 4.3M read from disk, 44.2M written to disk.
Nov 04 15:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:00:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:01:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:02:33 evo-x2 memory-emergency-guard-check[421186]: MEMORY EMERGENCY IO-PAUSE (trip #6646, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.723s wall clock time, 12.4M memory peak, 4.7M read from disk, 29.5M written to disk.
Nov 04 15:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:03:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:07:34 evo-x2 memory-emergency-guard-check[496037]: MEMORY EMERGENCY IO-PAUSE (trip #6647, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 2.650s wall clock time, 12.3M memory peak, 9.7M read from disk, 36.8M written to disk.
Nov 04 15:08:01 evo-x2 memory-emergency-guard-check[510135]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.25% sustained (max disk busy 31.8%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 15:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:10:33 evo-x2 memory-emergency-guard-check[557540]: MEMORY EMERGENCY IO-PAUSE (trip #6648, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 735ms CPU time over 1.514s wall clock time, 11.6M memory peak, 6.3M read from disk, 79.3M written to disk.
Nov 04 15:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:11:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:12:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:12:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:13:03 evo-x2 memory-emergency-guard-check[592838]: MEMORY EMERGENCY IO-PAUSE (trip #6649, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 1.794s wall clock time, 10.9M memory peak, 3.5M read from disk, 49.3M written to disk.
Nov 04 15:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:15:38 evo-x2 memory-emergency-guard-check[632444]: MEMORY EMERGENCY IO-PAUSE (trip #6650, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 6.634s wall clock time, 13.6M memory peak, 19.8M read from disk, 55.6M written to disk.
Nov 04 15:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:18:06 evo-x2 memory-emergency-guard-check[671580]: MEMORY EMERGENCY IO-PAUSE (trip #6651, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 4.524s wall clock time, 11M memory peak, 9M read from disk, 58M written to disk.
Nov 04 15:18:31 evo-x2 memory-emergency-guard-check[690528]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.46% sustained (max disk busy 74.8%, MemAvailable=31.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 15:18:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:19:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:19:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:20:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:20:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:21:08 evo-x2 memory-emergency-guard-check[735396]: MEMORY EMERGENCY IO-PAUSE (trip #6652, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 6.452s wall clock time, 12.1M memory peak, 19.6M read from disk, 58.8M written to disk.
Nov 04 15:21:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:23:33 evo-x2 memory-emergency-guard-check[775068]: MEMORY EMERGENCY IO-PAUSE (trip #6653, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 659ms CPU time over 2.174s wall clock time, 11M memory peak, 2.5M read from disk, 39.1M written to disk.
Nov 04 15:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:26:33 evo-x2 memory-emergency-guard-check[819412]: MEMORY EMERGENCY IO-PAUSE (trip #6654, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 1.243s wall clock time, 11.9M memory peak, 9.2M read from disk, 58.8M written to disk.
Nov 04 15:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:31:34 evo-x2 memory-emergency-guard-check[884816]: MEMORY EMERGENCY IO-PAUSE (trip #6655, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 2.608s wall clock time, 10.6M memory peak, 8M read from disk, 52.3M written to disk.
Nov 04 15:32:02 evo-x2 memory-emergency-guard-check[897702]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.82% sustained (max disk busy 47.8%, MemAvailable=34.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 15:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 182ms wall clock time, 19.1M memory peak, 10M read from disk, 4K written to disk.
Nov 04 15:32:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:34:35 evo-x2 memory-emergency-guard-check[924949]: MEMORY EMERGENCY IO-PAUSE (trip #6656, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 3.482s wall clock time, 12M memory peak, 27.1M read from disk, 56.9M written to disk.
Nov 04 15:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:37:02 evo-x2 memory-emergency-guard-check[958710]: MEMORY EMERGENCY IO-PAUSE (trip #6657, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 674ms CPU time over 940ms wall clock time, 10.9M memory peak, 11.4M read from disk, 61.6M written to disk.
Nov 04 15:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:39:32 evo-x2 memory-emergency-guard-check[990716]: MEMORY EMERGENCY IO-PAUSE (trip #6658, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 676ms CPU time over 892ms wall clock time, 10.6M memory peak, 4.9M read from disk, 46.5M written to disk.
Nov 04 15:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:44:04 evo-x2 memory-emergency-guard-check[1060277]: MEMORY EMERGENCY IO-PAUSE (trip #6659, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 1.981s wall clock time, 11.3M memory peak, 9.2M read from disk, 48M written to disk.
Nov 04 15:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:45:32 evo-x2 memory-emergency-guard-check[1079643]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.70% sustained (max disk busy 54.5%, MemAvailable=29.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 15:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:47:04 evo-x2 memory-emergency-guard-check[1096142]: MEMORY EMERGENCY IO-PAUSE (trip #6660, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 621ms CPU time over 1.884s wall clock time, 11.1M memory peak, 6.2M read from disk, 55.7M written to disk.
Nov 04 15:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:49:33 evo-x2 memory-emergency-guard-check[1125789]: MEMORY EMERGENCY IO-PAUSE (trip #6661, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 908ms wall clock time, 11.3M memory peak, 2.2M read from disk, 51.3M written to disk.
Nov 04 15:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:54:05 evo-x2 memory-emergency-guard-check[1184910]: MEMORY EMERGENCY IO-PAUSE (trip #6662, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 2.987s wall clock time, 11M memory peak, 3.7M read from disk, 31.5M written to disk.
Nov 04 15:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:55:32 evo-x2 memory-emergency-guard-check[1220560]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.88% sustained (max disk busy 30.6%, MemAvailable=30.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 15:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:56:35 evo-x2 memory-emergency-guard-check[1234982]: MEMORY EMERGENCY IO-PAUSE (trip #6663, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 607ms CPU time over 2.760s wall clock time, 12.1M memory peak, 12.9M read from disk, 42.1M written to disk.
Nov 04 15:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:59:04 evo-x2 memory-emergency-guard-check[1268070]: MEMORY EMERGENCY IO-PAUSE (trip #6664, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 15:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 15:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 2.129s wall clock time, 11.7M memory peak, 6.2M read from disk, 54.3M written to disk.
Nov 04 15:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:01:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:02:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:03:03 evo-x2 memory-emergency-guard-check[1335286]: MEMORY EMERGENCY IO-PAUSE (trip #6665, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 679ms CPU time over 1.309s wall clock time, 10.7M memory peak, 23M read from disk, 50.2M written to disk.
Nov 04 16:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:06:35 evo-x2 memory-emergency-guard-check[1377023]: MEMORY EMERGENCY IO-PAUSE (trip #6666, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 3.249s wall clock time, 11.5M memory peak, 9.7M read from disk, 64.1M written to disk.
Nov 04 16:07:02 evo-x2 memory-emergency-guard-check[1390324]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.26% sustained (max disk busy 26.8%, MemAvailable=30.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:11:35 evo-x2 memory-emergency-guard-check[1437381]: MEMORY EMERGENCY IO-PAUSE (trip #6667, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 2.538s wall clock time, 10.6M memory peak, 8.9M read from disk, 63.5M written to disk.
Nov 04 16:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:15:03 evo-x2 memory-emergency-guard-check[1479802]: MEMORY EMERGENCY IO-PAUSE (trip #6668, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 680ms CPU time over 980ms wall clock time, 11.7M memory peak, 10.6M read from disk, 59.1M written to disk.
Nov 04 16:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:17:02 evo-x2 memory-emergency-guard-check[1528933]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.96% sustained (max disk busy 72.8%, MemAvailable=30.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:17:37 evo-x2 memory-emergency-guard-check[1535145]: MEMORY EMERGENCY IO-PAUSE (trip #6669, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 4.664s wall clock time, 12.7M memory peak, 16.9M read from disk, 47.9M written to disk.
Nov 04 16:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:20:05 evo-x2 memory-emergency-guard-check[1571801]: MEMORY EMERGENCY IO-PAUSE (trip #6670, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 2.455s wall clock time, 11.4M memory peak, 6M read from disk, 42.1M written to disk.
Nov 04 16:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:22:33 evo-x2 memory-emergency-guard-check[1607833]: MEMORY EMERGENCY IO-PAUSE (trip #6671, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 654ms CPU time over 858ms wall clock time, 12M memory peak, 7.2M read from disk, 55.1M written to disk.
Nov 04 16:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:26:35 evo-x2 memory-emergency-guard-check[1659372]: MEMORY EMERGENCY IO-PAUSE (trip #6672, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 3.028s wall clock time, 12.3M memory peak, 8.6M read from disk, 68M written to disk.
Nov 04 16:27:03 evo-x2 memory-emergency-guard-check[1669738]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.22% sustained (max disk busy 27.2%, MemAvailable=30.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:28:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:29:36 evo-x2 memory-emergency-guard-check[1694770]: MEMORY EMERGENCY IO-PAUSE (trip #6673, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 634ms CPU time over 3.222s wall clock time, 12.2M memory peak, 4.6M read from disk, 57.2M written to disk.
Nov 04 16:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:33:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:34:35 evo-x2 memory-emergency-guard-check[1746957]: MEMORY EMERGENCY IO-PAUSE (trip #6674, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 886ms CPU time over 2.667s wall clock time, 12.1M memory peak, 6.2M read from disk, 41.1M written to disk.
Nov 04 16:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:37:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:37:34 evo-x2 memory-emergency-guard-check[1786972]: MEMORY EMERGENCY IO-PAUSE (trip #6675, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 1.180s wall clock time, 11.7M memory peak, 37.9M read from disk, 54.8M written to disk.
Nov 04 16:38:03 evo-x2 memory-emergency-guard-check[1813616]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.32% sustained (max disk busy 26.6%, MemAvailable=30.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:40:05 evo-x2 memory-emergency-guard-check[1838494]: MEMORY EMERGENCY IO-PAUSE (trip #6676, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:40:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:40:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 2.228s wall clock time, 11.5M memory peak, 3.8M read from disk, 35.9M written to disk.
Nov 04 16:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:43:05 evo-x2 memory-emergency-guard-check[1884028]: MEMORY EMERGENCY IO-PAUSE (trip #6677, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:43:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:43:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 714ms CPU time over 2.511s wall clock time, 11.1M memory peak, 7.6M read from disk, 53.4M written to disk.
Nov 04 16:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:45:36 evo-x2 memory-emergency-guard-check[1998082]: MEMORY EMERGENCY IO-PAUSE (trip #6678, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.069s CPU time over 3.240s wall clock time, 10.8M memory peak, 15.5M read from disk, 61.5M written to disk.
Nov 04 16:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:48:07 evo-x2 memory-emergency-guard-check[2130754]: MEMORY EMERGENCY IO-PAUSE (trip #6679, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 761ms CPU time over 4.153s wall clock time, 13.2M memory peak, 5.2M read from disk, 30.4M written to disk.
Nov 04 16:48:33 evo-x2 memory-emergency-guard-check[2150730]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.20% sustained (max disk busy 99.5%, MemAvailable=29.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:50:50 evo-x2 memory-emergency-guard-check[2221440]: MEMORY EMERGENCY IO-PAUSE (trip #6680, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 17.590s wall clock time, 11.5M memory peak, 3.7M read from disk, 33.1M written to disk.
Nov 04 16:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:53:06 evo-x2 memory-emergency-guard-check[2307604]: MEMORY EMERGENCY IO-PAUSE (trip #6681, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 963ms CPU time over 3.365s wall clock time, 11.5M memory peak, 6.4M read from disk, 38.3M written to disk.
Nov 04 16:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:55:36 evo-x2 memory-emergency-guard-check[2387438]: MEMORY EMERGENCY IO-PAUSE (trip #6682, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 3.414s wall clock time, 11.1M memory peak, 5.3M read from disk, 30M written to disk.
Nov 04 16:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:58:13 evo-x2 memory-emergency-guard-check[2431844]: MEMORY EMERGENCY IO-PAUSE (trip #6683, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 16:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 9.838s wall clock time, 11.6M memory peak, 17.3M read from disk, 28.5M written to disk.
Nov 04 16:58:33 evo-x2 memory-emergency-guard-check[2464323]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.24% sustained (max disk busy 100.0%, MemAvailable=30.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 16:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 16:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:01:09 evo-x2 memory-emergency-guard-check[2535448]: MEMORY EMERGENCY IO-PAUSE (trip #6684, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 874ms CPU time over 36.229s wall clock time, 11.9M memory peak, 7.3M read from disk, 38.4M written to disk.
Nov 04 17:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 175ms CPU time over 233ms wall clock time, 9.2M memory peak, 1.8M read from disk, 4K written to disk.
Nov 04 17:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:03:15 evo-x2 memory-emergency-guard-check[2609658]: MEMORY EMERGENCY IO-PAUSE (trip #6685, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 5.923s wall clock time, 12.3M memory peak, 4.2M read from disk, 36.3M written to disk.
Nov 04 17:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:05:45 evo-x2 memory-emergency-guard-check[2675526]: MEMORY EMERGENCY IO-PAUSE (trip #6686, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 800ms CPU time over 5.682s wall clock time, 11M memory peak, 752K read from disk, 18.8M written to disk.
Nov 04 17:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:08:14 evo-x2 memory-emergency-guard-check[2790691]: MEMORY EMERGENCY IO-PAUSE (trip #6687, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.222s CPU time over 5.023s wall clock time, 11.6M memory peak, 14.2M read from disk, 51.9M written to disk.
Nov 04 17:08:40 evo-x2 memory-emergency-guard-check[2823900]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.23% sustained (max disk busy 100.0%, MemAvailable=30.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:11:01 evo-x2 memory-emergency-guard-check[2881991]: MEMORY EMERGENCY IO-PAUSE (trip #6688, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 941ms CPU time over 21.935s wall clock time, 11.6M memory peak, 23M read from disk, 40.9M written to disk.
Nov 04 17:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:13:19 evo-x2 memory-emergency-guard-check[2976423]: MEMORY EMERGENCY IO-PAUSE (trip #6689, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:13:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:13:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 819ms CPU time over 9.075s wall clock time, 11.2M memory peak, 9.9M read from disk, 50.7M written to disk.
Nov 04 17:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:16:20 evo-x2 memory-emergency-guard-check[3088563]: MEMORY EMERGENCY IO-PAUSE (trip #6690, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.094s CPU time over 40.194s wall clock time, 8.2M memory peak, 26.3M read from disk, 20.4M written to disk.
Nov 04 17:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 207ms CPU time over 367ms wall clock time, 4.7M memory peak, 1.4M read from disk, 4K written to disk.
Nov 04 17:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:18:23 evo-x2 memory-emergency-guard-check[3255863]: MEMORY EMERGENCY IO-PAUSE (trip #6691, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 970ms CPU time over 2.952s wall clock time, 11.5M memory peak, 24.4M read from disk, 8M written to disk.
Nov 04 17:18:50 evo-x2 memory-emergency-guard-check[3292095]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.52% sustained (max disk busy 100.0%, MemAvailable=25.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:20:59 evo-x2 memory-emergency-guard-check[3403498]: MEMORY EMERGENCY IO-PAUSE (trip #6692, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.556s CPU time over 8.815s wall clock time, 9M memory peak, 30.4M read from disk, 162.8M written to disk.
Nov 04 17:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 260ms CPU time over 434ms wall clock time, 13M memory peak, 8.3M read from disk, 4K written to disk.
Nov 04 17:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:23:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:23:53 evo-x2 memory-emergency-guard-check[3545692]: MEMORY EMERGENCY IO-PAUSE (trip #6693, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 972ms CPU time over 2.891s wall clock time, 9.7M memory peak, 16.8M read from disk, 26.4M written to disk.
Nov 04 17:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 208ms CPU time over 343ms wall clock time, 6.6M memory peak, 2.9M read from disk, 4K written to disk.
Nov 04 17:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:26:41 evo-x2 memory-emergency-guard-check[3700527]: MEMORY EMERGENCY IO-PAUSE (trip #6694, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 978ms CPU time over 20.569s wall clock time, 11.4M memory peak, 50.8M read from disk, 28.2M written to disk.
Nov 04 17:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 146ms CPU time over 223ms wall clock time, 7M memory peak, 2.6M read from disk, 4K written to disk.
Nov 04 17:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:29:21 evo-x2 memory-emergency-guard-check[3786728]: MEMORY EMERGENCY IO-PAUSE (trip #6695, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.319s CPU time over 31.128s wall clock time, 8.9M memory peak, 13.5M read from disk, 15.9M written to disk.
Nov 04 17:29:22 evo-x2 memory-emergency-guard-check[3831779]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.20% sustained (max disk busy 100.0%, MemAvailable=13.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:31:37 evo-x2 memory-emergency-guard-check[3942273]: MEMORY EMERGENCY IO-PAUSE (trip #6696, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 878ms CPU time over 11.121s wall clock time, 12.5M memory peak, 6.6M read from disk, 22.5M written to disk.
Nov 04 17:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:35:30 evo-x2 memory-emergency-guard-check[4171952]: MEMORY EMERGENCY IO-PAUSE (trip #6697, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 848ms CPU time over 3.687s wall clock time, 10.3M memory peak, 608K read from disk, 19M written to disk.
Nov 04 17:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:37:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:38:18 evo-x2 memory-emergency-guard-check[146183]: MEMORY EMERGENCY IO-PAUSE (trip #6698, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 903ms CPU time over 21.759s wall clock time, 10.1M memory peak, 9.5M read from disk, 15.2M written to disk.
Nov 04 17:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:39:26 evo-x2 memory-emergency-guard-check[234985]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.66% sustained (max disk busy 100.0%, MemAvailable=31.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:41:11 evo-x2 memory-emergency-guard-check[324138]: MEMORY EMERGENCY IO-PAUSE (trip #6699, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.569s CPU time over 44.606s wall clock time, 10.1M memory peak, 43M read from disk, 72.5M written to disk.
Nov 04 17:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 224ms CPU time over 668ms wall clock time, 6.8M memory peak, 1M read from disk, 4K written to disk.
Nov 04 17:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:43:51 evo-x2 memory-emergency-guard-check[566723]: MEMORY EMERGENCY IO-PAUSE (trip #6700, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.089s CPU time over 40.585s wall clock time, 11.4M memory peak, 13.2M read from disk, 40.4M written to disk.
Nov 04 17:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 161ms CPU time over 285ms wall clock time, 7.8M memory peak, 1.6M read from disk, 4K written to disk.
Nov 04 17:46:14 evo-x2 memory-emergency-guard-check[718417]: MEMORY EMERGENCY IO-PAUSE (trip #6701, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.152s CPU time over 22.291s wall clock time, 8.8M memory peak, 12.3M read from disk, 28.5M written to disk.
Nov 04 17:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:47:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:47:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:48:40 evo-x2 memory-emergency-guard-check[828462]: MEMORY EMERGENCY IO-PAUSE (trip #6702, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.052s CPU time over 18.579s wall clock time, 12.5M memory peak, 6.5M read from disk, 111.2M written to disk.
Nov 04 17:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:49:52 evo-x2 memory-emergency-guard-check[926357]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.43% sustained (max disk busy 99.1%, MemAvailable=25.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:51:12 evo-x2 memory-emergency-guard-check[988855]: MEMORY EMERGENCY IO-PAUSE (trip #6703, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 845ms CPU time over 20.659s wall clock time, 13.6M memory peak, 9.8M read from disk, 20.8M written to disk.
Nov 04 17:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:53:31 evo-x2 memory-emergency-guard-check[1139595]: MEMORY EMERGENCY IO-PAUSE (trip #6704, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.032s CPU time over 9.752s wall clock time, 11.4M memory peak, 27.3M read from disk, 30.8M written to disk.
Nov 04 17:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:56:00 evo-x2 memory-emergency-guard-check[1234732]: MEMORY EMERGENCY IO-PAUSE (trip #6705, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 8.545s wall clock time, 10M memory peak, 20.6M read from disk, 53.3M written to disk.
Nov 04 17:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 138ms CPU time over 184ms wall clock time, 8.6M memory peak, 1.9M read from disk, 4K written to disk.
Nov 04 17:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:58:31 evo-x2 memory-emergency-guard-check[1321228]: MEMORY EMERGENCY IO-PAUSE (trip #6706, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 17:58:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:58:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.074s CPU time over 9.007s wall clock time, 9.6M memory peak, 23.9M read from disk, 57.3M written to disk.
Nov 04 17:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 139ms CPU time over 180ms wall clock time, 8.6M memory peak, 2.1M read from disk, 4K written to disk.
Nov 04 17:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 17:59:52 evo-x2 memory-emergency-guard-check[1414321]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.11% sustained (max disk busy 89.2%, MemAvailable=24.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 17:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:01:50 evo-x2 memory-emergency-guard-check[1473642]: MEMORY EMERGENCY IO-PAUSE (trip #6707, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.306s CPU time over 58.674s wall clock time, 9.7M memory peak, 41.3M read from disk, 3.2M written to disk.
Nov 04 18:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:02:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:04:12 evo-x2 memory-emergency-guard-check[1628267]: MEMORY EMERGENCY IO-PAUSE (trip #6708, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 865ms CPU time over 21.469s wall clock time, 13.2M memory peak, 10.1M read from disk, 4M written to disk.
Nov 04 18:04:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:04:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 154ms CPU time over 239ms wall clock time, 9.6M memory peak, 2M read from disk, 4K written to disk.
Nov 04 18:04:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 201ms CPU time over 1.008s wall clock time, 9.7M memory peak, 3.6M read from disk, 4K written to disk.
Nov 04 18:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:06:41 evo-x2 memory-emergency-guard-check[1783437]: MEMORY EMERGENCY IO-PAUSE (trip #6709, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 942ms CPU time over 20.900s wall clock time, 14.6M memory peak, 42.4M read from disk, 34M written to disk.
Nov 04 18:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 153ms CPU time over 289ms wall clock time, 7.2M memory peak, 1.2M read from disk, 4K written to disk.
Nov 04 18:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 150ms CPU time over 243ms wall clock time, 8.8M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 18:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:08:54 evo-x2 memory-emergency-guard-check[1880252]: MEMORY EMERGENCY IO-PAUSE (trip #6710, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 793ms CPU time over 3.484s wall clock time, 14M memory peak, 3.5M read from disk, 24M written to disk.
Nov 04 18:09:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:10:21 evo-x2 memory-emergency-guard-check[1969826]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.75% sustained (max disk busy 88.1%, MemAvailable=30.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 18:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:11:43 evo-x2 memory-emergency-guard-check[2049754]: MEMORY EMERGENCY IO-PAUSE (trip #6711, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 963ms CPU time over 22.282s wall clock time, 11.8M memory peak, 12.3M read from disk, 15.1M written to disk.
Nov 04 18:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 129ms CPU time over 187ms wall clock time, 8.7M memory peak, 1.3M read from disk, 4K written to disk.
Nov 04 18:14:33 evo-x2 memory-emergency-guard-check[2176266]: MEMORY EMERGENCY IO-PAUSE (trip #6712, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.079s CPU time over 42.791s wall clock time, 13.2M memory peak, 15.1M read from disk, 96.8M written to disk.
Nov 04 18:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:16:53 evo-x2 memory-emergency-guard-check[2317055]: MEMORY EMERGENCY IO-PAUSE (trip #6713, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 895ms CPU time over 19.485s wall clock time, 11.5M memory peak, 9.9M read from disk, 16.1M written to disk.
Nov 04 18:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:18:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:20:44 evo-x2 memory-emergency-guard-check[2462907]: MEMORY EMERGENCY IO-PAUSE (trip #6714, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 799ms CPU time over 1min 40.497s wall clock time, 10.1M memory peak, 30.2M read from disk, 2.5M written to disk.
Nov 04 18:20:44 evo-x2 memory-emergency-guard-check[2502086]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.44% sustained (max disk busy 100.0%, MemAvailable=21.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (100s < 150s, 50s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 18:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:23:30 evo-x2 memory-emergency-guard-check[2563708]: MEMORY EMERGENCY IO-PAUSE (trip #6715, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 759ms CPU time over 1min 45.970s wall clock time, 13M memory peak, 16.3M read from disk, 7.6M written to disk.
Nov 04 18:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:26:25 evo-x2 memory-emergency-guard-check[2646547]: MEMORY EMERGENCY IO-PAUSE (trip #6716, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 874ms CPU time over 1min 34.411s wall clock time, 9.9M memory peak, 18.7M read from disk, 20.3M written to disk.
Nov 04 18:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 179ms CPU time over 411ms wall clock time, 8.3M memory peak, 4.1M read from disk, 4K written to disk.
Nov 04 18:28:05 evo-x2 memory-emergency-guard-check[2769238]: MEMORY EMERGENCY IO-PAUSE (trip #6717, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 804ms CPU time over 39.425s wall clock time, 10.8M memory peak, 11.3M read from disk, 16.5M written to disk.
Nov 04 18:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:28:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:33:48 evo-x2 memory-emergency-guard-check[2907890]: MEMORY EMERGENCY IO-PAUSE (trip #6718, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.285s CPU time over 3min 43.426s wall clock time, 12.2M memory peak, 61.8M read from disk, 16.5M written to disk.
Nov 04 18:34:09 evo-x2 memory-emergency-guard-check[3027592]: MEMORY EMERGENCY IO-PAUSE (trip #6719, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 871ms CPU time over 20.753s wall clock time, 12.1M memory peak, 3.7M read from disk, 3.9M written to disk.
Nov 04 18:34:18 evo-x2 memory-emergency-guard-check[3080004]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.52% sustained (max disk busy 99.9%, MemAvailable=23.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 18:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:37:39 evo-x2 memory-emergency-guard-check[3192165]: MEMORY EMERGENCY IO-PAUSE (trip #6720, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 1min 20.907s wall clock time, 12.4M memory peak, 13.9M read from disk, 20.4M written to disk.
Nov 04 18:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:43:16 evo-x2 memory-emergency-guard-check[3339350]: MEMORY EMERGENCY IO-PAUSE (trip #6721, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 892ms CPU time over 4min 6.557s wall clock time, 11.2M memory peak, 368K memory swap peak, 29.8M read from disk, 36.5M written to disk.
Nov 04 18:43:44 evo-x2 memory-emergency-guard-check[3476980]: MEMORY EMERGENCY IO-PAUSE (trip #6722, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.183s CPU time over 28.310s wall clock time, 13.8M memory peak, 48.3M read from disk, 84.4M written to disk.
Nov 04 18:43:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:44:46 evo-x2 memory-emergency-guard-check[3528299]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.80% sustained (max disk busy 100.0%, MemAvailable=27.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 18:44:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:48:19 evo-x2 memory-emergency-guard-check[3554708]: MEMORY EMERGENCY IO-PAUSE (trip #6723, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.350s CPU time over 2min 33.515s wall clock time, 13.2M memory peak, 91.7M read from disk, 4.7M written to disk.
Nov 04 18:49:13 evo-x2 memory-emergency-guard-check[3632748]: MEMORY EMERGENCY IO-PAUSE (trip #6724, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 850ms CPU time over 54.022s wall clock time, 14.1M memory peak, 15.4M read from disk, 8M written to disk.
Nov 04 18:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:50:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 159ms wall clock time, 12M memory peak, 3M read from disk, 4K written to disk.
Nov 04 18:52:04 evo-x2 memory-emergency-guard-check[3728681]: MEMORY EMERGENCY IO-PAUSE (trip #6725, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 926ms CPU time over 50.467s wall clock time, 14.9M memory peak, 23.2M read from disk, 26.1M written to disk.
Nov 04 18:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:52:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 140ms CPU time over 335ms wall clock time, 8.7M memory peak, 3.8M read from disk, 4K written to disk.
Nov 04 18:53:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:53:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 143ms CPU time over 399ms wall clock time, 9.6M memory peak, 2.7M read from disk, 4K written to disk.
Nov 04 18:55:11 evo-x2 memory-emergency-guard-check[3884459]: MEMORY EMERGENCY IO-PAUSE (trip #6726, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.066s CPU time over 1min 6.976s wall clock time, 13.6M memory peak, 22.3M read from disk, 7.9M written to disk.
Nov 04 18:55:11 evo-x2 memory-emergency-guard-check[3946123]: MEMORY EMERGENCY still active (I/O PSI some avg60=82.11% sustained (max disk busy 100.0%, MemAvailable=28.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (66s < 150s, 84s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 04 18:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:56:54 evo-x2 memory-emergency-guard-check[4007789]: MEMORY EMERGENCY IO-PAUSE (trip #6727, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.085s CPU time over 12.501s wall clock time, 13.2M memory peak, 4.9M read from disk, 36M written to disk.
Nov 04 18:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:59:49 evo-x2 memory-emergency-guard-check[4181806]: MEMORY EMERGENCY IO-PAUSE (trip #6728, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 04 18:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 18:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 968ms CPU time over 38.091s wall clock time, 13.6M memory peak, 10.6M read from disk, 25.2M written to disk.
Nov 04 18:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 04 19:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 03 21:47:32 evo-x2 thermal-pstate-guard-check[40692]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 03 21:44:34 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/6nz9id10qkf5cg7972iqbqb3958hi04y-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 21:44:34 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/6nz9id10qkf5cg7972iqbqb3958hi04y-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 21:44:34 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 03 21:44:36 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793815470000000000 -> 1793815564000000000 epoch-ns UTC (2026-11-04 18:04:30 -> 2026-11-04 18:06:04 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
