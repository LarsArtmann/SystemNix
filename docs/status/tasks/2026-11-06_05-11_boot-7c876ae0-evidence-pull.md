# Boot evidence pull: id8 7c876ae0 (full: 7c876ae078ab4c67aa1ff34154a30ca2)

Pulled 2026-11-06 05:11 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-05 20:39:20 -> 2026-11-06 05:56:21 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 7c876ae0 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 05 20:39:20 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 05 20:39:20 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 20:39:20 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 06 05:56:20 evo-x2 pma[2303]:   │ Daemon: true
Nov 06 05:56:20 evo-x2 pma[2303]:  duration=30.355433347s
Nov 06 05:56:20 evo-x2 pma[2303]:   error=
Nov 06 05:56:20 evo-x2 pma[2303]:   │ [transient] commit.generate: generate commit message for /home/lars/projects/go-appkit with style detailed
Nov 06 05:56:20 evo-x2 pma[2303]:   │   at: 2026-11-06T04:56:20Z
Nov 06 05:56:20 evo-x2 pma[2303]:   │   caused by: [transient:provider.request] request failed: Post "http://127.0.0.1:52625/v1/chat/completions": context deadline exceeded
Nov 06 05:56:20 evo-x2 pma[2303]:  processing batch component=service project=/home/lars/projects/templ-components events=96 files=95
Nov 06 05:56:20 evo-x2 pma[2303]: WARN  conflicts detected, attempting resolution component=service project=/home/lars/projects/templ-components
Nov 06 05:56:20 evo-x2 pma[2303]: WARN  conflicts remain after resolution attempt component=service project=/home/lars/projects/templ-components resolution="Conflicting operation aborted — human resolution required"
Nov 06 05:56:20 evo-x2 pma[2303]:  processing batch component=service project=/home/lars/projects/SystemNix events=4 files=3
Nov 06 05:56:21 evo-x2 psi-wait-gate[1912502]: WAIT: fastflowlm — IO PSI some avg10=90.71% >= 30% (check 2, 30s elapsed); queued clients keep waiting
Nov 06 05:56:21 evo-x2 crm-server[20044]: time=2026-11-06T05:56:21.270+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=45.414ms
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 1670
- thermal-THROTTLE-lines: 3
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
```
```

