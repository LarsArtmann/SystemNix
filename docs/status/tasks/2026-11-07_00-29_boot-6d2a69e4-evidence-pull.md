# Boot evidence pull: id8 6d2a69e4 (full: 6d2a69e459d0481ba122847b1fc65a53)

Pulled 2026-11-07 00:29 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-06 05:58:52 -> 2026-11-07 01:06:21 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 6d2a69e4 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 06 05:58:52 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 06 05:58:52 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 06 05:58:52 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 07 01:05:59 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:05:59+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:01 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:01+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:03 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:03+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:05 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:05+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:07 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:07+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:09 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:09+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:11 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:11+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:13 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:13+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:15 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:15+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:17 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:17+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:19 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:19+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
Nov 07 01:06:21 evo-x2 forgejo-runner[635103]: time="2026-11-07T01:06:21+01:00" level=error msg="failed to fetch task" error="unavailable: dial tcp [::1]:3000: connect: connection refused"
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 3197
- thermal-THROTTLE-lines: 11
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
```
```

## memory-emergency-guard lines (all)
```
Nov 06 05:58:59 evo-x2 post-crash-calm-gate[1785]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 06:04:30 evo-x2 memory-emergency-guard-check[31216]: MEMORY EMERGENCY IO-PAUSE (trip #7437, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 707ms CPU time over 3min 39.928s wall clock time, 12.4M memory peak, 7.6M read from disk, 69.2M written to disk.
Nov 06 06:07:43 evo-x2 memory-emergency-guard-check[105482]: MEMORY EMERGENCY IO-PAUSE (trip #7438, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 785ms CPU time over 3min 12.754s wall clock time, 10.5M memory peak, 14.2M read from disk, 49.8M written to disk.
Nov 06 06:07:45 evo-x2 memory-emergency-guard-check[157031]: MEMORY EMERGENCY IO-PAUSE (trip #7439, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 486ms CPU time over 2.732s wall clock time, 11.7M memory peak, 1.3M written to disk.
Nov 06 06:08:13 evo-x2 memory-emergency-guard-check[175298]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.18% sustained (max disk busy 100.0%, MemAvailable=66.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:10:27 evo-x2 memory-emergency-guard-check[209813]: MEMORY EMERGENCY IO-PAUSE (trip #7440, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 14.019s wall clock time, 10.9M memory peak, 5M read from disk, 65.6M written to disk.
Nov 06 06:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:11:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:12:49 evo-x2 memory-emergency-guard-check[347495]: MEMORY EMERGENCY IO-PAUSE (trip #7441, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 6.352s wall clock time, 11.3M memory peak, 416K read from disk, 27.5M written to disk.
Nov 06 06:13:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:13:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:15:32 evo-x2 memory-emergency-guard-check[399596]: MEMORY EMERGENCY IO-PAUSE (trip #7442, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 18.950s wall clock time, 12M memory peak, 5.3M read from disk, 49M written to disk.
Nov 06 06:15:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:16:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:16:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:17:51 evo-x2 memory-emergency-guard-check[447825]: MEMORY EMERGENCY IO-PAUSE (trip #7443, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 7.453s wall clock time, 11.5M memory peak, 3.9M read from disk, 22.3M written to disk.
Nov 06 06:18:14 evo-x2 memory-emergency-guard-check[462464]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.55% sustained (max disk busy 100.0%, MemAvailable=50.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:20:09 evo-x2 post-crash-calm-gate[561899]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:20:18 evo-x2 memory-emergency-guard-check[564536]: MEMORY EMERGENCY IO-PAUSE (trip #7444, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 4.166s wall clock time, 10.1M memory peak, 8.2M read from disk, 53M written to disk.
Nov 06 06:20:24 evo-x2 post-crash-calm-gate[576826]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 06:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:22:47 evo-x2 memory-emergency-guard-check[610659]: MEMORY EMERGENCY IO-PAUSE (trip #7445, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:22:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:22:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 3.176s wall clock time, 10.6M memory peak, 3.3M read from disk, 37.5M written to disk.
Nov 06 06:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:24:09 evo-x2 post-crash-calm-gate[646598]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:24:39 evo-x2 post-crash-calm-gate[663443]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:24:54 evo-x2 post-crash-calm-gate[675659]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:25:16 evo-x2 memory-emergency-guard-check[695714]: MEMORY EMERGENCY IO-PAUSE (trip #7446, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 928ms CPU time over 1.598s wall clock time, 8M memory peak, 6.6M read from disk, 49M written to disk.
Nov 06 06:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:25:54 evo-x2 post-crash-calm-gate[724249]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 06:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:26:39 evo-x2 post-crash-calm-gate[756928]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:27:46 evo-x2 memory-emergency-guard-check[779923]: MEMORY EMERGENCY IO-PAUSE (trip #7447, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 591ms CPU time over 970ms wall clock time, 10.6M memory peak, 3.1M read from disk, 40.1M written to disk.
Nov 06 06:28:15 evo-x2 memory-emergency-guard-check[795071]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.79% sustained (max disk busy 60.9%, MemAvailable=67.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:30:30 evo-x2 memory-emergency-guard-check[849384]: MEMORY EMERGENCY IO-PAUSE (trip #7448, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 13.273s wall clock time, 11M memory peak, 1.5M read from disk, 4.3M written to disk.
Nov 06 06:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:33:07 evo-x2 memory-emergency-guard-check[908716]: MEMORY EMERGENCY IO-PAUSE (trip #7449, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 669ms CPU time over 19.880s wall clock time, 10.3M memory peak, 11.5M read from disk, 19.8M written to disk.
Nov 06 06:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:35:23 evo-x2 memory-emergency-guard-check[997396]: MEMORY EMERGENCY IO-PAUSE (trip #7450, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 6.074s wall clock time, 12.7M memory peak, 22.7M read from disk, 64.8M written to disk.
Nov 06 06:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:38:23 evo-x2 memory-emergency-guard-check[1081887]: MEMORY EMERGENCY IO-PAUSE (trip #7451, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 35.084s wall clock time, 12M memory peak, 8.3M read from disk, 32.9M written to disk.
Nov 06 06:38:23 evo-x2 memory-emergency-guard-check[1099777]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.20% sustained (max disk busy 100.0%, MemAvailable=51.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (35s < 150s, 115s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:38:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:39:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:40:26 evo-x2 memory-emergency-guard-check[1135561]: MEMORY EMERGENCY IO-PAUSE (trip #7452, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 3.126s wall clock time, 10.9M memory peak, 9.2M read from disk, 59M written to disk.
Nov 06 06:40:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:42:55 evo-x2 memory-emergency-guard-check[1205913]: MEMORY EMERGENCY IO-PAUSE (trip #7453, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 1.029s wall clock time, 10.3M memory peak, 12.8M read from disk, 51.8M written to disk.
Nov 06 06:43:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:45:27 evo-x2 memory-emergency-guard-check[1327628]: MEMORY EMERGENCY IO-PAUSE (trip #7454, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 2.146s wall clock time, 9.5M memory peak, 10.1M read from disk, 47.6M written to disk.
Nov 06 06:45:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:46:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:46:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:47:58 evo-x2 memory-emergency-guard-check[1466636]: MEMORY EMERGENCY IO-PAUSE (trip #7455, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 795ms CPU time over 2.587s wall clock time, 10.4M memory peak, 7.4M read from disk, 58M written to disk.
Nov 06 06:48:26 evo-x2 memory-emergency-guard-check[1490892]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.24% sustained (max disk busy 100.0%, MemAvailable=68.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:50:26 evo-x2 post-crash-calm-gate[1551612]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:50:28 evo-x2 memory-emergency-guard-check[1552562]: MEMORY EMERGENCY IO-PAUSE (trip #7456, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:50:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:50:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 773ms CPU time over 1.362s wall clock time, 9.8M memory peak, 2.7M read from disk, 29.5M written to disk.
Nov 06 06:50:41 evo-x2 post-crash-calm-gate[1572893]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 06:50:56 evo-x2 post-crash-calm-gate[1581650]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 06:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:51:41 evo-x2 post-crash-calm-gate[1618160]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:51:56 evo-x2 post-crash-calm-gate[1633687]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:52:11 evo-x2 post-crash-calm-gate[1642182]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 06:52:26 evo-x2 post-crash-calm-gate[1651329]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:52:41 evo-x2 post-crash-calm-gate[1670439]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:52:56 evo-x2 post-crash-calm-gate[1674861]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:53:11 evo-x2 post-crash-calm-gate[1687605]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 06:53:26 evo-x2 post-crash-calm-gate[1704835]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 06:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:53:41 evo-x2 post-crash-calm-gate[1719786]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 06:53:56 evo-x2 post-crash-calm-gate[1732503]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 06:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:54:11 evo-x2 post-crash-calm-gate[1748089]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 06:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:55:02 evo-x2 memory-emergency-guard-check[1765486]: MEMORY EMERGENCY IO-PAUSE (trip #7457, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 632ms CPU time over 5.079s wall clock time, 12.7M memory peak, 2.9M read from disk, 66.5M written to disk.
Nov 06 06:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:57:39 evo-x2 memory-emergency-guard-check[1856402]: MEMORY EMERGENCY IO-PAUSE (trip #7458, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 06:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 905ms CPU time over 12.021s wall clock time, 9.1M memory peak, 19.3M read from disk, 7.9M written to disk.
Nov 06 06:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:58:28 evo-x2 memory-emergency-guard-check[1916401]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.04% sustained (max disk busy 98.3%, MemAvailable=52.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 06:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 06:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:00:25 evo-x2 memory-emergency-guard-check[1988959]: MEMORY EMERGENCY IO-PAUSE (trip #7459, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.187s CPU time over 26.511s wall clock time, 9.2M memory peak, 28.8M read from disk, 48.8M written to disk.
Nov 06 07:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:02:50 evo-x2 memory-emergency-guard-check[2177599]: MEMORY EMERGENCY IO-PAUSE (trip #7460, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 847ms CPU time over 21.027s wall clock time, 11.5M memory peak, 15.6M read from disk, 10.6M written to disk.
Nov 06 07:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:05:44 evo-x2 memory-emergency-guard-check[2295281]: MEMORY EMERGENCY IO-PAUSE (trip #7461, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 885ms CPU time over 43.040s wall clock time, 11.4M memory peak, 11.1M read from disk, 26.1M written to disk.
Nov 06 07:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:06:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:06:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:07:50 evo-x2 memory-emergency-guard-check[2475668]: MEMORY EMERGENCY IO-PAUSE (trip #7462, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 932ms CPU time over 6.643s wall clock time, 10M memory peak, 19.9M read from disk, 63M written to disk.
Nov 06 07:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:08:44 evo-x2 memory-emergency-guard-check[2537110]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.33% sustained (max disk busy 99.7%, MemAvailable=23.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 07:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 186ms CPU time over 287ms wall clock time, 8.5M memory peak, 3.5M read from disk, 4K written to disk.
Nov 06 07:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:11:11 evo-x2 memory-emergency-guard-check[2616346]: MEMORY EMERGENCY IO-PAUSE (trip #7463, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 999ms CPU time over 56.749s wall clock time, 10.7M memory peak, 11.5M read from disk, 2.9M written to disk.
Nov 06 07:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:13:31 evo-x2 memory-emergency-guard-check[2778723]: MEMORY EMERGENCY IO-PAUSE (trip #7464, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:13:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 18.989s wall clock time, 12.8M memory peak, 17.2M read from disk, 45.1M written to disk.
Nov 06 07:13:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:14:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:15:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:15:45 evo-x2 memory-emergency-guard-check[2832020]: MEMORY EMERGENCY IO-PAUSE (trip #7465, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 680ms CPU time over 2.348s wall clock time, 14.1M memory peak, 16.2M read from disk, 57.3M written to disk.
Nov 06 07:16:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:16:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:18:22 evo-x2 memory-emergency-guard-check[2945422]: sort: write failed: 'standard output': Broken pipe
Nov 06 07:18:22 evo-x2 memory-emergency-guard-check[2945422]: sort: write error
Nov 06 07:18:22 evo-x2 memory-emergency-guard-check[2936067]: MEMORY EMERGENCY IO-PAUSE (trip #7466, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 8.846s wall clock time, 18.6M memory peak, 10.1M read from disk, 29.7M written to disk.
Nov 06 07:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:19:13 evo-x2 memory-emergency-guard-check[2960341]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.42% sustained (max disk busy 93.5%, MemAvailable=64.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 07:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:20:47 evo-x2 memory-emergency-guard-check[3031950]: MEMORY EMERGENCY IO-PAUSE (trip #7467, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 888ms CPU time over 3.247s wall clock time, 10.6M memory peak, 3.3M read from disk, 25.8M written to disk.
Nov 06 07:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 153ms CPU time over 269ms wall clock time, 5.3M memory peak, 1.6M read from disk, 4K written to disk.
Nov 06 07:23:17 evo-x2 memory-emergency-guard-check[3132171]: MEMORY EMERGENCY IO-PAUSE (trip #7468, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 1.708s wall clock time, 13.2M memory peak, 7.2M read from disk, 27.9M written to disk.
Nov 06 07:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:24:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:25:48 evo-x2 memory-emergency-guard-check[3239591]: MEMORY EMERGENCY IO-PAUSE (trip #7469, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 2.669s wall clock time, 22M memory peak, 8.7M read from disk, 43.3M written to disk.
Nov 06 07:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:28:30 evo-x2 memory-emergency-guard-check[3364816]: MEMORY EMERGENCY IO-PAUSE (trip #7470, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 887ms CPU time over 14.537s wall clock time, 11.4M memory peak, 25.5M read from disk, 17.5M written to disk.
Nov 06 07:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:29:16 evo-x2 memory-emergency-guard-check[3430758]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.42% sustained (max disk busy 100.0%, MemAvailable=41.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 07:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:31:26 evo-x2 memory-emergency-guard-check[3515235]: MEMORY EMERGENCY IO-PAUSE (trip #7471, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 980ms CPU time over 40.464s wall clock time, 10.8M memory peak, 52.1M read from disk, 10.6M written to disk.
Nov 06 07:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 127ms CPU time over 1.550s wall clock time, 12.4M memory peak, 6M read from disk, 4K written to disk.
Nov 06 07:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:33:55 evo-x2 memory-emergency-guard-check[3635271]: MEMORY EMERGENCY IO-PAUSE (trip #7472, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.229s CPU time over 27.941s wall clock time, 11.8M memory peak, 27M read from disk, 10.4M written to disk.
Nov 06 07:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:37:02 evo-x2 memory-emergency-guard-check[3796784]: MEMORY EMERGENCY IO-PAUSE (trip #7473, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.092s CPU time over 33.211s wall clock time, 11.9M memory peak, 27.8M read from disk, 25.4M written to disk.
Nov 06 07:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:39:30 evo-x2 memory-emergency-guard-check[3960644]: MEMORY EMERGENCY IO-PAUSE (trip #7474, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 602ms CPU time over 27.775s wall clock time, 12.7M memory peak, 12.1M read from disk, 2.8M written to disk.
Nov 06 07:39:33 evo-x2 memory-emergency-guard-check[3981785]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.53% sustained (max disk busy 99.5%, MemAvailable=48.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 07:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 293ms wall clock time, 14.4M memory peak, 4.5M read from disk, 4K written to disk.
Nov 06 07:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 158ms CPU time over 360ms wall clock time, 9.7M memory peak, 4.4M read from disk, 4K written to disk.
Nov 06 07:41:35 evo-x2 memory-emergency-guard-check[4071118]: MEMORY EMERGENCY IO-PAUSE (trip #7475, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:41:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:41:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 967ms CPU time over 2.767s wall clock time, 11.7M memory peak, 3.4M read from disk, 46.9M written to disk.
Nov 06 07:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 200ms CPU time over 445ms wall clock time, 8M memory peak, 1.9M read from disk, 4K written to disk.
Nov 06 07:44:38 evo-x2 memory-emergency-guard-check[1346]: MEMORY EMERGENCY IO-PAUSE (trip #7476, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.127s CPU time over 35.272s wall clock time, 9.5M memory peak, 29.7M read from disk, 3.4M written to disk.
Nov 06 07:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:45:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:47:28 evo-x2 memory-emergency-guard-check[127316]: MEMORY EMERGENCY IO-PAUSE (trip #7477, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.200s CPU time over 50.414s wall clock time, 8.6M memory peak, 29.4M read from disk, 10.9M written to disk.
Nov 06 07:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:50:08 evo-x2 memory-emergency-guard-check[283473]: MEMORY EMERGENCY IO-PAUSE (trip #7478, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 948ms CPU time over 38.945s wall clock time, 10.2M memory peak, 14.6M read from disk, 36.1M written to disk.
Nov 06 07:50:08 evo-x2 memory-emergency-guard-check[349888]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.38% sustained (max disk busy 99.9%, MemAvailable=40.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (39s < 150s, 111s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 07:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:52:21 evo-x2 memory-emergency-guard-check[506296]: MEMORY EMERGENCY IO-PAUSE (trip #7479, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 875ms CPU time over 13.074s wall clock time, 11.1M memory peak, 4.7M read from disk, 21.8M written to disk.
Nov 06 07:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:54:53 evo-x2 memory-emergency-guard-check[673064]: MEMORY EMERGENCY IO-PAUSE (trip #7480, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.226s CPU time over 14.969s wall clock time, 10.6M memory peak, 20.6M read from disk, 61.8M written to disk.
Nov 06 07:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 180ms CPU time over 385ms wall clock time, 10.1M memory peak, 5.6M read from disk, 4K written to disk.
Nov 06 07:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:57:27 evo-x2 memory-emergency-guard-check[911039]: MEMORY EMERGENCY IO-PAUSE (trip #7481, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 933ms CPU time over 18.081s wall clock time, 11.1M memory peak, 15.8M read from disk, 24.3M written to disk.
Nov 06 07:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:59:54 evo-x2 memory-emergency-guard-check[1051136]: MEMORY EMERGENCY IO-PAUSE (trip #7482, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 07:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 07:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 14.684s wall clock time, 19.1M memory peak, 11.9M read from disk, 19.4M written to disk.
Nov 06 08:00:10 evo-x2 memory-emergency-guard-check[1075509]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.66% sustained (max disk busy 100.0%, MemAvailable=43.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:02:15 evo-x2 memory-emergency-guard-check[1184736]: MEMORY EMERGENCY IO-PAUSE (trip #7483, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.048s CPU time over 4.931s wall clock time, 10M memory peak, 7.2M read from disk, 43.3M written to disk.
Nov 06 08:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:06:43 evo-x2 memory-emergency-guard-check[1389835]: MEMORY EMERGENCY IO-PAUSE (trip #7484, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.075s CPU time over 2.085s wall clock time, 9.5M memory peak, 488K read from disk, 8.3M written to disk.
Nov 06 08:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 176ms CPU time over 557ms wall clock time, 6.8M memory peak, 2.4M read from disk, 4K written to disk.
Nov 06 08:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:09:52 evo-x2 memory-emergency-guard-check[1512288]: MEMORY EMERGENCY IO-PAUSE (trip #7485, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.153s CPU time over 9.269s wall clock time, 8.7M memory peak, 21.3M read from disk, 17.6M written to disk.
Nov 06 08:10:14 evo-x2 memory-emergency-guard-check[1536571]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.89% sustained (max disk busy 100.0%, MemAvailable=20.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:12:30 evo-x2 memory-emergency-guard-check[1619983]: MEMORY EMERGENCY IO-PAUSE (trip #7486, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 833ms CPU time over 16.340s wall clock time, 14.9M memory peak, 35.7M read from disk, 9.2M written to disk.
Nov 06 08:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 173ms wall clock time, 7.5M memory peak, 1.2M read from disk, 4K written to disk.
Nov 06 08:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 169ms wall clock time, 8.8M memory peak, 1.3M read from disk, 4K written to disk.
Nov 06 08:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:14:49 evo-x2 memory-emergency-guard-check[1706993]: MEMORY EMERGENCY IO-PAUSE (trip #7487, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.082s CPU time over 4.192s wall clock time, 8.8M memory peak, 10.1M read from disk, 31M written to disk.
Nov 06 08:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:17:19 evo-x2 memory-emergency-guard-check[1799166]: MEMORY EMERGENCY IO-PAUSE (trip #7488, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 751ms CPU time over 3.548s wall clock time, 10.2M memory peak, 21.2M read from disk, 51.9M written to disk.
Nov 06 08:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:19:48 evo-x2 memory-emergency-guard-check[1960342]: MEMORY EMERGENCY IO-PAUSE (trip #7489, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 751ms CPU time over 2.637s wall clock time, 10.6M memory peak, 10M read from disk, 52.6M written to disk.
Nov 06 08:20:16 evo-x2 memory-emergency-guard-check[1983185]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.46% sustained (max disk busy 44.8%, MemAvailable=74.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:22:18 evo-x2 memory-emergency-guard-check[2113032]: MEMORY EMERGENCY IO-PAUSE (trip #7490, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 684ms CPU time over 2.042s wall clock time, 10.5M memory peak, 3.9M read from disk, 45.6M written to disk.
Nov 06 08:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:24:49 evo-x2 memory-emergency-guard-check[2299077]: MEMORY EMERGENCY IO-PAUSE (trip #7491, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.030s CPU time over 2.965s wall clock time, 9.3M memory peak, 5.9M read from disk, 53.2M written to disk.
Nov 06 08:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 658ms wall clock time, 6.5M memory peak, 1.5M read from disk, 4K written to disk.
Nov 06 08:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:30:34 evo-x2 memory-emergency-guard-check[2571442]: MEMORY EMERGENCY IO-PAUSE (trip #7492, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.064s CPU time over 47.214s wall clock time, 8.7M memory peak, 36.9M read from disk, 3.2M written to disk.
Nov 06 08:30:34 evo-x2 memory-emergency-guard-check[2661437]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.09% sustained (max disk busy 100.0%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (47s < 150s, 103s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:32:45 evo-x2 memory-emergency-guard-check[2829036]: MEMORY EMERGENCY IO-PAUSE (trip #7493, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 770ms CPU time over 10.974s wall clock time, 10M memory peak, 14.3M read from disk, 17M written to disk.
Nov 06 08:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:33:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:34:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:35:38 evo-x2 memory-emergency-guard-check[2951265]: MEMORY EMERGENCY IO-PAUSE (trip #7494, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 33.207s wall clock time, 10.7M memory peak, 29.3M read from disk, 33.8M written to disk.
Nov 06 08:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:37:56 evo-x2 memory-emergency-guard-check[3113546]: MEMORY EMERGENCY IO-PAUSE (trip #7495, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.050s CPU time over 17.303s wall clock time, 9.1M memory peak, 8.8M read from disk, 39M written to disk.
Nov 06 08:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:40:13 evo-x2 memory-emergency-guard-check[3387976]: MEMORY EMERGENCY IO-PAUSE (trip #7496, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 779ms CPU time over 3.525s wall clock time, 8.3M memory peak, 2.4M read from disk, 28.7M written to disk.
Nov 06 08:40:40 evo-x2 memory-emergency-guard-check[3447774]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.37% sustained (max disk busy 97.2%, MemAvailable=74.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:40:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:42:43 evo-x2 memory-emergency-guard-check[3577648]: MEMORY EMERGENCY IO-PAUSE (trip #7497, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 3.190s wall clock time, 10M memory peak, 17.1M read from disk, 54.3M written to disk.
Nov 06 08:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:44:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:46:12 evo-x2 memory-emergency-guard-check[3778363]: MEMORY EMERGENCY IO-PAUSE (trip #7498, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 703ms CPU time over 2.630s wall clock time, 10.9M memory peak, 11.5M read from disk, 60.2M written to disk.
Nov 06 08:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:48:46 evo-x2 memory-emergency-guard-check[3958611]: MEMORY EMERGENCY IO-PAUSE (trip #7499, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.057s CPU time over 5.753s wall clock time, 11.2M memory peak, 19M read from disk, 74.8M written to disk.
Nov 06 08:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:50:40 evo-x2 memory-emergency-guard-check[4117668]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.24% sustained (max disk busy 88.0%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 08:50:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:51:14 evo-x2 memory-emergency-guard-check[4131482]: MEMORY EMERGENCY IO-PAUSE (trip #7500, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 762ms CPU time over 3.839s wall clock time, 10.8M memory peak, 57.2M read from disk, 24.4M written to disk.
Nov 06 08:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:53:43 evo-x2 memory-emergency-guard-check[46475]: MEMORY EMERGENCY IO-PAUSE (trip #7501, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 3.251s wall clock time, 10.4M memory peak, 3.7M read from disk, 33.2M written to disk.
Nov 06 08:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:57:16 evo-x2 memory-emergency-guard-check[357614]: MEMORY EMERGENCY IO-PAUSE (trip #7502, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:57:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:57:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 945ms CPU time over 5.372s wall clock time, 9.6M memory peak, 55M read from disk, 53M written to disk.
Nov 06 08:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:59:43 evo-x2 memory-emergency-guard-check[489963]: MEMORY EMERGENCY IO-PAUSE (trip #7503, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 08:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 08:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 945ms CPU time over 1.400s wall clock time, 11.6M memory peak, 9.1M read from disk, 59.3M written to disk.
Nov 06 09:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:00:49 evo-x2 memory-emergency-guard-check[564013]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.07% sustained (max disk busy 89.1%, MemAvailable=49.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (68s < 150s, 82s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:02:55 evo-x2 memory-emergency-guard-check[689973]: MEMORY EMERGENCY IO-PAUSE (trip #7504, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 5.595s wall clock time, 11.9M memory peak, 5.6M read from disk, 32.4M written to disk.
Nov 06 09:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:03:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:05:24 evo-x2 memory-emergency-guard-check[813389]: MEMORY EMERGENCY IO-PAUSE (trip #7505, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 758ms CPU time over 4.236s wall clock time, 12.2M memory peak, 18.5M read from disk, 47.1M written to disk.
Nov 06 09:05:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:06:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:07:59 evo-x2 memory-emergency-guard-check[1039448]: MEMORY EMERGENCY IO-PAUSE (trip #7506, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 8.539s wall clock time, 13.8M memory peak, 10.1M read from disk, 5.2M written to disk.
Nov 06 09:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:08:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:10:35 evo-x2 memory-emergency-guard-check[1160830]: MEMORY EMERGENCY IO-PAUSE (trip #7507, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 13.580s wall clock time, 12.4M memory peak, 20M read from disk, 14M written to disk.
Nov 06 09:10:52 evo-x2 memory-emergency-guard-check[1218133]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.35% sustained (max disk busy 93.2%, MemAvailable=40.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 157ms CPU time over 213ms wall clock time, 6.6M memory peak, 1M read from disk, 4K written to disk.
Nov 06 09:11:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:13:04 evo-x2 memory-emergency-guard-check[1293650]: MEMORY EMERGENCY IO-PAUSE (trip #7508, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 11.081s wall clock time, 12.5M memory peak, 8.9M read from disk, 2.7M written to disk.
Nov 06 09:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:16:15 evo-x2 memory-emergency-guard-check[1410958]: MEMORY EMERGENCY IO-PAUSE (trip #7509, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 797ms CPU time over 22.127s wall clock time, 11.4M memory peak, 18.3M read from disk, 49.8M written to disk.
Nov 06 09:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:20:58 evo-x2 memory-emergency-guard-check[1880388]: MEMORY EMERGENCY IO-PAUSE (trip #7510, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 773ms CPU time over 4.305s wall clock time, 10.9M memory peak, 3.9M read from disk, 50M written to disk.
Nov 06 09:21:24 evo-x2 memory-emergency-guard-check[1927132]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.50% sustained (max disk busy 100.0%, MemAvailable=69.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:23:28 evo-x2 memory-emergency-guard-check[2038236]: MEMORY EMERGENCY IO-PAUSE (trip #7511, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:23:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:23:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 840ms CPU time over 3.329s wall clock time, 8.9M memory peak, 6.4M read from disk, 43.5M written to disk.
Nov 06 09:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:26:16 evo-x2 memory-emergency-guard-check[2213585]: MEMORY EMERGENCY IO-PAUSE (trip #7512, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 684ms CPU time over 21.309s wall clock time, 11.2M memory peak, 912K read from disk, 3.8M written to disk.
Nov 06 09:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:28:29 evo-x2 memory-emergency-guard-check[2293965]: MEMORY EMERGENCY IO-PAUSE (trip #7513, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 2.478s wall clock time, 10.7M memory peak, 10.5M read from disk, 57.7M written to disk.
Nov 06 09:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:31:00 evo-x2 memory-emergency-guard-check[2380184]: MEMORY EMERGENCY IO-PAUSE (trip #7514, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 3.260s wall clock time, 11.3M memory peak, 2.7M read from disk, 42.9M written to disk.
Nov 06 09:31:28 evo-x2 memory-emergency-guard-check[2397088]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.86% sustained (max disk busy 51.4%, MemAvailable=62.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:33:32 evo-x2 memory-emergency-guard-check[2458539]: MEMORY EMERGENCY IO-PAUSE (trip #7515, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.206s CPU time over 3.655s wall clock time, 8.1M memory peak, 6M read from disk, 60.9M written to disk.
Nov 06 09:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:36:01 evo-x2 memory-emergency-guard-check[2518463]: MEMORY EMERGENCY IO-PAUSE (trip #7516, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 2.093s wall clock time, 11.3M memory peak, 2.3M read from disk, 47.7M written to disk.
Nov 06 09:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:38:32 evo-x2 memory-emergency-guard-check[2606986]: MEMORY EMERGENCY IO-PAUSE (trip #7517, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 2.159s wall clock time, 10.3M memory peak, 3.6M read from disk, 38.2M written to disk.
Nov 06 09:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:41:01 evo-x2 memory-emergency-guard-check[2653786]: MEMORY EMERGENCY IO-PAUSE (trip #7518, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 584ms CPU time over 753ms wall clock time, 10.1M memory peak, 2.9M read from disk, 17.4M written to disk.
Nov 06 09:41:31 evo-x2 memory-emergency-guard-check[2671272]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.96% sustained (max disk busy 58.9%, MemAvailable=49.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:44:16 evo-x2 memory-emergency-guard-check[2730904]: MEMORY EMERGENCY IO-PAUSE (trip #7519, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 792ms CPU time over 44.822s wall clock time, 12.5M memory peak, 10M read from disk, 35.9M written to disk.
Nov 06 09:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:44:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:46:19 evo-x2 memory-emergency-guard-check[2812778]: MEMORY EMERGENCY IO-PAUSE (trip #7520, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 2.509s wall clock time, 10.9M memory peak, 3M read from disk, 28M written to disk.
Nov 06 09:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:47:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:47:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:48:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:48:49 evo-x2 memory-emergency-guard-check[2908274]: MEMORY EMERGENCY IO-PAUSE (trip #7521, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 615ms CPU time over 1.753s wall clock time, 11.1M memory peak, 2.5M read from disk, 43.4M written to disk.
Nov 06 09:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:50:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:51:21 evo-x2 memory-emergency-guard-check[2981138]: MEMORY EMERGENCY IO-PAUSE (trip #7522, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 792ms CPU time over 3.520s wall clock time, 9.6M memory peak, 17.2M read from disk, 80.7M written to disk.
Nov 06 09:51:48 evo-x2 memory-emergency-guard-check[3001369]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.03% sustained (max disk busy 68.1%, MemAvailable=63.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 09:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:52:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:53:50 evo-x2 memory-emergency-guard-check[3066351]: MEMORY EMERGENCY IO-PAUSE (trip #7523, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 924ms CPU time over 2.046s wall clock time, 10.3M memory peak, 10.8M read from disk, 70.1M written to disk.
Nov 06 09:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:56:37 evo-x2 memory-emergency-guard-check[3259995]: MEMORY EMERGENCY IO-PAUSE (trip #7524, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 715ms CPU time over 18.532s wall clock time, 10.1M memory peak, 8M read from disk, 6.2M written to disk.
Nov 06 09:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:58:53 evo-x2 memory-emergency-guard-check[3425656]: MEMORY EMERGENCY IO-PAUSE (trip #7525, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 09:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 890ms CPU time over 3.668s wall clock time, 9.9M memory peak, 10.2M read from disk, 65.4M written to disk.
Nov 06 09:59:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 09:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:01:23 evo-x2 memory-emergency-guard-check[3566814]: MEMORY EMERGENCY IO-PAUSE (trip #7526, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 690ms CPU time over 3.506s wall clock time, 11.1M memory peak, 7.3M read from disk, 50.5M written to disk.
Nov 06 10:01:50 evo-x2 memory-emergency-guard-check[3614315]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.36% sustained (max disk busy 63.7%, MemAvailable=59.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:03:53 evo-x2 memory-emergency-guard-check[3742212]: MEMORY EMERGENCY IO-PAUSE (trip #7527, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 904ms CPU time over 3.504s wall clock time, 12.4M memory peak, 15M read from disk, 74.8M written to disk.
Nov 06 10:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:05:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:05:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:06:22 evo-x2 memory-emergency-guard-check[3904723]: MEMORY EMERGENCY IO-PAUSE (trip #7528, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 2.688s wall clock time, 11.8M memory peak, 1.7M read from disk, 39.8M written to disk.
Nov 06 10:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:08:53 evo-x2 memory-emergency-guard-check[4015859]: MEMORY EMERGENCY IO-PAUSE (trip #7529, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 702ms CPU time over 1.825s wall clock time, 11.3M memory peak, 7M read from disk, 40.3M written to disk.
Nov 06 10:09:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:11:26 evo-x2 memory-emergency-guard-check[4083190]: MEMORY EMERGENCY IO-PAUSE (trip #7530, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 957ms CPU time over 2.722s wall clock time, 11.4M memory peak, 1.8M read from disk, 40.7M written to disk.
Nov 06 10:11:54 evo-x2 memory-emergency-guard-check[4107944]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.90% sustained (max disk busy 72.0%, MemAvailable=62.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:14:46 evo-x2 memory-emergency-guard-check[4189228]: MEMORY EMERGENCY IO-PAUSE (trip #7531, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.077s CPU time over 51.655s wall clock time, 12.6M memory peak, 47.3M read from disk, 29.6M written to disk.
Nov 06 10:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 145ms CPU time over 176ms wall clock time, 7.3M memory peak, 1.2M read from disk, 4K written to disk.
Nov 06 10:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:17:24 evo-x2 memory-emergency-guard-check[107306]: MEMORY EMERGENCY IO-PAUSE (trip #7532, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 38.352s wall clock time, 11.8M memory peak, 7.5M read from disk, 11M written to disk.
Nov 06 10:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:20:32 evo-x2 memory-emergency-guard-check[205885]: MEMORY EMERGENCY IO-PAUSE (trip #7533, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 885ms CPU time over 1min 6.934s wall clock time, 12.1M memory peak, 21.8M read from disk, 71.9M written to disk.
Nov 06 10:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:22:04 evo-x2 memory-emergency-guard-check[365436]: MEMORY EMERGENCY IO-PAUSE (trip #7534, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 2.511s wall clock time, 9.6M memory peak, 3.2M read from disk, 38.8M written to disk.
Nov 06 10:22:32 evo-x2 memory-emergency-guard-check[405203]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.79% sustained (max disk busy 71.0%, MemAvailable=69.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:24:37 evo-x2 memory-emergency-guard-check[585203]: MEMORY EMERGENCY IO-PAUSE (trip #7535, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 4.886s wall clock time, 12.2M memory peak, 3.7M read from disk, 54.7M written to disk.
Nov 06 10:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:27:33 evo-x2 memory-emergency-guard-check[800539]: MEMORY EMERGENCY IO-PAUSE (trip #7536, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 919ms wall clock time, 10.6M memory peak, 4.5M read from disk, 61.2M written to disk.
Nov 06 10:28:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:30:04 evo-x2 memory-emergency-guard-check[901447]: MEMORY EMERGENCY IO-PAUSE (trip #7537, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:30:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:30:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 663ms CPU time over 952ms wall clock time, 11.4M memory peak, 9.5M read from disk, 64.9M written to disk.
Nov 06 10:30:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:31:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:33:56 evo-x2 memory-emergency-guard-check[1006858]: MEMORY EMERGENCY IO-PAUSE (trip #7538, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.226s CPU time over 1min 21.750s wall clock time, 9.6M memory peak, 7.3M read from disk, 177.7M written to disk.
Nov 06 10:33:57 evo-x2 memory-emergency-guard-check[1055964]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.97% sustained (max disk busy 100.0%, MemAvailable=58.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (81s < 150s, 69s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:35:39 evo-x2 memory-emergency-guard-check[1118857]: MEMORY EMERGENCY IO-PAUSE (trip #7539, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 731ms CPU time over 10.422s wall clock time, 11.2M memory peak, 26.1M read from disk, 35.6M written to disk.
Nov 06 10:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:38:05 evo-x2 memory-emergency-guard-check[1265269]: MEMORY EMERGENCY IO-PAUSE (trip #7540, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.153s CPU time over 5.388s wall clock time, 10.2M memory peak, 25.4M read from disk, 80.4M written to disk.
Nov 06 10:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:40:36 evo-x2 memory-emergency-guard-check[1425373]: MEMORY EMERGENCY IO-PAUSE (trip #7541, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 826ms CPU time over 4.900s wall clock time, 9.8M memory peak, 7.8M read from disk, 64.7M written to disk.
Nov 06 10:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:43:06 evo-x2 memory-emergency-guard-check[1561822]: MEMORY EMERGENCY IO-PAUSE (trip #7542, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 838ms CPU time over 4.581s wall clock time, 11.9M memory peak, 7.9M read from disk, 82.1M written to disk.
Nov 06 10:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:44:02 evo-x2 memory-emergency-guard-check[1612374]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.22% sustained (max disk busy 100.0%, MemAvailable=61.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:45:35 evo-x2 memory-emergency-guard-check[1692712]: MEMORY EMERGENCY IO-PAUSE (trip #7543, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 774ms CPU time over 3.469s wall clock time, 11.4M memory peak, 3.3M read from disk, 59.2M written to disk.
Nov 06 10:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:48:09 evo-x2 memory-emergency-guard-check[1783177]: MEMORY EMERGENCY IO-PAUSE (trip #7544, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 6.353s wall clock time, 12.9M memory peak, 1.6M read from disk, 37.4M written to disk.
Nov 06 10:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:50:36 evo-x2 memory-emergency-guard-check[1858675]: MEMORY EMERGENCY IO-PAUSE (trip #7545, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 3.900s wall clock time, 10.2M memory peak, 2M read from disk, 37.3M written to disk.
Nov 06 10:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:53:23 evo-x2 memory-emergency-guard-check[1981012]: MEMORY EMERGENCY IO-PAUSE (trip #7546, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 947ms CPU time over 20.223s wall clock time, 11M memory peak, 25.9M read from disk, 9.3M written to disk.
Nov 06 10:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:54:03 evo-x2 memory-emergency-guard-check[2065712]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.36% sustained (max disk busy 96.5%, MemAvailable=44.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 10:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:55:42 evo-x2 memory-emergency-guard-check[2177635]: MEMORY EMERGENCY IO-PAUSE (trip #7547, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 9.389s wall clock time, 14.1M memory peak, 15.5M read from disk, 3.4M written to disk.
Nov 06 10:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 358ms wall clock time, 10.7M memory peak, 3.8M read from disk, 4K written to disk.
Nov 06 10:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 108ms CPU time over 158ms wall clock time, 8.9M memory peak, 1M read from disk, 4K written to disk.
Nov 06 10:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:58:32 evo-x2 memory-emergency-guard-check[2262282]: MEMORY EMERGENCY IO-PAUSE (trip #7548, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 10:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 27.362s wall clock time, 13.6M memory peak, 12.8M read from disk, 28M written to disk.
Nov 06 10:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 10:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 242ms wall clock time, 9.6M memory peak, 3.8M read from disk, 4K written to disk.
Nov 06 11:02:01 evo-x2 memory-emergency-guard-check[2394262]: MEMORY EMERGENCY IO-PAUSE (trip #7549, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.098s CPU time over 1min 25.916s wall clock time, 12.4M memory peak, 36.3M read from disk, 12.2M written to disk.
Nov 06 11:02:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:03:55 evo-x2 memory-emergency-guard-check[2569471]: MEMORY EMERGENCY IO-PAUSE (trip #7550, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.017s CPU time over 23.080s wall clock time, 9.7M memory peak, 16M read from disk, 6.9M written to disk.
Nov 06 11:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:04:32 evo-x2 memory-emergency-guard-check[2617690]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.60% sustained (max disk busy 100.0%, MemAvailable=49.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:06:30 evo-x2 memory-emergency-guard-check[2674899]: MEMORY EMERGENCY IO-PAUSE (trip #7551, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.107s CPU time over 26.464s wall clock time, 11.3M memory peak, 25.2M read from disk, 57.7M written to disk.
Nov 06 11:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 149ms CPU time over 422ms wall clock time, 7.1M memory peak, 1.5M read from disk, 4K written to disk.
Nov 06 11:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:09:04 evo-x2 memory-emergency-guard-check[2794109]: MEMORY EMERGENCY IO-PAUSE (trip #7552, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.340s CPU time over 31.264s wall clock time, 9.4M memory peak, 25.8M read from disk, 740K written to disk.
Nov 06 11:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:11:30 evo-x2 memory-emergency-guard-check[2949150]: MEMORY EMERGENCY IO-PAUSE (trip #7553, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.065s CPU time over 26.001s wall clock time, 10.4M memory peak, 21.8M read from disk, 12.5M written to disk.
Nov 06 11:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:13:41 evo-x2 memory-emergency-guard-check[3126134]: MEMORY EMERGENCY IO-PAUSE (trip #7554, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 5.974s wall clock time, 12.3M memory peak, 9.7M read from disk, 12.4M written to disk.
Nov 06 11:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:14:35 evo-x2 memory-emergency-guard-check[3163011]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.43% sustained (max disk busy 100.0%, MemAvailable=42.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:16:14 evo-x2 memory-emergency-guard-check[3197513]: MEMORY EMERGENCY IO-PAUSE (trip #7555, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:16:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:16:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 7.797s wall clock time, 11.6M memory peak, 11M read from disk, 31.2M written to disk.
Nov 06 11:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:18:51 evo-x2 memory-emergency-guard-check[3317831]: MEMORY EMERGENCY IO-PAUSE (trip #7556, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 699ms CPU time over 15.269s wall clock time, 13.1M memory peak, 19.7M read from disk, 8.2M written to disk.
Nov 06 11:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:21:10 evo-x2 memory-emergency-guard-check[3442189]: MEMORY EMERGENCY IO-PAUSE (trip #7557, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 794ms CPU time over 3.319s wall clock time, 10.9M memory peak, 22.9M read from disk, 81.9M written to disk.
Nov 06 11:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:23:40 evo-x2 memory-emergency-guard-check[3574894]: MEMORY EMERGENCY IO-PAUSE (trip #7558, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 2.923s wall clock time, 10.9M memory peak, 14.4M read from disk, 65.4M written to disk.
Nov 06 11:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:24:37 evo-x2 memory-emergency-guard-check[3601339]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.35% sustained (max disk busy 100.0%, MemAvailable=67.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:26:09 evo-x2 memory-emergency-guard-check[3632302]: MEMORY EMERGENCY IO-PAUSE (trip #7559, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 621ms CPU time over 1.876s wall clock time, 11.8M memory peak, 5.2M read from disk, 45.1M written to disk.
Nov 06 11:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:28:40 evo-x2 memory-emergency-guard-check[3743966]: MEMORY EMERGENCY IO-PAUSE (trip #7560, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 1.980s wall clock time, 11.9M memory peak, 5.9M read from disk, 48.6M written to disk.
Nov 06 11:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:31:10 evo-x2 memory-emergency-guard-check[3852696]: MEMORY EMERGENCY IO-PAUSE (trip #7561, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 557ms CPU time over 1.914s wall clock time, 11M memory peak, 736K read from disk, 33.8M written to disk.
Nov 06 11:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:33:41 evo-x2 memory-emergency-guard-check[3896018]: MEMORY EMERGENCY IO-PAUSE (trip #7562, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 660ms CPU time over 1.974s wall clock time, 10.8M memory peak, 3.2M read from disk, 21.2M written to disk.
Nov 06 11:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:34:39 evo-x2 memory-emergency-guard-check[3931903]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.81% sustained (max disk busy 95.1%, MemAvailable=66.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:36:11 evo-x2 memory-emergency-guard-check[3986143]: MEMORY EMERGENCY IO-PAUSE (trip #7563, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 664ms CPU time over 1.277s wall clock time, 11.8M memory peak, 11.5M read from disk, 48.4M written to disk.
Nov 06 11:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:39:43 evo-x2 memory-emergency-guard-check[4073844]: MEMORY EMERGENCY IO-PAUSE (trip #7564, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 2.420s wall clock time, 13.1M memory peak, 9M read from disk, 62.9M written to disk.
Nov 06 11:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:42:14 evo-x2 memory-emergency-guard-check[4118262]: MEMORY EMERGENCY IO-PAUSE (trip #7565, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:42:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:42:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 2.938s wall clock time, 12M memory peak, 7M read from disk, 50.2M written to disk.
Nov 06 11:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:45:15 evo-x2 memory-emergency-guard-check[4164439]: MEMORY EMERGENCY IO-PAUSE (trip #7566, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 3.567s wall clock time, 12.5M memory peak, 2.7M read from disk, 39.9M written to disk.
Nov 06 11:45:42 evo-x2 memory-emergency-guard-check[4176082]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.48% sustained (max disk busy 25.2%, MemAvailable=65.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:47:44 evo-x2 memory-emergency-guard-check[10213]: MEMORY EMERGENCY IO-PAUSE (trip #7567, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 552ms CPU time over 2.000s wall clock time, 11.8M memory peak, 1.5M read from disk, 34.6M written to disk.
Nov 06 11:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:49:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:50:16 evo-x2 memory-emergency-guard-check[47991]: MEMORY EMERGENCY IO-PAUSE (trip #7568, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:50:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:50:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 2.871s wall clock time, 10.9M memory peak, 3.8M read from disk, 8.6M written to disk.
Nov 06 11:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:52:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:52:46 evo-x2 memory-emergency-guard-check[88358]: MEMORY EMERGENCY IO-PAUSE (trip #7569, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 1.689s wall clock time, 11.4M memory peak, 2M read from disk, 28.8M written to disk.
Nov 06 11:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:54:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:55:15 evo-x2 memory-emergency-guard-check[154086]: MEMORY EMERGENCY IO-PAUSE (trip #7570, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 670ms wall clock time, 11.7M memory peak, 1.4M read from disk, 38M written to disk.
Nov 06 11:55:45 evo-x2 memory-emergency-guard-check[177108]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.41% sustained (max disk busy 60.7%, MemAvailable=66.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 11:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:56:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:57:47 evo-x2 memory-emergency-guard-check[237287]: MEMORY EMERGENCY IO-PAUSE (trip #7571, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 11:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 656ms CPU time over 1.962s wall clock time, 10.9M memory peak, 10.7M read from disk, 65.6M written to disk.
Nov 06 11:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 11:59:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:00:19 evo-x2 memory-emergency-guard-check[423063]: MEMORY EMERGENCY IO-PAUSE (trip #7572, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 955ms CPU time over 3.035s wall clock time, 9.2M memory peak, 2.4M read from disk, 31.4M written to disk.
Nov 06 12:00:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:01:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:01:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:02:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:02:50 evo-x2 memory-emergency-guard-check[560546]: MEMORY EMERGENCY IO-PAUSE (trip #7573, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 4.462s wall clock time, 12.6M memory peak, 2.8M read from disk, 80.9M written to disk.
Nov 06 12:03:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:03:43 evo-x2 gatus[40370]: 2026/11/06 12:03:43 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Nov 06 12:03:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:03:56 evo-x2 systemd[1632]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Nov 06 12:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:05:23 evo-x2 memory-emergency-guard-check[674434]: MEMORY EMERGENCY IO-PAUSE (trip #7574, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 7.030s wall clock time, 11.2M memory peak, 8.5M read from disk, 68.4M written to disk.
Nov 06 12:05:46 evo-x2 memory-emergency-guard-check[728291]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.88% sustained (max disk busy 100.0%, MemAvailable=61.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 12:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:06:44 evo-x2 post-crash-calm-gate[745660]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 12:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:06:59 evo-x2 post-crash-calm-gate[747768]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 12:07:14 evo-x2 post-crash-calm-gate[752830]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 12:07:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:07:29 evo-x2 post-crash-calm-gate[754551]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 12:07:44 evo-x2 post-crash-calm-gate[760797]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 12:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:07:59 evo-x2 post-crash-calm-gate[764927]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 12:08:14 evo-x2 post-crash-calm-gate[770259]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 06 12:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:08:44 evo-x2 post-crash-calm-gate[778796]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 06 12:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:09:49 evo-x2 memory-emergency-guard-check[795733]: MEMORY EMERGENCY IO-PAUSE (trip #7575, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 666ms CPU time over 3.390s wall clock time, 10.4M memory peak, 2.1M read from disk, 50.1M written to disk.
Nov 06 12:10:14 evo-x2 post-crash-calm-gate[809618]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 12:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:10:29 evo-x2 post-crash-calm-gate[814226]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 12:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:12:19 evo-x2 memory-emergency-guard-check[841806]: MEMORY EMERGENCY IO-PAUSE (trip #7576, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 3.361s wall clock time, 12.8M memory peak, 2.2M read from disk, 39M written to disk.
Nov 06 12:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:14:47 evo-x2 memory-emergency-guard-check[915952]: MEMORY EMERGENCY IO-PAUSE (trip #7577, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 949ms wall clock time, 11.3M memory peak, 11.5M read from disk, 55.1M written to disk.
Nov 06 12:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:16:17 evo-x2 memory-emergency-guard-check[948758]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.29% sustained (max disk busy 29.2%, MemAvailable=64.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 12:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:19:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:20:19 evo-x2 memory-emergency-guard-check[996221]: MEMORY EMERGENCY IO-PAUSE (trip #7578, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 510ms CPU time over 721ms wall clock time, 13.4M memory peak, 508K read from disk, 7.6M written to disk.
Nov 06 12:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:23:19 evo-x2 systemd[1632]: Started [systemd-run] /nix/store/hf9wcn7jhcynf4ihndzbscbknx97in30-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY GUARD DEAD; UNIT CRASH LOOP" "memory-emergency-guard metrics are missing/stale (-1s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard | A monitored service is restart-looping (indexer-web) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u indexer-web -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Nov 06 12:23:49 evo-x2 memory-emergency-guard-check[1045151]: MEMORY EMERGENCY IO-PAUSE (trip #7579, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 1.018s wall clock time, 12.1M memory peak, 19.6M read from disk, 56M written to disk.
Nov 06 12:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:26:20 evo-x2 memory-emergency-guard-check[1078495]: MEMORY EMERGENCY IO-PAUSE (trip #7580, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:26:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:26:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 1.001s wall clock time, 12.1M memory peak, 24.7M read from disk, 78.4M written to disk.
Nov 06 12:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:29:22 evo-x2 memory-emergency-guard-check[1112332]: MEMORY EMERGENCY IO-PAUSE (trip #7581, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 500ms CPU time over 709ms wall clock time, 11.7M memory peak, 816K read from disk, 14.6M written to disk.
Nov 06 12:29:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:30:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:34:23 evo-x2 memory-emergency-guard-check[1174830]: MEMORY EMERGENCY IO-PAUSE (trip #7582, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 485ms CPU time over 543ms wall clock time, 11.7M memory peak, 1.1M read from disk, 18.9M written to disk.
Nov 06 12:34:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:38:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:39:25 evo-x2 memory-emergency-guard-check[1233442]: MEMORY EMERGENCY IO-PAUSE (trip #7583, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 538ms CPU time over 1.856s wall clock time, 12.1M memory peak, 5.2M read from disk, 32.8M written to disk.
Nov 06 12:39:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:43:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:46:57 evo-x2 memory-emergency-guard-check[1325088]: MEMORY EMERGENCY IO-PAUSE (trip #7584, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 611ms CPU time over 931ms wall clock time, 11M memory peak, 4.1M read from disk, 35M written to disk.
Nov 06 12:47:26 evo-x2 memory-emergency-guard-check[1337133]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.73% sustained (max disk busy 50.2%, MemAvailable=65.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 12:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:49:58 evo-x2 memory-emergency-guard-check[1376098]: MEMORY EMERGENCY IO-PAUSE (trip #7585, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 543ms CPU time over 1.103s wall clock time, 11M memory peak, 640K read from disk, 16.1M written to disk.
Nov 06 12:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:52:28 evo-x2 memory-emergency-guard-check[1461817]: MEMORY EMERGENCY IO-PAUSE (trip #7586, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 805ms CPU time over 1.125s wall clock time, 10.3M memory peak, 1.5M read from disk, 24.6M written to disk.
Nov 06 12:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:53:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:54:59 evo-x2 memory-emergency-guard-check[1541455]: MEMORY EMERGENCY IO-PAUSE (trip #7587, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 647ms wall clock time, 11.6M memory peak, 1.6M read from disk, 33M written to disk.
Nov 06 12:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:55:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:59:00 evo-x2 memory-emergency-guard-check[1598278]: MEMORY EMERGENCY IO-PAUSE (trip #7588, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 12:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 844ms CPU time over 1.153s wall clock time, 10M memory peak, 3.4M read from disk, 33.5M written to disk.
Nov 06 12:59:16 evo-x2 post-crash-calm-gate[1610507]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 12:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 12:59:31 evo-x2 post-crash-calm-gate[1618145]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 12:59:47 evo-x2 post-crash-calm-gate[1622657]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 12:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:00:02 evo-x2 post-crash-calm-gate[1629544]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 13:00:17 evo-x2 post-crash-calm-gate[1637885]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 13:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:00:32 evo-x2 post-crash-calm-gate[1645108]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 06 13:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:02:01 evo-x2 memory-emergency-guard-check[1659933]: MEMORY EMERGENCY IO-PAUSE (trip #7589, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 592ms CPU time over 766ms wall clock time, 11M memory peak, 6.7M read from disk, 42.2M written to disk.
Nov 06 13:02:17 evo-x2 post-crash-calm-gate[1672953]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 13:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:02:32 evo-x2 post-crash-calm-gate[1688972]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 13:03:00 evo-x2 memory-emergency-guard-check[1699206]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.23% sustained (max disk busy 81.4%, MemAvailable=62.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:03:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:04:32 evo-x2 memory-emergency-guard-check[1738384]: MEMORY EMERGENCY IO-PAUSE (trip #7590, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:04:32 evo-x2 post-crash-calm-gate[1741162]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 13:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 953ms CPU time over 1.139s wall clock time, 9.4M memory peak, 2.5M read from disk, 36.9M written to disk.
Nov 06 13:04:47 evo-x2 post-crash-calm-gate[1755667]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 06 13:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:07:03 evo-x2 memory-emergency-guard-check[1818900]: MEMORY EMERGENCY IO-PAUSE (trip #7591, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.536s CPU time over 2.354s wall clock time, 8.1M memory peak, 1.4M read from disk, 42.4M written to disk.
Nov 06 13:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:09:32 evo-x2 memory-emergency-guard-check[1882142]: MEMORY EMERGENCY IO-PAUSE (trip #7592, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 805ms CPU time over 965ms wall clock time, 10.5M memory peak, 192K read from disk, 34.4M written to disk.
Nov 06 13:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:14:03 evo-x2 memory-emergency-guard-check[2000553]: MEMORY EMERGENCY IO-PAUSE (trip #7593, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 1.006s wall clock time, 10.3M memory peak, 7.9M read from disk, 54.1M written to disk.
Nov 06 13:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:15:02 evo-x2 memory-emergency-guard-check[2032713]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.31% sustained (max disk busy 60.0%, MemAvailable=61.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:16:34 evo-x2 memory-emergency-guard-check[2060669]: MEMORY EMERGENCY IO-PAUSE (trip #7594, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 1.622s wall clock time, 11M memory peak, 4.5M read from disk, 57.9M written to disk.
Nov 06 13:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:19:35 evo-x2 memory-emergency-guard-check[2205421]: MEMORY EMERGENCY IO-PAUSE (trip #7595, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 839ms CPU time over 2.318s wall clock time, 9.1M memory peak, 4.5M read from disk, 42.8M written to disk.
Nov 06 13:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:23:05 evo-x2 memory-emergency-guard-check[2372272]: MEMORY EMERGENCY IO-PAUSE (trip #7596, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 915ms wall clock time, 9.8M memory peak, 3.2M read from disk, 50M written to disk.
Nov 06 13:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:25:04 evo-x2 memory-emergency-guard-check[2457374]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.56% sustained (max disk busy 97.7%, MemAvailable=59.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:25:36 evo-x2 memory-emergency-guard-check[2477702]: MEMORY EMERGENCY IO-PAUSE (trip #7597, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 770ms CPU time over 1.875s wall clock time, 10.5M memory peak, 172K read from disk, 31.8M written to disk.
Nov 06 13:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:33:10 evo-x2 memory-emergency-guard-check[2849249]: MEMORY EMERGENCY IO-PAUSE (trip #7598, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 2.353s wall clock time, 11.4M memory peak, 4.8M read from disk, 52.9M written to disk.
Nov 06 13:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:35:08 evo-x2 memory-emergency-guard-check[2955038]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.02% sustained (max disk busy 62.7%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:40:11 evo-x2 memory-emergency-guard-check[3149686]: MEMORY EMERGENCY IO-PAUSE (trip #7599, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 861ms CPU time over 1.011s wall clock time, 10.1M memory peak, 5.6M read from disk, 21.3M written to disk.
Nov 06 13:40:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:42:42 evo-x2 memory-emergency-guard-check[3283489]: MEMORY EMERGENCY IO-PAUSE (trip #7600, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 863ms CPU time over 1.135s wall clock time, 8.6M memory peak, 4M read from disk, 26.5M written to disk.
Nov 06 13:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:45:13 evo-x2 memory-emergency-guard-check[3345321]: MEMORY EMERGENCY IO-PAUSE (trip #7601, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 958ms CPU time over 1.144s wall clock time, 8.8M memory peak, 3.6M read from disk, 30.1M written to disk.
Nov 06 13:45:42 evo-x2 memory-emergency-guard-check[3365525]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.41% sustained (max disk busy 90.4%, MemAvailable=47.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:46:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:47:44 evo-x2 memory-emergency-guard-check[3403986]: MEMORY EMERGENCY IO-PAUSE (trip #7602, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.018s CPU time over 1.414s wall clock time, 11M memory peak, 14M read from disk, 38.6M written to disk.
Nov 06 13:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:50:15 evo-x2 memory-emergency-guard-check[3480452]: MEMORY EMERGENCY IO-PAUSE (trip #7603, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 576ms CPU time over 871ms wall clock time, 11.9M memory peak, 3.7M read from disk, 25.6M written to disk.
Nov 06 13:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:51:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:51:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:52:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:54:17 evo-x2 memory-emergency-guard-check[3563836]: MEMORY EMERGENCY IO-PAUSE (trip #7604, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 730ms CPU time over 1.207s wall clock time, 10.9M memory peak, 26.6M read from disk, 74.6M written to disk.
Nov 06 13:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:56:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:57:18 evo-x2 memory-emergency-guard-check[3682095]: MEMORY EMERGENCY IO-PAUSE (trip #7605, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 13:57:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:57:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 675ms CPU time over 868ms wall clock time, 11.4M memory peak, 5M read from disk, 42.1M written to disk.
Nov 06 13:57:48 evo-x2 memory-emergency-guard-check[3702593]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.44% sustained (max disk busy 82.0%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 13:57:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:59:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 13:59:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:00:50 evo-x2 memory-emergency-guard-check[3769668]: MEMORY EMERGENCY IO-PAUSE (trip #7606, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 596ms CPU time over 771ms wall clock time, 11.4M memory peak, 8.2M read from disk, 43.4M written to disk.
Nov 06 14:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:03:21 evo-x2 memory-emergency-guard-check[3810604]: MEMORY EMERGENCY IO-PAUSE (trip #7607, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 943ms wall clock time, 11.4M memory peak, 22.4M read from disk, 53.2M written to disk.
Nov 06 14:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:05:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:06:51 evo-x2 memory-emergency-guard-check[3874721]: MEMORY EMERGENCY IO-PAUSE (trip #7608, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 576ms CPU time over 711ms wall clock time, 12.4M memory peak, 4.8M read from disk, 38.2M written to disk.
Nov 06 14:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 102ms CPU time over 130ms wall clock time, 13.2M memory peak, 3.3M read from disk, 4K written to disk.
Nov 06 14:07:51 evo-x2 memory-emergency-guard-check[3904644]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.97% sustained (max disk busy 93.8%, MemAvailable=59.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:09:22 evo-x2 memory-emergency-guard-check[3982615]: MEMORY EMERGENCY IO-PAUSE (trip #7609, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 723ms CPU time over 1.197s wall clock time, 11.1M memory peak, 23.6M read from disk, 66.6M written to disk.
Nov 06 14:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:10:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:13:22 evo-x2 memory-emergency-guard-check[4180408]: MEMORY EMERGENCY IO-PAUSE (trip #7610, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 676ms CPU time over 903ms wall clock time, 11.5M memory peak, 8.9M read from disk, 52.2M written to disk.
Nov 06 14:13:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:14:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:14:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:15:53 evo-x2 memory-emergency-guard-check[112036]: MEMORY EMERGENCY IO-PAUSE (trip #7611, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 706ms wall clock time, 13M memory peak, 1.7M read from disk, 26.8M written to disk.
Nov 06 14:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:17:53 evo-x2 memory-emergency-guard-check[232882]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.82% sustained (max disk busy 93.0%, MemAvailable=65.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:18:24 evo-x2 memory-emergency-guard-check[245132]: MEMORY EMERGENCY IO-PAUSE (trip #7612, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 1.166s wall clock time, 13.1M memory peak, 1.6M read from disk, 28.1M written to disk.
Nov 06 14:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:20:55 evo-x2 memory-emergency-guard-check[349855]: MEMORY EMERGENCY IO-PAUSE (trip #7613, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 919ms wall clock time, 13.4M memory peak, 11.2M read from disk, 56.9M written to disk.
Nov 06 14:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:22:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:23:25 evo-x2 memory-emergency-guard-check[412458]: MEMORY EMERGENCY IO-PAUSE (trip #7614, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 1.179s wall clock time, 15.1M memory peak, 2.8M read from disk, 32.1M written to disk.
Nov 06 14:23:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:25:56 evo-x2 memory-emergency-guard-check[482804]: MEMORY EMERGENCY IO-PAUSE (trip #7615, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 626ms CPU time over 736ms wall clock time, 16.4M memory peak, 3M read from disk, 30.7M written to disk.
Nov 06 14:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:27:55 evo-x2 memory-emergency-guard-check[546327]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.60% sustained (max disk busy 87.1%, MemAvailable=66.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:28:26 evo-x2 memory-emergency-guard-check[558356]: MEMORY EMERGENCY IO-PAUSE (trip #7616, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 598ms CPU time over 720ms wall clock time, 13.9M memory peak, 376K read from disk, 20.2M written to disk.
Nov 06 14:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:30:57 evo-x2 memory-emergency-guard-check[637634]: MEMORY EMERGENCY IO-PAUSE (trip #7617, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 983ms wall clock time, 17.1M memory peak, 9.4M read from disk, 22.2M written to disk.
Nov 06 14:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:33:28 evo-x2 memory-emergency-guard-check[753701]: MEMORY EMERGENCY IO-PAUSE (trip #7618, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 799ms CPU time over 1.008s wall clock time, 15.2M memory peak, 6.6M read from disk, 31.2M written to disk.
Nov 06 14:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 106ms CPU time over 133ms wall clock time, 9M memory peak, 1.1M read from disk, 4K written to disk.
Nov 06 14:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:35:58 evo-x2 memory-emergency-guard-check[897844]: MEMORY EMERGENCY IO-PAUSE (trip #7619, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:35:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:35:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 689ms CPU time over 815ms wall clock time, 14.5M memory peak, 4.7M read from disk, 26.7M written to disk.
Nov 06 14:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:37:57 evo-x2 memory-emergency-guard-check[995296]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.05% sustained (max disk busy 79.0%, MemAvailable=62.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:38:28 evo-x2 memory-emergency-guard-check[1014463]: MEMORY EMERGENCY IO-PAUSE (trip #7620, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 894ms CPU time over 1.000s wall clock time, 16.1M memory peak, 656K read from disk, 15.5M written to disk.
Nov 06 14:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:40:58 evo-x2 memory-emergency-guard-check[1146645]: MEMORY EMERGENCY IO-PAUSE (trip #7621, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 707ms CPU time over 820ms wall clock time, 17.7M memory peak, 832K read from disk, 15M written to disk.
Nov 06 14:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:43:29 evo-x2 memory-emergency-guard-check[1244547]: MEMORY EMERGENCY IO-PAUSE (trip #7622, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 735ms CPU time over 804ms wall clock time, 14.1M memory peak, 816K read from disk, 14.6M written to disk.
Nov 06 14:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:46:00 evo-x2 memory-emergency-guard-check[1327552]: MEMORY EMERGENCY IO-PAUSE (trip #7623, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 1.234s wall clock time, 12.4M memory peak, 3.9M read from disk, 23.4M written to disk.
Nov 06 14:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:48:00 evo-x2 memory-emergency-guard-check[1362939]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.94% sustained (max disk busy 63.4%, MemAvailable=63.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:48:31 evo-x2 memory-emergency-guard-check[1370502]: MEMORY EMERGENCY IO-PAUSE (trip #7624, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 548ms CPU time over 595ms wall clock time, 12.4M memory peak, 736K read from disk, 14M written to disk.
Nov 06 14:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:51:04 evo-x2 memory-emergency-guard-check[1466166]: MEMORY EMERGENCY IO-PAUSE (trip #7625, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 2.040s wall clock time, 12.7M memory peak, 13.2M read from disk, 30.3M written to disk.
Nov 06 14:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:53:33 evo-x2 memory-emergency-guard-check[1544642]: MEMORY EMERGENCY IO-PAUSE (trip #7626, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 545ms CPU time over 1.071s wall clock time, 11.5M memory peak, 1.9M read from disk, 19.2M written to disk.
Nov 06 14:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 169ms CPU time over 385ms wall clock time, 10.2M memory peak, 5.2M read from disk, 4K written to disk.
Nov 06 14:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:56:04 evo-x2 memory-emergency-guard-check[1627527]: MEMORY EMERGENCY IO-PAUSE (trip #7627, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 1.388s wall clock time, 10.9M memory peak, 5.3M read from disk, 17.1M written to disk.
Nov 06 14:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:58:04 evo-x2 memory-emergency-guard-check[1700340]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.52% sustained (max disk busy 81.4%, MemAvailable=61.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 14:58:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:58:36 evo-x2 memory-emergency-guard-check[1709080]: MEMORY EMERGENCY IO-PAUSE (trip #7628, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 14:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 542ms CPU time over 1.606s wall clock time, 12.1M memory peak, 4.2M read from disk, 19.3M written to disk.
Nov 06 14:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 14:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:01:07 evo-x2 memory-emergency-guard-check[1775353]: MEMORY EMERGENCY IO-PAUSE (trip #7629, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 1.024s wall clock time, 10.8M memory peak, 17.3M read from disk, 41.8M written to disk.
Nov 06 15:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:03:38 evo-x2 memory-emergency-guard-check[1840252]: MEMORY EMERGENCY IO-PAUSE (trip #7630, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 526ms CPU time over 636ms wall clock time, 11.7M memory peak, 1.1M read from disk, 17.6M written to disk.
Nov 06 15:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:06:09 evo-x2 memory-emergency-guard-check[1882970]: MEMORY EMERGENCY IO-PAUSE (trip #7631, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 829ms wall clock time, 12.2M memory peak, 12.4M read from disk, 34.6M written to disk.
Nov 06 15:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:08:09 evo-x2 memory-emergency-guard-check[1928758]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.90% sustained (max disk busy 99.9%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 15:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:08:40 evo-x2 memory-emergency-guard-check[1937084]: MEMORY EMERGENCY IO-PAUSE (trip #7632, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 762ms CPU time over 934ms wall clock time, 9.7M memory peak, 3.9M read from disk, 22.6M written to disk.
Nov 06 15:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:11:10 evo-x2 memory-emergency-guard-check[1973843]: MEMORY EMERGENCY IO-PAUSE (trip #7633, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 693ms CPU time over 1.048s wall clock time, 12.2M memory peak, 25.3M read from disk, 56.4M written to disk.
Nov 06 15:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:15:12 evo-x2 memory-emergency-guard-check[2024931]: MEMORY EMERGENCY IO-PAUSE (trip #7634, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 547ms CPU time over 620ms wall clock time, 11.7M memory peak, 1.4M read from disk, 22.9M written to disk.
Nov 06 15:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:17:43 evo-x2 memory-emergency-guard-check[2111305]: MEMORY EMERGENCY IO-PAUSE (trip #7635, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 773ms wall clock time, 11.2M memory peak, 11.1M read from disk, 26.8M written to disk.
Nov 06 15:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:18:42 evo-x2 memory-emergency-guard-check[2128277]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.27% sustained (max disk busy 21.9%, MemAvailable=64.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 15:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:20:14 evo-x2 memory-emergency-guard-check[2161729]: MEMORY EMERGENCY IO-PAUSE (trip #7636, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 953ms wall clock time, 10.7M memory peak, 1.7M read from disk, 19.3M written to disk.
Nov 06 15:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:23:44 evo-x2 memory-emergency-guard-check[2234738]: MEMORY EMERGENCY IO-PAUSE (trip #7637, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 772ms wall clock time, 11.1M memory peak, 9.5M read from disk, 22.9M written to disk.
Nov 06 15:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:26:14 evo-x2 memory-emergency-guard-check[2313792]: MEMORY EMERGENCY IO-PAUSE (trip #7638, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 576ms CPU time over 703ms wall clock time, 10.9M memory peak, 2M read from disk, 18.1M written to disk.
Nov 06 15:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:28:45 evo-x2 memory-emergency-guard-check[2352237]: MEMORY EMERGENCY IO-PAUSE (trip #7639, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 499ms CPU time over 564ms wall clock time, 12M memory peak, 1.8M read from disk, 17.4M written to disk.
Nov 06 15:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:29:45 evo-x2 memory-emergency-guard-check[2369062]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.29% sustained (max disk busy 86.2%, MemAvailable=62.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 15:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:34:18 evo-x2 memory-emergency-guard-check[2423538]: MEMORY EMERGENCY IO-PAUSE (trip #7640, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 508ms CPU time over 596ms wall clock time, 11.3M memory peak, 3M read from disk, 17M written to disk.
Nov 06 15:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:36:49 evo-x2 memory-emergency-guard-check[2465578]: MEMORY EMERGENCY IO-PAUSE (trip #7641, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 580ms CPU time over 904ms wall clock time, 11.2M memory peak, 22.3M read from disk, 50.7M written to disk.
Nov 06 15:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:39:52 evo-x2 memory-emergency-guard-check[2526271]: MEMORY EMERGENCY IO-PAUSE (trip #7642, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 752ms wall clock time, 10.3M memory peak, 1M read from disk, 21.9M written to disk.
Nov 06 15:40:21 evo-x2 memory-emergency-guard-check[2559713]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.14% sustained (max disk busy 31.2%, MemAvailable=62.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 15:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:47:55 evo-x2 memory-emergency-guard-check[2728251]: MEMORY EMERGENCY IO-PAUSE (trip #7643, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:47:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 583ms CPU time over 1.512s wall clock time, 12M memory peak, 2.9M read from disk, 23M written to disk.
Nov 06 15:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:50:25 evo-x2 memory-emergency-guard-check[2796498]: MEMORY EMERGENCY IO-PAUSE (trip #7644, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 659ms wall clock time, 12.9M memory peak, 1.8M read from disk, 19.8M written to disk.
Nov 06 15:50:54 evo-x2 memory-emergency-guard-check[2811663]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.29% sustained (max disk busy 29.2%, MemAvailable=60.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 15:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:56:28 evo-x2 memory-emergency-guard-check[2965066]: MEMORY EMERGENCY IO-PAUSE (trip #7645, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 1.448s wall clock time, 12.2M memory peak, 656K read from disk, 12.7M written to disk.
Nov 06 15:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:59:58 evo-x2 memory-emergency-guard-check[3049174]: MEMORY EMERGENCY IO-PAUSE (trip #7646, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 15:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 15:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 611ms CPU time over 831ms wall clock time, 11.4M memory peak, 10.5M read from disk, 38.5M written to disk.
Nov 06 16:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:00:57 evo-x2 memory-emergency-guard-check[3095424]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.58% sustained (max disk busy 97.0%, MemAvailable=60.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:01:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:02:29 evo-x2 memory-emergency-guard-check[3137955]: MEMORY EMERGENCY IO-PAUSE (trip #7647, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 1.190s wall clock time, 12.1M memory peak, 32.6M read from disk, 69.4M written to disk.
Nov 06 16:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:06:29 evo-x2 memory-emergency-guard-check[3222085]: MEMORY EMERGENCY IO-PAUSE (trip #7648, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 573ms CPU time over 687ms wall clock time, 11.4M memory peak, 5M read from disk, 30.3M written to disk.
Nov 06 16:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:11:00 evo-x2 memory-emergency-guard-check[3369650]: MEMORY EMERGENCY IO-PAUSE (trip #7649, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 1.342s wall clock time, 12.4M memory peak, 30.5M read from disk, 84.3M written to disk.
Nov 06 16:11:29 evo-x2 memory-emergency-guard-check[3380875]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.26% sustained (max disk busy 73.9%, MemAvailable=59.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:13:30 evo-x2 memory-emergency-guard-check[3408639]: MEMORY EMERGENCY IO-PAUSE (trip #7650, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 545ms CPU time over 719ms wall clock time, 10.9M memory peak, 8.7M read from disk, 23.8M written to disk.
Nov 06 16:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:15:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:17:02 evo-x2 memory-emergency-guard-check[3468644]: MEMORY EMERGENCY IO-PAUSE (trip #7651, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 516ms CPU time over 595ms wall clock time, 11.3M memory peak, 2.6M read from disk, 19.3M written to disk.
Nov 06 16:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:20:33 evo-x2 memory-emergency-guard-check[3544891]: MEMORY EMERGENCY IO-PAUSE (trip #7652, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:20:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 632ms CPU time over 841ms wall clock time, 11.7M memory peak, 10.8M read from disk, 35.9M written to disk.
Nov 06 16:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:22:02 evo-x2 memory-emergency-guard-check[3571744]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.31% sustained (max disk busy 95.6%, MemAvailable=60.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:23:03 evo-x2 memory-emergency-guard-check[3583947]: MEMORY EMERGENCY IO-PAUSE (trip #7653, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 535ms CPU time over 634ms wall clock time, 11.7M memory peak, 2.8M read from disk, 25.9M written to disk.
Nov 06 16:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:26:04 evo-x2 memory-emergency-guard-check[3621484]: MEMORY EMERGENCY IO-PAUSE (trip #7654, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 541ms CPU time over 643ms wall clock time, 11.5M memory peak, 1.2M read from disk, 21.1M written to disk.
Nov 06 16:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:27:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:28:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:30:06 evo-x2 memory-emergency-guard-check[3701870]: MEMORY EMERGENCY IO-PAUSE (trip #7655, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 661ms wall clock time, 12.8M memory peak, 1.6M read from disk, 26.4M written to disk.
Nov 06 16:30:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:32:05 evo-x2 memory-emergency-guard-check[3735409]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.50% sustained (max disk busy 95.6%, MemAvailable=60.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:32:36 evo-x2 memory-emergency-guard-check[3773111]: MEMORY EMERGENCY IO-PAUSE (trip #7656, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:32:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:32:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 626ms CPU time over 748ms wall clock time, 12.7M memory peak, 1.5M read from disk, 27M written to disk.
Nov 06 16:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:33:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:35:07 evo-x2 memory-emergency-guard-check[3874537]: MEMORY EMERGENCY IO-PAUSE (trip #7657, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 1.470s wall clock time, 12.2M memory peak, 11.4M read from disk, 57M written to disk.
Nov 06 16:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:37:37 evo-x2 memory-emergency-guard-check[3971192]: MEMORY EMERGENCY IO-PAUSE (trip #7658, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 818ms wall clock time, 11M memory peak, 4.5M read from disk, 45.1M written to disk.
Nov 06 16:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:40:10 evo-x2 memory-emergency-guard-check[4062784]: MEMORY EMERGENCY IO-PAUSE (trip #7659, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 749ms CPU time over 3.066s wall clock time, 9.4M memory peak, 4.5M read from disk, 40.5M written to disk.
Nov 06 16:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:42:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 185ms CPU time over 1.554s wall clock time, 9.7M memory peak, 1.1M read from disk, 4K written to disk.
Nov 06 16:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:44:44 evo-x2 memory-emergency-guard-check[138992]: MEMORY EMERGENCY IO-PAUSE (trip #7660, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.042s CPU time over 4.848s wall clock time, 11.9M memory peak, 35.4M read from disk, 76.4M written to disk.
Nov 06 16:45:10 evo-x2 memory-emergency-guard-check[155461]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.90% sustained (max disk busy 98.0%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:47:13 evo-x2 memory-emergency-guard-check[204787]: MEMORY EMERGENCY IO-PAUSE (trip #7661, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 598ms CPU time over 2.268s wall clock time, 11.8M memory peak, 8.5M read from disk, 40.9M written to disk.
Nov 06 16:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:49:42 evo-x2 memory-emergency-guard-check[272280]: MEMORY EMERGENCY IO-PAUSE (trip #7662, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 544ms CPU time over 712ms wall clock time, 10.8M memory peak, 1.6M read from disk, 25.8M written to disk.
Nov 06 16:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:51:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:52:13 evo-x2 memory-emergency-guard-check[377187]: MEMORY EMERGENCY IO-PAUSE (trip #7663, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 539ms CPU time over 753ms wall clock time, 11.7M memory peak, 1008K read from disk, 21.7M written to disk.
Nov 06 16:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:53:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:54:44 evo-x2 memory-emergency-guard-check[440120]: MEMORY EMERGENCY IO-PAUSE (trip #7664, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:54:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:54:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 530ms CPU time over 614ms wall clock time, 11.9M memory peak, 608K read from disk, 20.4M written to disk.
Nov 06 16:55:14 evo-x2 memory-emergency-guard-check[452220]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.65% sustained (max disk busy 78.3%, MemAvailable=59.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 16:55:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:55:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:56:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:56:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:57:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:58:15 evo-x2 memory-emergency-guard-check[513972]: MEMORY EMERGENCY IO-PAUSE (trip #7665, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 16:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 539ms CPU time over 591ms wall clock time, 11.6M memory peak, 480K read from disk, 20.5M written to disk.
Nov 06 16:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 16:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:02:46 evo-x2 memory-emergency-guard-check[576094]: MEMORY EMERGENCY IO-PAUSE (trip #7666, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 611ms CPU time over 891ms wall clock time, 12.9M memory peak, 19.9M read from disk, 36.1M written to disk.
Nov 06 17:03:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:03:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:05:17 evo-x2 memory-emergency-guard-check[614900]: MEMORY EMERGENCY IO-PAUSE (trip #7667, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:05:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:05:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 785ms wall clock time, 12.4M memory peak, 10.8M read from disk, 34.7M written to disk.
Nov 06 17:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:07:47 evo-x2 memory-emergency-guard-check[655506]: MEMORY EMERGENCY IO-PAUSE (trip #7668, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:07:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:07:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 537ms CPU time over 657ms wall clock time, 11.2M memory peak, 5M read from disk, 25M written to disk.
Nov 06 17:08:17 evo-x2 memory-emergency-guard-check[668149]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.52% sustained (max disk busy 94.0%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 17:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 100ms CPU time over 126ms wall clock time, 8.9M memory peak, 1M read from disk, 4K written to disk.
Nov 06 17:10:22 evo-x2 memory-emergency-guard-check[717440]: MEMORY EMERGENCY IO-PAUSE (trip #7669, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 731ms CPU time over 4.302s wall clock time, 11.4M memory peak, 12.4M read from disk, 42.8M written to disk.
Nov 06 17:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 159ms wall clock time, 12.9M memory peak, 3.9M read from disk, 4K written to disk.
Nov 06 17:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 195ms CPU time over 749ms wall clock time, 13.2M memory peak, 1.4M read from disk, 4K written to disk.
Nov 06 17:12:50 evo-x2 memory-emergency-guard-check[836304]: MEMORY EMERGENCY IO-PAUSE (trip #7670, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 1.663s wall clock time, 12M memory peak, 3.6M read from disk, 34.1M written to disk.
Nov 06 17:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:14:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:14:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:15:23 evo-x2 memory-emergency-guard-check[937602]: MEMORY EMERGENCY IO-PAUSE (trip #7671, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 2.308s wall clock time, 10.9M memory peak, 3.2M read from disk, 37.3M written to disk.
Nov 06 17:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:17:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:17:52 evo-x2 memory-emergency-guard-check[991828]: MEMORY EMERGENCY IO-PAUSE (trip #7672, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 576ms CPU time over 712ms wall clock time, 11.5M memory peak, 3.8M read from disk, 39.5M written to disk.
Nov 06 17:18:22 evo-x2 memory-emergency-guard-check[1002498]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.74% sustained (max disk busy 81.4%, MemAvailable=57.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 17:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:20:24 evo-x2 memory-emergency-guard-check[1089448]: MEMORY EMERGENCY IO-PAUSE (trip #7673, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 872ms CPU time over 1.566s wall clock time, 9.8M memory peak, 2.8M read from disk, 34.4M written to disk.
Nov 06 17:20:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:22:55 evo-x2 memory-emergency-guard-check[1205802]: MEMORY EMERGENCY IO-PAUSE (trip #7674, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 750ms CPU time over 1.045s wall clock time, 9M memory peak, 1.6M read from disk, 26.4M written to disk.
Nov 06 17:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:23:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:25:26 evo-x2 memory-emergency-guard-check[1299912]: MEMORY EMERGENCY IO-PAUSE (trip #7675, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 927ms CPU time over 1.367s wall clock time, 11.2M memory peak, 23.2M read from disk, 77.7M written to disk.
Nov 06 17:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:27:57 evo-x2 memory-emergency-guard-check[1380228]: MEMORY EMERGENCY IO-PAUSE (trip #7676, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 880ms CPU time over 1.563s wall clock time, 11.2M memory peak, 13.7M read from disk, 34.8M written to disk.
Nov 06 17:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:30:58 evo-x2 memory-emergency-guard-check[1466586]: MEMORY EMERGENCY IO-PAUSE (trip #7677, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 802ms wall clock time, 11.3M memory peak, 8.2M read from disk, 45.4M written to disk.
Nov 06 17:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 262ms wall clock time, 6.3M memory peak, 2M read from disk, 4K written to disk.
Nov 06 17:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:32:28 evo-x2 memory-emergency-guard-check[1520689]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.38% sustained (max disk busy 52.2%, MemAvailable=56.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 17:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:34:30 evo-x2 memory-emergency-guard-check[1576325]: MEMORY EMERGENCY IO-PAUSE (trip #7678, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 1.214s wall clock time, 10.2M memory peak, 7.3M read from disk, 43.8M written to disk.
Nov 06 17:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:38:00 evo-x2 memory-emergency-guard-check[1716673]: MEMORY EMERGENCY IO-PAUSE (trip #7679, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 754ms wall clock time, 12.1M memory peak, 5.1M read from disk, 46M written to disk.
Nov 06 17:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:41:01 evo-x2 memory-emergency-guard-check[1797400]: MEMORY EMERGENCY IO-PAUSE (trip #7680, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 562ms CPU time over 715ms wall clock time, 11.5M memory peak, 3.3M read from disk, 41.6M written to disk.
Nov 06 17:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:44:01 evo-x2 memory-emergency-guard-check[1839427]: MEMORY EMERGENCY IO-PAUSE (trip #7681, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 502ms CPU time over 577ms wall clock time, 11.1M memory peak, 1.4M read from disk, 19.7M written to disk.
Nov 06 17:44:31 evo-x2 memory-emergency-guard-check[1849211]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.10% sustained (max disk busy 82.1%, MemAvailable=59.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 17:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:53:03 evo-x2 memory-emergency-guard-check[1946505]: MEMORY EMERGENCY IO-PAUSE (trip #7682, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 524ms CPU time over 635ms wall clock time, 11.1M memory peak, 2.7M read from disk, 28.1M written to disk.
Nov 06 17:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:54:32 evo-x2 memory-emergency-guard-check[1969636]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.35% sustained (max disk busy 69.5%, MemAvailable=57.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 17:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:57:35 evo-x2 memory-emergency-guard-check[2005386]: MEMORY EMERGENCY IO-PAUSE (trip #7683, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 17:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 526ms CPU time over 604ms wall clock time, 12.3M memory peak, 2M read from disk, 25.2M written to disk.
Nov 06 17:58:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:58:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 17:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:00:06 evo-x2 memory-emergency-guard-check[2061019]: MEMORY EMERGENCY IO-PAUSE (trip #7684, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 1.296s wall clock time, 11.4M memory peak, 7.1M read from disk, 35.5M written to disk.
Nov 06 18:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 174ms CPU time over 250ms wall clock time, 14.5M memory peak, 5.1M read from disk, 4K written to disk.
Nov 06 18:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:03:38 evo-x2 memory-emergency-guard-check[2123127]: MEMORY EMERGENCY IO-PAUSE (trip #7685, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 503ms CPU time over 2.481s wall clock time, 11.6M memory peak, 1M read from disk, 15.9M written to disk.
Nov 06 18:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:04:36 evo-x2 memory-emergency-guard-check[2151489]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.19% sustained (max disk busy 68.1%, MemAvailable=56.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 18:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:06:08 evo-x2 memory-emergency-guard-check[2173539]: MEMORY EMERGENCY IO-PAUSE (trip #7686, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 543ms CPU time over 1.367s wall clock time, 11.5M memory peak, 3.4M read from disk, 31.4M written to disk.
Nov 06 18:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:08:38 evo-x2 memory-emergency-guard-check[2236378]: MEMORY EMERGENCY IO-PAUSE (trip #7687, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 1.247s wall clock time, 10.9M memory peak, 8.6M read from disk, 46.2M written to disk.
Nov 06 18:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:11:08 evo-x2 memory-emergency-guard-check[2283400]: MEMORY EMERGENCY IO-PAUSE (trip #7688, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 861ms wall clock time, 12.1M memory peak, 13.3M read from disk, 48.4M written to disk.
Nov 06 18:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 102ms CPU time over 131ms wall clock time, 8.7M memory peak, 1.1M read from disk, 4K written to disk.
Nov 06 18:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 99ms CPU time over 139ms wall clock time, 14.9M memory peak, 5.2M read from disk, 4K written to disk.
Nov 06 18:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:15:41 evo-x2 memory-emergency-guard-check[2360308]: MEMORY EMERGENCY IO-PAUSE (trip #7689, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 701ms wall clock time, 11.5M memory peak, 6.3M read from disk, 29M written to disk.
Nov 06 18:16:11 evo-x2 memory-emergency-guard-check[2372577]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.43% sustained (max disk busy 92.8%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 18:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:18:12 evo-x2 memory-emergency-guard-check[2396804]: MEMORY EMERGENCY IO-PAUSE (trip #7690, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 494ms CPU time over 530ms wall clock time, 12.3M memory peak, 560K read from disk, 12.7M written to disk.
Nov 06 18:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:20:43 evo-x2 memory-emergency-guard-check[2434078]: MEMORY EMERGENCY IO-PAUSE (trip #7691, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 525ms CPU time over 577ms wall clock time, 11.8M memory peak, 720K read from disk, 13.2M written to disk.
Nov 06 18:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:23:15 evo-x2 memory-emergency-guard-check[2468767]: MEMORY EMERGENCY IO-PAUSE (trip #7692, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 707ms CPU time over 1.425s wall clock time, 12.6M memory peak, 54.2M read from disk, 96.8M written to disk.
Nov 06 18:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:25:45 evo-x2 memory-emergency-guard-check[2501410]: MEMORY EMERGENCY IO-PAUSE (trip #7693, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 558ms CPU time over 1.148s wall clock time, 10.9M memory peak, 3.1M read from disk, 33.7M written to disk.
Nov 06 18:26:14 evo-x2 memory-emergency-guard-check[2512310]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.93% sustained (max disk busy 71.3%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 18:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:27:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:30:16 evo-x2 memory-emergency-guard-check[2556113]: MEMORY EMERGENCY IO-PAUSE (trip #7694, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 587ms CPU time over 745ms wall clock time, 11.1M memory peak, 2.8M read from disk, 39.5M written to disk.
Nov 06 18:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 143ms wall clock time, 10.1M memory peak, 3.2M read from disk, 4K written to disk.
Nov 06 18:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:33:18 evo-x2 memory-emergency-guard-check[2612378]: MEMORY EMERGENCY IO-PAUSE (trip #7695, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 680ms wall clock time, 15M memory peak, 2.7M read from disk, 32.1M written to disk.
Nov 06 18:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:40:21 evo-x2 memory-emergency-guard-check[2705717]: MEMORY EMERGENCY IO-PAUSE (trip #7696, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 525ms wall clock time, 11M memory peak, 80K read from disk, 13.8M written to disk.
Nov 06 18:40:51 evo-x2 memory-emergency-guard-check[2717558]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.70% sustained (max disk busy 75.8%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 18:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 96ms CPU time over 127ms wall clock time, 8.7M memory peak, 2.4M read from disk, 4K written to disk.
Nov 06 18:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 100ms CPU time over 131ms wall clock time, 9M memory peak, 2.4M read from disk, 4K written to disk.
Nov 06 18:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 98ms CPU time over 129ms wall clock time, 7.8M memory peak, 2.3M read from disk, 4K written to disk.
Nov 06 18:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 95ms CPU time over 158ms wall clock time, 13.9M memory peak, 2.3M read from disk, 4K written to disk.
Nov 06 18:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:47:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:47:52 evo-x2 memory-emergency-guard-check[2785231]: MEMORY EMERGENCY IO-PAUSE (trip #7697, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:47:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:47:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 500ms CPU time over 623ms wall clock time, 11M memory peak, 864K read from disk, 13.1M written to disk.
Nov 06 18:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 154ms wall clock time, 9M memory peak, 1.8M read from disk, 4K written to disk.
Nov 06 18:50:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:50:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 99ms CPU time over 167ms wall clock time, 8.5M memory peak, 1.7M read from disk, 4K written to disk.
Nov 06 18:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 99ms CPU time over 127ms wall clock time, 10M memory peak, 1.8M read from disk, 4K written to disk.
Nov 06 18:51:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 97ms CPU time over 129ms wall clock time, 8.6M memory peak, 1M read from disk, 4K written to disk.
Nov 06 18:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 91ms CPU time over 117ms wall clock time, 7.9M memory peak, 1M read from disk, 4K written to disk.
Nov 06 18:54:24 evo-x2 memory-emergency-guard-check[2861455]: MEMORY EMERGENCY IO-PAUSE (trip #7698, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 18:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 488ms CPU time over 528ms wall clock time, 11.7M memory peak, 980K read from disk, 10.5M written to disk.
Nov 06 18:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:55:54 evo-x2 memory-emergency-guard-check[2885936]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.06% sustained (max disk busy 26.0%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 18:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 18:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:00:30 evo-x2 memory-emergency-guard-check[2936238]: MEMORY EMERGENCY IO-PAUSE (trip #7699, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 5.169s wall clock time, 12.2M memory peak, 13.4M read from disk, 21.5M written to disk.
Nov 06 19:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:01:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:02:57 evo-x2 memory-emergency-guard-check[2969453]: MEMORY EMERGENCY IO-PAUSE (trip #7700, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 770ms wall clock time, 11.1M memory peak, 192K read from disk, 11.1M written to disk.
Nov 06 19:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:05:27 evo-x2 memory-emergency-guard-check[3005335]: MEMORY EMERGENCY IO-PAUSE (trip #7701, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 534ms CPU time over 858ms wall clock time, 11.3M memory peak, 1.2M read from disk, 22.3M written to disk.
Nov 06 19:05:57 evo-x2 memory-emergency-guard-check[3015981]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.43% sustained (max disk busy 93.7%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 19:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:07:58 evo-x2 memory-emergency-guard-check[3038932]: MEMORY EMERGENCY IO-PAUSE (trip #7702, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 520ms CPU time over 1.007s wall clock time, 10.9M memory peak, 4.7M read from disk, 27.5M written to disk.
Nov 06 19:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:10:30 evo-x2 memory-emergency-guard-check[3068880]: MEMORY EMERGENCY IO-PAUSE (trip #7703, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 666ms CPU time over 2.518s wall clock time, 11.4M memory peak, 28.7M read from disk, 68.7M written to disk.
Nov 06 19:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:11:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:12:59 evo-x2 memory-emergency-guard-check[3100956]: MEMORY EMERGENCY IO-PAUSE (trip #7704, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 522ms CPU time over 660ms wall clock time, 11.2M memory peak, 528K read from disk, 15.1M written to disk.
Nov 06 19:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:16:00 evo-x2 memory-emergency-guard-check[3135395]: MEMORY EMERGENCY IO-PAUSE (trip #7705, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 506ms CPU time over 688ms wall clock time, 11.4M memory peak, 704K read from disk, 14.9M written to disk.
Nov 06 19:16:29 evo-x2 memory-emergency-guard-check[3146126]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.04% sustained (max disk busy 21.1%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 19:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:18:30 evo-x2 memory-emergency-guard-check[3174658]: MEMORY EMERGENCY IO-PAUSE (trip #7706, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 960ms wall clock time, 10.8M memory peak, 26M read from disk, 39.6M written to disk.
Nov 06 19:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:22:01 evo-x2 memory-emergency-guard-check[3222474]: MEMORY EMERGENCY IO-PAUSE (trip #7707, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 681ms wall clock time, 11.6M memory peak, 2.6M read from disk, 27M written to disk.
Nov 06 19:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:24:33 evo-x2 memory-emergency-guard-check[3256353]: MEMORY EMERGENCY IO-PAUSE (trip #7708, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 833ms wall clock time, 11M memory peak, 976K read from disk, 16.2M written to disk.
Nov 06 19:25:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:26:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:26:32 evo-x2 memory-emergency-guard-check[3284380]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.01% sustained (max disk busy 65.6%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 19:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:27:03 evo-x2 memory-emergency-guard-check[3292642]: MEMORY EMERGENCY IO-PAUSE (trip #7709, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 608ms wall clock time, 12.7M memory peak, 608K read from disk, 14.3M written to disk.
Nov 06 19:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:29:33 evo-x2 memory-emergency-guard-check[3336365]: MEMORY EMERGENCY IO-PAUSE (trip #7710, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 548ms CPU time over 595ms wall clock time, 12.4M memory peak, 768K read from disk, 15M written to disk.
Nov 06 19:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:32:05 evo-x2 memory-emergency-guard-check[3381306]: MEMORY EMERGENCY IO-PAUSE (trip #7711, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:32:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 563ms CPU time over 789ms wall clock time, 12.3M memory peak, 11.8M read from disk, 40.2M written to disk.
Nov 06 19:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:33:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:34:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:35:07 evo-x2 memory-emergency-guard-check[3420778]: MEMORY EMERGENCY IO-PAUSE (trip #7712, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 509ms CPU time over 576ms wall clock time, 11.1M memory peak, 736K read from disk, 16.6M written to disk.
Nov 06 19:35:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:36:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:37:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:38:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:38:39 evo-x2 memory-emergency-guard-check[3462021]: MEMORY EMERGENCY IO-PAUSE (trip #7713, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 633ms wall clock time, 10.7M memory peak, 864K read from disk, 20.7M written to disk.
Nov 06 19:39:08 evo-x2 memory-emergency-guard-check[3474360]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.63% sustained (max disk busy 32.5%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 19:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:41:11 evo-x2 memory-emergency-guard-check[3494830]: MEMORY EMERGENCY IO-PAUSE (trip #7714, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 526ms CPU time over 710ms wall clock time, 10.9M memory peak, 1.3M read from disk, 20.2M written to disk.
Nov 06 19:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:43:42 evo-x2 memory-emergency-guard-check[3525401]: MEMORY EMERGENCY IO-PAUSE (trip #7715, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 522ms CPU time over 858ms wall clock time, 10.4M memory peak, 2.3M read from disk, 22.4M written to disk.
Nov 06 19:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:46:13 evo-x2 memory-emergency-guard-check[3554886]: MEMORY EMERGENCY IO-PAUSE (trip #7716, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 487ms CPU time over 786ms wall clock time, 12.3M memory peak, 1.3M read from disk, 18.8M written to disk.
Nov 06 19:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:47:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:48:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:48:44 evo-x2 memory-emergency-guard-check[3585094]: MEMORY EMERGENCY IO-PAUSE (trip #7717, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 526ms CPU time over 763ms wall clock time, 11.5M memory peak, 7.6M read from disk, 38M written to disk.
Nov 06 19:49:14 evo-x2 memory-emergency-guard-check[3594013]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.77% sustained (max disk busy 74.5%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 19:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:50:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:51:15 evo-x2 memory-emergency-guard-check[3613130]: MEMORY EMERGENCY IO-PAUSE (trip #7718, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 478ms CPU time over 507ms wall clock time, 11.4M memory peak, 160K read from disk, 12M written to disk.
Nov 06 19:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:55:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:58:17 evo-x2 memory-emergency-guard-check[3684507]: MEMORY EMERGENCY IO-PAUSE (trip #7719, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 19:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 523ms wall clock time, 10.8M memory peak, 256K read from disk, 12.6M written to disk.
Nov 06 19:58:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:59:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 19:59:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:00:17 evo-x2 memory-emergency-guard-check[3709061]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.26% sustained (max disk busy 40.6%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:00:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:00:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:01:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:01:48 evo-x2 memory-emergency-guard-check[3724257]: MEMORY EMERGENCY IO-PAUSE (trip #7720, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:01:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:01:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 562ms CPU time over 812ms wall clock time, 11.5M memory peak, 21.7M read from disk, 40.3M written to disk.
Nov 06 20:02:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:02:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:04:18 evo-x2 memory-emergency-guard-check[3757097]: MEMORY EMERGENCY IO-PAUSE (trip #7721, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:04:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:04:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 508ms CPU time over 570ms wall clock time, 11.2M memory peak, 2M read from disk, 16.7M written to disk.
Nov 06 20:04:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:05:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:05:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:06:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:06:49 evo-x2 memory-emergency-guard-check[3790945]: MEMORY EMERGENCY IO-PAUSE (trip #7722, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 509ms CPU time over 903ms wall clock time, 12.2M memory peak, 2.1M read from disk, 22.5M written to disk.
Nov 06 20:07:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:07:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:08:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:09:20 evo-x2 memory-emergency-guard-check[3825892]: MEMORY EMERGENCY IO-PAUSE (trip #7723, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 708ms CPU time over 1.310s wall clock time, 12.5M memory peak, 53.5M read from disk, 81.6M written to disk.
Nov 06 20:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:10:19 evo-x2 memory-emergency-guard-check[3842934]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.32% sustained (max disk busy 86.3%, MemAvailable=51.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:11:50 evo-x2 memory-emergency-guard-check[3859594]: MEMORY EMERGENCY IO-PAUSE (trip #7724, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 885ms wall clock time, 12M memory peak, 16.5M read from disk, 58.5M written to disk.
Nov 06 20:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:12:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:14:22 evo-x2 memory-emergency-guard-check[3892912]: MEMORY EMERGENCY IO-PAUSE (trip #7725, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:14:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:14:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 517ms CPU time over 637ms wall clock time, 11.2M memory peak, 1.2M read from disk, 15.3M written to disk.
Nov 06 20:14:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:16:52 evo-x2 memory-emergency-guard-check[3947544]: MEMORY EMERGENCY IO-PAUSE (trip #7726, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 598ms CPU time over 819ms wall clock time, 11.5M memory peak, 11.3M read from disk, 38.3M written to disk.
Nov 06 20:17:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:18:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:19:22 evo-x2 memory-emergency-guard-check[3991511]: MEMORY EMERGENCY IO-PAUSE (trip #7727, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 661ms wall clock time, 10.8M memory peak, 2.1M read from disk, 30.2M written to disk.
Nov 06 20:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:20:22 evo-x2 memory-emergency-guard-check[4015266]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.27% sustained (max disk busy 44.0%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:21:53 evo-x2 memory-emergency-guard-check[4066103]: MEMORY EMERGENCY IO-PAUSE (trip #7728, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 579ms CPU time over 782ms wall clock time, 11.3M memory peak, 4.4M read from disk, 28.2M written to disk.
Nov 06 20:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:24:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:26:55 evo-x2 memory-emergency-guard-check[4163200]: MEMORY EMERGENCY IO-PAUSE (trip #7729, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 819ms wall clock time, 11.5M memory peak, 14.7M read from disk, 32.7M written to disk.
Nov 06 20:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:29:27 evo-x2 memory-emergency-guard-check[2016]: MEMORY EMERGENCY IO-PAUSE (trip #7730, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 503ms CPU time over 568ms wall clock time, 11.2M memory peak, 1008K read from disk, 14.8M written to disk.
Nov 06 20:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:30:27 evo-x2 memory-emergency-guard-check[18232]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.00% sustained (max disk busy 43.3%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:33:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:33:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:34:29 evo-x2 memory-emergency-guard-check[65529]: MEMORY EMERGENCY IO-PAUSE (trip #7731, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:34:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:34:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 509ms CPU time over 583ms wall clock time, 11.6M memory peak, 1.6M read from disk, 20.8M written to disk.
Nov 06 20:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:36:59 evo-x2 memory-emergency-guard-check[102320]: sort: fflush failed: 'standard output': Broken pipe
Nov 06 20:36:59 evo-x2 memory-emergency-guard-check[102320]: sort: write error
Nov 06 20:36:59 evo-x2 memory-emergency-guard-check[101408]: MEMORY EMERGENCY IO-PAUSE (trip #7732, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 524ms CPU time over 602ms wall clock time, 11.1M memory peak, 672K read from disk, 15.9M written to disk.
Nov 06 20:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:39:30 evo-x2 memory-emergency-guard-check[133130]: MEMORY EMERGENCY IO-PAUSE (trip #7733, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 496ms CPU time over 533ms wall clock time, 12.2M memory peak, 352K read from disk, 13.8M written to disk.
Nov 06 20:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:40:30 evo-x2 memory-emergency-guard-check[148223]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.95% sustained (max disk busy 66.2%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:42:01 evo-x2 memory-emergency-guard-check[165124]: MEMORY EMERGENCY IO-PAUSE (trip #7734, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 505ms CPU time over 557ms wall clock time, 12.1M memory peak, 432K read from disk, 14.3M written to disk.
Nov 06 20:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:49:33 evo-x2 memory-emergency-guard-check[245953]: MEMORY EMERGENCY IO-PAUSE (trip #7735, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 502ms CPU time over 548ms wall clock time, 11.2M memory peak, 176K read from disk, 11.7M written to disk.
Nov 06 20:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:50:32 evo-x2 memory-emergency-guard-check[259806]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.51% sustained (max disk busy 80.1%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 20:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:52:03 evo-x2 memory-emergency-guard-check[275575]: MEMORY EMERGENCY IO-PAUSE (trip #7736, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 501ms CPU time over 548ms wall clock time, 11.1M memory peak, 480K read from disk, 13.6M written to disk.
Nov 06 20:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:54:33 evo-x2 memory-emergency-guard-check[303047]: MEMORY EMERGENCY IO-PAUSE (trip #7737, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 20:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 480ms CPU time over 534ms wall clock time, 11.3M memory peak, 688K read from disk, 12.2M written to disk.
Nov 06 20:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 20:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:01:04 evo-x2 memory-emergency-guard-check[373812]: MEMORY EMERGENCY IO-PAUSE (trip #7738, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 553ms CPU time over 748ms wall clock time, 11.8M memory peak, 14.1M read from disk, 34.6M written to disk.
Nov 06 21:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:02:34 evo-x2 memory-emergency-guard-check[392657]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.61% sustained (max disk busy 24.9%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:05:07 evo-x2 memory-emergency-guard-check[419961]: MEMORY EMERGENCY IO-PAUSE (trip #7739, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 500ms CPU time over 559ms wall clock time, 10.9M memory peak, 1.7M read from disk, 16.7M written to disk.
Nov 06 21:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:09:08 evo-x2 memory-emergency-guard-check[469099]: MEMORY EMERGENCY IO-PAUSE (trip #7740, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 1.380s wall clock time, 11.7M memory peak, 42.2M read from disk, 66.2M written to disk.
Nov 06 21:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:11:38 evo-x2 memory-emergency-guard-check[501669]: MEMORY EMERGENCY IO-PAUSE (trip #7741, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 716ms wall clock time, 12.3M memory peak, 7.5M read from disk, 44.5M written to disk.
Nov 06 21:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:12:38 evo-x2 memory-emergency-guard-check[520530]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.97% sustained (max disk busy 66.3%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:14:09 evo-x2 memory-emergency-guard-check[538538]: MEMORY EMERGENCY IO-PAUSE (trip #7742, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 497ms CPU time over 592ms wall clock time, 12.1M memory peak, 336K read from disk, 14M written to disk.
Nov 06 21:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:15:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:18:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:20:13 evo-x2 memory-emergency-guard-check[608148]: MEMORY EMERGENCY IO-PAUSE (trip #7743, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 500ms CPU time over 1.747s wall clock time, 11M memory peak, 4.6M read from disk, 13M written to disk.
Nov 06 21:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:22:45 evo-x2 memory-emergency-guard-check[636852]: MEMORY EMERGENCY IO-PAUSE (trip #7744, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 3.247s wall clock time, 10.8M memory peak, 23.8M read from disk, 45.4M written to disk.
Nov 06 21:23:12 evo-x2 memory-emergency-guard-check[648906]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.49% sustained (max disk busy 91.4%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:25:14 evo-x2 memory-emergency-guard-check[669313]: MEMORY EMERGENCY IO-PAUSE (trip #7745, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 500ms CPU time over 774ms wall clock time, 11.2M memory peak, 1M read from disk, 15.2M written to disk.
Nov 06 21:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:27:46 evo-x2 memory-emergency-guard-check[707663]: MEMORY EMERGENCY IO-PAUSE (trip #7746, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 685ms wall clock time, 11.7M memory peak, 5.1M read from disk, 25.8M written to disk.
Nov 06 21:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:28:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:30:17 evo-x2 memory-emergency-guard-check[789030]: MEMORY EMERGENCY IO-PAUSE (trip #7747, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 914ms CPU time over 1.542s wall clock time, 9.9M memory peak, 2.2M read from disk, 22.4M written to disk.
Nov 06 21:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:32:48 evo-x2 memory-emergency-guard-check[866270]: MEMORY EMERGENCY IO-PAUSE (trip #7748, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 1.579s wall clock time, 11.2M memory peak, 19.7M read from disk, 40.1M written to disk.
Nov 06 21:33:17 evo-x2 memory-emergency-guard-check[881052]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.44% sustained (max disk busy 97.8%, MemAvailable=51.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:35:18 evo-x2 memory-emergency-guard-check[921109]: MEMORY EMERGENCY IO-PAUSE (trip #7749, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 902ms wall clock time, 10.5M memory peak, 11M read from disk, 39.3M written to disk.
Nov 06 21:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:37:49 evo-x2 memory-emergency-guard-check[967929]: MEMORY EMERGENCY IO-PAUSE (trip #7750, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 797ms wall clock time, 11.5M memory peak, 8.8M read from disk, 23.1M written to disk.
Nov 06 21:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:40:20 evo-x2 memory-emergency-guard-check[1010104]: MEMORY EMERGENCY IO-PAUSE (trip #7751, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 818ms wall clock time, 10.8M memory peak, 10.7M read from disk, 41.5M written to disk.
Nov 06 21:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:43:20 evo-x2 memory-emergency-guard-check[1083717]: MEMORY EMERGENCY IO-PAUSE (trip #7752, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 797ms wall clock time, 11.1M memory peak, 5.7M read from disk, 54.1M written to disk.
Nov 06 21:43:50 evo-x2 memory-emergency-guard-check[1095940]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.84% sustained (max disk busy 77.1%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:45:52 evo-x2 memory-emergency-guard-check[1130555]: MEMORY EMERGENCY IO-PAUSE (trip #7753, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 820ms wall clock time, 11.9M memory peak, 3.4M read from disk, 56.5M written to disk.
Nov 06 21:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:48:22 evo-x2 memory-emergency-guard-check[1174931]: MEMORY EMERGENCY IO-PAUSE (trip #7754, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 702ms wall clock time, 11.7M memory peak, 1.7M read from disk, 31.7M written to disk.
Nov 06 21:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:50:52 evo-x2 memory-emergency-guard-check[1212529]: MEMORY EMERGENCY IO-PAUSE (trip #7755, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 794ms wall clock time, 11M memory peak, 13.4M read from disk, 44.1M written to disk.
Nov 06 21:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:53:24 evo-x2 memory-emergency-guard-check[1256980]: MEMORY EMERGENCY IO-PAUSE (trip #7756, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 862ms wall clock time, 11.2M memory peak, 3.2M read from disk, 35.5M written to disk.
Nov 06 21:53:53 evo-x2 memory-emergency-guard-check[1267553]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.11% sustained (max disk busy 96.3%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 21:53:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:55:54 evo-x2 memory-emergency-guard-check[1321737]: MEMORY EMERGENCY IO-PAUSE (trip #7757, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 21:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 1.615s wall clock time, 9.9M memory peak, 5.4M read from disk, 59.5M written to disk.
Nov 06 21:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 21:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:02:25 evo-x2 memory-emergency-guard-check[1550061]: MEMORY EMERGENCY IO-PAUSE (trip #7758, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 848ms wall clock time, 11.6M memory peak, 11.1M read from disk, 60.2M written to disk.
Nov 06 22:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:05:59 evo-x2 memory-emergency-guard-check[1625961]: MEMORY EMERGENCY IO-PAUSE (trip #7759, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 893ms CPU time over 1.779s wall clock time, 8.1M memory peak, 4.7M read from disk, 41.7M written to disk.
Nov 06 22:06:27 evo-x2 memory-emergency-guard-check[1667600]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.34% sustained (max disk busy 84.8%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 22:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:08:29 evo-x2 memory-emergency-guard-check[1723142]: MEMORY EMERGENCY IO-PAUSE (trip #7760, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 749ms CPU time over 1.222s wall clock time, 10.4M memory peak, 40M read from disk, 70M written to disk.
Nov 06 22:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:11:00 evo-x2 memory-emergency-guard-check[1779619]: MEMORY EMERGENCY IO-PAUSE (trip #7761, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 790ms CPU time over 1.422s wall clock time, 11.2M memory peak, 44.7M read from disk, 86.4M written to disk.
Nov 06 22:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:13:30 evo-x2 memory-emergency-guard-check[1890870]: MEMORY EMERGENCY IO-PAUSE (trip #7762, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 669ms CPU time over 921ms wall clock time, 10.2M memory peak, 11.5M read from disk, 25.5M written to disk.
Nov 06 22:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:16:00 evo-x2 memory-emergency-guard-check[2104955]: MEMORY EMERGENCY IO-PAUSE (trip #7763, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 762ms wall clock time, 11.1M memory peak, 2.9M read from disk, 19.6M written to disk.
Nov 06 22:16:29 evo-x2 memory-emergency-guard-check[2147113]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.01% sustained (max disk busy 100.0%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 22:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:18:30 evo-x2 memory-emergency-guard-check[2310209]: MEMORY EMERGENCY IO-PAUSE (trip #7764, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 648ms CPU time over 816ms wall clock time, 12.3M memory peak, 6.1M read from disk, 31.2M written to disk.
Nov 06 22:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:21:01 evo-x2 memory-emergency-guard-check[2412147]: MEMORY EMERGENCY IO-PAUSE (trip #7765, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:21:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:21:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 730ms CPU time over 1.056s wall clock time, 9.4M memory peak, 10.7M read from disk, 28.7M written to disk.
Nov 06 22:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:23:31 evo-x2 memory-emergency-guard-check[2536199]: MEMORY EMERGENCY IO-PAUSE (trip #7766, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 727ms wall clock time, 10.8M memory peak, 3.2M read from disk, 26.5M written to disk.
Nov 06 22:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:26:04 evo-x2 memory-emergency-guard-check[2718567]: MEMORY EMERGENCY IO-PAUSE (trip #7767, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 970ms CPU time over 2.440s wall clock time, 7.7M memory peak, 11.7M read from disk, 47.2M written to disk.
Nov 06 22:26:32 evo-x2 memory-emergency-guard-check[2758665]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.82% sustained (max disk busy 89.6%, MemAvailable=51.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 22:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:28:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:28:34 evo-x2 memory-emergency-guard-check[2913917]: MEMORY EMERGENCY IO-PAUSE (trip #7768, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:28:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 806ms CPU time over 1.255s wall clock time, 9.5M memory peak, 7.7M read from disk, 2.4M written to disk.
Nov 06 22:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:31:04 evo-x2 memory-emergency-guard-check[3085119]: MEMORY EMERGENCY IO-PAUSE (trip #7769, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:31:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 849ms wall clock time, 10.2M memory peak, 5.4M read from disk, 45.8M written to disk.
Nov 06 22:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:33:34 evo-x2 memory-emergency-guard-check[3218723]: MEMORY EMERGENCY IO-PAUSE (trip #7770, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 936ms wall clock time, 9.7M memory peak, 5.2M read from disk, 93.6M written to disk.
Nov 06 22:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:36:06 evo-x2 memory-emergency-guard-check[3305830]: MEMORY EMERGENCY IO-PAUSE (trip #7771, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 660ms CPU time over 909ms wall clock time, 10.8M memory peak, 6.6M read from disk, 69.9M written to disk.
Nov 06 22:36:35 evo-x2 memory-emergency-guard-check[3335937]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.33% sustained (max disk busy 65.7%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 22:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:38:37 evo-x2 memory-emergency-guard-check[3395169]: MEMORY EMERGENCY IO-PAUSE (trip #7772, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 997ms CPU time over 1.237s wall clock time, 9.8M memory peak, 1.3M read from disk, 42.4M written to disk.
Nov 06 22:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:49:41 evo-x2 memory-emergency-guard-check[4003826]: MEMORY EMERGENCY IO-PAUSE (trip #7773, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.056s CPU time over 2.859s wall clock time, 7.8M memory peak, 1.4M read from disk, 32.3M written to disk.
Nov 06 22:50:08 evo-x2 memory-emergency-guard-check[4031232]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.96% sustained (max disk busy 99.6%, MemAvailable=49.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 22:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:52:10 evo-x2 memory-emergency-guard-check[4109737]: MEMORY EMERGENCY IO-PAUSE (trip #7774, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 897ms CPU time over 1.485s wall clock time, 9.2M memory peak, 14.3M read from disk, 40.8M written to disk.
Nov 06 22:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:54:40 evo-x2 memory-emergency-guard-check[85973]: MEMORY EMERGENCY IO-PAUSE (trip #7775, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 830ms CPU time over 1.240s wall clock time, 9.3M memory peak, 10.8M read from disk, 36M written to disk.
Nov 06 22:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:56:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:57:10 evo-x2 memory-emergency-guard-check[219901]: MEMORY EMERGENCY IO-PAUSE (trip #7776, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 764ms wall clock time, 9.7M memory peak, 3.4M read from disk, 22.7M written to disk.
Nov 06 22:57:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:59:41 evo-x2 memory-emergency-guard-check[405168]: MEMORY EMERGENCY IO-PAUSE (trip #7777, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 22:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 22:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 1.934s wall clock time, 9.9M memory peak, 12.6M read from disk, 29.5M written to disk.
Nov 06 23:00:10 evo-x2 memory-emergency-guard-check[445885]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.91% sustained (max disk busy 100.0%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:02:11 evo-x2 memory-emergency-guard-check[555249]: MEMORY EMERGENCY IO-PAUSE (trip #7778, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 696ms CPU time over 1.038s wall clock time, 9.6M memory peak, 8.9M read from disk, 39.1M written to disk.
Nov 06 23:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:04:42 evo-x2 memory-emergency-guard-check[668260]: MEMORY EMERGENCY IO-PAUSE (trip #7779, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 692ms CPU time over 1.071s wall clock time, 10.2M memory peak, 8.8M read from disk, 52.7M written to disk.
Nov 06 23:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:07:13 evo-x2 memory-emergency-guard-check[807268]: MEMORY EMERGENCY IO-PAUSE (trip #7780, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 835ms CPU time over 1.306s wall clock time, 8.6M memory peak, 11.6M read from disk, 30.8M written to disk.
Nov 06 23:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:09:43 evo-x2 memory-emergency-guard-check[928101]: MEMORY EMERGENCY IO-PAUSE (trip #7781, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 816ms CPU time over 1.332s wall clock time, 9.5M memory peak, 12.4M read from disk, 65.1M written to disk.
Nov 06 23:10:12 evo-x2 memory-emergency-guard-check[960446]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.03% sustained (max disk busy 99.6%, MemAvailable=47.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:12:13 evo-x2 memory-emergency-guard-check[1051841]: MEMORY EMERGENCY IO-PAUSE (trip #7782, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 843ms wall clock time, 11.5M memory peak, 6.7M read from disk, 34.5M written to disk.
Nov 06 23:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:13:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:13:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:14:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:14:44 evo-x2 memory-emergency-guard-check[1212617]: MEMORY EMERGENCY IO-PAUSE (trip #7783, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.419s wall clock time, 10.9M memory peak, 2.8M read from disk, 58M written to disk.
Nov 06 23:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:16:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:16:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:17:14 evo-x2 memory-emergency-guard-check[1324002]: MEMORY EMERGENCY IO-PAUSE (trip #7784, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:17:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:17:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 597ms CPU time over 1.265s wall clock time, 10.9M memory peak, 9.5M read from disk, 4.8M written to disk.
Nov 06 23:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:18:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:19:44 evo-x2 memory-emergency-guard-check[1522273]: MEMORY EMERGENCY IO-PAUSE (trip #7785, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 779ms wall clock time, 10.6M memory peak, 5.3M read from disk, 21.7M written to disk.
Nov 06 23:20:13 evo-x2 memory-emergency-guard-check[1542204]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.03% sustained (max disk busy 100.0%, MemAvailable=61.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:22:15 evo-x2 memory-emergency-guard-check[1582475]: MEMORY EMERGENCY IO-PAUSE (trip #7786, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:22:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:22:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 809ms wall clock time, 11.7M memory peak, 15.3M read from disk, 31M written to disk.
Nov 06 23:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:24:46 evo-x2 memory-emergency-guard-check[1705213]: MEMORY EMERGENCY IO-PAUSE (trip #7787, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 619ms CPU time over 941ms wall clock time, 10M memory peak, 4M read from disk, 33.7M written to disk.
Nov 06 23:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:27:17 evo-x2 memory-emergency-guard-check[1876078]: MEMORY EMERGENCY IO-PAUSE (trip #7788, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 1.018s wall clock time, 9.5M memory peak, 16.4M read from disk, 66M written to disk.
Nov 06 23:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:29:47 evo-x2 memory-emergency-guard-check[2048607]: MEMORY EMERGENCY IO-PAUSE (trip #7789, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 871ms wall clock time, 10.1M memory peak, 7.3M read from disk, 56M written to disk.
Nov 06 23:30:17 evo-x2 memory-emergency-guard-check[2073976]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.17% sustained (max disk busy 70.1%, MemAvailable=56.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:32:18 evo-x2 memory-emergency-guard-check[2171104]: MEMORY EMERGENCY IO-PAUSE (trip #7790, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 562ms CPU time over 664ms wall clock time, 10.5M memory peak, 2.3M read from disk, 20.8M written to disk.
Nov 06 23:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:34:49 evo-x2 memory-emergency-guard-check[2249463]: MEMORY EMERGENCY IO-PAUSE (trip #7791, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 726ms wall clock time, 12M memory peak, 2.8M read from disk, 30.5M written to disk.
Nov 06 23:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:37:21 evo-x2 memory-emergency-guard-check[2379765]: MEMORY EMERGENCY IO-PAUSE (trip #7792, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.202s CPU time over 1.646s wall clock time, 8.3M memory peak, 12.6M read from disk, 54.3M written to disk.
Nov 06 23:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:40:54 evo-x2 memory-emergency-guard-check[2591996]: MEMORY EMERGENCY IO-PAUSE (trip #7793, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 735ms CPU time over 2.960s wall clock time, 10.3M memory peak, 11.6M read from disk, 69.3M written to disk.
Nov 06 23:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:41:53 evo-x2 memory-emergency-guard-check[2676142]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.70% sustained (max disk busy 20.3%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (62s < 150s, 88s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:43:56 evo-x2 memory-emergency-guard-check[2728811]: MEMORY EMERGENCY IO-PAUSE (trip #7794, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 2.908s wall clock time, 12.6M memory peak, 17.8M read from disk, 48.3M written to disk.
Nov 06 23:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:46:26 evo-x2 memory-emergency-guard-check[2824314]: MEMORY EMERGENCY IO-PAUSE (trip #7795, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 879ms CPU time over 2.151s wall clock time, 9.7M memory peak, 2.3M read from disk, 60.5M written to disk.
Nov 06 23:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:48:56 evo-x2 memory-emergency-guard-check[2917547]: MEMORY EMERGENCY IO-PAUSE (trip #7796, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 886ms wall clock time, 10.1M memory peak, 4.8M read from disk, 29.1M written to disk.
Nov 06 23:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:50:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:51:27 evo-x2 memory-emergency-guard-check[3018744]: MEMORY EMERGENCY IO-PAUSE (trip #7797, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 944ms wall clock time, 10.2M memory peak, 21.4M read from disk, 50.6M written to disk.
Nov 06 23:51:57 evo-x2 memory-emergency-guard-check[3056993]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.78% sustained (max disk busy 85.9%, MemAvailable=40.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 23:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:53:58 evo-x2 memory-emergency-guard-check[3106069]: MEMORY EMERGENCY IO-PAUSE (trip #7798, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 619ms CPU time over 769ms wall clock time, 9.4M memory peak, 3M read from disk, 19M written to disk.
Nov 06 23:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:56:29 evo-x2 memory-emergency-guard-check[3311755]: MEMORY EMERGENCY IO-PAUSE (trip #7799, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.208s CPU time over 1.696s wall clock time, 8.3M memory peak, 4.7M read from disk, 27.3M written to disk.
Nov 06 23:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:58:59 evo-x2 memory-emergency-guard-check[3467276]: MEMORY EMERGENCY IO-PAUSE (trip #7800, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 23:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.090s CPU time over 1.998s wall clock time, 9.4M memory peak, 11.8M read from disk, 66.8M written to disk.
Nov 06 23:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 23:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:01:28 evo-x2 memory-emergency-guard-check[3694846]: MEMORY EMERGENCY IO-PAUSE (trip #7801, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 880ms wall clock time, 10.6M memory peak, 4M read from disk, 21.9M written to disk.
Nov 07 00:01:58 evo-x2 memory-emergency-guard-check[3742130]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.49% sustained (max disk busy 100.0%, MemAvailable=54.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:03:59 evo-x2 memory-emergency-guard-check[3880279]: MEMORY EMERGENCY IO-PAUSE (trip #7802, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 914ms CPU time over 1.165s wall clock time, 7.7M memory peak, 1.1M read from disk, 18.7M written to disk.
Nov 07 00:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:06:29 evo-x2 memory-emergency-guard-check[4074795]: MEMORY EMERGENCY IO-PAUSE (trip #7803, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 874ms CPU time over 1.386s wall clock time, 9.3M memory peak, 7.2M read from disk, 54M written to disk.
Nov 07 00:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:08:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:10:30 evo-x2 memory-emergency-guard-check[200663]: MEMORY EMERGENCY IO-PAUSE (trip #7804, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 721ms CPU time over 1.267s wall clock time, 9.7M memory peak, 24.1M read from disk, 55M written to disk.
Nov 07 00:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:11:59 evo-x2 memory-emergency-guard-check[267429]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.03% sustained (max disk busy 97.3%, MemAvailable=57.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:13:00 evo-x2 memory-emergency-guard-check[336940]: MEMORY EMERGENCY IO-PAUSE (trip #7805, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 902ms wall clock time, 11.2M memory peak, 752K read from disk, 45.1M written to disk.
Nov 07 00:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:15:30 evo-x2 memory-emergency-guard-check[511729]: MEMORY EMERGENCY IO-PAUSE (trip #7806, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 805ms CPU time over 1.274s wall clock time, 9.6M memory peak, 24.2M read from disk, 75.2M written to disk.
Nov 07 00:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:18:01 evo-x2 memory-emergency-guard-check[761629]: sort: write failed: 'standard output': Broken pipe
Nov 07 00:18:01 evo-x2 memory-emergency-guard-check[761629]: sort: write error
Nov 07 00:18:01 evo-x2 memory-emergency-guard-check[758982]: MEMORY EMERGENCY IO-PAUSE (trip #7807, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 1.878s wall clock time, 9.8M memory peak, 4.2M read from disk, 59.7M written to disk.
Nov 07 00:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:20:35 evo-x2 memory-emergency-guard-check[897055]: MEMORY EMERGENCY IO-PAUSE (trip #7808, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 741ms CPU time over 5.527s wall clock time, 11.5M memory peak, 3.2M read from disk, 78.7M written to disk.
Nov 07 00:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:22:30 evo-x2 memory-emergency-guard-check[1062345]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.95% sustained (max disk busy 95.6%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:23:01 evo-x2 memory-emergency-guard-check[1079625]: MEMORY EMERGENCY IO-PAUSE (trip #7809, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 1.373s wall clock time, 11.1M memory peak, 1.2M read from disk, 45.8M written to disk.
Nov 07 00:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:27:03 evo-x2 memory-emergency-guard-check[1207004]: MEMORY EMERGENCY IO-PAUSE (trip #7810, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 815ms CPU time over 2.492s wall clock time, 10.2M memory peak, 37.8M read from disk, 58.3M written to disk.
Nov 07 00:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:29:33 evo-x2 memory-emergency-guard-check[1284304]: MEMORY EMERGENCY IO-PAUSE (trip #7811, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 796ms wall clock time, 11.3M memory peak, 6.3M read from disk, 28.7M written to disk.
Nov 07 00:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:32:04 evo-x2 memory-emergency-guard-check[1472800]: MEMORY EMERGENCY IO-PAUSE (trip #7812, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:32:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 1.131s wall clock time, 10.5M memory peak, 1.8M read from disk, 16.7M written to disk.
Nov 07 00:32:33 evo-x2 memory-emergency-guard-check[1515888]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.69% sustained (max disk busy 87.6%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:34:36 evo-x2 memory-emergency-guard-check[1617161]: MEMORY EMERGENCY IO-PAUSE (trip #7813, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 1.321s wall clock time, 10.7M memory peak, 1.4M read from disk, 16.6M written to disk.
Nov 07 00:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:35:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:37:07 evo-x2 memory-emergency-guard-check[1780245]: MEMORY EMERGENCY IO-PAUSE (trip #7814, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 664ms CPU time over 918ms wall clock time, 10.2M memory peak, 12.2M read from disk, 63M written to disk.
Nov 07 00:37:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:39:38 evo-x2 memory-emergency-guard-check[1870385]: MEMORY EMERGENCY IO-PAUSE (trip #7815, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 901ms wall clock time, 10.2M memory peak, 11.6M read from disk, 59.6M written to disk.
Nov 07 00:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:42:09 evo-x2 memory-emergency-guard-check[1986772]: MEMORY EMERGENCY IO-PAUSE (trip #7816, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 549ms CPU time over 656ms wall clock time, 11.4M memory peak, 4.1M read from disk, 37.1M written to disk.
Nov 07 00:42:39 evo-x2 memory-emergency-guard-check[2024290]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.86% sustained (max disk busy 86.6%, MemAvailable=53.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:44:40 evo-x2 memory-emergency-guard-check[2104039]: MEMORY EMERGENCY IO-PAUSE (trip #7817, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 714ms wall clock time, 10.6M memory peak, 6M read from disk, 36M written to disk.
Nov 07 00:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:47:10 evo-x2 memory-emergency-guard-check[2175473]: MEMORY EMERGENCY IO-PAUSE (trip #7818, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 864ms wall clock time, 9.8M memory peak, 17.9M read from disk, 34.8M written to disk.
Nov 07 00:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:49:40 evo-x2 memory-emergency-guard-check[2236692]: MEMORY EMERGENCY IO-PAUSE (trip #7819, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 556ms CPU time over 723ms wall clock time, 10.6M memory peak, 4.4M read from disk, 19M written to disk.
Nov 07 00:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:50:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:52:12 evo-x2 memory-emergency-guard-check[2285963]: MEMORY EMERGENCY IO-PAUSE (trip #7820, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 07 00:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 1.067s wall clock time, 10.9M memory peak, 5.3M read from disk, 70.2M written to disk.
Nov 07 00:52:41 evo-x2 memory-emergency-guard-check[2300437]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.36% sustained (max disk busy 81.0%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 07 00:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 07 00:53:22 evo-x2 systemd[1]: memory-emergency-guard.timer: Deactivated successfully.
Nov 07 00:53:22 evo-x2 gatus[656139]: 2026/11/07 00:53:22 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
```

