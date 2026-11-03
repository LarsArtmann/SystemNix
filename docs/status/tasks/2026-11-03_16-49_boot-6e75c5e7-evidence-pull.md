# Boot evidence pull: id8 6e75c5e7 (full: 6e75c5e765d44a20ae4e876b82551cfc)

Pulled 2026-11-03 16:50 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-03 16:18:05 -> 2026-11-03 17:39:40 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 6e75c5e7 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 03 16:18:05 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 03 16:18:05 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/dnc9swbbkqi2gkpmfah7y7yshksy78xi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 16:18:05 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 03 17:38:37 evo-x2 node_exporter[2008]: time=2026-11-03T17:38:33.746+01:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9400->127.0.0.1:55588: write: broken pipe"
Nov 03 17:38:37 evo-x2 node_exporter[2008]: time=2026-11-03T17:38:33.746+01:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9400->127.0.0.1:55588: write: broken pipe"
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:33.137425Z [info     ] Running job "Poll CrowdSec decision stream (trigger: interval[0:00:15], next run at: 2026-11-03 17:38:48 CET)" (scheduled at 2026-11-03 17:38:33.136510+01:00) [apscheduler.executors.default]
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:33.375544Z [info     ] HTTP Request: GET http://127.0.0.1:8082/v1/decisions/stream "HTTP/1.1 200 OK" [httpx2]
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:33.491870Z [info     ] Job "Poll CrowdSec decision stream (trigger: interval[0:00:15], next run at: 2026-11-03 17:38:48 CET)" executed successfully [apscheduler.executors.default]
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:33.492116Z [success  ] scheduler_job_completed        [geometrikks.server.scheduler_tracking] duration_seconds=0.355421 job_id=crowdsec-stream-poll
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:44.028498Z [info     ] HTTP Request                   [litestar] method=GET path=/ path_params={} query={}
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:44.029425Z [info     ] HTTP Response                  [litestar] status_code=200
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:48.137796Z [info     ] Running job "Poll CrowdSec decision stream (trigger: interval[0:00:15], next run at: 2026-11-03 17:39:03 CET)" (scheduled at 2026-11-03 17:38:48.136510+01:00) [apscheduler.executors.default]
Nov 03 17:38:55 evo-x2 geometrikks-server[27387]: 2026-11-03T16:38:48.213342Z [info     ] HTTP Request: GET http://127.0.0.1:8082/v1/decisions/stream "HTTP/1.1 200 OK" [httpx2]
Nov 03 17:39:40 evo-x2 browser-history-server[33812]: {"time":"2026-11-03T17:38:32.714519019+01:00","level":"INFO","msg":"http request","method":"GET","path":"/metrics","status":200,"duration":2200847,"request_id":"01M6H4DMG8KPBNDV5A60008E2A"}
Nov 03 17:39:40 evo-x2 browser-history-server[33812]: {"time":"2026-11-03T17:38:44.055105064+01:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":26747808,"request_id":"01M6H4DZHW3C1J77JDA8008E2B"}
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 208
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
Nov 03 16:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:20:58 evo-x2 memory-emergency-guard-check[35398]: MEMORY EMERGENCY IO-PAUSE (trip #6166, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 511ms CPU time over 25.342s wall clock time, 10.4M memory peak, 592K read from disk, 13.5M written to disk.
Nov 03 16:21:03 evo-x2 memory-emergency-guard-check[47942]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.58% sustained (max disk busy 100.0%, MemAvailable=48.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 16:21:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:24:27 evo-x2 memory-emergency-guard-check[144233]: MEMORY EMERGENCY IO-PAUSE (trip #6167, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.381s CPU time over 1min 23.781s wall clock time, 8.3M memory peak, 56.8M read from disk, 49.2M written to disk.
Nov 03 16:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:24:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:27:35 evo-x2 memory-emergency-guard-check[286782]: MEMORY EMERGENCY IO-PAUSE (trip #6168, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.234s CPU time over 1min 38.095s wall clock time, 9.7M memory peak, 16.8M read from disk, 46.6M written to disk.
Nov 03 16:27:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:28:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:31:13 evo-x2 memory-emergency-guard-check[367621]: MEMORY EMERGENCY IO-PAUSE (trip #6169, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 769ms CPU time over 2min 38.414s wall clock time, 10.9M memory peak, 26.3M read from disk, 32.3M written to disk.
Nov 03 16:31:16 evo-x2 memory-emergency-guard-check[480213]: MEMORY EMERGENCY IO-PAUSE (trip #6170, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 3.052s wall clock time, 8.7M memory peak, 116K read from disk, 2.4M written to disk.
Nov 03 16:31:43 evo-x2 memory-emergency-guard-check[495624]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.31% sustained (max disk busy 99.7%, MemAvailable=44.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 16:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:32:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:34:51 evo-x2 memory-emergency-guard-check[601238]: MEMORY EMERGENCY IO-PAUSE (trip #6171, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 867ms CPU time over 1min 7.671s wall clock time, 8.6M memory peak, 16.4M read from disk, 27.8M written to disk.
Nov 03 16:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:37:18 evo-x2 memory-emergency-guard-check[743357]: MEMORY EMERGENCY IO-PAUSE (trip #6172, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 969ms CPU time over 57.045s wall clock time, 7.1M memory peak, 12.3M read from disk, 66M written to disk.
Nov 03 16:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:39:46 evo-x2 memory-emergency-guard-check[883021]: MEMORY EMERGENCY IO-PAUSE (trip #6173, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.003s CPU time over 28.045s wall clock time, 9.2M memory peak, 17M read from disk, 32.6M written to disk.
Nov 03 16:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:41:52 evo-x2 memory-emergency-guard-check[1013412]: MEMORY EMERGENCY IO-PAUSE (trip #6174, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 981ms CPU time over 3.488s wall clock time, 7.1M memory peak, 11.1M read from disk, 51.8M written to disk.
Nov 03 16:42:19 evo-x2 memory-emergency-guard-check[1032214]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.11% sustained (max disk busy 95.4%, MemAvailable=27.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 16:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:44:22 evo-x2 memory-emergency-guard-check[1110878]: MEMORY EMERGENCY IO-PAUSE (trip #6175, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 852ms CPU time over 3.510s wall clock time, 7.4M memory peak, 21.4M read from disk, 17.5M written to disk.
Nov 03 16:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:45:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:48:14 evo-x2 memory-emergency-guard-check[1240050]: MEMORY EMERGENCY IO-PAUSE (trip #6176, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.083s CPU time over 1min 26.340s wall clock time, 9.8M memory peak, 7.3M read from disk, 28.8M written to disk.
Nov 03 16:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:48:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:49:55 evo-x2 memory-emergency-guard-check[1392908]: MEMORY EMERGENCY IO-PAUSE (trip #6177, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 984ms CPU time over 10.018s wall clock time, 8.2M memory peak, 16.8M read from disk, 50.8M written to disk.
Nov 03 16:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:52:35 evo-x2 memory-emergency-guard-check[1527085]: MEMORY EMERGENCY IO-PAUSE (trip #6178, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 970ms CPU time over 20.459s wall clock time, 9.5M memory peak, 14.2M read from disk, 7.9M written to disk.
Nov 03 16:52:45 evo-x2 memory-emergency-guard-check[1565608]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.47% sustained (max disk busy 100.0%, MemAvailable=27.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 16:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 160ms CPU time over 456ms wall clock time, 11.2M memory peak, 3.9M read from disk, 4K written to disk.
Nov 03 16:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:55:45 evo-x2 memory-emergency-guard-check[1640321]: MEMORY EMERGENCY IO-PAUSE (trip #6179, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 849ms CPU time over 1min 418ms wall clock time, 13.8M memory peak, 24.7M read from disk, 8.9M written to disk.
Nov 03 16:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:56:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:58:57 evo-x2 memory-emergency-guard-check[1729870]: MEMORY EMERGENCY IO-PAUSE (trip #6180, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 16:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 1min 42.209s wall clock time, 11.2M memory peak, 4K memory swap peak, 6.5M read from disk, 3.9M written to disk.
Nov 03 16:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 16:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 337ms wall clock time, 16.1M memory peak, 7M read from disk, 4K written to disk.
Nov 03 16:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:02:23 evo-x2 memory-emergency-guard-check[1798454]: MEMORY EMERGENCY IO-PAUSE (trip #6181, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.286s CPU time over 2min 25.838s wall clock time, 8.6M memory peak, 26.9M read from disk, 14M written to disk.
Nov 03 17:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:03:05 evo-x2 memory-emergency-guard-check[1984531]: MEMORY EMERGENCY IO-PAUSE (trip #6182, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 843ms CPU time over 11.655s wall clock time, 9.7M memory peak, 1.2M read from disk, 27.6M written to disk.
Nov 03 17:03:23 evo-x2 memory-emergency-guard-check[2026925]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.20% sustained (max disk busy 100.0%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (29s < 150s, 121s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 17:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:04:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:06:03 evo-x2 memory-emergency-guard-check[2199946]: MEMORY EMERGENCY IO-PAUSE (trip #6183, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.213s CPU time over 9.632s wall clock time, 8.4M memory peak, 17.1M read from disk, 51.7M written to disk.
Nov 03 17:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:08:39 evo-x2 memory-emergency-guard-check[2337944]: MEMORY EMERGENCY IO-PAUSE (trip #6184, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 957ms CPU time over 15.404s wall clock time, 10.7M memory peak, 16.8M read from disk, 47.8M written to disk.
Nov 03 17:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:11:16 evo-x2 memory-emergency-guard-check[2452339]: MEMORY EMERGENCY IO-PAUSE (trip #6185, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.092s CPU time over 22.356s wall clock time, 7.7M memory peak, 21.1M read from disk, 9.9M written to disk.
Nov 03 17:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:14:41 evo-x2 memory-emergency-guard-check[2668357]: MEMORY EMERGENCY IO-PAUSE (trip #6186, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.147s CPU time over 1min 18.021s wall clock time, 9.3M memory peak, 53.2M read from disk, 4.9M written to disk.
Nov 03 17:14:42 evo-x2 memory-emergency-guard-check[2796521]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.83% sustained (max disk busy 100.0%, MemAvailable=25.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (78s < 150s, 72s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 17:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 186ms CPU time over 356ms wall clock time, 5.5M memory peak, 1.3M read from disk, 4K written to disk.
Nov 03 17:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:16:17 evo-x2 memory-emergency-guard-check[2883106]: MEMORY EMERGENCY IO-PAUSE (trip #6187, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 884ms CPU time over 5.225s wall clock time, 8.3M memory peak, 28.4M read from disk, 49.6M written to disk.
Nov 03 17:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 163ms CPU time over 521ms wall clock time, 10.2M memory peak, 4.2M read from disk, 4K written to disk.
Nov 03 17:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:18:46 evo-x2 memory-emergency-guard-check[3047692]: MEMORY EMERGENCY IO-PAUSE (trip #6188, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 948ms CPU time over 4.757s wall clock time, 7.5M memory peak, 9.7M read from disk, 64.7M written to disk.
Nov 03 17:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 161ms CPU time over 277ms wall clock time, 10.2M memory peak, 3.9M read from disk, 4K written to disk.
Nov 03 17:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:22:05 evo-x2 memory-emergency-guard-check[3283958]: sort: write failed: 'standard output': Broken pipe
Nov 03 17:22:05 evo-x2 memory-emergency-guard-check[3283958]: sort: write error
Nov 03 17:22:06 evo-x2 memory-emergency-guard-check[3232852]: MEMORY EMERGENCY IO-PAUSE (trip #6189, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.093s CPU time over 53.939s wall clock time, 9.7M memory peak, 6.9M read from disk, 34.2M written to disk.
Nov 03 17:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:23:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:24:26 evo-x2 memory-emergency-guard-check[3369421]: MEMORY EMERGENCY IO-PAUSE (trip #6190, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 943ms CPU time over 20.059s wall clock time, 9.1M memory peak, 24.4M read from disk, 16.7M written to disk.
Nov 03 17:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:25:06 evo-x2 memory-emergency-guard-check[3440905]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.44% sustained (max disk busy 99.5%, MemAvailable=43.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 17:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:26:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:27:25 evo-x2 memory-emergency-guard-check[3602914]: MEMORY EMERGENCY IO-PAUSE (trip #6191, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.074s CPU time over 49.479s wall clock time, 12.9M memory peak, 10.8M read from disk, 39.3M written to disk.
Nov 03 17:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:30:24 evo-x2 memory-emergency-guard-check[4132772]: sort: write failed: 'standard output': Broken pipe
Nov 03 17:30:24 evo-x2 memory-emergency-guard-check[4132772]: sort: write error
Nov 03 17:30:24 evo-x2 memory-emergency-guard-check[3995140]: MEMORY EMERGENCY IO-PAUSE (trip #6192, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.111s CPU time over 58.769s wall clock time, 15.4M memory peak, 15.1M read from disk, 18.5M written to disk.
Nov 03 17:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:33:00 evo-x2 memory-emergency-guard-check[145316]: MEMORY EMERGENCY IO-PAUSE (trip #6193, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.123s CPU time over 36.396s wall clock time, 13.9M memory peak, 39.7M read from disk, 10.4M written to disk.
Nov 03 17:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:34:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:35:12 evo-x2 memory-emergency-guard-check[468152]: sort: write failed: 'standard output': Broken pipe
Nov 03 17:35:12 evo-x2 memory-emergency-guard-check[468152]: sort: write error
Nov 03 17:35:13 evo-x2 memory-emergency-guard-check[440798]: MEMORY EMERGENCY IO-PAUSE (trip #6194, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 03 17:35:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:35:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.073s CPU time over 12.095s wall clock time, 8.1M memory peak, 15.5M read from disk, 6.2M written to disk.
Nov 03 17:35:31 evo-x2 memory-emergency-guard-check[489542]: MEMORY EMERGENCY still active (I/O PSI some avg60=90.33% sustained (max disk busy 100.0%, MemAvailable=17.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 03 17:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 03 17:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 03 16:20:23 evo-x2 thermal-pstate-guard-check[34280]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 03 16:18:05 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/dnc9swbbkqi2gkpmfah7y7yshksy78xi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 16:18:05 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/dnc9swbbkqi2gkpmfah7y7yshksy78xi-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 03 16:18:05 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 03 16:18:07 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793723980000000000 -> 1793724088000000000 epoch-ns UTC (2026-11-03 16:39:40 -> 2026-11-03 16:41:28 UTC)
Pipeline ALIVE in this window — newest row: 1793723985576432626 (2026-11-03 16:39:45 UTC); rows fetched: 20 (last 20 by timestamp DESC). Per M22 pull BOTH sources: ClickHouse is fresher than the journal cut by the flush lag.

Last rows (timestamp<TAB>body, newest first):
```
1793723985576432626	dispatch error
1793723984211720614	local zone miss, returning NXDOMAIN
1793723984207765134	local zone miss, returning NXDOMAIN
1793723984200711616	local zone miss, returning NXDOMAIN
1793723984197121253	local zone miss, returning NXDOMAIN
1793723984183776681	local zone miss, returning NXDOMAIN
1793723984176384633	local zone miss, returning NXDOMAIN
1793723984164570151	local zone miss, returning NXDOMAIN
1793723984161717894	local zone miss, returning NXDOMAIN
1793723984161093395	local zone miss, returning NXDOMAIN
1793723984152082460	local zone miss, returning NXDOMAIN
1793723984151869247	local zone miss, returning NXDOMAIN
1793723984130336193	local zone miss, returning NXDOMAIN
1793723984122109893	local zone miss, returning NXDOMAIN
1793723984093644337	local zone miss, returning NXDOMAIN
1793723984093610488	local zone miss, returning NXDOMAIN
1793723984085256532	local zone miss, returning NXDOMAIN
1793723984073293444	local zone miss, returning NXDOMAIN
1793723984072494070	local zone miss, returning NXDOMAIN
1793723984062717701	local zone miss, returning NXDOMAIN
```