## memory-emergency-guard lines (all)
```
Nov 05 20:39:27 evo-x2 post-crash-calm-gate[1562]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 20:42:28 evo-x2 memory-emergency-guard-check[22684]: MEMORY EMERGENCY IO-PAUSE (trip #7227, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 20:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 632ms CPU time over 1min 11.078s wall clock time, 12.2M memory peak, 32M read from disk, 88.2M written to disk.
Nov 05 20:42:28 evo-x2 memory-emergency-guard-check[59086]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.24% sustained (max disk busy 100.0%, MemAvailable=81.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (71s < 150s, 79s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 20:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:44:12 evo-x2 post-crash-calm-gate[120979]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 20:44:29 evo-x2 memory-emergency-guard-check[110930]: MEMORY EMERGENCY IO-PAUSE (trip #7228, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 20:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 533ms CPU time over 30.858s wall clock time, 11M memory peak, 1.4M read from disk, 27.7M written to disk.
Nov 05 20:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:47:07 evo-x2 memory-emergency-guard-check[165063]: MEMORY EMERGENCY IO-PAUSE (trip #7229, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 20:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 443ms CPU time over 36.847s wall clock time, 12.1M memory peak, 1.2M read from disk, 3.8M written to disk.
Nov 05 20:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:48:57 evo-x2 post-crash-calm-gate[229845]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 20:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:49:12 evo-x2 post-crash-calm-gate[245932]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 20:49:27 evo-x2 post-crash-calm-gate[251133]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 20:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:49:42 evo-x2 post-crash-calm-gate[253532]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 20:49:57 evo-x2 post-crash-calm-gate[275738]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 20:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:50:12 evo-x2 post-crash-calm-gate[279761]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 20:50:27 evo-x2 post-crash-calm-gate[294105]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 20:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:50:42 evo-x2 post-crash-calm-gate[301400]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 20:50:57 evo-x2 post-crash-calm-gate[314830]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 20:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:51:12 evo-x2 post-crash-calm-gate[325093]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 20:51:27 evo-x2 post-crash-calm-gate[344967]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 20:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:51:42 evo-x2 post-crash-calm-gate[348622]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 20:51:57 evo-x2 post-crash-calm-gate[354573]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 20:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:53:12 evo-x2 post-crash-calm-gate[365682]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 05 20:53:27 evo-x2 post-crash-calm-gate[368164]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 05 20:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:53:42 evo-x2 post-crash-calm-gate[368748]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 05 20:53:57 evo-x2 post-crash-calm-gate[373403]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 05 20:54:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:54:12 evo-x2 post-crash-calm-gate[374331]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 05 20:54:27 evo-x2 post-crash-calm-gate[377952]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 05 20:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:54:42 evo-x2 post-crash-calm-gate[381917]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 05 20:54:57 evo-x2 post-crash-calm-gate[395903]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 05 20:55:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:55:12 evo-x2 post-crash-calm-gate[401787]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 05 20:55:27 evo-x2 post-crash-calm-gate[413834]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 05 20:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:55:42 evo-x2 post-crash-calm-gate[421927]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 05 20:55:57 evo-x2 post-crash-calm-gate[432566]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 05 20:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:56:12 evo-x2 post-crash-calm-gate[435166]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 05 20:56:27 evo-x2 post-crash-calm-gate[439293]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 05 20:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:56:43 evo-x2 post-crash-calm-gate[441255]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 05 20:56:58 evo-x2 post-crash-calm-gate[466245]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 05 20:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:57:13 evo-x2 post-crash-calm-gate[471638]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 05 20:57:28 evo-x2 post-crash-calm-gate[484889]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 05 20:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:57:43 evo-x2 post-crash-calm-gate[490355]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 05 20:57:58 evo-x2 post-crash-calm-gate[497049]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 05 20:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:58:28 evo-x2 post-crash-calm-gate[522336]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 05 20:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:58:43 evo-x2 post-crash-calm-gate[526940]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 05 20:58:58 evo-x2 post-crash-calm-gate[532528]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 05 20:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 20:59:13 evo-x2 post-crash-calm-gate[536356]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 05 20:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:01:06 evo-x2 memory-emergency-guard-check[582745]: MEMORY EMERGENCY IO-PAUSE (trip #7230, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 932ms CPU time over 58.207s wall clock time, 10M memory peak, 35.6M read from disk, 60.4M written to disk.
Nov 05 21:01:06 evo-x2 memory-emergency-guard-check[625845]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.27% sustained (max disk busy 100.0%, MemAvailable=53.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (58s < 150s, 92s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:02:43 evo-x2 post-crash-calm-gate[661945]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 21:02:58 evo-x2 post-crash-calm-gate[681834]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 21:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:03:13 evo-x2 post-crash-calm-gate[686916]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 21:03:28 evo-x2 post-crash-calm-gate[691627]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 21:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:03:43 evo-x2 post-crash-calm-gate[697501]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 21:03:58 evo-x2 post-crash-calm-gate[703851]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 21:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:04:13 evo-x2 post-crash-calm-gate[709217]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 21:04:28 evo-x2 post-crash-calm-gate[714098]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 21:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:04:43 evo-x2 post-crash-calm-gate[716409]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 21:04:58 evo-x2 post-crash-calm-gate[720924]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 05 21:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:05:13 evo-x2 post-crash-calm-gate[722798]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 21:05:28 evo-x2 post-crash-calm-gate[728295]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 21:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:05:43 evo-x2 post-crash-calm-gate[733037]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 21:05:58 evo-x2 post-crash-calm-gate[742206]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 05 21:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:06:13 evo-x2 post-crash-calm-gate[746119]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 05 21:06:28 evo-x2 post-crash-calm-gate[753018]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 05 21:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:07:13 evo-x2 post-crash-calm-gate[793554]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 05 21:07:40 evo-x2 memory-emergency-guard-check[820032]: MEMORY EMERGENCY IO-PAUSE (trip #7231, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 897ms CPU time over 3.889s wall clock time, 10.3M memory peak, 3.5M read from disk, 59.7M written to disk.
Nov 05 21:07:58 evo-x2 post-crash-calm-gate[846486]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 21:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:08:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:10:09 evo-x2 memory-emergency-guard-check[913462]: MEMORY EMERGENCY IO-PAUSE (trip #7232, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 3.543s wall clock time, 10.5M memory peak, 5M read from disk, 79.1M written to disk.
Nov 05 21:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:10:43 evo-x2 post-crash-calm-gate[937308]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 21:10:58 evo-x2 post-crash-calm-gate[943687]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 21:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:11:13 evo-x2 post-crash-calm-gate[948892]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:11:28 evo-x2 post-crash-calm-gate[959516]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:11:43 evo-x2 post-crash-calm-gate[965873]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:11:58 evo-x2 post-crash-calm-gate[981176]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:12:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:12:13 evo-x2 post-crash-calm-gate[985024]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 21:12:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:13:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:13:13 evo-x2 post-crash-calm-gate[1010645]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 05 21:13:48 evo-x2 memory-emergency-guard-check[1020854]: MEMORY EMERGENCY IO-PAUSE (trip #7233, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 11.763s wall clock time, 10.5M memory peak, 2.5M read from disk, 25.7M written to disk.
Nov 05 21:14:07 evo-x2 memory-emergency-guard-check[1039430]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.96% sustained (max disk busy 100.0%, MemAvailable=49.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:14:43 evo-x2 post-crash-calm-gate[1053028]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:14:58 evo-x2 post-crash-calm-gate[1058853]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 21:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:15:59 evo-x2 post-crash-calm-gate[1122956]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 21:17:44 evo-x2 memory-emergency-guard-check[1128545]: MEMORY EMERGENCY IO-PAUSE (trip #7234, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.226s CPU time over 1min 35.623s wall clock time, 10.5M memory peak, 7.5M read from disk, 363.4M written to disk.
Nov 05 21:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:18:49 evo-x2 memory-emergency-guard-check[1231521]: MEMORY EMERGENCY IO-PAUSE (trip #7235, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 3.842s wall clock time, 9.8M memory peak, 28.7M read from disk, 56.3M written to disk.
Nov 05 21:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:21:23 evo-x2 memory-emergency-guard-check[1382075]: MEMORY EMERGENCY IO-PAUSE (trip #7236, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 5.648s wall clock time, 11.1M memory peak, 10.2M read from disk, 44.4M written to disk.
Nov 05 21:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:23:52 evo-x2 memory-emergency-guard-check[1556498]: MEMORY EMERGENCY IO-PAUSE (trip #7237, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 3.976s wall clock time, 9M memory peak, 10M read from disk, 67.4M written to disk.
Nov 05 21:24:18 evo-x2 memory-emergency-guard-check[1608389]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.61% sustained (max disk busy 100.0%, MemAvailable=68.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:26:22 evo-x2 memory-emergency-guard-check[1751373]: MEMORY EMERGENCY IO-PAUSE (trip #7238, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 663ms CPU time over 3.727s wall clock time, 10.4M memory peak, 6.3M read from disk, 12.2M written to disk.
Nov 05 21:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:28:52 evo-x2 memory-emergency-guard-check[1849168]: MEMORY EMERGENCY IO-PAUSE (trip #7239, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 2.764s wall clock time, 10.6M memory peak, 18.2M read from disk, 78.1M written to disk.
Nov 05 21:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:31:22 evo-x2 memory-emergency-guard-check[1923796]: MEMORY EMERGENCY IO-PAUSE (trip #7240, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 909ms CPU time over 2.689s wall clock time, 10.2M memory peak, 3M read from disk, 57.8M written to disk.
Nov 05 21:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:33:52 evo-x2 memory-emergency-guard-check[1988386]: MEMORY EMERGENCY IO-PAUSE (trip #7241, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 2.523s wall clock time, 11M memory peak, 7.8M read from disk, 68.6M written to disk.
Nov 05 21:34:20 evo-x2 memory-emergency-guard-check[2019775]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.48% sustained (max disk busy 100.0%, MemAvailable=71.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:36:27 evo-x2 memory-emergency-guard-check[2080796]: MEMORY EMERGENCY IO-PAUSE (trip #7242, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 6.145s wall clock time, 11.4M memory peak, 5.9M read from disk, 90M written to disk.
Nov 05 21:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:39:20 evo-x2 memory-emergency-guard-check[2310875]: MEMORY EMERGENCY IO-PAUSE (trip #7243, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 810ms CPU time over 29.282s wall clock time, 11.7M memory peak, 1.1M read from disk, 27.3M written to disk.
Nov 05 21:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:41:24 evo-x2 memory-emergency-guard-check[2486363]: MEMORY EMERGENCY IO-PAUSE (trip #7244, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 800ms CPU time over 2.656s wall clock time, 10M memory peak, 10.3M read from disk, 52.3M written to disk.
Nov 05 21:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:43:55 evo-x2 memory-emergency-guard-check[2584421]: MEMORY EMERGENCY IO-PAUSE (trip #7245, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 903ms CPU time over 2.620s wall clock time, 8.4M memory peak, 5M read from disk, 54.6M written to disk.
Nov 05 21:44:23 evo-x2 memory-emergency-guard-check[2612635]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.10% sustained (max disk busy 89.0%, MemAvailable=70.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:46:26 evo-x2 memory-emergency-guard-check[2720154]: MEMORY EMERGENCY IO-PAUSE (trip #7246, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 949ms CPU time over 3.252s wall clock time, 8.6M memory peak, 7.1M read from disk, 50.2M written to disk.
Nov 05 21:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:48:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:48:57 evo-x2 memory-emergency-guard-check[2902819]: MEMORY EMERGENCY IO-PAUSE (trip #7247, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 857ms CPU time over 4.062s wall clock time, 9.3M memory peak, 25M read from disk, 28.7M written to disk.
Nov 05 21:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:49:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:51:26 evo-x2 memory-emergency-guard-check[3063247]: MEMORY EMERGENCY IO-PAUSE (trip #7248, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 980ms CPU time over 2.318s wall clock time, 7.6M memory peak, 8.7M read from disk, 48.8M written to disk.
Nov 05 21:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:53:55 evo-x2 memory-emergency-guard-check[3197985]: MEMORY EMERGENCY IO-PAUSE (trip #7249, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 706ms CPU time over 974ms wall clock time, 10.2M memory peak, 12.4M read from disk, 53.1M written to disk.
Nov 05 21:54:24 evo-x2 memory-emergency-guard-check[3215488]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.35% sustained (max disk busy 100.0%, MemAvailable=71.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 21:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:57:08 evo-x2 memory-emergency-guard-check[3252356]: MEMORY EMERGENCY IO-PAUSE (trip #7250, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 43.919s wall clock time, 11.6M memory peak, 17.5M read from disk, 1.7M written to disk.
Nov 05 21:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:59:12 evo-x2 memory-emergency-guard-check[3321397]: MEMORY EMERGENCY IO-PAUSE (trip #7251, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 21:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 21:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 837ms CPU time over 3.000s wall clock time, 10.6M memory peak, 3.6M read from disk, 48.1M written to disk.
Nov 05 21:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:01:42 evo-x2 memory-emergency-guard-check[3423383]: MEMORY EMERGENCY IO-PAUSE (trip #7252, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 3.124s wall clock time, 9.2M memory peak, 7.1M read from disk, 78.8M written to disk.
Nov 05 22:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:04:14 evo-x2 memory-emergency-guard-check[3579763]: MEMORY EMERGENCY IO-PAUSE (trip #7253, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 4.700s wall clock time, 10.2M memory peak, 34.1M read from disk, 42.6M written to disk.
Nov 05 22:04:40 evo-x2 memory-emergency-guard-check[3623013]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.19% sustained (max disk busy 85.4%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:08:25 evo-x2 memory-emergency-guard-check[3860467]: MEMORY EMERGENCY IO-PAUSE (trip #7254, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 802ms CPU time over 14.711s wall clock time, 10.6M memory peak, 17.1M read from disk, 59.6M written to disk.
Nov 05 22:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:10:43 evo-x2 memory-emergency-guard-check[3920184]: MEMORY EMERGENCY IO-PAUSE (trip #7255, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 2.139s wall clock time, 11.1M memory peak, 4.1M read from disk, 64.7M written to disk.
Nov 05 22:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:13:14 evo-x2 memory-emergency-guard-check[3988459]: MEMORY EMERGENCY IO-PAUSE (trip #7256, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 961ms CPU time over 2.461s wall clock time, 10.2M memory peak, 12.2M read from disk, 59.6M written to disk.
Nov 05 22:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:14:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:14:42 evo-x2 memory-emergency-guard-check[4063958]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.35% sustained (max disk busy 53.8%, MemAvailable=66.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:16:15 evo-x2 memory-emergency-guard-check[4121617]: MEMORY EMERGENCY IO-PAUSE (trip #7257, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 971ms CPU time over 3.352s wall clock time, 10.6M memory peak, 7.3M read from disk, 45.6M written to disk.
Nov 05 22:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:18:44 evo-x2 memory-emergency-guard-check[793]: MEMORY EMERGENCY IO-PAUSE (trip #7258, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 654ms CPU time over 1.930s wall clock time, 10.7M memory peak, 5.6M read from disk, 47.4M written to disk.
Nov 05 22:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:21:13 evo-x2 memory-emergency-guard-check[113297]: MEMORY EMERGENCY IO-PAUSE (trip #7259, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 648ms CPU time over 802ms wall clock time, 10.9M memory peak, 5.2M read from disk, 39.1M written to disk.
Nov 05 22:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:23:48 evo-x2 memory-emergency-guard-check[180765]: MEMORY EMERGENCY IO-PAUSE (trip #7260, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 4.426s wall clock time, 12.1M memory peak, 2.2M read from disk, 60.8M written to disk.
Nov 05 22:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:24:44 evo-x2 memory-emergency-guard-check[220333]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.08% sustained (max disk busy 58.1%, MemAvailable=73.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:26:17 evo-x2 memory-emergency-guard-check[256317]: MEMORY EMERGENCY IO-PAUSE (trip #7261, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 2.827s wall clock time, 11.2M memory peak, 13.6M read from disk, 42.7M written to disk.
Nov 05 22:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:27:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:28:48 evo-x2 memory-emergency-guard-check[327089]: MEMORY EMERGENCY IO-PAUSE (trip #7262, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 635ms CPU time over 2.598s wall clock time, 10M memory peak, 6.4M read from disk, 36.9M written to disk.
Nov 05 22:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:31:17 evo-x2 memory-emergency-guard-check[394886]: MEMORY EMERGENCY IO-PAUSE (trip #7263, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 640ms CPU time over 1.837s wall clock time, 11.2M memory peak, 6.8M read from disk, 43.9M written to disk.
Nov 05 22:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:33:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:33:35 evo-x2 post-crash-calm-gate[569967]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 05 22:33:48 evo-x2 memory-emergency-guard-check[577996]: MEMORY EMERGENCY IO-PAUSE (trip #7264, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 970ms CPU time over 2.297s wall clock time, 9.8M memory peak, 4.8M read from disk, 42.8M written to disk.
Nov 05 22:33:50 evo-x2 post-crash-calm-gate[583061]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 22:34:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:34:49 evo-x2 memory-emergency-guard-check[604169]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.02% sustained (max disk busy 100.0%, MemAvailable=71.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (63s < 150s, 87s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:36:28 evo-x2 memory-emergency-guard-check[675764]: MEMORY EMERGENCY IO-PAUSE (trip #7265, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 9.091s wall clock time, 11.5M memory peak, 13.6M read from disk, 24.2M written to disk.
Nov 05 22:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:38:56 evo-x2 memory-emergency-guard-check[762669]: MEMORY EMERGENCY IO-PAUSE (trip #7266, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 626ms CPU time over 6.765s wall clock time, 12.9M memory peak, 12.3M read from disk, 17M written to disk.
Nov 05 22:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:39:20 evo-x2 post-crash-calm-gate[792156]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 22:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:40:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:41:23 evo-x2 memory-emergency-guard-check[843440]: MEMORY EMERGENCY IO-PAUSE (trip #7267, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 621ms CPU time over 4.357s wall clock time, 12.3M memory peak, 3.4M read from disk, 49.6M written to disk.
Nov 05 22:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:41:50 evo-x2 post-crash-calm-gate[878810]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 22:42:05 evo-x2 post-crash-calm-gate[903607]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 05 22:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:42:20 evo-x2 post-crash-calm-gate[910668]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 05 22:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:43:51 evo-x2 memory-emergency-guard-check[965763]: MEMORY EMERGENCY IO-PAUSE (trip #7268, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 1.890s wall clock time, 9.8M memory peak, 1M read from disk, 35.2M written to disk.
Nov 05 22:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:44:50 evo-x2 memory-emergency-guard-check[995819]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.33% sustained (max disk busy 98.0%, MemAvailable=50.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:46:23 evo-x2 memory-emergency-guard-check[1064174]: MEMORY EMERGENCY IO-PAUSE (trip #7269, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 3.795s wall clock time, 10.6M memory peak, 5.3M read from disk, 12.2M written to disk.
Nov 05 22:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:49:04 evo-x2 memory-emergency-guard-check[1117928]: MEMORY EMERGENCY IO-PAUSE (trip #7270, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 13.086s wall clock time, 10.2M memory peak, 26.9M read from disk, 8.2M written to disk.
Nov 05 22:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:51:24 evo-x2 memory-emergency-guard-check[1172541]: MEMORY EMERGENCY IO-PAUSE (trip #7271, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 497ms CPU time over 3.010s wall clock time, 11.2M memory peak, 704K read from disk, 14.4M written to disk.
Nov 05 22:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:53:54 evo-x2 memory-emergency-guard-check[1226087]: MEMORY EMERGENCY IO-PAUSE (trip #7272, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 705ms CPU time over 2.091s wall clock time, 10M memory peak, 5.7M read from disk, 43.8M written to disk.
Nov 05 22:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:54:52 evo-x2 memory-emergency-guard-check[1257182]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.13% sustained (max disk busy 87.4%, MemAvailable=71.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 22:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:56:24 evo-x2 memory-emergency-guard-check[1276404]: MEMORY EMERGENCY IO-PAUSE (trip #7273, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 546ms CPU time over 2.640s wall clock time, 12.4M memory peak, 9.6M read from disk, 41M written to disk.
Nov 05 22:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:58:53 evo-x2 memory-emergency-guard-check[1311707]: MEMORY EMERGENCY IO-PAUSE (trip #7274, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 22:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 605ms CPU time over 781ms wall clock time, 11.7M memory peak, 5.3M read from disk, 51.1M written to disk.
Nov 05 22:59:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 22:59:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:01:25 evo-x2 memory-emergency-guard-check[1349181]: MEMORY EMERGENCY IO-PAUSE (trip #7275, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 1.459s wall clock time, 11.5M memory peak, 10.6M read from disk, 71.5M written to disk.
Nov 05 23:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:03:58 evo-x2 memory-emergency-guard-check[1388082]: MEMORY EMERGENCY IO-PAUSE (trip #7276, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 4.521s wall clock time, 12.3M memory peak, 6.1M read from disk, 58.1M written to disk.
Nov 05 23:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:04:54 evo-x2 memory-emergency-guard-check[1409297]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.69% sustained (max disk busy 96.3%, MemAvailable=68.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:06:27 evo-x2 memory-emergency-guard-check[1432996]: MEMORY EMERGENCY IO-PAUSE (trip #7277, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 591ms CPU time over 2.270s wall clock time, 12.2M memory peak, 784K read from disk, 31.1M written to disk.
Nov 05 23:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:08:57 evo-x2 memory-emergency-guard-check[1476438]: MEMORY EMERGENCY IO-PAUSE (trip #7278, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 625ms CPU time over 2.514s wall clock time, 11.5M memory peak, 18.9M read from disk, 52.3M written to disk.
Nov 05 23:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:11:28 evo-x2 memory-emergency-guard-check[1520666]: MEMORY EMERGENCY IO-PAUSE (trip #7279, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 2.033s wall clock time, 10.7M memory peak, 3.9M read from disk, 29.4M written to disk.
Nov 05 23:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:12:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:13:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:13:56 evo-x2 memory-emergency-guard-check[1560586]: MEMORY EMERGENCY IO-PAUSE (trip #7280, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 768ms wall clock time, 10.6M memory peak, 5.4M read from disk, 36.3M written to disk.
Nov 05 23:14:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:14:56 evo-x2 memory-emergency-guard-check[1580000]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.84% sustained (max disk busy 59.7%, MemAvailable=67.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:15:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:16:29 evo-x2 memory-emergency-guard-check[1610348]: MEMORY EMERGENCY IO-PAUSE (trip #7281, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 3.323s wall clock time, 10.9M memory peak, 33.4M read from disk, 91M written to disk.
Nov 05 23:16:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:19:00 evo-x2 memory-emergency-guard-check[1762468]: MEMORY EMERGENCY IO-PAUSE (trip #7282, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 3.764s wall clock time, 12.9M memory peak, 12.5M read from disk, 54.7M written to disk.
Nov 05 23:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:20:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:21:29 evo-x2 memory-emergency-guard-check[1823329]: MEMORY EMERGENCY IO-PAUSE (trip #7283, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 628ms CPU time over 2.635s wall clock time, 11.4M memory peak, 6M read from disk, 47.7M written to disk.
Nov 05 23:21:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:24:05 evo-x2 memory-emergency-guard-check[1929906]: MEMORY EMERGENCY IO-PAUSE (trip #7284, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 667ms CPU time over 7.527s wall clock time, 9.8M memory peak, 8.7M read from disk, 43.1M written to disk.
Nov 05 23:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:24:57 evo-x2 memory-emergency-guard-check[1968859]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.74% sustained (max disk busy 100.0%, MemAvailable=64.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:24:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:25:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:25:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:26:29 evo-x2 memory-emergency-guard-check[2013488]: MEMORY EMERGENCY IO-PAUSE (trip #7285, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 740ms CPU time over 1.934s wall clock time, 10.6M memory peak, 2.1M read from disk, 39.9M written to disk.
Nov 05 23:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:27:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:29:16 evo-x2 memory-emergency-guard-check[2080308]: MEMORY EMERGENCY IO-PAUSE (trip #7286, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 17.600s wall clock time, 11M memory peak, 2.6M read from disk, 31.9M written to disk.
Nov 05 23:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:30:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:32:10 evo-x2 memory-emergency-guard-check[2127983]: MEMORY EMERGENCY IO-PAUSE (trip #7287, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 40.738s wall clock time, 13.1M memory peak, 10.7M read from disk, 36.7M written to disk.
Nov 05 23:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:34:18 evo-x2 memory-emergency-guard-check[2196034]: MEMORY EMERGENCY IO-PAUSE (trip #7288, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 7.623s wall clock time, 15.4M memory peak, 20.8M read from disk, 48M written to disk.
Nov 05 23:34:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:35:10 evo-x2 memory-emergency-guard-check[2229527]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.99% sustained (max disk busy 100.0%, MemAvailable=49.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:36:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:38:18 evo-x2 memory-emergency-guard-check[2262185]: MEMORY EMERGENCY IO-PAUSE (trip #7289, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 1min 37.104s wall clock time, 16M memory peak, 5.2M read from disk, 67.9M written to disk.
Nov 05 23:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:39:21 evo-x2 memory-emergency-guard-check[2329586]: MEMORY EMERGENCY IO-PAUSE (trip #7290, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 2.119s wall clock time, 13.5M memory peak, 1.2M read from disk, 21M written to disk.
Nov 05 23:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:40:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:41:51 evo-x2 memory-emergency-guard-check[2400426]: MEMORY EMERGENCY IO-PAUSE (trip #7291, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 1.477s wall clock time, 14.1M memory peak, 1.2M read from disk, 26.3M written to disk.
Nov 05 23:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:44:22 evo-x2 memory-emergency-guard-check[2466182]: MEMORY EMERGENCY IO-PAUSE (trip #7292, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 2.277s wall clock time, 15M memory peak, 2.5M read from disk, 29.8M written to disk.
Nov 05 23:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:45:19 evo-x2 memory-emergency-guard-check[2499455]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.39% sustained (max disk busy 61.8%, MemAvailable=65.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:46:52 evo-x2 memory-emergency-guard-check[2529408]: MEMORY EMERGENCY IO-PAUSE (trip #7293, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 582ms CPU time over 2.717s wall clock time, 12.6M memory peak, 4M read from disk, 35.3M written to disk.
Nov 05 23:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:48:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:49:22 evo-x2 memory-emergency-guard-check[2590914]: MEMORY EMERGENCY IO-PAUSE (trip #7294, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 699ms CPU time over 2.377s wall clock time, 14M memory peak, 8M read from disk, 61.6M written to disk.
Nov 05 23:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:51:51 evo-x2 memory-emergency-guard-check[2667492]: MEMORY EMERGENCY IO-PAUSE (trip #7295, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 1.016s wall clock time, 13.2M memory peak, 5.3M read from disk, 47.6M written to disk.
Nov 05 23:52:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:53:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:54:57 evo-x2 memory-emergency-guard-check[2824042]: MEMORY EMERGENCY IO-PAUSE (trip #7296, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 696ms CPU time over 6.565s wall clock time, 15M memory peak, 5M read from disk, 28.5M written to disk.
Nov 05 23:55:21 evo-x2 memory-emergency-guard-check[2852095]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.71% sustained (max disk busy 35.6%, MemAvailable=66.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 05 23:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:57:24 evo-x2 memory-emergency-guard-check[2913569]: MEMORY EMERGENCY IO-PAUSE (trip #7297, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 747ms CPU time over 2.489s wall clock time, 15.7M memory peak, 4.4M read from disk, 37M written to disk.
Nov 05 23:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:59:54 evo-x2 memory-emergency-guard-check[3059640]: MEMORY EMERGENCY IO-PAUSE (trip #7298, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 23:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 23:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.054s CPU time over 2.726s wall clock time, 15.9M memory peak, 21.7M read from disk, 50.2M written to disk.
Nov 06 00:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 201ms CPU time over 684ms wall clock time, 8.7M memory peak, 3.8M read from disk, 4K written to disk.
Nov 06 00:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:02:25 evo-x2 memory-emergency-guard-check[3256472]: MEMORY EMERGENCY IO-PAUSE (trip #7299, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.264s CPU time over 3.292s wall clock time, 15.1M memory peak, 1.7M read from disk, 28.1M written to disk.
Nov 06 00:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 201ms CPU time over 543ms wall clock time, 9M memory peak, 3.4M read from disk, 4K written to disk.
Nov 06 00:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:06:55 evo-x2 memory-emergency-guard-check[3555797]: MEMORY EMERGENCY IO-PAUSE (trip #7300, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 2.518s wall clock time, 12.4M memory peak, 12.3M read from disk, 15.9M written to disk.
Nov 06 00:07:22 evo-x2 memory-emergency-guard-check[3579975]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.87% sustained (max disk busy 100.0%, MemAvailable=44.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 00:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:09:26 evo-x2 memory-emergency-guard-check[3696676]: MEMORY EMERGENCY IO-PAUSE (trip #7301, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.093s CPU time over 3.285s wall clock time, 9.1M memory peak, 2.7M read from disk, 38.8M written to disk.
Nov 06 00:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:11:55 evo-x2 memory-emergency-guard-check[3872119]: MEMORY EMERGENCY IO-PAUSE (trip #7302, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.172s CPU time over 2.490s wall clock time, 8.8M memory peak, 4.3M read from disk, 45.1M written to disk.
Nov 06 00:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:14:28 evo-x2 memory-emergency-guard-check[4061900]: MEMORY EMERGENCY IO-PAUSE (trip #7303, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.137s CPU time over 4.117s wall clock time, 9.1M memory peak, 26.9M read from disk, 66.1M written to disk.
Nov 06 00:14:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:18:33 evo-x2 memory-emergency-guard-check[98766]: MEMORY EMERGENCY IO-PAUSE (trip #7304, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.061s CPU time over 4.758s wall clock time, 9M memory peak, 14.5M read from disk, 55.6M written to disk.
Nov 06 00:18:59 evo-x2 memory-emergency-guard-check[125583]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.76% sustained (max disk busy 98.2%, MemAvailable=43.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 00:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:21:08 evo-x2 memory-emergency-guard-check[188338]: MEMORY EMERGENCY IO-PAUSE (trip #7305, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 998ms CPU time over 9.195s wall clock time, 10.8M memory peak, 19.3M read from disk, 41.2M written to disk.
Nov 06 00:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:24:12 evo-x2 memory-emergency-guard-check[244243]: MEMORY EMERGENCY IO-PAUSE (trip #7306, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 990ms CPU time over 42.825s wall clock time, 12.5M memory peak, 3.7M read from disk, 12.2M written to disk.
Nov 06 00:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:24:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:25:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:26:17 evo-x2 memory-emergency-guard-check[311210]: MEMORY EMERGENCY IO-PAUSE (trip #7307, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 4.147s wall clock time, 10.4M memory peak, 1.5M read from disk, 39.8M written to disk.
Nov 06 00:26:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:28:46 evo-x2 memory-emergency-guard-check[443390]: MEMORY EMERGENCY IO-PAUSE (trip #7308, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 768ms CPU time over 3.021s wall clock time, 10.3M memory peak, 9.8M read from disk, 54.6M written to disk.
Nov 06 00:29:13 evo-x2 memory-emergency-guard-check[468824]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.44% sustained (max disk busy 66.3%, MemAvailable=59.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 00:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:31:17 evo-x2 memory-emergency-guard-check[536444]: MEMORY EMERGENCY IO-PAUSE (trip #7309, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 674ms CPU time over 2.436s wall clock time, 10.8M memory peak, 1.8M read from disk, 20.7M written to disk.
Nov 06 00:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:33:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:33:47 evo-x2 memory-emergency-guard-check[637911]: MEMORY EMERGENCY IO-PAUSE (trip #7310, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 1.188s wall clock time, 9.7M memory peak, 16K read from disk, 12.5M written to disk.
Nov 06 00:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:36:27 evo-x2 memory-emergency-guard-check[710209]: MEMORY EMERGENCY IO-PAUSE (trip #7311, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 634ms CPU time over 10.316s wall clock time, 10.5M memory peak, 1.2M read from disk, 16.6M written to disk.
Nov 06 00:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:38:51 evo-x2 memory-emergency-guard-check[813863]: MEMORY EMERGENCY IO-PAUSE (trip #7312, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 819ms CPU time over 3.917s wall clock time, 10.4M memory peak, 26.5M read from disk, 71.7M written to disk.
Nov 06 00:39:18 evo-x2 memory-emergency-guard-check[845552]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.69% sustained (max disk busy 86.3%, MemAvailable=50.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 00:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:41:56 evo-x2 memory-emergency-guard-check[940399]: MEMORY EMERGENCY IO-PAUSE (trip #7313, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 37.707s wall clock time, 11.6M memory peak, 27.6M read from disk, 18.1M written to disk.
Nov 06 00:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:43:58 evo-x2 memory-emergency-guard-check[1045918]: MEMORY EMERGENCY IO-PAUSE (trip #7314, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 812ms CPU time over 1.946s wall clock time, 10.4M memory peak, 11.7M read from disk, 48.2M written to disk.
Nov 06 00:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:45:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:46:31 evo-x2 memory-emergency-guard-check[1159519]: MEMORY EMERGENCY IO-PAUSE (trip #7315, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 969ms CPU time over 3.122s wall clock time, 10.2M memory peak, 10.6M read from disk, 35.5M written to disk.
Nov 06 00:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:48:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:49:01 evo-x2 memory-emergency-guard-check[1292256]: MEMORY EMERGENCY IO-PAUSE (trip #7316, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.000s CPU time over 3.381s wall clock time, 8.1M memory peak, 7.8M read from disk, 52.3M written to disk.
Nov 06 00:49:28 evo-x2 memory-emergency-guard-check[1366926]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.62% sustained (max disk busy 94.0%, MemAvailable=51.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 00:49:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 177ms CPU time over 389ms wall clock time, 4.8M memory peak, 1.4M read from disk, 4K written to disk.
Nov 06 00:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 185ms CPU time over 781ms wall clock time, 8.6M memory peak, 2.8M read from disk, 4K written to disk.
Nov 06 00:53:16 evo-x2 memory-emergency-guard-check[1538096]: MEMORY EMERGENCY IO-PAUSE (trip #7317, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.335s CPU time over 1min 16.293s wall clock time, 8.5M memory peak, 5.2M read from disk, 33.7M written to disk.
Nov 06 00:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:53:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 198ms CPU time over 580ms wall clock time, 9.6M memory peak, 4.3M read from disk, 4K written to disk.
Nov 06 00:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:55:16 evo-x2 memory-emergency-guard-check[1725481]: MEMORY EMERGENCY IO-PAUSE (trip #7318, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:55:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:55:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 933ms CPU time over 29.921s wall clock time, 9.7M memory peak, 19.1M read from disk, 25.9M written to disk.
Nov 06 00:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:56:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:57:28 evo-x2 memory-emergency-guard-check[1799237]: MEMORY EMERGENCY IO-PAUSE (trip #7319, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 00:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 755ms CPU time over 11.127s wall clock time, 8.6M memory peak, 4.8M read from disk, 16.8M written to disk.
Nov 06 00:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 149ms wall clock time, 8.6M memory peak, 3.2M read from disk, 4K written to disk.
Nov 06 00:59:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 00:59:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 219ms CPU time over 383ms wall clock time, 8.5M memory peak, 3.3M read from disk, 4K written to disk.
Nov 06 01:00:08 evo-x2 memory-emergency-guard-check[1933665]: MEMORY EMERGENCY IO-PAUSE (trip #7320, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 942ms CPU time over 20.400s wall clock time, 10.6M memory peak, 30M read from disk, 18M written to disk.
Nov 06 01:00:18 evo-x2 memory-emergency-guard-check[1962361]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.50% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:00:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:00:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:00:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 164ms CPU time over 234ms wall clock time, 6.5M memory peak, 1.9M read from disk, 4K written to disk.
Nov 06 01:01:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:01:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:02:45 evo-x2 memory-emergency-guard-check[2070856]: MEMORY EMERGENCY IO-PAUSE (trip #7321, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 846ms CPU time over 26.666s wall clock time, 12.3M memory peak, 18.2M read from disk, 28.1M written to disk.
Nov 06 01:02:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:03:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:03:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:05:07 evo-x2 memory-emergency-guard-check[2177153]: MEMORY EMERGENCY IO-PAUSE (trip #7322, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.288s CPU time over 18.554s wall clock time, 9.5M memory peak, 31.6M read from disk, 11.7M written to disk.
Nov 06 01:05:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:05:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 208ms CPU time over 850ms wall clock time, 5.8M memory peak, 1.5M read from disk, 4K written to disk.
Nov 06 01:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:07:25 evo-x2 memory-emergency-guard-check[2345871]: MEMORY EMERGENCY IO-PAUSE (trip #7323, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.089s CPU time over 7.255s wall clock time, 9.1M memory peak, 3.8M read from disk, 35.3M written to disk.
Nov 06 01:07:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:08:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 180ms CPU time over 402ms wall clock time, 8.5M memory peak, 1.9M read from disk, 4K written to disk.
Nov 06 01:09:55 evo-x2 memory-emergency-guard-check[2478532]: MEMORY EMERGENCY IO-PAUSE (trip #7324, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.080s CPU time over 6.110s wall clock time, 12.7M memory peak, 6.3M read from disk, 17.2M written to disk.
Nov 06 01:10:19 evo-x2 memory-emergency-guard-check[2518970]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.24% sustained (max disk busy 99.7%, MemAvailable=35.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:11:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:13:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:14:44 evo-x2 memory-emergency-guard-check[2682618]: MEMORY EMERGENCY IO-PAUSE (trip #7325, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.109s CPU time over 25.728s wall clock time, 9.2M memory peak, 28M read from disk, 6.3M written to disk.
Nov 06 01:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:17:30 evo-x2 memory-emergency-guard-check[2762241]: MEMORY EMERGENCY IO-PAUSE (trip #7326, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.039s CPU time over 41.098s wall clock time, 10.2M memory peak, 21.3M read from disk, 28.9M written to disk.
Nov 06 01:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:18:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:19:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:20:28 evo-x2 memory-emergency-guard-check[2847123]: MEMORY EMERGENCY IO-PAUSE (trip #7327, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 933ms CPU time over 56.467s wall clock time, 11.2M memory peak, 22.3M read from disk, 7.8M written to disk.
Nov 06 01:20:28 evo-x2 memory-emergency-guard-check[2893107]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.70% sustained (max disk busy 99.1%, MemAvailable=38.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (57s < 150s, 93s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:22:31 evo-x2 memory-emergency-guard-check[2943221]: MEMORY EMERGENCY IO-PAUSE (trip #7328, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 754ms CPU time over 27.193s wall clock time, 10.4M memory peak, 11.9M read from disk, 15.1M written to disk.
Nov 06 01:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:23:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:25:34 evo-x2 memory-emergency-guard-check[3011481]: MEMORY EMERGENCY IO-PAUSE (trip #7329, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.024s CPU time over 59.706s wall clock time, 10.9M memory peak, 28.2M read from disk, 46.8M written to disk.
Nov 06 01:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 147ms CPU time over 208ms wall clock time, 8.3M memory peak, 2.8M read from disk, 4K written to disk.
Nov 06 01:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:27:42 evo-x2 memory-emergency-guard-check[3092354]: MEMORY EMERGENCY IO-PAUSE (trip #7330, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.033s CPU time over 36.911s wall clock time, 11.8M memory peak, 55.7M read from disk, 76M written to disk.
Nov 06 01:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:28:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:29:46 evo-x2 memory-emergency-guard-check[3191459]: MEMORY EMERGENCY IO-PAUSE (trip #7331, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.312s CPU time over 4.406s wall clock time, 8.6M memory peak, 26.9M read from disk, 71.2M written to disk.
Nov 06 01:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:30:43 evo-x2 memory-emergency-guard-check[3250605]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.30% sustained (max disk busy 99.8%, MemAvailable=58.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:32:15 evo-x2 memory-emergency-guard-check[3310404]: MEMORY EMERGENCY IO-PAUSE (trip #7332, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.032s CPU time over 2.790s wall clock time, 8.8M memory peak, 9.3M read from disk, 47.4M written to disk.
Nov 06 01:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:33:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:34:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:34:47 evo-x2 memory-emergency-guard-check[3454924]: MEMORY EMERGENCY IO-PAUSE (trip #7333, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.177s CPU time over 3.722s wall clock time, 14.6M memory peak, 13.5M read from disk, 64.9M written to disk.
Nov 06 01:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:36:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:36:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:37:18 evo-x2 memory-emergency-guard-check[3630743]: MEMORY EMERGENCY IO-PAUSE (trip #7334, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.160s CPU time over 4.260s wall clock time, 8.7M memory peak, 8.5M read from disk, 61.3M written to disk.
Nov 06 01:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:39:49 evo-x2 memory-emergency-guard-check[3856477]: MEMORY EMERGENCY IO-PAUSE (trip #7335, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.175s CPU time over 3.281s wall clock time, 7.8M memory peak, 15.1M read from disk, 62M written to disk.
Nov 06 01:40:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:40:46 evo-x2 memory-emergency-guard-check[3941679]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.71% sustained (max disk busy 100.0%, MemAvailable=60.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:40:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:41:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:41:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:42:20 evo-x2 memory-emergency-guard-check[4032377]: MEMORY EMERGENCY IO-PAUSE (trip #7336, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.063s CPU time over 3.816s wall clock time, 11.2M memory peak, 8.7M read from disk, 74.5M written to disk.
Nov 06 01:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:44:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:44:52 evo-x2 memory-emergency-guard-check[16700]: MEMORY EMERGENCY IO-PAUSE (trip #7337, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.533s CPU time over 4.646s wall clock time, 8.6M memory peak, 21.6M read from disk, 52.9M written to disk.
Nov 06 01:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:47:34 evo-x2 memory-emergency-guard-check[110983]: MEMORY EMERGENCY IO-PAUSE (trip #7338, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.294s CPU time over 17.091s wall clock time, 10.8M memory peak, 17.5M read from disk, 47M written to disk.
Nov 06 01:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:48:28 evo-x2 gatus[31796]: 2026/11/06 01:48:28 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 06 01:48:28 evo-x2 gatus[31796]: 2026/11/06 01:48:28 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 06 01:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:50:17 evo-x2 memory-emergency-guard-check[234589]: MEMORY EMERGENCY IO-PAUSE (trip #7339, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.345s CPU time over 28.462s wall clock time, 10.2M memory peak, 31M read from disk, 12.3M written to disk.
Nov 06 01:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:50:49 evo-x2 memory-emergency-guard-check[282160]: MEMORY EMERGENCY still active (I/O PSI some avg60=96.58% sustained (max disk busy 99.9%, MemAvailable=39.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 01:50:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:51:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:52:49 evo-x2 memory-emergency-guard-check[335529]: MEMORY EMERGENCY IO-PAUSE (trip #7340, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.070s CPU time over 30.345s wall clock time, 10.4M memory peak, 14.7M read from disk, 68.2M written to disk.
Nov 06 01:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:53:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:54:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:54:55 evo-x2 memory-emergency-guard-check[464097]: sort: write failed: 'standard output': Broken pipe
Nov 06 01:54:55 evo-x2 memory-emergency-guard-check[464097]: sort: write error
Nov 06 01:54:55 evo-x2 memory-emergency-guard-check[458871]: MEMORY EMERGENCY IO-PAUSE (trip #7341, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.079s CPU time over 5.043s wall clock time, 9.3M memory peak, 4.2M read from disk, 29M written to disk.
Nov 06 01:55:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:55:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:56:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:57:27 evo-x2 memory-emergency-guard-check[680411]: MEMORY EMERGENCY IO-PAUSE (trip #7342, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.276s CPU time over 6.791s wall clock time, 9.5M memory peak, 23.1M read from disk, 91.3M written to disk.
Nov 06 01:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:59:52 evo-x2 memory-emergency-guard-check[820589]: MEMORY EMERGENCY IO-PAUSE (trip #7343, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 01:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 01:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 785ms CPU time over 1.858s wall clock time, 10.5M memory peak, 3.5M read from disk, 45.1M written to disk.
Nov 06 02:00:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:00:51 evo-x2 memory-emergency-guard-check[906927]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.25% sustained (max disk busy 100.0%, MemAvailable=52.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:02:37 evo-x2 memory-emergency-guard-check[1015783]: MEMORY EMERGENCY IO-PAUSE (trip #7344, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.008s CPU time over 15.436s wall clock time, 11.8M memory peak, 19.3M read from disk, 2.9M written to disk.
Nov 06 02:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:04:56 evo-x2 memory-emergency-guard-check[1131110]: MEMORY EMERGENCY IO-PAUSE (trip #7345, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 843ms CPU time over 4.526s wall clock time, 10.1M memory peak, 11.7M read from disk, 18.3M written to disk.
Nov 06 02:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:07:25 evo-x2 memory-emergency-guard-check[1255658]: MEMORY EMERGENCY IO-PAUSE (trip #7346, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.019s CPU time over 2.625s wall clock time, 9.7M memory peak, 17.7M read from disk, 79.7M written to disk.
Nov 06 02:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:10:08 evo-x2 memory-emergency-guard-check[1405932]: MEMORY EMERGENCY IO-PAUSE (trip #7347, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.002s CPU time over 15.452s wall clock time, 10.2M memory peak, 18M read from disk, 772K written to disk.
Nov 06 02:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:10:53 evo-x2 memory-emergency-guard-check[1468101]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.91% sustained (max disk busy 100.0%, MemAvailable=36.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:12:27 evo-x2 memory-emergency-guard-check[1515138]: MEMORY EMERGENCY IO-PAUSE (trip #7348, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 4.188s wall clock time, 9.7M memory peak, 1.9M read from disk, 7.2M written to disk.
Nov 06 02:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:15:27 evo-x2 memory-emergency-guard-check[1570350]: MEMORY EMERGENCY IO-PAUSE (trip #7349, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 32.789s wall clock time, 12.1M memory peak, 23.2M read from disk, 10.9M written to disk.
Nov 06 02:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:16:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:17:41 evo-x2 memory-emergency-guard-check[1690885]: MEMORY EMERGENCY IO-PAUSE (trip #7350, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 759ms CPU time over 13.992s wall clock time, 10.2M memory peak, 17.1M read from disk, 3.4M written to disk.
Nov 06 02:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:20:19 evo-x2 memory-emergency-guard-check[1757957]: MEMORY EMERGENCY IO-PAUSE (trip #7351, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 917ms CPU time over 20.421s wall clock time, 11.6M memory peak, 18.8M read from disk, 15.9M written to disk.
Nov 06 02:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:20:59 evo-x2 memory-emergency-guard-check[1779011]: MEMORY EMERGENCY still active (I/O PSI some avg60=96.34% sustained (max disk busy 100.0%, MemAvailable=26.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 155ms wall clock time, 8.1M memory peak, 1.9M read from disk, 4K written to disk.
Nov 06 02:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 160ms wall clock time, 9.2M memory peak, 1.2M read from disk, 4K written to disk.
Nov 06 02:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:22:38 evo-x2 memory-emergency-guard-check[1800697]: MEMORY EMERGENCY IO-PAUSE (trip #7352, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 8.923s wall clock time, 11.8M memory peak, 15.7M read from disk, 2.5M written to disk.
Nov 06 02:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:25:50 evo-x2 memory-emergency-guard-check[1861687]: MEMORY EMERGENCY IO-PAUSE (trip #7353, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 50.050s wall clock time, 11.5M memory peak, 11.8M read from disk, 22.4M written to disk.
Nov 06 02:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:27:59 evo-x2 memory-emergency-guard-check[1915899]: MEMORY EMERGENCY IO-PAUSE (trip #7354, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 7.916s wall clock time, 11.6M memory peak, 1M read from disk, 18.1M written to disk.
Nov 06 02:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:29:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:31:00 evo-x2 memory-emergency-guard-check[1980148]: MEMORY EMERGENCY IO-PAUSE (trip #7355, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 967ms CPU time over 38.446s wall clock time, 11.9M memory peak, 15.2M read from disk, 12.4M written to disk.
Nov 06 02:31:01 evo-x2 memory-emergency-guard-check[2006143]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.15% sustained (max disk busy 100.0%, MemAvailable=44.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (38s < 150s, 112s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:34:54 evo-x2 memory-emergency-guard-check[2066476]: MEMORY EMERGENCY IO-PAUSE (trip #7356, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.060s CPU time over 1min 53.270s wall clock time, 9.9M memory peak, 6.2M read from disk, 60.3M written to disk.
Nov 06 02:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:35:55 evo-x2 memory-emergency-guard-check[2185275]: MEMORY EMERGENCY IO-PAUSE (trip #7357, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 1.084s wall clock time, 10M memory peak, 560K read from disk, 14.1M written to disk.
Nov 06 02:36:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:37:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:38:27 evo-x2 memory-emergency-guard-check[2236471]: MEMORY EMERGENCY IO-PAUSE (trip #7358, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 879ms CPU time over 1.883s wall clock time, 8.6M memory peak, 4.2M read from disk, 30.3M written to disk.
Nov 06 02:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:40:58 evo-x2 memory-emergency-guard-check[2315229]: MEMORY EMERGENCY IO-PAUSE (trip #7359, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 773ms CPU time over 2.337s wall clock time, 9.5M memory peak, 3.9M read from disk, 38.8M written to disk.
Nov 06 02:41:26 evo-x2 memory-emergency-guard-check[2335768]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.74% sustained (max disk busy 87.0%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:43:31 evo-x2 memory-emergency-guard-check[2392952]: MEMORY EMERGENCY IO-PAUSE (trip #7360, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.224s CPU time over 4.582s wall clock time, 9.7M memory peak, 32.8M read from disk, 79.1M written to disk.
Nov 06 02:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:45:59 evo-x2 memory-emergency-guard-check[2483812]: MEMORY EMERGENCY IO-PAUSE (trip #7361, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 913ms CPU time over 1.627s wall clock time, 9.7M memory peak, 7.8M read from disk, 32.1M written to disk.
Nov 06 02:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:48:30 evo-x2 memory-emergency-guard-check[2619431]: MEMORY EMERGENCY IO-PAUSE (trip #7362, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.110s CPU time over 2.501s wall clock time, 11M memory peak, 3.8M read from disk, 56.6M written to disk.
Nov 06 02:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:51:03 evo-x2 memory-emergency-guard-check[2731107]: MEMORY EMERGENCY IO-PAUSE (trip #7363, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 3.805s wall clock time, 16.7M memory peak, 16.2M read from disk, 52.6M written to disk.
Nov 06 02:51:30 evo-x2 memory-emergency-guard-check[2753781]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.67% sustained (max disk busy 99.9%, MemAvailable=33.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 02:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:53:57 evo-x2 memory-emergency-guard-check[2811418]: MEMORY EMERGENCY IO-PAUSE (trip #7364, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.022s CPU time over 26.598s wall clock time, 10.5M memory peak, 40.4M read from disk, 17.8M written to disk.
Nov 06 02:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:54:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:55:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:56:10 evo-x2 memory-emergency-guard-check[2874056]: MEMORY EMERGENCY IO-PAUSE (trip #7365, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 915ms CPU time over 7.868s wall clock time, 9.9M memory peak, 8M read from disk, 62.7M written to disk.
Nov 06 02:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:58:37 evo-x2 memory-emergency-guard-check[2957433]: MEMORY EMERGENCY IO-PAUSE (trip #7366, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 02:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 4.772s wall clock time, 9.7M memory peak, 6.3M read from disk, 23.3M written to disk.
Nov 06 02:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 02:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:01:15 evo-x2 memory-emergency-guard-check[3006146]: MEMORY EMERGENCY IO-PAUSE (trip #7367, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 841ms CPU time over 12.487s wall clock time, 11M memory peak, 3.7M read from disk, 32.3M written to disk.
Nov 06 03:01:33 evo-x2 memory-emergency-guard-check[3020109]: MEMORY EMERGENCY still active (I/O PSI some avg60=97.15% sustained (max disk busy 100.0%, MemAvailable=37.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:03:39 evo-x2 memory-emergency-guard-check[3077762]: MEMORY EMERGENCY IO-PAUSE (trip #7368, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 786ms CPU time over 6.740s wall clock time, 10.5M memory peak, 4.1M read from disk, 5.2M written to disk.
Nov 06 03:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:06:06 evo-x2 memory-emergency-guard-check[3144256]: MEMORY EMERGENCY IO-PAUSE (trip #7369, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 907ms CPU time over 3.747s wall clock time, 10M memory peak, 10.6M read from disk, 44.6M written to disk.
Nov 06 03:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:08:35 evo-x2 memory-emergency-guard-check[3219875]: sort: fflush failed: 'standard output': Broken pipe
Nov 06 03:08:35 evo-x2 memory-emergency-guard-check[3219875]: sort: write error
Nov 06 03:08:35 evo-x2 memory-emergency-guard-check[3218265]: MEMORY EMERGENCY IO-PAUSE (trip #7370, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 741ms CPU time over 1.766s wall clock time, 9.6M memory peak, 3.2M read from disk, 51.2M written to disk.
Nov 06 03:09:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:11:25 evo-x2 memory-emergency-guard-check[3309433]: MEMORY EMERGENCY IO-PAUSE (trip #7371, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 865ms CPU time over 21.038s wall clock time, 8.6M memory peak, 3.3M read from disk, 14.4M written to disk.
Nov 06 03:11:34 evo-x2 memory-emergency-guard-check[3362240]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.36% sustained (max disk busy 100.0%, MemAvailable=52.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:13:41 evo-x2 memory-emergency-guard-check[3484759]: MEMORY EMERGENCY IO-PAUSE (trip #7372, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.034s CPU time over 7.589s wall clock time, 10.5M memory peak, 9M read from disk, 64M written to disk.
Nov 06 03:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:16:08 evo-x2 memory-emergency-guard-check[3625566]: MEMORY EMERGENCY IO-PAUSE (trip #7373, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 3.708s wall clock time, 10.6M memory peak, 17M read from disk, 18.3M written to disk.
Nov 06 03:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 130ms CPU time over 168ms wall clock time, 8.8M memory peak, 1.7M read from disk, 4K written to disk.
Nov 06 03:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:19:35 evo-x2 memory-emergency-guard-check[3678349]: MEMORY EMERGENCY IO-PAUSE (trip #7374, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 999ms CPU time over 1min 21ms wall clock time, 10.7M memory peak, 10M read from disk, 25.8M written to disk.
Nov 06 03:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:21:09 evo-x2 memory-emergency-guard-check[3728122]: MEMORY EMERGENCY IO-PAUSE (trip #7375, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 3.909s wall clock time, 11.4M memory peak, 9.9M read from disk, 46.6M written to disk.
Nov 06 03:21:36 evo-x2 memory-emergency-guard-check[3760281]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.21% sustained (max disk busy 97.6%, MemAvailable=39.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 148ms CPU time over 188ms wall clock time, 9.7M memory peak, 1.8M read from disk, 4K written to disk.
Nov 06 03:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:23:46 evo-x2 memory-emergency-guard-check[3863450]: MEMORY EMERGENCY IO-PAUSE (trip #7376, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 877ms CPU time over 10.330s wall clock time, 10.6M memory peak, 18M read from disk, 49.5M written to disk.
Nov 06 03:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:26:15 evo-x2 memory-emergency-guard-check[3925302]: MEMORY EMERGENCY IO-PAUSE (trip #7377, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 8.600s wall clock time, 11.4M memory peak, 11M read from disk, 9M written to disk.
Nov 06 03:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:29:13 evo-x2 memory-emergency-guard-check[3982628]: MEMORY EMERGENCY IO-PAUSE (trip #7378, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 870ms CPU time over 35.419s wall clock time, 11.3M memory peak, 36.9M read from disk, 28.6M written to disk.
Nov 06 03:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:31:21 evo-x2 memory-emergency-guard-check[4081477]: MEMORY EMERGENCY IO-PAUSE (trip #7379, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 885ms CPU time over 8.223s wall clock time, 10.3M memory peak, 8.5M read from disk, 15.5M written to disk.
Nov 06 03:31:44 evo-x2 memory-emergency-guard-check[4118213]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.59% sustained (max disk busy 97.9%, MemAvailable=38.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:31:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 429ms wall clock time, 7.7M memory peak, 1.6M read from disk, 4K written to disk.
Nov 06 03:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 155ms wall clock time, 8.8M memory peak, 1.9M read from disk, 4K written to disk.
Nov 06 03:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:33:55 evo-x2 memory-emergency-guard-check[14233]: MEMORY EMERGENCY IO-PAUSE (trip #7380, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 942ms CPU time over 11.423s wall clock time, 10.9M memory peak, 12.4M read from disk, 18.6M written to disk.
Nov 06 03:34:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:36:17 evo-x2 memory-emergency-guard-check[137406]: MEMORY EMERGENCY IO-PAUSE (trip #7381, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.252s CPU time over 2.330s wall clock time, 9M memory peak, 6.4M read from disk, 44.4M written to disk.
Nov 06 03:36:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:38:48 evo-x2 memory-emergency-guard-check[232434]: MEMORY EMERGENCY IO-PAUSE (trip #7382, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 3.772s wall clock time, 9.2M memory peak, 17.8M read from disk, 45.4M written to disk.
Nov 06 03:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:41:18 evo-x2 memory-emergency-guard-check[328493]: MEMORY EMERGENCY IO-PAUSE (trip #7383, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 873ms CPU time over 3.639s wall clock time, 10.2M memory peak, 26.8M read from disk, 70M written to disk.
Nov 06 03:41:45 evo-x2 memory-emergency-guard-check[372542]: MEMORY EMERGENCY still active (I/O PSI some avg60=91.38% sustained (max disk busy 100.0%, MemAvailable=52.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:43:47 evo-x2 memory-emergency-guard-check[438305]: MEMORY EMERGENCY IO-PAUSE (trip #7384, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.097s CPU time over 3.069s wall clock time, 9.1M memory peak, 8.6M read from disk, 49.5M written to disk.
Nov 06 03:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 191ms CPU time over 298ms wall clock time, 7.7M memory peak, 1M read from disk, 4K written to disk.
Nov 06 03:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 250ms CPU time over 455ms wall clock time, 6.3M memory peak, 1.3M read from disk, 4K written to disk.
Nov 06 03:46:17 evo-x2 memory-emergency-guard-check[528795]: MEMORY EMERGENCY IO-PAUSE (trip #7385, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 823ms CPU time over 1.696s wall clock time, 9.5M memory peak, 7.7M read from disk, 29.8M written to disk.
Nov 06 03:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:48:48 evo-x2 memory-emergency-guard-check[630371]: MEMORY EMERGENCY IO-PAUSE (trip #7386, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 775ms CPU time over 2.482s wall clock time, 10.9M memory peak, 7.5M read from disk, 32.2M written to disk.
Nov 06 03:49:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:49:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:50:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:50:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:51:20 evo-x2 memory-emergency-guard-check[691638]: MEMORY EMERGENCY IO-PAUSE (trip #7387, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 4.497s wall clock time, 11.6M memory peak, 46.3M read from disk, 27.5M written to disk.
Nov 06 03:51:46 evo-x2 memory-emergency-guard-check[722228]: MEMORY EMERGENCY still active (I/O PSI some avg60=93.37% sustained (max disk busy 100.0%, MemAvailable=37.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 03:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:52:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:53:50 evo-x2 memory-emergency-guard-check[774869]: MEMORY EMERGENCY IO-PAUSE (trip #7388, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 818ms CPU time over 3.256s wall clock time, 10.4M memory peak, 7.2M read from disk, 47.4M written to disk.
Nov 06 03:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:54:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:56:19 evo-x2 memory-emergency-guard-check[914785]: MEMORY EMERGENCY IO-PAUSE (trip #7389, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.233s CPU time over 2.567s wall clock time, 10M memory peak, 3.6M read from disk, 33.5M written to disk.
Nov 06 03:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 157ms CPU time over 193ms wall clock time, 8.3M memory peak, 1.8M read from disk, 4K written to disk.
Nov 06 03:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:58:54 evo-x2 memory-emergency-guard-check[1106545]: MEMORY EMERGENCY IO-PAUSE (trip #7390, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 03:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.252s CPU time over 7.169s wall clock time, 8.7M memory peak, 7M read from disk, 57.5M written to disk.
Nov 06 03:59:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 03:59:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:00:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:00:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:01:22 evo-x2 memory-emergency-guard-check[1276678]: MEMORY EMERGENCY IO-PAUSE (trip #7391, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.078s CPU time over 5.152s wall clock time, 11.4M memory peak, 10M read from disk, 74.3M written to disk.
Nov 06 04:01:47 evo-x2 memory-emergency-guard-check[1309319]: MEMORY EMERGENCY still active (I/O PSI some avg60=90.43% sustained (max disk busy 100.0%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:01:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:02:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:02:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:03:53 evo-x2 memory-emergency-guard-check[1440946]: MEMORY EMERGENCY IO-PAUSE (trip #7392, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.097s CPU time over 6.319s wall clock time, 10.8M memory peak, 14.5M read from disk, 9.8M written to disk.
Nov 06 04:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:04:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:05:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:05:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:06:22 evo-x2 memory-emergency-guard-check[1617105]: MEMORY EMERGENCY IO-PAUSE (trip #7393, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.115s CPU time over 4.227s wall clock time, 10.1M memory peak, 4.2M read from disk, 74.1M written to disk.
Nov 06 04:06:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:07:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:07:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:08:49 evo-x2 memory-emergency-guard-check[1753983]: MEMORY EMERGENCY IO-PAUSE (trip #7394, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 2.030s wall clock time, 10.2M memory peak, 2.4M read from disk, 42.1M written to disk.
Nov 06 04:09:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:09:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 133ms CPU time over 244ms wall clock time, 7.6M memory peak, 1.2M read from disk, 4K written to disk.
Nov 06 04:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 124ms CPU time over 180ms wall clock time, 8.1M memory peak, 1M read from disk, 4K written to disk.
Nov 06 04:11:39 evo-x2 memory-emergency-guard-check[1819918]: MEMORY EMERGENCY IO-PAUSE (trip #7395, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 21.482s wall clock time, 11.3M memory peak, 18.6M read from disk, 8.3M written to disk.
Nov 06 04:11:48 evo-x2 memory-emergency-guard-check[1837522]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.28% sustained (max disk busy 100.0%, MemAvailable=40.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 184ms CPU time over 370ms wall clock time, 7.5M memory peak, 1.1M read from disk, 4K written to disk.
Nov 06 04:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:13:56 evo-x2 memory-emergency-guard-check[1878527]: MEMORY EMERGENCY IO-PAUSE (trip #7396, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 998ms CPU time over 8.185s wall clock time, 9.7M memory peak, 23.3M read from disk, 13.8M written to disk.
Nov 06 04:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 246ms CPU time over 484ms wall clock time, 4.9M memory peak, 1.6M read from disk, 4K written to disk.
Nov 06 04:16:39 evo-x2 memory-emergency-guard-check[1957758]: MEMORY EMERGENCY IO-PAUSE (trip #7397, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.154s CPU time over 19.993s wall clock time, 8.7M memory peak, 16M read from disk, 27.9M written to disk.
Nov 06 04:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 183ms CPU time over 342ms wall clock time, 11.5M memory peak, 5.9M read from disk, 4K written to disk.
Nov 06 04:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:19:15 evo-x2 memory-emergency-guard-check[2084212]: MEMORY EMERGENCY IO-PAUSE (trip #7398, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.114s CPU time over 26.391s wall clock time, 10.8M memory peak, 31.7M read from disk, 68K written to disk.
Nov 06 04:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:20:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:22:11 evo-x2 memory-emergency-guard-check[2211596]: MEMORY EMERGENCY IO-PAUSE (trip #7399, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.281s CPU time over 52.556s wall clock time, 8.8M memory peak, 25.4M read from disk, 24.4M written to disk.
Nov 06 04:22:12 evo-x2 memory-emergency-guard-check[2251023]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.16% sustained (max disk busy 97.9%, MemAvailable=40.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (53s < 150s, 97s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 168ms CPU time over 631ms wall clock time, 7M memory peak, 4M read from disk, 4K written to disk.
Nov 06 04:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:24:31 evo-x2 memory-emergency-guard-check[2336779]: MEMORY EMERGENCY IO-PAUSE (trip #7400, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.107s CPU time over 23.837s wall clock time, 8.9M memory peak, 5.1M read from disk, 17.8M written to disk.
Nov 06 04:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:27:13 evo-x2 memory-emergency-guard-check[2418127]: MEMORY EMERGENCY IO-PAUSE (trip #7401, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.079s CPU time over 35.887s wall clock time, 8.4M memory peak, 4.2M read from disk, 33.6M written to disk.
Nov 06 04:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:29:18 evo-x2 memory-emergency-guard-check[2501600]: MEMORY EMERGENCY IO-PAUSE (trip #7402, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.531s CPU time over 4.673s wall clock time, 8.7M memory peak, 7.9M read from disk, 72.1M written to disk.
Nov 06 04:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:31:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:31:47 evo-x2 memory-emergency-guard-check[2607473]: MEMORY EMERGENCY IO-PAUSE (trip #7403, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 789ms CPU time over 2.472s wall clock time, 10.5M memory peak, 31.8M read from disk, 64.7M written to disk.
Nov 06 04:32:14 evo-x2 memory-emergency-guard-check[2627320]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.13% sustained (max disk busy 100.0%, MemAvailable=60.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:34:18 evo-x2 memory-emergency-guard-check[2732435]: MEMORY EMERGENCY IO-PAUSE (trip #7404, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 3.493s wall clock time, 11.3M memory peak, 5.8M read from disk, 42.9M written to disk.
Nov 06 04:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:36:49 evo-x2 memory-emergency-guard-check[2798019]: MEMORY EMERGENCY IO-PAUSE (trip #7405, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 981ms CPU time over 3.063s wall clock time, 11.4M memory peak, 4.5M read from disk, 38.4M written to disk.
Nov 06 04:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:37:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:38:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:39:20 evo-x2 memory-emergency-guard-check[2943850]: MEMORY EMERGENCY IO-PAUSE (trip #7406, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 802ms CPU time over 3.559s wall clock time, 11.1M memory peak, 6.3M read from disk, 41.9M written to disk.
Nov 06 04:39:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:40:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:40:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:41:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:41:49 evo-x2 memory-emergency-guard-check[3054329]: MEMORY EMERGENCY IO-PAUSE (trip #7407, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 791ms CPU time over 2.164s wall clock time, 10.2M memory peak, 5.8M read from disk, 5M written to disk.
Nov 06 04:42:17 evo-x2 memory-emergency-guard-check[3110756]: MEMORY EMERGENCY still active (I/O PSI some avg60=97.29% sustained (max disk busy 99.9%, MemAvailable=57.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:44:19 evo-x2 memory-emergency-guard-check[3243562]: MEMORY EMERGENCY IO-PAUSE (trip #7408, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 824ms CPU time over 2.194s wall clock time, 16.8M memory peak, 6.3M read from disk, 14.2M written to disk.
Nov 06 04:44:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 161ms CPU time over 466ms wall clock time, 7.5M memory peak, 1.6M read from disk, 4K written to disk.
Nov 06 04:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 299ms CPU time over 857ms wall clock time, 14.3M memory peak, 7.8M read from disk, 4K written to disk.
Nov 06 04:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:47:23 evo-x2 memory-emergency-guard-check[3379228]: MEMORY EMERGENCY IO-PAUSE (trip #7409, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.310s CPU time over 27.537s wall clock time, 8.9M memory peak, 49M read from disk, 2.6M written to disk.
Nov 06 04:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:49:32 evo-x2 memory-emergency-guard-check[3577965]: MEMORY EMERGENCY IO-PAUSE (trip #7410, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.292s CPU time over 6.316s wall clock time, 9.2M memory peak, 3.5M read from disk, 29.2M written to disk.
Nov 06 04:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:51:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:52:02 evo-x2 memory-emergency-guard-check[3699799]: MEMORY EMERGENCY IO-PAUSE (trip #7411, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 922ms CPU time over 5.844s wall clock time, 10.6M memory peak, 11.3M read from disk, 51.8M written to disk.
Nov 06 04:52:27 evo-x2 memory-emergency-guard-check[3718174]: MEMORY EMERGENCY still active (I/O PSI some avg60=87.38% sustained (max disk busy 100.0%, MemAvailable=50.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 04:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:54:30 evo-x2 memory-emergency-guard-check[3763827]: MEMORY EMERGENCY IO-PAUSE (trip #7412, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 903ms CPU time over 3.315s wall clock time, 10.1M memory peak, 5.1M read from disk, 46.2M written to disk.
Nov 06 04:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:57:08 evo-x2 memory-emergency-guard-check[3844848]: MEMORY EMERGENCY IO-PAUSE (trip #7413, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 954ms CPU time over 11.382s wall clock time, 9.2M memory peak, 20.4M read from disk, 5.8M written to disk.
Nov 06 04:57:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:58:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:59:39 evo-x2 memory-emergency-guard-check[3930968]: MEMORY EMERGENCY IO-PAUSE (trip #7414, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 04:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 04:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 903ms CPU time over 11.379s wall clock time, 9.7M memory peak, 20.8M read from disk, 8.3M written to disk.
Nov 06 04:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:02:08 evo-x2 memory-emergency-guard-check[4006282]: MEMORY EMERGENCY IO-PAUSE (trip #7415, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.004s CPU time over 10.895s wall clock time, 8.8M memory peak, 9M read from disk, 19.5M written to disk.
Nov 06 05:02:28 evo-x2 memory-emergency-guard-check[4039092]: MEMORY EMERGENCY still active (I/O PSI some avg60=90.02% sustained (max disk busy 97.1%, MemAvailable=38.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:04:39 evo-x2 memory-emergency-guard-check[4125096]: MEMORY EMERGENCY IO-PAUSE (trip #7416, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.046s CPU time over 11.502s wall clock time, 10.8M memory peak, 21.7M read from disk, 9.4M written to disk.
Nov 06 05:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:07:11 evo-x2 memory-emergency-guard-check[4180047]: MEMORY EMERGENCY IO-PAUSE (trip #7417, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 746ms CPU time over 12.699s wall clock time, 11.4M memory peak, 8.3M read from disk, 2.4M written to disk.
Nov 06 05:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:08:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:09:38 evo-x2 memory-emergency-guard-check[46871]: MEMORY EMERGENCY IO-PAUSE (trip #7418, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 10.015s wall clock time, 11.2M memory peak, 13.5M read from disk, 29.2M written to disk.
Nov 06 05:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:12:16 evo-x2 memory-emergency-guard-check[124090]: MEMORY EMERGENCY IO-PAUSE (trip #7419, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 17.805s wall clock time, 11M memory peak, 14.2M read from disk, 11.6M written to disk.
Nov 06 05:12:29 evo-x2 memory-emergency-guard-check[141882]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.32% sustained (max disk busy 100.0%, MemAvailable=35.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:14:36 evo-x2 memory-emergency-guard-check[206507]: MEMORY EMERGENCY IO-PAUSE (trip #7420, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 713ms CPU time over 7.407s wall clock time, 9.7M memory peak, 7.3M read from disk, 7.9M written to disk.
Nov 06 05:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:18:14 evo-x2 memory-emergency-guard-check[294721]: MEMORY EMERGENCY IO-PAUSE (trip #7421, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 898ms CPU time over 1min 14.563s wall clock time, 11.5M memory peak, 29.8M read from disk, 21.6M written to disk.
Nov 06 05:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:20:15 evo-x2 memory-emergency-guard-check[422896]: MEMORY EMERGENCY IO-PAUSE (trip #7422, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:20:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:20:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.226s CPU time over 31.352s wall clock time, 8.5M memory peak, 29.6M read from disk, 62.7M written to disk.
Nov 06 05:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:22:22 evo-x2 memory-emergency-guard-check[554374]: MEMORY EMERGENCY IO-PAUSE (trip #7423, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.309s CPU time over 6.909s wall clock time, 7.7M memory peak, 12.7M read from disk, 99.7M written to disk.
Nov 06 05:22:46 evo-x2 memory-emergency-guard-check[582277]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.15% sustained (max disk busy 90.3%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:24:52 evo-x2 memory-emergency-guard-check[715719]: MEMORY EMERGENCY IO-PAUSE (trip #7424, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.235s CPU time over 5.413s wall clock time, 10.1M memory peak, 17.6M read from disk, 72.3M written to disk.
Nov 06 05:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 179ms wall clock time, 9.9M memory peak, 5.5M read from disk, 4K written to disk.
Nov 06 05:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:27:22 evo-x2 memory-emergency-guard-check[814861]: MEMORY EMERGENCY IO-PAUSE (trip #7425, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.020s CPU time over 5.483s wall clock time, 11.4M memory peak, 49.3M read from disk, 70M written to disk.
Nov 06 05:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:29:48 evo-x2 memory-emergency-guard-check[878900]: MEMORY EMERGENCY IO-PAUSE (trip #7426, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.201s CPU time over 1.722s wall clock time, 9.8M memory peak, 12M read from disk, 50.7M written to disk.
Nov 06 05:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:32:18 evo-x2 memory-emergency-guard-check[957476]: MEMORY EMERGENCY IO-PAUSE (trip #7427, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 777ms CPU time over 1.291s wall clock time, 11.1M memory peak, 12.9M read from disk, 54.9M written to disk.
Nov 06 05:32:48 evo-x2 memory-emergency-guard-check[1011645]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.58% sustained (max disk busy 100.0%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:34:50 evo-x2 memory-emergency-guard-check[1115205]: MEMORY EMERGENCY IO-PAUSE (trip #7428, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 769ms CPU time over 2.849s wall clock time, 10.9M memory peak, 8.3M read from disk, 56.9M written to disk.
Nov 06 05:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:37:21 evo-x2 memory-emergency-guard-check[1300384]: MEMORY EMERGENCY IO-PAUSE (trip #7429, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.050s CPU time over 3.459s wall clock time, 11.1M memory peak, 16.3M read from disk, 67.1M written to disk.
Nov 06 05:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 371ms wall clock time, 13.2M memory peak, 4.6M read from disk, 4K written to disk.
Nov 06 05:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:40:08 evo-x2 memory-emergency-guard-check[1395125]: MEMORY EMERGENCY IO-PAUSE (trip #7430, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 816ms CPU time over 19.542s wall clock time, 10.6M memory peak, 30M read from disk, 47.5M written to disk.
Nov 06 05:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:42:23 evo-x2 memory-emergency-guard-check[1452588]: MEMORY EMERGENCY IO-PAUSE (trip #7431, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 978ms CPU time over 4.964s wall clock time, 8.9M memory peak, 3.1M read from disk, 8.3M written to disk.
Nov 06 05:42:49 evo-x2 memory-emergency-guard-check[1468147]: MEMORY EMERGENCY still active (I/O PSI some avg60=93.31% sustained (max disk busy 100.0%, MemAvailable=30.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (29s < 150s, 121s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 140ms CPU time over 574ms wall clock time, 8M memory peak, 2.1M read from disk, 4K written to disk.
Nov 06 05:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:46:07 evo-x2 memory-emergency-guard-check[1515276]: MEMORY EMERGENCY IO-PAUSE (trip #7432, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 814ms CPU time over 1min 18.297s wall clock time, 11.4M memory peak, 24.3M read from disk, 8.2M written to disk.
Nov 06 05:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 185ms wall clock time, 10.9M memory peak, 2.8M read from disk, 4K written to disk.
Nov 06 05:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:47:40 evo-x2 memory-emergency-guard-check[1566300]: MEMORY EMERGENCY IO-PAUSE (trip #7433, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 822ms CPU time over 2.647s wall clock time, 10.4M memory peak, 10.9M read from disk, 27.6M written to disk.
Nov 06 05:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:50:10 evo-x2 memory-emergency-guard-check[1622774]: MEMORY EMERGENCY IO-PAUSE (trip #7434, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.328s CPU time over 2.438s wall clock time, 10.5M memory peak, 12.1M read from disk, 44.4M written to disk.
Nov 06 05:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:51:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:52:39 evo-x2 memory-emergency-guard-check[1682124]: MEMORY EMERGENCY IO-PAUSE (trip #7435, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.022s CPU time over 1.829s wall clock time, 10.4M memory peak, 11.9M read from disk, 54.9M written to disk.
Nov 06 05:53:08 evo-x2 memory-emergency-guard-check[1722434]: MEMORY EMERGENCY still active (I/O PSI some avg60=96.32% sustained (max disk busy 100.0%, MemAvailable=46.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 06 05:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:54:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:55:11 evo-x2 memory-emergency-guard-check[1845735]: MEMORY EMERGENCY IO-PAUSE (trip #7436, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 06 05:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.240s CPU time over 3.455s wall clock time, 8.7M memory peak, 2.9M read from disk, 44.1M written to disk.
Nov 06 05:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 06 05:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 05 20:44:02 evo-x2 thermal-pstate-guard-check[115332]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Nov 05 23:35:35 evo-x2 thermal-pstate-guard-check[2239187]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Nov 05 23:46:43 evo-x2 thermal-pstate-guard-check[2528629]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 05 20:39:20 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 20:39:20 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/pcfbrxjab3ksl30iq535m3817rymx9jp-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 20:39:20 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 05 20:39:22 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793940981000000000 -> 1793941132000000000 epoch-ns UTC (2026-11-06 04:56:21 -> 2026-11-06 04:58:52 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