## THERMAL THROTTLE lines
```
Nov 06 06:01:56 evo-x2 thermal-pstate-guard-check[56876]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 06 11:43:23 evo-x2 thermal-pstate-guard-check[4140669]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=76C(hi:95/lo:80)
Nov 06 11:56:01 evo-x2 thermal-pstate-guard-check[179338]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Nov 06 12:13:49 evo-x2 thermal-pstate-guard-check[889516]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=66C(hi:95/lo:80)
Nov 06 12:50:50 evo-x2 thermal-pstate-guard-check[1417075]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 06 19:44:45 evo-x2 thermal-pstate-guard-check[3544478]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=68C(hi:95/lo:80)
Nov 06 20:22:11 evo-x2 thermal-pstate-guard-check[4090421]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 06 20:28:11 evo-x2 thermal-pstate-guard-check[4183316]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=63C(hi:95/lo:80)
Nov 06 21:29:41 evo-x2 thermal-pstate-guard-check[751899]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=99C(hi:95/lo:80)
Nov 06 21:54:53 evo-x2 thermal-pstate-guard-check[1295690]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=79C(hi:95/lo:80)
Nov 06 21:56:03 evo-x2 thermal-pstate-guard-check[1336742]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 06 05:58:52 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 06 05:58:52 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 06 05:58:52 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 06 05:58:54 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1794009981000000000 -> 1794010000000000000 epoch-ns UTC (2026-11-07 00:06:21 -> 2026-11-07 00:06:40 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
