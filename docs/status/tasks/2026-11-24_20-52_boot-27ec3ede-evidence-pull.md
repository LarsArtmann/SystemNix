# Boot evidence pull: id8 27ec3ede (full: 27ec3ede94a54e0c847f1e49840b5047)

Pulled 2026-11-24 20:52 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-23 21:13:15 -> 2026-11-24 20:44:18 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 27ec3ede — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 23 21:13:15 evo-x2 kernel: Linux version 7.3.5 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1794910461
Nov 23 21:13:15 evo-x2 kernel: Command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/19sgcfq2kypdgarvpasdjx6jhzb68ihc-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 23 21:13:15 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 24 20:44:17 evo-x2 file-renamer[2095]: 2026-11-24T20:44:17+01:00 INFO  watcher: request method=GET path=/health status=200 duration=175.044µs client_ip=127.0.0.1 request_id=6b05e9110000d08740e198930b06e342
Nov 24 20:44:17 evo-x2 systemd[2047]: Detect niri DRM zombie state and restart niri skipped, unmet condition check ConditionEnvironment=XDG_SESSION_ID
Nov 24 20:44:17 evo-x2 systemd[5888]: Detect niri DRM zombie state and restart niri skipped, unmet condition check ConditionEnvironment=XDG_SESSION_ID
Nov 24 20:44:17 evo-x2 crm-server[47541]: time=2026-11-24T20:44:17.348+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=517µs
Nov 24 20:44:17 evo-x2 crm-server[47541]: time=2026-11-24T20:44:17.348+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=575µs
Nov 24 20:44:17 evo-x2 inboxclean[2570]: 2026/11/24 20:44:17 INFO account reconnected account=main
Nov 24 20:44:17 evo-x2 inboxclean[2570]: 2026/11/24 20:44:17 INFO request method=GET path=/sync/status status=200 duration=298.152211ms client_ip=192.168.1.46 request_id=6b05e911000021fd98727c40df5485dd
Nov 24 20:44:18 evo-x2 crm-server[47541]: time=2026-11-24T20:44:18.348+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=335µs
Nov 24 20:44:18 evo-x2 crm-server[47541]: time=2026-11-24T20:44:18.349+01:00 level=INFO msg=request method=GET path=/api/contacts/by-phone status=200 duration=532µs
Nov 24 20:44:18 evo-x2 signoz-wrapper[109868]: {"timestamp":"2026-11-24T20:44:18.4061722+01:00","level":"INFO","msg":"promql rule task","name":"01a00809-95cb-72e6-a3d2-fb2147c285c5-groupname","eval_started_at":"2026-11-24T19:44:18.404971301Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Nov 24 20:44:18 evo-x2 signoz-wrapper[109868]: {"timestamp":"2026-11-24T20:44:18.406277587+01:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-95cb-72e6-a3d2-fb2147c285c5","rule.query":"node_nvme_temperature_celsius","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":99}
Nov 24 20:44:18 evo-x2 signoz-wrapper[109868]: {"timestamp":"2026-11-24T20:44:18.426423294+01:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-95cb-72e6-a3d2-fb2147c285c5","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":242}
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 3766
- thermal-THROTTLE-lines: 29
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
```
```

## memory-emergency-guard lines (all)
```
Nov 23 21:13:29 evo-x2 post-crash-calm-gate[1771]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:16:08 evo-x2 memory-emergency-guard-check[30802]: MEMORY EMERGENCY IO-PAUSE (trip #12710, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 534ms CPU time over 55.796s wall clock time, 11.8M memory peak, 10.9M read from disk, 59.2M written to disk.
Nov 23 21:16:09 evo-x2 memory-emergency-guard-check[54379]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.04% sustained (max disk busy 99.6%, MemAvailable=84.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (56s < 150s, 94s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 21:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:17:02 evo-x2 post-crash-calm-gate[89771]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:21:23 evo-x2 memory-emergency-guard-check[116775]: MEMORY EMERGENCY IO-PAUSE (trip #12711, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 509ms CPU time over 3min 13.980s wall clock time, 10.5M memory peak, 448K read from disk, 15.2M written to disk.
Nov 23 21:21:25 evo-x2 memory-emergency-guard-check[143377]: MEMORY EMERGENCY IO-PAUSE (trip #12712, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 388ms CPU time over 1.504s wall clock time, 12.3M memory peak, 2.9M written to disk.
Nov 23 21:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:23:13 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4783 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 23 21:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:24:02 evo-x2 memory-emergency-guard-check[178316]: MEMORY EMERGENCY IO-PAUSE (trip #12713, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 483ms CPU time over 6.244s wall clock time, 12.2M memory peak, 672K read from disk, 24.1M written to disk.
Nov 23 21:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:26:33 evo-x2 memory-emergency-guard-check[215266]: MEMORY EMERGENCY IO-PAUSE (trip #12714, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 460ms CPU time over 6.821s wall clock time, 12.7M memory peak, 944K read from disk, 21M written to disk.
Nov 23 21:26:57 evo-x2 memory-emergency-guard-check[225653]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.15% sustained (max disk busy 100.0%, MemAvailable=79.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 21:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:29:05 evo-x2 memory-emergency-guard-check[244267]: MEMORY EMERGENCY IO-PAUSE (trip #12715, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:29:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 463ms CPU time over 7.694s wall clock time, 11.9M memory peak, 208K read from disk, 10.1M written to disk.
Nov 23 21:29:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:29:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:31:02 evo-x2 post-crash-calm-gate[270545]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:31:17 evo-x2 post-crash-calm-gate[276920]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:31:32 evo-x2 post-crash-calm-gate[278518]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:33:07 evo-x2 memory-emergency-guard-check[291893]: MEMORY EMERGENCY IO-PAUSE (trip #12716, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 462ms CPU time over 9.073s wall clock time, 12.7M memory peak, 1.2M read from disk, 9.8M written to disk.
Nov 23 21:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:35:32 evo-x2 memory-emergency-guard-check[316506]: MEMORY EMERGENCY IO-PAUSE (trip #12717, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 426ms CPU time over 4.128s wall clock time, 11.8M memory peak, 16K read from disk, 7.9M written to disk.
Nov 23 21:35:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:36:58 evo-x2 memory-emergency-guard-check[335447]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.70% sustained (max disk busy 100.0%, MemAvailable=78.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 21:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:38:03 evo-x2 memory-emergency-guard-check[344794]: MEMORY EMERGENCY IO-PAUSE (trip #12718, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 439ms CPU time over 4.836s wall clock time, 13.7M memory peak, 128K read from disk, 1.2M written to disk.
Nov 23 21:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:40:00 evo-x2 btrbk-admission[364865]: REFUSE: btrbk-forgejo — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:40:32 evo-x2 memory-emergency-guard-check[368185]: MEMORY EMERGENCY IO-PAUSE (trip #12719, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 437ms CPU time over 4.088s wall clock time, 12.8M memory peak, 16K read from disk, 8.3M written to disk.
Nov 23 21:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:43:01 evo-x2 memory-emergency-guard-check[399232]: MEMORY EMERGENCY IO-PAUSE (trip #12720, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 424ms CPU time over 2.854s wall clock time, 11.3M memory peak, 6.4M written to disk.
Nov 23 21:43:18 evo-x2 post-crash-calm-gate[408402]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:43:48 evo-x2 post-crash-calm-gate[412235]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:44:03 evo-x2 post-crash-calm-gate[416212]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:44:18 evo-x2 post-crash-calm-gate[419245]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:44:33 evo-x2 post-crash-calm-gate[419845]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:44:48 evo-x2 post-crash-calm-gate[422883]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:45:03 evo-x2 post-crash-calm-gate[423653]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:45:18 evo-x2 post-crash-calm-gate[426442]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:45:33 evo-x2 post-crash-calm-gate[427046]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:45:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:46:18 evo-x2 post-crash-calm-gate[443441]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:46:33 evo-x2 post-crash-calm-gate[444778]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:46:48 evo-x2 post-crash-calm-gate[449267]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:47:18 evo-x2 post-crash-calm-gate[457462]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 23 21:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:48:03 evo-x2 post-crash-calm-gate[471108]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:48:04 evo-x2 memory-emergency-guard-check[465551]: MEMORY EMERGENCY IO-PAUSE (trip #12721, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 21:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 546ms CPU time over 6.258s wall clock time, 12.9M memory peak, 736K read from disk, 17.6M written to disk.
Nov 23 21:48:18 evo-x2 post-crash-calm-gate[474758]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:48:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:48:33 evo-x2 post-crash-calm-gate[475342]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:48:48 evo-x2 post-crash-calm-gate[478363]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 21:48:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:49:03 evo-x2 post-crash-calm-gate[479086]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:49:18 evo-x2 post-crash-calm-gate[482179]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:49:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:49:33 evo-x2 post-crash-calm-gate[482742]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 21:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:50:03 evo-x2 post-crash-calm-gate[490308]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:50:18 evo-x2 post-crash-calm-gate[493355]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:50:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:50:33 evo-x2 post-crash-calm-gate[493918]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:50:48 evo-x2 post-crash-calm-gate[496967]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 21:50:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:50:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 99ms CPU time over 129ms wall clock time, 12.2M memory peak, 2.5M read from disk, 4K written to disk.
Nov 23 21:51:03 evo-x2 post-crash-calm-gate[501348]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:51:18 evo-x2 post-crash-calm-gate[504870]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:51:33 evo-x2 post-crash-calm-gate[505414]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:51:48 evo-x2 post-crash-calm-gate[509392]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 23 21:51:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:52:03 evo-x2 post-crash-calm-gate[512569]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 23 21:52:18 evo-x2 post-crash-calm-gate[515480]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 23 21:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:52:33 evo-x2 post-crash-calm-gate[516029]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 23 21:52:48 evo-x2 post-crash-calm-gate[519199]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 23 21:52:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:53:03 evo-x2 post-crash-calm-gate[519891]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 23 21:53:18 evo-x2 post-crash-calm-gate[523036]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 23 21:53:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:53:33 evo-x2 post-crash-calm-gate[523584]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 23 21:53:48 evo-x2 post-crash-calm-gate[527337]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 23 21:53:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:54:03 evo-x2 post-crash-calm-gate[530396]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 23 21:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:55:03 evo-x2 post-crash-calm-gate[536980]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 23 21:55:18 evo-x2 post-crash-calm-gate[539573]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 23 21:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:55:33 evo-x2 post-crash-calm-gate[540188]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 23 21:55:48 evo-x2 post-crash-calm-gate[542896]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 23 21:55:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:56:03 evo-x2 post-crash-calm-gate[550448]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 23 21:56:18 evo-x2 post-crash-calm-gate[553000]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 23 21:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:56:34 evo-x2 post-crash-calm-gate[553545]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 23 21:56:49 evo-x2 post-crash-calm-gate[555960]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 23 21:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:57:04 evo-x2 post-crash-calm-gate[556647]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 23 21:57:19 evo-x2 post-crash-calm-gate[559118]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 23 21:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:57:34 evo-x2 post-crash-calm-gate[559693]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 23 21:57:49 evo-x2 post-crash-calm-gate[563563]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 9 min ago (window 60 min).
Nov 23 21:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:58:04 evo-x2 post-crash-calm-gate[566590]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 23 21:58:19 evo-x2 post-crash-calm-gate[569362]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 23 21:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:58:34 evo-x2 post-crash-calm-gate[569919]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 23 21:58:49 evo-x2 post-crash-calm-gate[572549]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 10 min ago (window 60 min).
Nov 23 21:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:59:04 evo-x2 post-crash-calm-gate[573204]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 23 21:59:19 evo-x2 post-crash-calm-gate[575847]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 23 21:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 21:59:34 evo-x2 post-crash-calm-gate[576461]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 23 21:59:49 evo-x2 post-crash-calm-gate[580080]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 11 min ago (window 60 min).
Nov 23 21:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:00:04 evo-x2 post-crash-calm-gate[583332]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 23 22:00:19 evo-x2 post-crash-calm-gate[585942]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 23 22:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:00:34 evo-x2 post-crash-calm-gate[586584]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 23 22:00:49 evo-x2 post-crash-calm-gate[589164]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 12 min ago (window 60 min).
Nov 23 22:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:01:04 evo-x2 post-crash-calm-gate[593859]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 13 min ago (window 60 min).
Nov 23 22:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:01:34 evo-x2 post-crash-calm-gate[597312]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 13 min ago (window 60 min).
Nov 23 22:01:49 evo-x2 post-crash-calm-gate[601270]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 13 min ago (window 60 min).
Nov 23 22:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:02:04 evo-x2 post-crash-calm-gate[603987]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 14 min ago (window 60 min).
Nov 23 22:02:19 evo-x2 post-crash-calm-gate[606554]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 14 min ago (window 60 min).
Nov 23 22:02:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:02:34 evo-x2 post-crash-calm-gate[607065]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 14 min ago (window 60 min).
Nov 23 22:02:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:03:04 evo-x2 post-crash-calm-gate[610641]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 15 min ago (window 60 min).
Nov 23 22:03:19 evo-x2 post-crash-calm-gate[613570]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 15 min ago (window 60 min).
Nov 23 22:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:03:34 evo-x2 post-crash-calm-gate[614073]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 15 min ago (window 60 min).
Nov 23 22:03:49 evo-x2 post-crash-calm-gate[617004]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 15 min ago (window 60 min).
Nov 23 22:03:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:04:04 evo-x2 post-crash-calm-gate[620790]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 16 min ago (window 60 min).
Nov 23 22:04:19 evo-x2 post-crash-calm-gate[623677]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 16 min ago (window 60 min).
Nov 23 22:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:04:34 evo-x2 post-crash-calm-gate[624113]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 16 min ago (window 60 min).
Nov 23 22:04:49 evo-x2 post-crash-calm-gate[626939]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 16 min ago (window 60 min).
Nov 23 22:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:05:04 evo-x2 post-crash-calm-gate[627600]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 17 min ago (window 60 min).
Nov 23 22:05:19 evo-x2 post-crash-calm-gate[630400]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 17 min ago (window 60 min).
Nov 23 22:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:05:34 evo-x2 post-crash-calm-gate[630833]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 17 min ago (window 60 min).
Nov 23 22:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:06:34 evo-x2 post-crash-calm-gate[644609]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 18 min ago (window 60 min).
Nov 23 22:06:49 evo-x2 post-crash-calm-gate[647305]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 18 min ago (window 60 min).
Nov 23 22:07:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:07:04 evo-x2 post-crash-calm-gate[647858]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 19 min ago (window 60 min).
Nov 23 22:07:19 evo-x2 post-crash-calm-gate[650592]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 19 min ago (window 60 min).
Nov 23 22:07:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:07:34 evo-x2 post-crash-calm-gate[651034]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 19 min ago (window 60 min).
Nov 23 22:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:08:19 evo-x2 post-crash-calm-gate[661332]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 20 min ago (window 60 min).
Nov 23 22:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:08:34 evo-x2 post-crash-calm-gate[661736]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 20 min ago (window 60 min).
Nov 23 22:08:49 evo-x2 post-crash-calm-gate[664456]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 20 min ago (window 60 min).
Nov 23 22:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:09:04 evo-x2 post-crash-calm-gate[665013]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 21 min ago (window 60 min).
Nov 23 22:09:19 evo-x2 post-crash-calm-gate[667850]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 21 min ago (window 60 min).
Nov 23 22:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:09:34 evo-x2 post-crash-calm-gate[668330]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 21 min ago (window 60 min).
Nov 23 22:09:49 evo-x2 post-crash-calm-gate[671178]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 21 min ago (window 60 min).
Nov 23 22:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:10:04 evo-x2 post-crash-calm-gate[675248]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 22 min ago (window 60 min).
Nov 23 22:10:19 evo-x2 post-crash-calm-gate[677922]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 22 min ago (window 60 min).
Nov 23 22:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:10:34 evo-x2 post-crash-calm-gate[678358]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 22 min ago (window 60 min).
Nov 23 22:10:49 evo-x2 post-crash-calm-gate[681040]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 22 min ago (window 60 min).
Nov 23 22:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:11:04 evo-x2 post-crash-calm-gate[685434]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 23 min ago (window 60 min).
Nov 23 22:11:19 evo-x2 post-crash-calm-gate[688230]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 23 min ago (window 60 min).
Nov 23 22:11:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:11:34 evo-x2 post-crash-calm-gate[688657]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 23 min ago (window 60 min).
Nov 23 22:12:04 evo-x2 memory-emergency-guard-check[694779]: MEMORY EMERGENCY IO-PAUSE (trip #12722, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 507ms CPU time over 2.742s wall clock time, 12.5M memory peak, 1.1M read from disk, 52.9M written to disk.
Nov 23 22:12:19 evo-x2 post-crash-calm-gate[701815]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 22:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:12:34 evo-x2 post-crash-calm-gate[702400]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 22:12:49 evo-x2 post-crash-calm-gate[705008]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 22:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:13:04 evo-x2 post-crash-calm-gate[705696]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 22:13:19 evo-x2 post-crash-calm-gate[708253]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 22:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:13:34 evo-x2 post-crash-calm-gate[708822]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 23 22:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:28:38 evo-x2 memory-emergency-guard-check[998596]: MEMORY EMERGENCY IO-PAUSE (trip #12723, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 812ms CPU time over 1.884s wall clock time, 10.4M memory peak, 2M read from disk, 13.2M written to disk.
Nov 23 22:29:06 evo-x2 memory-emergency-guard-check[1015442]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.47% sustained (max disk busy 98.6%, MemAvailable=65.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 22:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:31:07 evo-x2 memory-emergency-guard-check[1057589]: MEMORY EMERGENCY IO-PAUSE (trip #12724, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 914ms wall clock time, 12.5M memory peak, 1.9M read from disk, 60.9M written to disk.
Nov 23 22:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:34:08 evo-x2 memory-emergency-guard-check[1099778]: MEMORY EMERGENCY IO-PAUSE (trip #12725, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 507ms CPU time over 673ms wall clock time, 12.5M memory peak, 1.2M read from disk, 61.9M written to disk.
Nov 23 22:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 201ms CPU time over 2.332s wall clock time, 8.6M memory peak, 1.7M read from disk, 4K written to disk.
Nov 23 22:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:36:39 evo-x2 memory-emergency-guard-check[1133058]: MEMORY EMERGENCY IO-PAUSE (trip #12726, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 482ms CPU time over 672ms wall clock time, 12.1M memory peak, 11.5M read from disk, 26.6M written to disk.
Nov 23 22:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:39:13 evo-x2 memory-emergency-guard-check[1157288]: MEMORY EMERGENCY IO-PAUSE (trip #12727, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:39:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:39:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 513ms CPU time over 777ms wall clock time, 11.6M memory peak, 13.4M read from disk, 44.2M written to disk.
Nov 23 22:39:42 evo-x2 memory-emergency-guard-check[1169305]: MEMORY EMERGENCY still active (I/O PSI some avg60=98.01% sustained (max disk busy 100.0%, MemAvailable=21.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 22:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:41:43 evo-x2 memory-emergency-guard-check[1196329]: MEMORY EMERGENCY IO-PAUSE (trip #12728, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 506ms CPU time over 1.102s wall clock time, 12.1M memory peak, 15.2M read from disk, 40.2M written to disk.
Nov 23 22:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:43:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:44:16 evo-x2 memory-emergency-guard-check[1250321]: MEMORY EMERGENCY IO-PAUSE (trip #12729, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 628ms CPU time over 2.632s wall clock time, 12.6M memory peak, 24.1M read from disk, 44.6M written to disk.
Nov 23 22:44:42 evo-x2 gatus[104704]: 2026/11/23 22:44:42 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 23 22:44:42 evo-x2 gatus[104704]: 2026/11/23 22:44:42 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 23 22:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:46:46 evo-x2 memory-emergency-guard-check[1331498]: MEMORY EMERGENCY IO-PAUSE (trip #12730, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 549ms CPU time over 945ms wall clock time, 13.3M memory peak, 24.2M read from disk, 40.8M written to disk.
Nov 23 22:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:49:17 evo-x2 memory-emergency-guard-check[1381975]: MEMORY EMERGENCY IO-PAUSE (trip #12731, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 974ms wall clock time, 12M memory peak, 21.6M read from disk, 35.3M written to disk.
Nov 23 22:49:47 evo-x2 memory-emergency-guard-check[1431562]: MEMORY EMERGENCY still active (I/O PSI some avg60=95.72% sustained (max disk busy 99.2%, MemAvailable=28.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 22:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:51:49 evo-x2 memory-emergency-guard-check[1508512]: MEMORY EMERGENCY IO-PAUSE (trip #12732, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 876ms CPU time over 2.445s wall clock time, 10.9M memory peak, 10.4M read from disk, 21.2M written to disk.
Nov 23 22:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:53:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:54:19 evo-x2 memory-emergency-guard-check[1594361]: MEMORY EMERGENCY IO-PAUSE (trip #12733, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 1.427s wall clock time, 12.2M memory peak, 38.4M read from disk, 1.6M written to disk.
Nov 23 22:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:56:50 evo-x2 memory-emergency-guard-check[1697592]: MEMORY EMERGENCY IO-PAUSE (trip #12734, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 1.102s wall clock time, 11.9M memory peak, 17.1M read from disk, 48.2M written to disk.
Nov 23 22:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:59:20 evo-x2 memory-emergency-guard-check[1753055]: MEMORY EMERGENCY IO-PAUSE (trip #12735, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 22:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 22:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 487ms CPU time over 718ms wall clock time, 12.5M memory peak, 2.9M read from disk, 25.8M written to disk.
Nov 23 22:59:49 evo-x2 memory-emergency-guard-check[1764073]: MEMORY EMERGENCY still active (I/O PSI some avg60=98.70% sustained (max disk busy 100.0%, MemAvailable=35.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 22:59:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:01:51 evo-x2 memory-emergency-guard-check[1794979]: MEMORY EMERGENCY IO-PAUSE (trip #12736, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 582ms CPU time over 915ms wall clock time, 12.9M memory peak, 12.4M read from disk, 29.4M written to disk.
Nov 23 23:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:04:23 evo-x2 memory-emergency-guard-check[1831304]: MEMORY EMERGENCY IO-PAUSE (trip #12737, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 529ms CPU time over 656ms wall clock time, 12.4M memory peak, 2.8M read from disk, 35.5M written to disk.
Nov 23 23:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:06:53 evo-x2 memory-emergency-guard-check[1866819]: MEMORY EMERGENCY IO-PAUSE (trip #12738, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 474ms CPU time over 654ms wall clock time, 12.7M memory peak, 13M read from disk, 29M written to disk.
Nov 23 23:07:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:09:25 evo-x2 memory-emergency-guard-check[1917638]: MEMORY EMERGENCY IO-PAUSE (trip #12739, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 480ms CPU time over 705ms wall clock time, 11.8M memory peak, 11.3M read from disk, 26.1M written to disk.
Nov 23 23:09:54 evo-x2 memory-emergency-guard-check[1933181]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.11% sustained (max disk busy 100.0%, MemAvailable=70.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 23:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:10:00 evo-x2 btrbk-admission[1935439]: REFUSE: btrbk-projects — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 23 23:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:11:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:15:02 evo-x2 memory-emergency-guard-check[1988157]: MEMORY EMERGENCY IO-PAUSE (trip #12740, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 488ms CPU time over 817ms wall clock time, 12M memory peak, 17.6M read from disk, 38M written to disk.
Nov 23 23:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:17:32 evo-x2 memory-emergency-guard-check[2023402]: MEMORY EMERGENCY IO-PAUSE (trip #12741, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:17:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 459ms CPU time over 617ms wall clock time, 11.6M memory peak, 7.2M read from disk, 24.1M written to disk.
Nov 23 23:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 116ms CPU time over 399ms wall clock time, 11.1M memory peak, 1.7M read from disk, 4K written to disk.
Nov 23 23:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:20:03 evo-x2 memory-emergency-guard-check[2051920]: MEMORY EMERGENCY IO-PAUSE (trip #12742, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 487ms CPU time over 592ms wall clock time, 11.9M memory peak, 1.8M read from disk, 22.6M written to disk.
Nov 23 23:20:36 evo-x2 memory-emergency-guard-check[2059591]: MEMORY EMERGENCY still active (I/O PSI some avg60=96.45% sustained (max disk busy 99.3%, MemAvailable=66.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (34s < 150s, 116s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 23:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:22:37 evo-x2 memory-emergency-guard-check[2080038]: MEMORY EMERGENCY IO-PAUSE (trip #12743, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 474ms CPU time over 965ms wall clock time, 15.1M memory peak, 3.3M read from disk, 18.7M written to disk.
Nov 23 23:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:23:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:24:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:25:07 evo-x2 memory-emergency-guard-check[2175925]: MEMORY EMERGENCY IO-PAUSE (trip #12744, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 466ms CPU time over 907ms wall clock time, 12.8M memory peak, 1.9M read from disk, 20.6M written to disk.
Nov 23 23:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:27:40 evo-x2 memory-emergency-guard-check[2203973]: MEMORY EMERGENCY IO-PAUSE (trip #12745, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 458ms CPU time over 3.274s wall clock time, 11.8M memory peak, 5.6M read from disk, 13.6M written to disk.
Nov 23 23:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:30:00 evo-x2 btrbk-admission[2261623]: REFUSE: btrbk-data — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 23 23:30:09 evo-x2 memory-emergency-guard-check[2262122]: MEMORY EMERGENCY IO-PAUSE (trip #12746, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 457ms CPU time over 2.861s wall clock time, 13.3M memory peak, 864K read from disk, 17.5M written to disk.
Nov 23 23:30:37 evo-x2 memory-emergency-guard-check[2271944]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.27% sustained (max disk busy 100.0%, MemAvailable=63.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 23:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:32:38 evo-x2 memory-emergency-guard-check[2299796]: MEMORY EMERGENCY IO-PAUSE (trip #12747, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 461ms CPU time over 811ms wall clock time, 12.6M memory peak, 816K read from disk, 16.2M written to disk.
Nov 23 23:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:35:09 evo-x2 memory-emergency-guard-check[2329727]: MEMORY EMERGENCY IO-PAUSE (trip #12748, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 485ms CPU time over 651ms wall clock time, 11.9M memory peak, 4.7M read from disk, 25.8M written to disk.
Nov 23 23:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:37:40 evo-x2 memory-emergency-guard-check[2442791]: MEMORY EMERGENCY IO-PAUSE (trip #12749, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 787ms wall clock time, 10.5M memory peak, 660K read from disk, 15.4M written to disk.
Nov 23 23:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:45:00 evo-x2 btrbk-admission[2530429]: REFUSE: btrbk-pool — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 23 23:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:50:19 evo-x2 memory-emergency-guard-check[2591433]: MEMORY EMERGENCY IO-PAUSE (trip #12750, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 545ms CPU time over 1.027s wall clock time, 11.8M memory peak, 9M read from disk, 43.4M written to disk.
Nov 23 23:50:48 evo-x2 memory-emergency-guard-check[2600133]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.90% sustained (max disk busy 100.0%, MemAvailable=64.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 23 23:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:51:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:53:01 evo-x2 memory-emergency-guard-check[2623032]: MEMORY EMERGENCY IO-PAUSE (trip #12751, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 493ms CPU time over 759ms wall clock time, 13M memory peak, 6.1M read from disk, 37.8M written to disk.
Nov 23 23:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:55:31 evo-x2 memory-emergency-guard-check[2650570]: MEMORY EMERGENCY IO-PAUSE (trip #12752, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 1.223s wall clock time, 10.6M memory peak, 1.2M read from disk, 17.3M written to disk.
Nov 23 23:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:58:03 evo-x2 memory-emergency-guard-check[2683959]: MEMORY EMERGENCY IO-PAUSE (trip #12753, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 23 23:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 473ms CPU time over 620ms wall clock time, 12M memory peak, 3.5M read from disk, 23.4M written to disk.
Nov 23 23:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 23 23:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:01:03 evo-x2 memory-emergency-guard-check[2866983]: MEMORY EMERGENCY IO-PAUSE (trip #12754, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 982ms wall clock time, 12.4M memory peak, 7.8M read from disk, 33.3M written to disk.
Nov 24 00:01:33 evo-x2 memory-emergency-guard-check[2938221]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.47% sustained (max disk busy 99.8%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 00:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:03:34 evo-x2 memory-emergency-guard-check[3020939]: MEMORY EMERGENCY IO-PAUSE (trip #12755, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 1.094s wall clock time, 12.5M memory peak, 5.8M read from disk, 19.6M written to disk.
Nov 24 00:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:14:02 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4826 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 24 00:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:15:06 evo-x2 memory-emergency-guard-check[3651598]: MEMORY EMERGENCY IO-PAUSE (trip #12756, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 658ms CPU time over 1.262s wall clock time, 10.6M memory peak, 29.3M read from disk, 64.1M written to disk.
Nov 24 00:15:35 evo-x2 memory-emergency-guard-check[3675134]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.07% sustained (max disk busy 99.8%, MemAvailable=66.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 00:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:39:43 evo-x2 memory-emergency-guard-check[768559]: MEMORY EMERGENCY IO-PAUSE (trip #12757, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 776ms CPU time over 1.264s wall clock time, 10.9M memory peak, 10.1M read from disk, 55.5M written to disk.
Nov 24 00:40:12 evo-x2 memory-emergency-guard-check[810749]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.64% sustained (max disk busy 100.0%, MemAvailable=61.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 00:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:41:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:46:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:48:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:50:15 evo-x2 memory-emergency-guard-check[1466910]: MEMORY EMERGENCY IO-PAUSE (trip #12758, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 827ms wall clock time, 10.2M memory peak, 1.8M read from disk, 17.3M written to disk.
Nov 24 00:50:44 evo-x2 memory-emergency-guard-check[1491265]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.23% sustained (max disk busy 100.0%, MemAvailable=52.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 00:50:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:52:46 evo-x2 memory-emergency-guard-check[1568012]: MEMORY EMERGENCY IO-PAUSE (trip #12759, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 793ms CPU time over 1.567s wall clock time, 11.7M memory peak, 13.5M read from disk, 37.5M written to disk.
Nov 24 00:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:57:23 evo-x2 memory-emergency-guard-check[1659827]: MEMORY EMERGENCY IO-PAUSE (trip #12760, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.174s CPU time over 2min 8.881s wall clock time, 11.2M memory peak, 13.6M read from disk, 241.6M written to disk.
Nov 24 00:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:58:00 evo-x2 memory-emergency-guard-check[1867925]: MEMORY EMERGENCY IO-PAUSE (trip #12761, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 00:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 900ms CPU time over 6.825s wall clock time, 11.8M memory peak, 912K read from disk, 107.2M written to disk.
Nov 24 00:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 00:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:00:45 evo-x2 memory-emergency-guard-check[2083923]: MEMORY EMERGENCY IO-PAUSE (trip #12762, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 2.435s CPU time over 21.060s wall clock time, 11M memory peak, 48K read from disk, 61.8M written to disk.
Nov 24 01:00:54 evo-x2 memory-emergency-guard-check[2129444]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.09% sustained (max disk busy 97.2%, MemAvailable=59.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:02:55 evo-x2 memory-emergency-guard-check[2276548]: MEMORY EMERGENCY IO-PAUSE (trip #12763, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 899ms CPU time over 1.317s wall clock time, 11.1M memory peak, 176K read from disk, 98.9M written to disk.
Nov 24 01:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:04:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:04:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:05:31 evo-x2 memory-emergency-guard-check[2416560]: MEMORY EMERGENCY IO-PAUSE (trip #12764, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 837ms CPU time over 7.045s wall clock time, 12.4M memory peak, 816K read from disk, 61.2M written to disk.
Nov 24 01:05:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:06:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:07:56 evo-x2 memory-emergency-guard-check[2556862]: MEMORY EMERGENCY IO-PAUSE (trip #12765, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 744ms CPU time over 1.269s wall clock time, 13M memory peak, 160K read from disk, 37.9M written to disk.
Nov 24 01:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:10:26 evo-x2 memory-emergency-guard-check[2661380]: MEMORY EMERGENCY IO-PAUSE (trip #12766, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 802ms CPU time over 1.780s wall clock time, 12.1M memory peak, 880K read from disk, 46.1M written to disk.
Nov 24 01:10:55 evo-x2 memory-emergency-guard-check[2681587]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.91% sustained (max disk busy 100.0%, MemAvailable=54.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:12:56 evo-x2 memory-emergency-guard-check[2764297]: MEMORY EMERGENCY IO-PAUSE (trip #12767, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 608ms CPU time over 1.219s wall clock time, 12.5M memory peak, 400K read from disk, 31.7M written to disk.
Nov 24 01:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:15:26 evo-x2 memory-emergency-guard-check[2868719]: MEMORY EMERGENCY IO-PAUSE (trip #12768, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 679ms CPU time over 958ms wall clock time, 13.1M memory peak, 2.3M read from disk, 47.6M written to disk.
Nov 24 01:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:17:56 evo-x2 memory-emergency-guard-check[2984642]: MEMORY EMERGENCY IO-PAUSE (trip #12769, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:17:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:17:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 969ms wall clock time, 11.9M memory peak, 688K read from disk, 68.3M written to disk.
Nov 24 01:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:20:26 evo-x2 memory-emergency-guard-check[3058191]: MEMORY EMERGENCY IO-PAUSE (trip #12770, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 730ms wall clock time, 10.2M memory peak, 640K read from disk, 33.4M written to disk.
Nov 24 01:20:55 evo-x2 memory-emergency-guard-check[3076145]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.44% sustained (max disk busy 100.0%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:22:57 evo-x2 memory-emergency-guard-check[3185212]: MEMORY EMERGENCY IO-PAUSE (trip #12771, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 795ms CPU time over 1.220s wall clock time, 9.9M memory peak, 1008K read from disk, 75.7M written to disk.
Nov 24 01:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:25:26 evo-x2 memory-emergency-guard-check[3326713]: MEMORY EMERGENCY IO-PAUSE (trip #12772, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 855ms wall clock time, 11.7M memory peak, 928K read from disk, 38.4M written to disk.
Nov 24 01:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:27:58 evo-x2 memory-emergency-guard-check[3494340]: MEMORY EMERGENCY IO-PAUSE (trip #12773, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 806ms wall clock time, 11.2M memory peak, 480K read from disk, 37M written to disk.
Nov 24 01:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:30:30 evo-x2 memory-emergency-guard-check[3586850]: MEMORY EMERGENCY IO-PAUSE (trip #12774, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 693ms wall clock time, 12.4M memory peak, 928K read from disk, 34.6M written to disk.
Nov 24 01:31:00 evo-x2 memory-emergency-guard-check[3602080]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.70% sustained (max disk busy 100.0%, MemAvailable=61.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:32:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:32:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:33:02 evo-x2 memory-emergency-guard-check[3673414]: MEMORY EMERGENCY IO-PAUSE (trip #12775, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 735ms wall clock time, 12.2M memory peak, 1.5M read from disk, 38.2M written to disk.
Nov 24 01:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:35:33 evo-x2 memory-emergency-guard-check[3783808]: MEMORY EMERGENCY IO-PAUSE (trip #12776, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 647ms CPU time over 835ms wall clock time, 11.2M memory peak, 1.2M read from disk, 43.8M written to disk.
Nov 24 01:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:38:06 evo-x2 memory-emergency-guard-check[3864621]: MEMORY EMERGENCY IO-PAUSE (trip #12777, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 849ms wall clock time, 11.4M memory peak, 7.7M read from disk, 47.2M written to disk.
Nov 24 01:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:40:37 evo-x2 memory-emergency-guard-check[3939525]: MEMORY EMERGENCY IO-PAUSE (trip #12778, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 730ms wall clock time, 12.1M memory peak, 2.3M read from disk, 33.9M written to disk.
Nov 24 01:41:06 evo-x2 memory-emergency-guard-check[3961547]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.86% sustained (max disk busy 99.8%, MemAvailable=61.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:43:08 evo-x2 memory-emergency-guard-check[4071914]: MEMORY EMERGENCY IO-PAUSE (trip #12779, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 1.483s wall clock time, 11.4M memory peak, 1.4M read from disk, 27.7M written to disk.
Nov 24 01:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:45:37 evo-x2 memory-emergency-guard-check[4191241]: MEMORY EMERGENCY IO-PAUSE (trip #12780, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 537ms CPU time over 629ms wall clock time, 11.5M memory peak, 1.7M read from disk, 20.3M written to disk.
Nov 24 01:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:48:09 evo-x2 memory-emergency-guard-check[142201]: MEMORY EMERGENCY IO-PAUSE (trip #12781, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 901ms CPU time over 1.322s wall clock time, 10.4M memory peak, 22.7M read from disk, 46.5M written to disk.
Nov 24 01:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:50:39 evo-x2 memory-emergency-guard-check[337753]: MEMORY EMERGENCY IO-PAUSE (trip #12782, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 873ms CPU time over 1.159s wall clock time, 10.7M memory peak, 8.1M read from disk, 35.5M written to disk.
Nov 24 01:51:09 evo-x2 memory-emergency-guard-check[369542]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.76% sustained (max disk busy 98.4%, MemAvailable=60.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 01:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:53:10 evo-x2 memory-emergency-guard-check[547784]: MEMORY EMERGENCY IO-PAUSE (trip #12783, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 867ms wall clock time, 11.6M memory peak, 6.7M read from disk, 36.4M written to disk.
Nov 24 01:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:55:43 evo-x2 memory-emergency-guard-check[685777]: MEMORY EMERGENCY IO-PAUSE (trip #12784, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 4.010s wall clock time, 9.8M memory peak, 5.1M read from disk, 35.4M written to disk.
Nov 24 01:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:57:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:58:17 evo-x2 memory-emergency-guard-check[891873]: MEMORY EMERGENCY IO-PAUSE (trip #12785, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 01:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.066s CPU time over 4.247s wall clock time, 9.1M memory peak, 12.2M read from disk, 45.2M written to disk.
Nov 24 01:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 01:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:00:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:01:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:02:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:02:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:09:19 evo-x2 memory-emergency-guard-check[1505703]: MEMORY EMERGENCY IO-PAUSE (trip #12786, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 3.844s wall clock time, 13M memory peak, 620K read from disk, 21.7M written to disk.
Nov 24 02:09:45 evo-x2 memory-emergency-guard-check[1526376]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.67% sustained (max disk busy 100.0%, MemAvailable=61.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 02:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:11:53 evo-x2 memory-emergency-guard-check[1634429]: MEMORY EMERGENCY IO-PAUSE (trip #12787, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 7.969s wall clock time, 12.5M memory peak, 8.3M read from disk, 29.6M written to disk.
Nov 24 02:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:14:23 evo-x2 memory-emergency-guard-check[1711826]: MEMORY EMERGENCY IO-PAUSE (trip #12788, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 7.418s wall clock time, 12.3M memory peak, 1.6M read from disk, 33.2M written to disk.
Nov 24 02:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:16:47 evo-x2 memory-emergency-guard-check[1796116]: MEMORY EMERGENCY IO-PAUSE (trip #12789, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 941ms CPU time over 1.545s wall clock time, 12.7M memory peak, 6.7M read from disk, 40.9M written to disk.
Nov 24 02:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:19:17 evo-x2 memory-emergency-guard-check[1921272]: MEMORY EMERGENCY IO-PAUSE (trip #12790, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 740ms CPU time over 1.018s wall clock time, 11.8M memory peak, 1.9M read from disk, 47.3M written to disk.
Nov 24 02:19:46 evo-x2 memory-emergency-guard-check[1947957]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.19% sustained (max disk busy 100.0%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 02:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:21:48 evo-x2 memory-emergency-guard-check[2012429]: MEMORY EMERGENCY IO-PAUSE (trip #12791, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 774ms CPU time over 1.988s wall clock time, 12.2M memory peak, 11.8M read from disk, 75.1M written to disk.
Nov 24 02:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:24:17 evo-x2 memory-emergency-guard-check[2113032]: MEMORY EMERGENCY IO-PAUSE (trip #12792, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 922ms wall clock time, 11.7M memory peak, 2M read from disk, 24M written to disk.
Nov 24 02:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:26:53 evo-x2 memory-emergency-guard-check[2216056]: MEMORY EMERGENCY IO-PAUSE (trip #12793, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 971ms CPU time over 5.320s wall clock time, 11.3M memory peak, 14.2M read from disk, 48.5M written to disk.
Nov 24 02:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 149ms CPU time over 263ms wall clock time, 7.5M memory peak, 1M read from disk, 4K written to disk.
Nov 24 02:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:29:49 evo-x2 memory-emergency-guard-check[2361643]: MEMORY EMERGENCY IO-PAUSE (trip #12794, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 901ms CPU time over 1.092s wall clock time, 9.2M memory peak, 1.5M read from disk, 23.1M written to disk.
Nov 24 02:30:18 evo-x2 memory-emergency-guard-check[2388840]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.36% sustained (max disk busy 100.0%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 02:30:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:30:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:31:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:31:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:39:24 evo-x2 memory-emergency-guard-check[2764238]: MEMORY EMERGENCY IO-PAUSE (trip #12795, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 871ms CPU time over 1.417s wall clock time, 10.9M memory peak, 9.7M read from disk, 99.3M written to disk.
Nov 24 02:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:40:57 evo-x2 memory-emergency-guard-check[2826942]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.57% sustained (max disk busy 20.6%, MemAvailable=61.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (94s < 150s, 56s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 02:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:43:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:45:00 evo-x2 memory-emergency-guard-check[2924907]: MEMORY EMERGENCY IO-PAUSE (trip #12796, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 511ms CPU time over 546ms wall clock time, 11.3M memory peak, 48K read from disk, 7.2M written to disk.
Nov 24 02:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:47:31 evo-x2 memory-emergency-guard-check[2993130]: MEMORY EMERGENCY IO-PAUSE (trip #12797, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 563ms CPU time over 710ms wall clock time, 10.6M memory peak, 3.5M read from disk, 31.6M written to disk.
Nov 24 02:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:53:36 evo-x2 memory-emergency-guard-check[3152874]: MEMORY EMERGENCY IO-PAUSE (trip #12798, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 02:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 547ms CPU time over 794ms wall clock time, 12.7M memory peak, 240K read from disk, 12.6M written to disk.
Nov 24 02:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:54:36 evo-x2 memory-emergency-guard-check[3186218]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.33% sustained (max disk busy 25.6%, MemAvailable=62.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 02:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 02:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:00:08 evo-x2 memory-emergency-guard-check[3457738]: MEMORY EMERGENCY IO-PAUSE (trip #12799, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 1.103s wall clock time, 12.6M memory peak, 112K read from disk, 20.9M written to disk.
Nov 24 03:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:02:38 evo-x2 memory-emergency-guard-check[3526119]: MEMORY EMERGENCY IO-PAUSE (trip #12800, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 536ms CPU time over 767ms wall clock time, 12.6M memory peak, 256K read from disk, 12.7M written to disk.
Nov 24 03:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:04:38 evo-x2 memory-emergency-guard-check[3578030]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.71% sustained (max disk busy 41.3%, MemAvailable=61.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:05:39 evo-x2 memory-emergency-guard-check[3598389]: MEMORY EMERGENCY IO-PAUSE (trip #12801, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 546ms CPU time over 882ms wall clock time, 11.9M memory peak, 3M read from disk, 28.2M written to disk.
Nov 24 03:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:08:09 evo-x2 memory-emergency-guard-check[3668158]: MEMORY EMERGENCY IO-PAUSE (trip #12802, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 543ms CPU time over 666ms wall clock time, 13M memory peak, 2M read from disk, 17.3M written to disk.
Nov 24 03:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:14:17 evo-x2 memory-emergency-guard-check[3806371]: MEMORY EMERGENCY IO-PAUSE (trip #12803, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 523ms CPU time over 597ms wall clock time, 12.2M memory peak, 640K read from disk, 12.8M written to disk.
Nov 24 03:14:47 evo-x2 memory-emergency-guard-check[3820847]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.00% sustained (max disk busy 99.2%, MemAvailable=62.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:16:49 evo-x2 memory-emergency-guard-check[3869077]: MEMORY EMERGENCY IO-PAUSE (trip #12804, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 524ms CPU time over 2.460s wall clock time, 13.5M memory peak, 3.3M read from disk, 23.8M written to disk.
Nov 24 03:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:19:23 evo-x2 memory-emergency-guard-check[3923716]: MEMORY EMERGENCY IO-PAUSE (trip #12805, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 479ms CPU time over 5.466s wall clock time, 12.5M memory peak, 2.1M read from disk, 7.4M written to disk.
Nov 24 03:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:21:52 evo-x2 memory-emergency-guard-check[4035624]: MEMORY EMERGENCY IO-PAUSE (trip #12806, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 4.192s wall clock time, 12.9M memory peak, 1.4M read from disk, 12.9M written to disk.
Nov 24 03:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:24:24 evo-x2 memory-emergency-guard-check[4159223]: MEMORY EMERGENCY IO-PAUSE (trip #12807, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 917ms CPU time over 5.969s wall clock time, 9.7M memory peak, 18.4M read from disk, 21.9M written to disk.
Nov 24 03:24:48 evo-x2 memory-emergency-guard-check[4184269]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.43% sustained (max disk busy 100.0%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:26:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:32:58 evo-x2 memory-emergency-guard-check[384358]: MEMORY EMERGENCY IO-PAUSE (trip #12808, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:32:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 566ms CPU time over 827ms wall clock time, 10.6M memory peak, 2.9M read from disk, 46.3M written to disk.
Nov 24 03:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:33:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:34:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:34:59 evo-x2 memory-emergency-guard-check[446917]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.08% sustained (max disk busy 22.7%, MemAvailable=61.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (122s < 150s, 28s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:35:31 evo-x2 memory-emergency-guard-check[459422]: MEMORY EMERGENCY IO-PAUSE (trip #12809, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.016s CPU time over 1.348s wall clock time, 11.2M memory peak, 2.5M read from disk, 53.1M written to disk.
Nov 24 03:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:38:33 evo-x2 memory-emergency-guard-check[575795]: MEMORY EMERGENCY IO-PAUSE (trip #12810, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 654ms CPU time over 998ms wall clock time, 10.7M memory peak, 2.3M read from disk, 60.8M written to disk.
Nov 24 03:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:41:04 evo-x2 memory-emergency-guard-check[710275]: MEMORY EMERGENCY IO-PAUSE (trip #12811, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 939ms CPU time over 1.555s wall clock time, 10.1M memory peak, 1.9M read from disk, 36.1M written to disk.
Nov 24 03:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:43:35 evo-x2 memory-emergency-guard-check[820009]: MEMORY EMERGENCY IO-PAUSE (trip #12812, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:43:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:43:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 484ms CPU time over 2.210s wall clock time, 11.8M memory peak, 608K read from disk, 22.8M written to disk.
Nov 24 03:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:45:03 evo-x2 memory-emergency-guard-check[910919]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.30% sustained (max disk busy 97.0%, MemAvailable=65.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:46:04 evo-x2 memory-emergency-guard-check[986968]: MEMORY EMERGENCY IO-PAUSE (trip #12813, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:46:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:46:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 531ms CPU time over 1.771s wall clock time, 13.6M memory peak, 1.4M read from disk, 36.1M written to disk.
Nov 24 03:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:48:37 evo-x2 memory-emergency-guard-check[1054767]: MEMORY EMERGENCY IO-PAUSE (trip #12814, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 505ms CPU time over 3.932s wall clock time, 13.5M memory peak, 2M read from disk, 30.7M written to disk.
Nov 24 03:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:51:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:52:07 evo-x2 memory-emergency-guard-check[1196502]: MEMORY EMERGENCY IO-PAUSE (trip #12815, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 488ms CPU time over 598ms wall clock time, 12.2M memory peak, 800K read from disk, 14.5M written to disk.
Nov 24 03:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:55:37 evo-x2 memory-emergency-guard-check[1273101]: MEMORY EMERGENCY IO-PAUSE (trip #12816, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 1.002s wall clock time, 11.4M memory peak, 3.7M read from disk, 45M written to disk.
Nov 24 03:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:57:07 evo-x2 memory-emergency-guard-check[1368403]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.47% sustained (max disk busy 27.7%, MemAvailable=61.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 03:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:58:07 evo-x2 memory-emergency-guard-check[1389664]: MEMORY EMERGENCY IO-PAUSE (trip #12817, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 03:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 479ms CPU time over 614ms wall clock time, 12.5M memory peak, 800K read from disk, 23.7M written to disk.
Nov 24 03:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 03:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:00:38 evo-x2 memory-emergency-guard-check[1467094]: MEMORY EMERGENCY IO-PAUSE (trip #12818, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 884ms CPU time over 1.550s wall clock time, 12.7M memory peak, 32.5M read from disk, 103.8M written to disk.
Nov 24 04:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:02:59 evo-x2 pma[2247]:   │ docs/services/memory-emergency-guard.md
Nov 24 04:03:09 evo-x2 memory-emergency-guard-check[1554629]: MEMORY EMERGENCY IO-PAUSE (trip #12819, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 629ms CPU time over 997ms wall clock time, 10.6M memory peak, 15.8M read from disk, 44.5M written to disk.
Nov 24 04:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:05:40 evo-x2 memory-emergency-guard-check[1674678]: MEMORY EMERGENCY IO-PAUSE (trip #12820, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 851ms wall clock time, 10.6M memory peak, 18M read from disk, 33.5M written to disk.
Nov 24 04:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:07:12 evo-x2 memory-emergency-guard-check[1746736]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.50% sustained (max disk busy 100.0%, MemAvailable=50.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (93s < 150s, 57s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:08:15 evo-x2 memory-emergency-guard-check[1777529]: MEMORY EMERGENCY IO-PAUSE (trip #12821, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 828ms wall clock time, 11.4M memory peak, 12.9M read from disk, 43.4M written to disk.
Nov 24 04:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:10:46 evo-x2 memory-emergency-guard-check[1834818]: MEMORY EMERGENCY IO-PAUSE (trip #12822, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 526ms CPU time over 638ms wall clock time, 11.3M memory peak, 3.2M read from disk, 23.4M written to disk.
Nov 24 04:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:13:18 evo-x2 memory-emergency-guard-check[1897006]: MEMORY EMERGENCY IO-PAUSE (trip #12823, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 519ms CPU time over 647ms wall clock time, 10.9M memory peak, 2.9M read from disk, 22.3M written to disk.
Nov 24 04:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:15:49 evo-x2 memory-emergency-guard-check[2009857]: MEMORY EMERGENCY IO-PAUSE (trip #12824, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 720ms CPU time over 1.180s wall clock time, 12.6M memory peak, 14.3M read from disk, 52.7M written to disk.
Nov 24 04:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:17:18 evo-x2 memory-emergency-guard-check[2096576]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.54% sustained (max disk busy 99.8%, MemAvailable=60.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:18:28 evo-x2 memory-emergency-guard-check[2177052]: MEMORY EMERGENCY IO-PAUSE (trip #12825, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.372s CPU time over 9.161s wall clock time, 8.3M memory peak, 20.3M read from disk, 42.6M written to disk.
Nov 24 04:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:19:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:20:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:20:52 evo-x2 memory-emergency-guard-check[2294318]: MEMORY EMERGENCY IO-PAUSE (trip #12826, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 2.465s wall clock time, 10.9M memory peak, 14.9M read from disk, 52.6M written to disk.
Nov 24 04:21:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:23:22 evo-x2 memory-emergency-guard-check[2384899]: sort: fflush failed: 'standard output': Broken pipe
Nov 24 04:23:22 evo-x2 memory-emergency-guard-check[2384899]: sort: write error
Nov 24 04:23:22 evo-x2 memory-emergency-guard-check[2380825]: MEMORY EMERGENCY IO-PAUSE (trip #12827, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 958ms CPU time over 2.029s wall clock time, 10.8M memory peak, 5.9M read from disk, 33.8M written to disk.
Nov 24 04:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:25:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:27:31 evo-x2 memory-emergency-guard-check[2564127]: MEMORY EMERGENCY IO-PAUSE (trip #12828, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 779ms CPU time over 10.187s wall clock time, 11.7M memory peak, 35.4M read from disk, 53M written to disk.
Nov 24 04:27:52 evo-x2 memory-emergency-guard-check[2585337]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.18% sustained (max disk busy 98.0%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:32:27 evo-x2 memory-emergency-guard-check[2730802]: MEMORY EMERGENCY IO-PAUSE (trip #12829, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 5.585s wall clock time, 11.5M memory peak, 4.8M read from disk, 67.8M written to disk.
Nov 24 04:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:35:04 evo-x2 memory-emergency-guard-check[2796621]: MEMORY EMERGENCY IO-PAUSE (trip #12830, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 12.051s wall clock time, 12.6M memory peak, 1.7M read from disk, 24.8M written to disk.
Nov 24 04:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:37:30 evo-x2 memory-emergency-guard-check[2898740]: MEMORY EMERGENCY IO-PAUSE (trip #12831, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 791ms CPU time over 7.026s wall clock time, 13.4M memory peak, 7.2M read from disk, 91.3M written to disk.
Nov 24 04:37:53 evo-x2 memory-emergency-guard-check[2919605]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.05% sustained (max disk busy 100.0%, MemAvailable=63.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:38:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:39:59 evo-x2 memory-emergency-guard-check[2977040]: MEMORY EMERGENCY IO-PAUSE (trip #12832, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 659ms CPU time over 3.998s wall clock time, 13.6M memory peak, 2.2M read from disk, 60.3M written to disk.
Nov 24 04:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:41:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:42:29 evo-x2 memory-emergency-guard-check[3085895]: MEMORY EMERGENCY IO-PAUSE (trip #12833, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 610ms CPU time over 1.974s wall clock time, 13.4M memory peak, 2.4M read from disk, 36.7M written to disk.
Nov 24 04:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:45:04 evo-x2 memory-emergency-guard-check[3171659]: sort: write failed: 'standard output': Broken pipe
Nov 24 04:45:04 evo-x2 memory-emergency-guard-check[3171659]: sort: write error
Nov 24 04:45:04 evo-x2 memory-emergency-guard-check[3164900]: MEMORY EMERGENCY IO-PAUSE (trip #12834, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.240s CPU time over 5.022s wall clock time, 9.7M memory peak, 1.8M read from disk, 71.4M written to disk.
Nov 24 04:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:47:43 evo-x2 memory-emergency-guard-check[3250129]: MEMORY EMERGENCY IO-PAUSE (trip #12835, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:47:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 11.084s wall clock time, 10.9M memory peak, 13.8M read from disk, 14M written to disk.
Nov 24 04:48:02 evo-x2 memory-emergency-guard-check[3289744]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.64% sustained (max disk busy 97.8%, MemAvailable=56.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:50:08 evo-x2 memory-emergency-guard-check[3339021]: MEMORY EMERGENCY IO-PAUSE (trip #12836, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 5.024s wall clock time, 13.1M memory peak, 6.1M read from disk, 31.6M written to disk.
Nov 24 04:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:52:35 evo-x2 memory-emergency-guard-check[3562983]: MEMORY EMERGENCY IO-PAUSE (trip #12837, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 607ms CPU time over 1.456s wall clock time, 11.5M memory peak, 3.5M read from disk, 28.6M written to disk.
Nov 24 04:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:56:10 evo-x2 memory-emergency-guard-check[3834969]: MEMORY EMERGENCY IO-PAUSE (trip #12838, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 3.323s wall clock time, 12.1M memory peak, 3.6M read from disk, 32.1M written to disk.
Nov 24 04:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:58:07 evo-x2 memory-emergency-guard-check[3891661]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.89% sustained (max disk busy 95.8%, MemAvailable=57.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 04:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:58:39 evo-x2 memory-emergency-guard-check[3901932]: MEMORY EMERGENCY IO-PAUSE (trip #12839, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 04:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 2.345s wall clock time, 12.3M memory peak, 7.5M read from disk, 31.6M written to disk.
Nov 24 04:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 04:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:01:13 evo-x2 memory-emergency-guard-check[3986787]: MEMORY EMERGENCY IO-PAUSE (trip #12840, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 3.379s wall clock time, 12.6M memory peak, 4.9M read from disk, 23M written to disk.
Nov 24 05:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:05:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:06:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:07:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:21:48 evo-x2 memory-emergency-guard-check[1084774]: MEMORY EMERGENCY IO-PAUSE (trip #12841, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 854ms CPU time over 1.041s wall clock time, 14.4M memory peak, 880K read from disk, 12.3M written to disk.
Nov 24 05:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:23:18 evo-x2 memory-emergency-guard-check[1151515]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.28% sustained (max disk busy 24.4%, MemAvailable=55.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 05:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:24:19 evo-x2 memory-emergency-guard-check[1200621]: MEMORY EMERGENCY IO-PAUSE (trip #12842, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 969ms wall clock time, 10.2M memory peak, 4.5M read from disk, 39.3M written to disk.
Nov 24 05:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:26:50 evo-x2 memory-emergency-guard-check[1314074]: MEMORY EMERGENCY IO-PAUSE (trip #12843, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 766ms CPU time over 891ms wall clock time, 12.1M memory peak, 1.2M read from disk, 24.9M written to disk.
Nov 24 05:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:29:21 evo-x2 memory-emergency-guard-check[1429912]: MEMORY EMERGENCY IO-PAUSE (trip #12844, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.095s CPU time over 1.613s wall clock time, 9M memory peak, 3.3M read from disk, 50M written to disk.
Nov 24 05:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:31:51 evo-x2 memory-emergency-guard-check[1519053]: MEMORY EMERGENCY IO-PAUSE (trip #12845, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 757ms CPU time over 1.015s wall clock time, 11.5M memory peak, 384K read from disk, 44.2M written to disk.
Nov 24 05:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:33:20 evo-x2 memory-emergency-guard-check[1569053]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.54% sustained (max disk busy 99.9%, MemAvailable=61.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 05:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:34:20 evo-x2 memory-emergency-guard-check[1601435]: MEMORY EMERGENCY IO-PAUSE (trip #12846, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 696ms CPU time over 899ms wall clock time, 10.2M memory peak, 1.5M read from disk, 37.9M written to disk.
Nov 24 05:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:36:50 evo-x2 memory-emergency-guard-check[1745299]: MEMORY EMERGENCY IO-PAUSE (trip #12847, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 813ms wall clock time, 10.7M memory peak, 2.2M read from disk, 22.7M written to disk.
Nov 24 05:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:39:21 evo-x2 memory-emergency-guard-check[1918507]: MEMORY EMERGENCY IO-PAUSE (trip #12848, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 811ms CPU time over 1.342s wall clock time, 11.6M memory peak, 17.8M read from disk, 50.2M written to disk.
Nov 24 05:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:40:00 evo-x2 btrbk-admission[1950063]: REFUSE: btrbk-forgejo — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 24 05:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:41:55 evo-x2 memory-emergency-guard-check[2058107]: sort: fflush failed: 'standard output': Broken pipe
Nov 24 05:41:55 evo-x2 memory-emergency-guard-check[2058107]: sort: write error
Nov 24 05:41:55 evo-x2 memory-emergency-guard-check[2047919]: MEMORY EMERGENCY IO-PAUSE (trip #12849, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.027s CPU time over 5.517s wall clock time, 11.2M memory peak, 9.3M read from disk, 38.7M written to disk.
Nov 24 05:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:43:20 evo-x2 memory-emergency-guard-check[2153105]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.94% sustained (max disk busy 97.3%, MemAvailable=54.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 05:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:45:14 evo-x2 memory-emergency-guard-check[2192123]: MEMORY EMERGENCY IO-PAUSE (trip #12850, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.727s CPU time over 53.752s wall clock time, 8.6M memory peak, 38.9M read from disk, 48.6M written to disk.
Nov 24 05:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:48:16 evo-x2 memory-emergency-guard-check[2501862]: MEMORY EMERGENCY IO-PAUSE (trip #12851, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.046s CPU time over 2.099s wall clock time, 10.1M memory peak, 1M read from disk, 7.6M written to disk.
Nov 24 05:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:49:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:56:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:57:54 evo-x2 memory-emergency-guard-check[2900880]: MEMORY EMERGENCY IO-PAUSE (trip #12852, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 05:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 868ms CPU time over 9.306s wall clock time, 11M memory peak, 12.4M read from disk, 57.2M written to disk.
Nov 24 05:58:15 evo-x2 memory-emergency-guard-check[2922006]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.71% sustained (max disk busy 98.9%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 05:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 05:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:00:23 evo-x2 memory-emergency-guard-check[2974896]: MEMORY EMERGENCY IO-PAUSE (trip #12853, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 812ms CPU time over 8.185s wall clock time, 10.4M memory peak, 12.5M read from disk, 8.1M written to disk.
Nov 24 06:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:02:53 evo-x2 memory-emergency-guard-check[3063418]: MEMORY EMERGENCY IO-PAUSE (trip #12854, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.153s CPU time over 8.343s wall clock time, 9M memory peak, 12.4M read from disk, 98.8M written to disk.
Nov 24 06:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:05:15 evo-x2 memory-emergency-guard-check[3153248]: MEMORY EMERGENCY IO-PAUSE (trip #12855, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 635ms CPU time over 779ms wall clock time, 10.6M memory peak, 3.2M read from disk, 32.7M written to disk.
Nov 24 06:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:07:46 evo-x2 memory-emergency-guard-check[3257674]: MEMORY EMERGENCY IO-PAUSE (trip #12856, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 689ms CPU time over 1.268s wall clock time, 11.6M memory peak, 1.2M read from disk, 26.3M written to disk.
Nov 24 06:08:15 evo-x2 memory-emergency-guard-check[3282860]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.57% sustained (max disk busy 100.0%, MemAvailable=56.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 06:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:10:18 evo-x2 memory-emergency-guard-check[3421101]: MEMORY EMERGENCY IO-PAUSE (trip #12857, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.122s CPU time over 2.843s wall clock time, 9.4M memory peak, 34.3M read from disk, 61.9M written to disk.
Nov 24 06:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:14:46 evo-x2 memory-emergency-guard-check[3705449]: MEMORY EMERGENCY IO-PAUSE (trip #12858, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 811ms CPU time over 1.327s wall clock time, 12M memory peak, 16.9M read from disk, 78.1M written to disk.
Nov 24 06:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:17:16 evo-x2 memory-emergency-guard-check[3809244]: MEMORY EMERGENCY IO-PAUSE (trip #12859, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 1.112s wall clock time, 11.4M memory peak, 8.3M read from disk, 41.5M written to disk.
Nov 24 06:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:18:15 evo-x2 memory-emergency-guard-check[3848777]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.54% sustained (max disk busy 99.9%, MemAvailable=56.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 06:18:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:18:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:19:46 evo-x2 memory-emergency-guard-check[3896864]: MEMORY EMERGENCY IO-PAUSE (trip #12860, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 684ms CPU time over 902ms wall clock time, 12.3M memory peak, 6.1M read from disk, 39.8M written to disk.
Nov 24 06:20:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:21:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:22:16 evo-x2 memory-emergency-guard-check[3986637]: MEMORY EMERGENCY IO-PAUSE (trip #12861, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 673ms CPU time over 893ms wall clock time, 11M memory peak, 6.4M read from disk, 36.5M written to disk.
Nov 24 06:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:24:53 evo-x2 memory-emergency-guard-check[4139333]: MEMORY EMERGENCY IO-PAUSE (trip #12862, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.750s CPU time over 8.194s wall clock time, 7.3M memory peak, 12.7M read from disk, 62.9M written to disk.
Nov 24 06:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:27:55 evo-x2 memory-emergency-guard-check[182287]: MEMORY EMERGENCY IO-PAUSE (trip #12863, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.357s CPU time over 4.374s wall clock time, 8.8M memory peak, 20.4M read from disk, 73.2M written to disk.
Nov 24 06:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:29:52 evo-x2 memory-emergency-guard-check[400514]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.49% sustained (max disk busy 94.5%, MemAvailable=51.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 06:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:30:22 evo-x2 memory-emergency-guard-check[433258]: MEMORY EMERGENCY IO-PAUSE (trip #12864, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 811ms CPU time over 1.103s wall clock time, 11.1M memory peak, 4.3M read from disk, 42.8M written to disk.
Nov 24 06:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:35:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:36:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:36:53 evo-x2 memory-emergency-guard-check[1115369]: MEMORY EMERGENCY IO-PAUSE (trip #12865, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.103s CPU time over 2.077s wall clock time, 11.5M memory peak, 27.7M read from disk, 44.2M written to disk.
Nov 24 06:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:37:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:37:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 150ms CPU time over 312ms wall clock time, 9M memory peak, 2.2M read from disk, 4K written to disk.
Nov 24 06:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:39:23 evo-x2 memory-emergency-guard-check[1235212]: MEMORY EMERGENCY IO-PAUSE (trip #12866, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 889ms CPU time over 1.522s wall clock time, 13.2M memory peak, 38.7M read from disk, 79M written to disk.
Nov 24 06:39:51 evo-x2 memory-emergency-guard-check[1258782]: MEMORY EMERGENCY still active (I/O PSI some avg60=82.83% sustained (max disk busy 99.6%, MemAvailable=19.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 06:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:41:53 evo-x2 memory-emergency-guard-check[1358361]: MEMORY EMERGENCY IO-PAUSE (trip #12867, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 921ms CPU time over 1.320s wall clock time, 10.8M memory peak, 12.8M read from disk, 40.5M written to disk.
Nov 24 06:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:44:59 evo-x2 memory-emergency-guard-check[1530144]: MEMORY EMERGENCY IO-PAUSE (trip #12868, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.519s CPU time over 37.947s wall clock time, 9.2M memory peak, 7.8M read from disk, 34.2M written to disk.
Nov 24 06:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:46:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:47:05 evo-x2 memory-emergency-guard-check[1762745]: MEMORY EMERGENCY IO-PAUSE (trip #12869, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.648s CPU time over 5.085s wall clock time, 12.6M memory peak, 576K read from disk, 53.6M written to disk.
Nov 24 06:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:49:31 evo-x2 memory-emergency-guard-check[1964592]: MEMORY EMERGENCY IO-PAUSE (trip #12870, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 766ms CPU time over 1.042s wall clock time, 11.6M memory peak, 1.5M read from disk, 72.2M written to disk.
Nov 24 06:50:00 evo-x2 memory-emergency-guard-check[1984420]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.62% sustained (max disk busy 100.0%, MemAvailable=58.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 06:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:52:01 evo-x2 memory-emergency-guard-check[2044849]: MEMORY EMERGENCY IO-PAUSE (trip #12871, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 656ms CPU time over 955ms wall clock time, 11.9M memory peak, 992K read from disk, 33.2M written to disk.
Nov 24 06:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:54:32 evo-x2 memory-emergency-guard-check[2207907]: MEMORY EMERGENCY IO-PAUSE (trip #12872, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.045s CPU time over 2.125s wall clock time, 9.6M memory peak, 4.2M read from disk, 57.9M written to disk.
Nov 24 06:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:55:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:57:01 evo-x2 memory-emergency-guard-check[2391878]: MEMORY EMERGENCY IO-PAUSE (trip #12873, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 926ms CPU time over 1.305s wall clock time, 9.8M memory peak, 1.4M read from disk, 45.9M written to disk.
Nov 24 06:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:59:31 evo-x2 memory-emergency-guard-check[2500870]: MEMORY EMERGENCY IO-PAUSE (trip #12874, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 06:59:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 06:59:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 691ms CPU time over 923ms wall clock time, 10.5M memory peak, 1.5M read from disk, 50.7M written to disk.
Nov 24 07:00:00 evo-x2 memory-emergency-guard-check[2524992]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.38% sustained (max disk busy 95.3%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:02:01 evo-x2 memory-emergency-guard-check[2658733]: MEMORY EMERGENCY IO-PAUSE (trip #12875, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 888ms CPU time over 1.453s wall clock time, 10.3M memory peak, 6.8M read from disk, 87.7M written to disk.
Nov 24 07:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:04:33 evo-x2 memory-emergency-guard-check[2825379]: MEMORY EMERGENCY IO-PAUSE (trip #12876, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 648ms CPU time over 3.371s wall clock time, 11.2M memory peak, 596K read from disk, 30.8M written to disk.
Nov 24 07:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 149ms CPU time over 343ms wall clock time, 12.3M memory peak, 3.4M read from disk, 4K written to disk.
Nov 24 07:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:07:05 evo-x2 memory-emergency-guard-check[2955693]: MEMORY EMERGENCY IO-PAUSE (trip #12877, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.116s CPU time over 5.558s wall clock time, 9.4M memory peak, 17.4M read from disk, 47M written to disk.
Nov 24 07:07:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:08:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:09:34 evo-x2 memory-emergency-guard-check[3083595]: MEMORY EMERGENCY IO-PAUSE (trip #12878, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.033s CPU time over 3.854s wall clock time, 9.7M memory peak, 3.6M read from disk, 37.7M written to disk.
Nov 24 07:10:00 evo-x2 memory-emergency-guard-check[3113239]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.14% sustained (max disk busy 98.4%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:12:05 evo-x2 memory-emergency-guard-check[3188716]: MEMORY EMERGENCY IO-PAUSE (trip #12879, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 4.691s wall clock time, 10.8M memory peak, 3.5M read from disk, 39M written to disk.
Nov 24 07:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:14:31 evo-x2 memory-emergency-guard-check[3299065]: MEMORY EMERGENCY IO-PAUSE (trip #12880, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 883ms wall clock time, 11.6M memory peak, 3.6M read from disk, 36.4M written to disk.
Nov 24 07:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:17:01 evo-x2 memory-emergency-guard-check[3463006]: MEMORY EMERGENCY IO-PAUSE (trip #12881, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 1.103s wall clock time, 11.5M memory peak, 3.7M read from disk, 33.2M written to disk.
Nov 24 07:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:19:32 evo-x2 memory-emergency-guard-check[3600937]: MEMORY EMERGENCY IO-PAUSE (trip #12882, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 926ms CPU time over 1.443s wall clock time, 10.8M memory peak, 16.6M read from disk, 48.1M written to disk.
Nov 24 07:20:00 evo-x2 memory-emergency-guard-check[3655127]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.77% sustained (max disk busy 99.7%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:22:01 evo-x2 memory-emergency-guard-check[3731677]: MEMORY EMERGENCY IO-PAUSE (trip #12883, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 813ms wall clock time, 11.1M memory peak, 2.4M read from disk, 28.9M written to disk.
Nov 24 07:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:24:31 evo-x2 memory-emergency-guard-check[3806690]: MEMORY EMERGENCY IO-PAUSE (trip #12884, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 868ms wall clock time, 10.7M memory peak, 3.9M read from disk, 33.2M written to disk.
Nov 24 07:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:27:01 evo-x2 memory-emergency-guard-check[3924338]: MEMORY EMERGENCY IO-PAUSE (trip #12885, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 684ms CPU time over 933ms wall clock time, 11.5M memory peak, 7.5M read from disk, 31.4M written to disk.
Nov 24 07:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:29:32 evo-x2 memory-emergency-guard-check[4056164]: MEMORY EMERGENCY IO-PAUSE (trip #12886, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 854ms CPU time over 1.477s wall clock time, 10.8M memory peak, 4.6M read from disk, 42.8M written to disk.
Nov 24 07:30:01 evo-x2 memory-emergency-guard-check[4078139]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.41% sustained (max disk busy 97.1%, MemAvailable=52.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:32:02 evo-x2 memory-emergency-guard-check[4172789]: MEMORY EMERGENCY IO-PAUSE (trip #12887, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 786ms CPU time over 1.114s wall clock time, 11.6M memory peak, 5.9M read from disk, 42.6M written to disk.
Nov 24 07:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 267ms CPU time over 659ms wall clock time, 9.7M memory peak, 4.9M read from disk, 4K written to disk.
Nov 24 07:34:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:45:32 evo-x2 memory-emergency-guard-check[546638]: MEMORY EMERGENCY IO-PAUSE (trip #12888, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 750ms wall clock time, 11.6M memory peak, 2.5M read from disk, 22.9M written to disk.
Nov 24 07:46:01 evo-x2 memory-emergency-guard-check[568134]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.12% sustained (max disk busy 95.9%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:48:02 evo-x2 memory-emergency-guard-check[678882]: MEMORY EMERGENCY IO-PAUSE (trip #12889, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 860ms wall clock time, 11.8M memory peak, 8.3M read from disk, 40.7M written to disk.
Nov 24 07:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:50:32 evo-x2 memory-emergency-guard-check[756324]: MEMORY EMERGENCY IO-PAUSE (trip #12890, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 668ms CPU time over 804ms wall clock time, 10.8M memory peak, 2.1M read from disk, 28.1M written to disk.
Nov 24 07:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:51:54 evo-x2 pma[2247]:   │ docs/status/2026-11-02_15-04_memory-emergency-guard-io-restore-gate-session.md
Nov 24 07:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:53:02 evo-x2 memory-emergency-guard-check[888047]: MEMORY EMERGENCY IO-PAUSE (trip #12891, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 715ms CPU time over 1.234s wall clock time, 11.4M memory peak, 24.2M read from disk, 49.4M written to disk.
Nov 24 07:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:54:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:55:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:55:32 evo-x2 memory-emergency-guard-check[952593]: MEMORY EMERGENCY IO-PAUSE (trip #12892, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 745ms wall clock time, 11.3M memory peak, 3.8M read from disk, 23.9M written to disk.
Nov 24 07:56:01 evo-x2 memory-emergency-guard-check[975903]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.22% sustained (max disk busy 100.0%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 07:56:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:57:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:58:02 evo-x2 memory-emergency-guard-check[1034723]: MEMORY EMERGENCY IO-PAUSE (trip #12893, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 07:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 1.295s wall clock time, 12.3M memory peak, 5.8M read from disk, 24.1M written to disk.
Nov 24 07:58:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:59:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 07:59:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:00:34 evo-x2 memory-emergency-guard-check[1160102]: MEMORY EMERGENCY IO-PAUSE (trip #12894, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.354s CPU time over 2.621s wall clock time, 11.2M memory peak, 46.8M read from disk, 104.6M written to disk.
Nov 24 08:01:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:03:02 evo-x2 memory-emergency-guard-check[1249253]: MEMORY EMERGENCY IO-PAUSE (trip #12895, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 877ms wall clock time, 12.2M memory peak, 6M read from disk, 40M written to disk.
Nov 24 08:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:05:32 evo-x2 memory-emergency-guard-check[1337857]: MEMORY EMERGENCY IO-PAUSE (trip #12896, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 704ms CPU time over 1.017s wall clock time, 11.7M memory peak, 8.5M read from disk, 51.8M written to disk.
Nov 24 08:06:02 evo-x2 memory-emergency-guard-check[1365132]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.49% sustained (max disk busy 81.1%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 08:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:08:02 evo-x2 memory-emergency-guard-check[1422718]: MEMORY EMERGENCY IO-PAUSE (trip #12897, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 1.178s wall clock time, 11.4M memory peak, 1.3M read from disk, 17.8M written to disk.
Nov 24 08:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:10:35 evo-x2 memory-emergency-guard-check[1513084]: MEMORY EMERGENCY IO-PAUSE (trip #12898, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 3.083s wall clock time, 11.1M memory peak, 20.7M read from disk, 85.4M written to disk.
Nov 24 08:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:13:03 evo-x2 memory-emergency-guard-check[1618186]: MEMORY EMERGENCY IO-PAUSE (trip #12899, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 1.003s wall clock time, 11.2M memory peak, 5.5M read from disk, 39.3M written to disk.
Nov 24 08:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:14:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:15:34 evo-x2 memory-emergency-guard-check[1692470]: MEMORY EMERGENCY IO-PAUSE (trip #12900, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 1.250s wall clock time, 12.1M memory peak, 688K read from disk, 35M written to disk.
Nov 24 08:16:03 evo-x2 memory-emergency-guard-check[1708750]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.43% sustained (max disk busy 31.3%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 08:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:20:04 evo-x2 memory-emergency-guard-check[1830386]: MEMORY EMERGENCY IO-PAUSE (trip #12901, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 607ms CPU time over 792ms wall clock time, 12.1M memory peak, 5.6M read from disk, 24.4M written to disk.
Nov 24 08:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:23:05 evo-x2 memory-emergency-guard-check[1918599]: MEMORY EMERGENCY IO-PAUSE (trip #12902, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 591ms CPU time over 966ms wall clock time, 12.7M memory peak, 2.9M read from disk, 26M written to disk.
Nov 24 08:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:25:37 evo-x2 memory-emergency-guard-check[1992072]: MEMORY EMERGENCY IO-PAUSE (trip #12903, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 942ms wall clock time, 11.6M memory peak, 2.2M read from disk, 25M written to disk.
Nov 24 08:26:06 evo-x2 memory-emergency-guard-check[2012149]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.61% sustained (max disk busy 92.8%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 08:26:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:28:07 evo-x2 memory-emergency-guard-check[2065300]: MEMORY EMERGENCY IO-PAUSE (trip #12904, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 746ms wall clock time, 10.8M memory peak, 1M read from disk, 22M written to disk.
Nov 24 08:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:30:38 evo-x2 memory-emergency-guard-check[2164448]: MEMORY EMERGENCY IO-PAUSE (trip #12905, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 948ms CPU time over 2.060s wall clock time, 9.5M memory peak, 25M read from disk, 56.4M written to disk.
Nov 24 08:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:33:08 evo-x2 memory-emergency-guard-check[2275736]: MEMORY EMERGENCY IO-PAUSE (trip #12906, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 721ms CPU time over 1.344s wall clock time, 12.3M memory peak, 4.5M read from disk, 82.6M written to disk.
Nov 24 08:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:35:38 evo-x2 memory-emergency-guard-check[2372656]: MEMORY EMERGENCY IO-PAUSE (trip #12907, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 1.167s wall clock time, 10.4M memory peak, 2M read from disk, 32.6M written to disk.
Nov 24 08:36:07 evo-x2 memory-emergency-guard-check[2403248]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.65% sustained (max disk busy 88.4%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 08:36:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:36:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:38:07 evo-x2 memory-emergency-guard-check[2473619]: MEMORY EMERGENCY IO-PAUSE (trip #12908, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 739ms wall clock time, 11.6M memory peak, 576K read from disk, 19.6M written to disk.
Nov 24 08:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:40:38 evo-x2 memory-emergency-guard-check[2574846]: MEMORY EMERGENCY IO-PAUSE (trip #12909, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 878ms CPU time over 1.695s wall clock time, 10.2M memory peak, 832K read from disk, 36M written to disk.
Nov 24 08:41:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:43:08 evo-x2 memory-emergency-guard-check[2673313]: MEMORY EMERGENCY IO-PAUSE (trip #12910, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 735ms CPU time over 951ms wall clock time, 11.4M memory peak, 2M read from disk, 34.5M written to disk.
Nov 24 08:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:49:38 evo-x2 memory-emergency-guard-check[3127825]: MEMORY EMERGENCY IO-PAUSE (trip #12911, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 935ms CPU time over 1.208s wall clock time, 11.3M memory peak, 1.6M read from disk, 21.2M written to disk.
Nov 24 08:50:07 evo-x2 memory-emergency-guard-check[3150793]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.57% sustained (max disk busy 87.6%, MemAvailable=47.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 08:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:52:08 evo-x2 memory-emergency-guard-check[3275245]: MEMORY EMERGENCY IO-PAUSE (trip #12912, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 726ms CPU time over 1.095s wall clock time, 10.9M memory peak, 5M read from disk, 52.5M written to disk.
Nov 24 08:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:57:38 evo-x2 memory-emergency-guard-check[3628307]: MEMORY EMERGENCY IO-PAUSE (trip #12913, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 08:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 664ms wall clock time, 11.5M memory peak, 384K read from disk, 12.2M written to disk.
Nov 24 08:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 08:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:00:09 evo-x2 memory-emergency-guard-check[3733051]: MEMORY EMERGENCY IO-PAUSE (trip #12914, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 761ms CPU time over 1.231s wall clock time, 9.6M memory peak, 932K read from disk, 13.1M written to disk.
Nov 24 09:00:38 evo-x2 memory-emergency-guard-check[3769126]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.41% sustained (max disk busy 96.7%, MemAvailable=54.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:02:39 evo-x2 memory-emergency-guard-check[3946370]: MEMORY EMERGENCY IO-PAUSE (trip #12915, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 898ms wall clock time, 10.8M memory peak, 6.7M read from disk, 49M written to disk.
Nov 24 09:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:05:09 evo-x2 memory-emergency-guard-check[4030653]: MEMORY EMERGENCY IO-PAUSE (trip #12916, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 621ms CPU time over 843ms wall clock time, 10.9M memory peak, 2.3M read from disk, 29.4M written to disk.
Nov 24 09:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:07:40 evo-x2 memory-emergency-guard-check[4149321]: MEMORY EMERGENCY IO-PAUSE (trip #12917, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 754ms CPU time over 1.423s wall clock time, 10.9M memory peak, 43.7M read from disk, 54.6M written to disk.
Nov 24 09:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:10:10 evo-x2 memory-emergency-guard-check[74228]: MEMORY EMERGENCY IO-PAUSE (trip #12918, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 703ms CPU time over 1.802s wall clock time, 11M memory peak, 2.9M read from disk, 28.8M written to disk.
Nov 24 09:10:38 evo-x2 memory-emergency-guard-check[97908]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.78% sustained (max disk busy 100.0%, MemAvailable=17.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:12:21 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=7.31%, MemAvailable=25.9%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4989 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 24 09:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:12:54 evo-x2 memory-emergency-guard-check[162383]: MEMORY EMERGENCY IO-PAUSE (trip #12919, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 718ms CPU time over 15.846s wall clock time, 11.8M memory peak, 23.7M read from disk, 3.2M written to disk.
Nov 24 09:13:01 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4990 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 24 09:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:14:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:15:12 evo-x2 memory-emergency-guard-check[283752]: MEMORY EMERGENCY IO-PAUSE (trip #12920, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 3.473s wall clock time, 10.5M memory peak, 21.2M read from disk, 42M written to disk.
Nov 24 09:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:21:37 evo-x2 memory-emergency-guard-check[390128]: MEMORY EMERGENCY IO-PAUSE (trip #12921, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.066s CPU time over 3min 35.702s wall clock time, 8M memory peak, 184K read from disk, 139.9M written to disk.
Nov 24 09:21:39 evo-x2 memory-emergency-guard-check[675433]: MEMORY EMERGENCY IO-PAUSE (trip #12922, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 893ms CPU time over 2.139s wall clock time, 10.1M memory peak, 148K read from disk, 15.6M written to disk.
Nov 24 09:22:07 evo-x2 memory-emergency-guard-check[724480]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.83% sustained (max disk busy 79.2%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:24:08 evo-x2 memory-emergency-guard-check[803484]: MEMORY EMERGENCY IO-PAUSE (trip #12923, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 805ms wall clock time, 11.9M memory peak, 1M read from disk, 36.6M written to disk.
Nov 24 09:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:26:39 evo-x2 memory-emergency-guard-check[913059]: MEMORY EMERGENCY IO-PAUSE (trip #12924, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 630ms CPU time over 2.128s wall clock time, 11.9M memory peak, 7.9M read from disk, 43.3M written to disk.
Nov 24 09:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:29:10 evo-x2 memory-emergency-guard-check[972321]: MEMORY EMERGENCY IO-PAUSE (trip #12925, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 3.632s wall clock time, 13.2M memory peak, 4.4M read from disk, 48.7M written to disk.
Nov 24 09:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:31:38 evo-x2 memory-emergency-guard-check[1043333]: MEMORY EMERGENCY IO-PAUSE (trip #12926, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:31:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 860ms wall clock time, 12.2M memory peak, 1.2M read from disk, 28.6M written to disk.
Nov 24 09:32:07 evo-x2 memory-emergency-guard-check[1058472]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.94% sustained (max disk busy 86.4%, MemAvailable=57.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:34:08 evo-x2 memory-emergency-guard-check[1101034]: MEMORY EMERGENCY IO-PAUSE (trip #12927, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 611ms CPU time over 850ms wall clock time, 11.5M memory peak, 736K read from disk, 47M written to disk.
Nov 24 09:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:35:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:36:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:36:38 evo-x2 memory-emergency-guard-check[1168812]: MEMORY EMERGENCY IO-PAUSE (trip #12928, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 580ms CPU time over 646ms wall clock time, 12.3M memory peak, 416K read from disk, 18.4M written to disk.
Nov 24 09:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:39:08 evo-x2 memory-emergency-guard-check[1228487]: MEMORY EMERGENCY IO-PAUSE (trip #12929, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 638ms wall clock time, 13.7M memory peak, 336K read from disk, 18.8M written to disk.
Nov 24 09:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:41:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:41:38 evo-x2 memory-emergency-guard-check[1294649]: MEMORY EMERGENCY IO-PAUSE (trip #12930, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 664ms wall clock time, 12.3M memory peak, 352K read from disk, 19.7M written to disk.
Nov 24 09:42:07 evo-x2 memory-emergency-guard-check[1312020]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.98% sustained (max disk busy 83.3%, MemAvailable=56.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:44:08 evo-x2 memory-emergency-guard-check[1355700]: MEMORY EMERGENCY IO-PAUSE (trip #12931, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 566ms CPU time over 678ms wall clock time, 11.5M memory peak, 368K read from disk, 20.4M written to disk.
Nov 24 09:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:46:38 evo-x2 memory-emergency-guard-check[1429361]: MEMORY EMERGENCY IO-PAUSE (trip #12932, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 580ms CPU time over 812ms wall clock time, 12.5M memory peak, 112K read from disk, 25.4M written to disk.
Nov 24 09:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:49:08 evo-x2 memory-emergency-guard-check[1493744]: MEMORY EMERGENCY IO-PAUSE (trip #12933, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 709ms wall clock time, 11.4M memory peak, 224K read from disk, 17.6M written to disk.
Nov 24 09:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:51:39 evo-x2 memory-emergency-guard-check[1562347]: MEMORY EMERGENCY IO-PAUSE (trip #12934, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 547ms CPU time over 632ms wall clock time, 12.7M memory peak, 976K read from disk, 24.4M written to disk.
Nov 24 09:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:55:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:55:41 evo-x2 memory-emergency-guard-check[1657076]: MEMORY EMERGENCY IO-PAUSE (trip #12935, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 09:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 900ms wall clock time, 12.8M memory peak, 1.6M read from disk, 60.2M written to disk.
Nov 24 09:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:56:42 evo-x2 memory-emergency-guard-check[1693957]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.40% sustained (max disk busy 30.4%, MemAvailable=56.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 09:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:57:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 09:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:00:46 evo-x2 memory-emergency-guard-check[1782153]: MEMORY EMERGENCY IO-PAUSE (trip #12936, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:00:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:00:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 968ms wall clock time, 11.4M memory peak, 7.4M read from disk, 51.9M written to disk.
Nov 24 10:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:01:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:02:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:02:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:04:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:05:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:05:48 evo-x2 memory-emergency-guard-check[1896669]: MEMORY EMERGENCY IO-PAUSE (trip #12937, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:05:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:05:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 869ms wall clock time, 13.1M memory peak, 4.2M read from disk, 53.9M written to disk.
Nov 24 10:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:07:51 evo-x2 memory-emergency-guard-check[1949423]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.48% sustained (max disk busy 27.6%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (124s < 150s, 26s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 10:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:08:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:09:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:10:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:11:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:11:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:15:37 evo-x2 memory-emergency-guard-check[2111700]: MEMORY EMERGENCY IO-PAUSE (trip #12938, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:15:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 1.211s wall clock time, 13.2M memory peak, 1.2M read from disk, 38.4M written to disk.
Nov 24 10:16:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:19:07 evo-x2 memory-emergency-guard-check[2196729]: MEMORY EMERGENCY IO-PAUSE (trip #12939, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 695ms wall clock time, 12.6M memory peak, 416K read from disk, 24.7M written to disk.
Nov 24 10:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:23:11 evo-x2 memory-emergency-guard-check[2286438]: MEMORY EMERGENCY IO-PAUSE (trip #12940, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 546ms CPU time over 4.110s wall clock time, 13.2M memory peak, 432K read from disk, 15.8M written to disk.
Nov 24 10:23:37 evo-x2 memory-emergency-guard-check[2301145]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.35% sustained (max disk busy 88.6%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 10:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:25:38 evo-x2 memory-emergency-guard-check[2341433]: MEMORY EMERGENCY IO-PAUSE (trip #12941, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 1.091s wall clock time, 13.5M memory peak, 880K read from disk, 30.2M written to disk.
Nov 24 10:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:28:39 evo-x2 memory-emergency-guard-check[2416242]: MEMORY EMERGENCY IO-PAUSE (trip #12942, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 556ms CPU time over 630ms wall clock time, 13.1M memory peak, 288K read from disk, 22.2M written to disk.
Nov 24 10:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:30:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:31:11 evo-x2 memory-emergency-guard-check[2475235]: MEMORY EMERGENCY IO-PAUSE (trip #12943, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 651ms wall clock time, 12.9M memory peak, 480K read from disk, 26.3M written to disk.
Nov 24 10:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:34:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:40:00 evo-x2 memory-emergency-guard-check[2670798]: MEMORY EMERGENCY IO-PAUSE (trip #12944, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 587ms CPU time over 910ms wall clock time, 13.2M memory peak, 5.3M read from disk, 50.7M written to disk.
Nov 24 10:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:42:31 evo-x2 memory-emergency-guard-check[2737839]: MEMORY EMERGENCY IO-PAUSE (trip #12945, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 529ms CPU time over 597ms wall clock time, 12.3M memory peak, 224K read from disk, 20.4M written to disk.
Nov 24 10:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:45:03 evo-x2 memory-emergency-guard-check[2792774]: MEMORY EMERGENCY IO-PAUSE (trip #12946, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 655ms wall clock time, 13.7M memory peak, 496K read from disk, 23.7M written to disk.
Nov 24 10:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:46:02 evo-x2 memory-emergency-guard-check[2819291]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.04% sustained (max disk busy 29.2%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 10:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:48:36 evo-x2 memory-emergency-guard-check[2878973]: MEMORY EMERGENCY IO-PAUSE (trip #12947, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 573ms CPU time over 683ms wall clock time, 12M memory peak, 944K read from disk, 31.5M written to disk.
Nov 24 10:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:53:37 evo-x2 memory-emergency-guard-check[2997625]: MEMORY EMERGENCY IO-PAUSE (trip #12948, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 587ms CPU time over 691ms wall clock time, 12.5M memory peak, 688K read from disk, 31.7M written to disk.
Nov 24 10:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:56:07 evo-x2 memory-emergency-guard-check[3064341]: MEMORY EMERGENCY IO-PAUSE (trip #12949, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 679ms wall clock time, 11.4M memory peak, 368K read from disk, 32.1M written to disk.
Nov 24 10:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:57:37 evo-x2 memory-emergency-guard-check[3104987]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.18% sustained (max disk busy 21.3%, MemAvailable=55.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 10:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:58:38 evo-x2 memory-emergency-guard-check[3126886]: MEMORY EMERGENCY IO-PAUSE (trip #12950, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 10:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 534ms CPU time over 609ms wall clock time, 11.7M memory peak, 224K read from disk, 21.3M written to disk.
Nov 24 10:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 10:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:01:45 evo-x2 memory-emergency-guard-check[3199123]: MEMORY EMERGENCY IO-PAUSE (trip #12951, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 704ms CPU time over 4.861s wall clock time, 14.8M memory peak, 6.9M read from disk, 81.8M written to disk.
Nov 24 11:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:04:14 evo-x2 memory-emergency-guard-check[3252598]: MEMORY EMERGENCY IO-PAUSE (trip #12952, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 3.499s wall clock time, 13.5M memory peak, 1.5M read from disk, 35.7M written to disk.
Nov 24 11:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:08:45 evo-x2 memory-emergency-guard-check[3355091]: MEMORY EMERGENCY IO-PAUSE (trip #12953, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 627ms wall clock time, 13.5M memory peak, 128K read from disk, 28.4M written to disk.
Nov 24 11:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:11:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:13:47 evo-x2 memory-emergency-guard-check[3468338]: MEMORY EMERGENCY IO-PAUSE (trip #12954, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 969ms wall clock time, 12.7M memory peak, 720K read from disk, 40.4M written to disk.
Nov 24 11:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:16:17 evo-x2 memory-emergency-guard-check[3533661]: MEMORY EMERGENCY IO-PAUSE (trip #12955, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 592ms CPU time over 779ms wall clock time, 12.5M memory peak, 1.3M read from disk, 45.6M written to disk.
Nov 24 11:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:17:46 evo-x2 memory-emergency-guard-check[3574992]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.81% sustained (max disk busy 44.2%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 11:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:27:27 evo-x2 memory-emergency-guard-check[3791571]: MEMORY EMERGENCY IO-PAUSE (trip #12956, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 592ms CPU time over 660ms wall clock time, 10.5M memory peak, 128K read from disk, 12.1M written to disk.
Nov 24 11:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:30:03 evo-x2 memory-emergency-guard-check[3867241]: MEMORY EMERGENCY IO-PAUSE (trip #12957, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 730ms wall clock time, 13.3M memory peak, 448K read from disk, 25.3M written to disk.
Nov 24 11:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:31:02 evo-x2 memory-emergency-guard-check[3913600]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.69% sustained (max disk busy 36.6%, MemAvailable=54.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 11:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:32:33 evo-x2 memory-emergency-guard-check[4044221]: MEMORY EMERGENCY IO-PAUSE (trip #12958, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 821ms wall clock time, 11.3M memory peak, 448K read from disk, 36M written to disk.
Nov 24 11:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:35:04 evo-x2 memory-emergency-guard-check[4135421]: MEMORY EMERGENCY IO-PAUSE (trip #12959, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.016s CPU time over 2.017s wall clock time, 10.7M memory peak, 2.3M read from disk, 63M written to disk.
Nov 24 11:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:37:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:37:33 evo-x2 memory-emergency-guard-check[92197]: MEMORY EMERGENCY IO-PAUSE (trip #12960, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 782ms wall clock time, 11.7M memory peak, 1M read from disk, 29.9M written to disk.
Nov 24 11:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:40:07 evo-x2 memory-emergency-guard-check[157769]: MEMORY EMERGENCY IO-PAUSE (trip #12961, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 924ms CPU time over 1.172s wall clock time, 10.4M memory peak, 2.1M read from disk, 39.7M written to disk.
Nov 24 11:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:41:06 evo-x2 memory-emergency-guard-check[196523]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.74% sustained (max disk busy 100.0%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 11:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:42:37 evo-x2 memory-emergency-guard-check[251948]: MEMORY EMERGENCY IO-PAUSE (trip #12962, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 742ms CPU time over 978ms wall clock time, 10.4M memory peak, 2.5M read from disk, 35.3M written to disk.
Nov 24 11:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:44:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:45:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:47:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:50:38 evo-x2 memory-emergency-guard-check[641314]: MEMORY EMERGENCY IO-PAUSE (trip #12963, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.075s CPU time over 1.545s wall clock time, 9.9M memory peak, 5.6M read from disk, 37.2M written to disk.
Nov 24 11:51:07 evo-x2 memory-emergency-guard-check[671511]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.77% sustained (max disk busy 88.5%, MemAvailable=15.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 11:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:53:08 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: MEMORY STALL SUSTAINED; IO-PAUSE DISARMED" "Memory-stall freeze precursor, 2026-08-31 class (avg60=54.66%, avg10-episode bucket=2). Stop heavy builds / VM tests NOW; the guard is (about to be) sacrificing FastFlowLM. journalctl -u memory-emergency-guard -n 30 | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 5034 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 24 11:53:37 evo-x2 memory-emergency-guard-check[790106]: MEMORY EMERGENCY IO-PAUSE (trip #12964, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.176s wall clock time, 11.7M memory peak, 3.5M read from disk, 20.6M written to disk.
Nov 24 11:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:54:07 evo-x2 systemd[2044]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 5035 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 24 11:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:57:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:58:09 evo-x2 memory-emergency-guard-check[1048034]: MEMORY EMERGENCY IO-PAUSE (trip #12965, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 11:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 2.510s wall clock time, 13.2M memory peak, 13M read from disk, 45.1M written to disk.
Nov 24 11:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 11:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:02:11 evo-x2 memory-emergency-guard-check[1246309]: MEMORY EMERGENCY IO-PAUSE (trip #12966, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 941ms CPU time over 4.746s wall clock time, 14.5M memory peak, 55.2M read from disk, 107.8M written to disk.
Nov 24 12:02:36 evo-x2 memory-emergency-guard-check[1277877]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.40% sustained (max disk busy 81.0%, MemAvailable=51.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 12:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:04:37 evo-x2 memory-emergency-guard-check[1339235]: MEMORY EMERGENCY IO-PAUSE (trip #12967, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 752ms wall clock time, 12.9M memory peak, 1.6M read from disk, 29.3M written to disk.
Nov 24 12:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:07:07 evo-x2 memory-emergency-guard-check[1413580]: MEMORY EMERGENCY IO-PAUSE (trip #12968, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 634ms CPU time over 765ms wall clock time, 11.9M memory peak, 2.8M read from disk, 29.4M written to disk.
Nov 24 12:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:12:10 evo-x2 memory-emergency-guard-check[1569660]: MEMORY EMERGENCY IO-PAUSE (trip #12969, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 1.029s wall clock time, 11.9M memory peak, 7.6M read from disk, 50.1M written to disk.
Nov 24 12:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:14:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:14:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:15:42 evo-x2 memory-emergency-guard-check[1719959]: MEMORY EMERGENCY IO-PAUSE (trip #12970, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 841ms wall clock time, 12.1M memory peak, 3.4M read from disk, 35.1M written to disk.
Nov 24 12:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:17:12 evo-x2 memory-emergency-guard-check[1776065]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.42% sustained (max disk busy 41.7%, MemAvailable=42.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 12:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:21:16 evo-x2 memory-emergency-guard-check[1875742]: MEMORY EMERGENCY IO-PAUSE (trip #12971, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 557ms CPU time over 843ms wall clock time, 12.1M memory peak, 880K read from disk, 10.2M written to disk.
Nov 24 12:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:22:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:22:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:24:18 evo-x2 memory-emergency-guard-check[1956007]: MEMORY EMERGENCY IO-PAUSE (trip #12972, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 638ms CPU time over 782ms wall clock time, 10.7M memory peak, 604K read from disk, 8.3M written to disk.
Nov 24 12:24:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:26:49 evo-x2 memory-emergency-guard-check[2029084]: MEMORY EMERGENCY IO-PAUSE (trip #12973, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 612ms CPU time over 1.397s wall clock time, 10.5M memory peak, 2.3M read from disk, 22.7M written to disk.
Nov 24 12:27:18 evo-x2 memory-emergency-guard-check[2044750]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.54% sustained (max disk busy 83.9%, MemAvailable=54.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 12:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:29:19 evo-x2 memory-emergency-guard-check[2096823]: MEMORY EMERGENCY IO-PAUSE (trip #12974, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 608ms CPU time over 1.197s wall clock time, 10.8M memory peak, 2.2M read from disk, 25.8M written to disk.
Nov 24 12:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:30:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:30:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:31:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:31:48 evo-x2 memory-emergency-guard-check[2186742]: MEMORY EMERGENCY IO-PAUSE (trip #12975, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 621ms CPU time over 994ms wall clock time, 12.2M memory peak, 3.9M read from disk, 32.9M written to disk.
Nov 24 12:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:34:18 evo-x2 memory-emergency-guard-check[2299338]: MEMORY EMERGENCY IO-PAUSE (trip #12976, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 824ms wall clock time, 10.7M memory peak, 1M read from disk, 26.6M written to disk.
Nov 24 12:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:36:48 evo-x2 memory-emergency-guard-check[2372551]: MEMORY EMERGENCY IO-PAUSE (trip #12977, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 869ms wall clock time, 10.8M memory peak, 928K read from disk, 19.2M written to disk.
Nov 24 12:37:18 evo-x2 memory-emergency-guard-check[2393356]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.36% sustained (max disk busy 82.7%, MemAvailable=39.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 12:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:44:25 evo-x2 memory-emergency-guard-check[2671325]: MEMORY EMERGENCY IO-PAUSE (trip #12978, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 661ms CPU time over 1.107s wall clock time, 11.6M memory peak, 18.7M read from disk, 45.2M written to disk.
Nov 24 12:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:47:31 evo-x2 memory-emergency-guard-check[2765524]: MEMORY EMERGENCY IO-PAUSE (trip #12979, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 713ms wall clock time, 12.6M memory peak, 3.4M read from disk, 25.4M written to disk.
Nov 24 12:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:50:37 evo-x2 memory-emergency-guard-check[2840329]: MEMORY EMERGENCY IO-PAUSE (trip #12980, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 12:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 716ms wall clock time, 12.5M memory peak, 3.2M read from disk, 27.4M written to disk.
Nov 24 12:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 12:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:00:38 evo-x2 memory-emergency-guard-check[3072587]: MEMORY EMERGENCY IO-PAUSE (trip #12981, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 728ms CPU time over 1.340s wall clock time, 12.9M memory peak, 27.5M read from disk, 77.5M written to disk.
Nov 24 13:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:04:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:06:46 evo-x2 memory-emergency-guard-check[3239669]: MEMORY EMERGENCY IO-PAUSE (trip #12982, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 579ms CPU time over 720ms wall clock time, 11.9M memory peak, 544K read from disk, 15.1M written to disk.
Nov 24 13:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:14:18 evo-x2 memory-emergency-guard-check[3433667]: MEMORY EMERGENCY IO-PAUSE (trip #12983, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 950ms wall clock time, 11.5M memory peak, 544K read from disk, 21.1M written to disk.
Nov 24 13:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:16:48 evo-x2 memory-emergency-guard-check[3508052]: MEMORY EMERGENCY IO-PAUSE (trip #12984, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 843ms wall clock time, 11.9M memory peak, 1.9M read from disk, 30.6M written to disk.
Nov 24 13:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:18:48 evo-x2 memory-emergency-guard-check[3571675]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.75% sustained (max disk busy 34.8%, MemAvailable=52.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 13:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:19:19 evo-x2 memory-emergency-guard-check[3585749]: MEMORY EMERGENCY IO-PAUSE (trip #12985, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 1.162s wall clock time, 11.4M memory peak, 14.5M read from disk, 38.2M written to disk.
Nov 24 13:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:20:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:22:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:26:51 evo-x2 memory-emergency-guard-check[3780415]: MEMORY EMERGENCY IO-PAUSE (trip #12986, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 603ms wall clock time, 11.6M memory peak, 208K read from disk, 15.6M written to disk.
Nov 24 13:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:29:23 evo-x2 memory-emergency-guard-check[3839175]: MEMORY EMERGENCY IO-PAUSE (trip #12987, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 552ms CPU time over 651ms wall clock time, 12.5M memory peak, 512K read from disk, 19.4M written to disk.
Nov 24 13:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:31:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:31:54 evo-x2 memory-emergency-guard-check[3909208]: MEMORY EMERGENCY IO-PAUSE (trip #12988, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 648ms wall clock time, 10.9M memory peak, 544K read from disk, 26.8M written to disk.
Nov 24 13:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:33:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:34:26 evo-x2 memory-emergency-guard-check[3984006]: MEMORY EMERGENCY IO-PAUSE (trip #12989, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 579ms CPU time over 663ms wall clock time, 10.8M memory peak, 944K read from disk, 21.8M written to disk.
Nov 24 13:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:37:01 evo-x2 memory-emergency-guard-check[4062788]: MEMORY EMERGENCY IO-PAUSE (trip #12990, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 689ms wall clock time, 12.6M memory peak, 464K read from disk, 18.6M written to disk.
Nov 24 13:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:39:33 evo-x2 memory-emergency-guard-check[4129428]: MEMORY EMERGENCY IO-PAUSE (trip #12991, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 670ms wall clock time, 11.4M memory peak, 660K read from disk, 26.2M written to disk.
Nov 24 13:40:00 evo-x2 btrbk-admission[4146689]: REFUSE: btrbk-forgejo — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 24 13:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:40:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:41:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:42:05 evo-x2 memory-emergency-guard-check[8855]: MEMORY EMERGENCY IO-PAUSE (trip #12992, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 618ms wall clock time, 11.7M memory peak, 672K read from disk, 18.4M written to disk.
Nov 24 13:42:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:43:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:43:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:44:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:45:07 evo-x2 memory-emergency-guard-check[95352]: MEMORY EMERGENCY IO-PAUSE (trip #12993, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 686ms wall clock time, 12.7M memory peak, 848K read from disk, 27.7M written to disk.
Nov 24 13:45:37 evo-x2 memory-emergency-guard-check[112308]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.07% sustained (max disk busy 78.9%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 13:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:47:37 evo-x2 memory-emergency-guard-check[211437]: MEMORY EMERGENCY IO-PAUSE (trip #12994, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 801ms wall clock time, 11.1M memory peak, 240K read from disk, 25.5M written to disk.
Nov 24 13:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:52:09 evo-x2 memory-emergency-guard-check[361557]: MEMORY EMERGENCY IO-PAUSE (trip #12995, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 715ms wall clock time, 12M memory peak, 672K read from disk, 25.4M written to disk.
Nov 24 13:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:54:41 evo-x2 memory-emergency-guard-check[421559]: MEMORY EMERGENCY IO-PAUSE (trip #12996, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 13:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 567ms CPU time over 663ms wall clock time, 11.7M memory peak, 640K read from disk, 26.5M written to disk.
Nov 24 13:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 13:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:00:16 evo-x2 memory-emergency-guard-check[548237]: MEMORY EMERGENCY IO-PAUSE (trip #12997, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:00:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:00:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 742ms CPU time over 1.147s wall clock time, 11.8M memory peak, 12.5M read from disk, 77.2M written to disk.
Nov 24 14:00:45 evo-x2 memory-emergency-guard-check[578957]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.28% sustained (max disk busy 80.1%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 14:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:01:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:02:46 evo-x2 memory-emergency-guard-check[672144]: MEMORY EMERGENCY IO-PAUSE (trip #12998, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 730ms CPU time over 1.228s wall clock time, 12M memory peak, 28M read from disk, 53.7M written to disk.
Nov 24 14:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:08:18 evo-x2 memory-emergency-guard-check[835031]: MEMORY EMERGENCY IO-PAUSE (trip #12999, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 789ms wall clock time, 11.9M memory peak, 1.1M read from disk, 14.3M written to disk.
Nov 24 14:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:09:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:10:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:10:49 evo-x2 memory-emergency-guard-check[930906]: MEMORY EMERGENCY IO-PAUSE (trip #13000, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 1.468s wall clock time, 12M memory peak, 10.9M read from disk, 56.5M written to disk.
Nov 24 14:11:18 evo-x2 memory-emergency-guard-check[949584]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.15% sustained (max disk busy 34.3%, MemAvailable=56.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 14:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:15:19 evo-x2 memory-emergency-guard-check[1041045]: MEMORY EMERGENCY IO-PAUSE (trip #13001, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 584ms CPU time over 751ms wall clock time, 12.3M memory peak, 2.1M read from disk, 29.3M written to disk.
Nov 24 14:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:17:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:21:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:25:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:26:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:31:07 evo-x2 memory-emergency-guard-check[1420480]: MEMORY EMERGENCY IO-PAUSE (trip #13002, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 794ms wall clock time, 12.1M memory peak, 2.1M read from disk, 32.6M written to disk.
Nov 24 14:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:36:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:38:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:38:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:39:45 evo-x2 memory-emergency-guard-check[1623318]: MEMORY EMERGENCY IO-PAUSE (trip #13003, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 691ms wall clock time, 12.3M memory peak, 1.7M read from disk, 27.7M written to disk.
Nov 24 14:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:43:18 evo-x2 memory-emergency-guard-check[1708489]: MEMORY EMERGENCY IO-PAUSE (trip #13004, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 660ms wall clock time, 11.3M memory peak, 736K read from disk, 17.7M written to disk.
Nov 24 14:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:44:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:45:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:45:49 evo-x2 memory-emergency-guard-check[1767473]: MEMORY EMERGENCY IO-PAUSE (trip #13005, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 14:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 1.734s wall clock time, 11.9M memory peak, 1.6M read from disk, 31.4M written to disk.
Nov 24 14:46:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:46:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:47:18 evo-x2 memory-emergency-guard-check[1813069]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.51% sustained (max disk busy 44.8%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 14:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:54:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:55:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 14:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:01:05 evo-x2 memory-emergency-guard-check[2119452]: MEMORY EMERGENCY IO-PAUSE (trip #13006, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 1.269s wall clock time, 12.5M memory peak, 22.2M read from disk, 89.8M written to disk.
Nov 24 15:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:05:37 evo-x2 memory-emergency-guard-check[2230322]: MEMORY EMERGENCY IO-PAUSE (trip #13007, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 583ms CPU time over 689ms wall clock time, 12.5M memory peak, 240K read from disk, 23.1M written to disk.
Nov 24 15:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:09:39 evo-x2 memory-emergency-guard-check[2330113]: MEMORY EMERGENCY IO-PAUSE (trip #13008, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 714ms wall clock time, 11.3M memory peak, 704K read from disk, 30.3M written to disk.
Nov 24 15:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:13:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:13:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:14:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:17:16 evo-x2 memory-emergency-guard-check[2567695]: MEMORY EMERGENCY IO-PAUSE (trip #13009, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 854ms wall clock time, 11.6M memory peak, 11.7M read from disk, 28.1M written to disk.
Nov 24 15:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:18:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:18:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:19:15 evo-x2 memory-emergency-guard-check[2620022]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.97% sustained (max disk busy 24.2%, MemAvailable=55.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 15:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:19:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:20:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:21:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:24:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:29:49 evo-x2 memory-emergency-guard-check[2922461]: MEMORY EMERGENCY IO-PAUSE (trip #13010, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 714ms wall clock time, 12.1M memory peak, 1.6M read from disk, 23.4M written to disk.
Nov 24 15:30:19 evo-x2 memory-emergency-guard-check[2938741]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.84% sustained (max disk busy 69.5%, MemAvailable=57.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 15:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:32:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:34:59 evo-x2 memory-emergency-guard-check[3118512]: MEMORY EMERGENCY IO-PAUSE (trip #13011, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 537ms CPU time over 587ms wall clock time, 12.1M memory peak, 432K read from disk, 11.2M written to disk.
Nov 24 15:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:42:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:43:39 evo-x2 memory-emergency-guard-check[3366523]: MEMORY EMERGENCY IO-PAUSE (trip #13012, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 633ms CPU time over 2.945s wall clock time, 12.1M memory peak, 932K read from disk, 28.9M written to disk.
Nov 24 15:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:44:36 evo-x2 memory-emergency-guard-check[3394337]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.35% sustained (max disk busy 34.1%, MemAvailable=41.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 15:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:46:08 evo-x2 memory-emergency-guard-check[3426441]: MEMORY EMERGENCY IO-PAUSE (trip #13013, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 656ms CPU time over 1.147s wall clock time, 11.5M memory peak, 1M read from disk, 31.2M written to disk.
Nov 24 15:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:48:40 evo-x2 memory-emergency-guard-check[3509690]: MEMORY EMERGENCY IO-PAUSE (trip #13014, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 630ms CPU time over 3.251s wall clock time, 10.4M memory peak, 1.2M read from disk, 28.1M written to disk.
Nov 24 15:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:51:09 evo-x2 memory-emergency-guard-check[3692081]: MEMORY EMERGENCY IO-PAUSE (trip #13015, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 2.477s wall clock time, 9.9M memory peak, 496K read from disk, 27.1M written to disk.
Nov 24 15:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:54:41 evo-x2 memory-emergency-guard-check[3793981]: MEMORY EMERGENCY IO-PAUSE (trip #13016, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 1.399s wall clock time, 11.4M memory peak, 2.7M read from disk, 31.6M written to disk.
Nov 24 15:55:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:56:11 evo-x2 memory-emergency-guard-check[3834277]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.51% sustained (max disk busy 20.8%, MemAvailable=57.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (92s < 150s, 58s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 15:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:57:43 evo-x2 memory-emergency-guard-check[3895726]: MEMORY EMERGENCY IO-PAUSE (trip #13017, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 15:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 825ms wall clock time, 11.1M memory peak, 4.5M read from disk, 28.4M written to disk.
Nov 24 15:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 15:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:00:14 evo-x2 memory-emergency-guard-check[4039564]: MEMORY EMERGENCY IO-PAUSE (trip #13018, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 1.297s wall clock time, 12M memory peak, 25.1M read from disk, 75.3M written to disk.
Nov 24 16:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:01:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:02:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:03:44 evo-x2 memory-emergency-guard-check[25390]: MEMORY EMERGENCY IO-PAUSE (trip #13019, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 924ms wall clock time, 12.8M memory peak, 17.2M read from disk, 36.8M written to disk.
Nov 24 16:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:06:16 evo-x2 memory-emergency-guard-check[101738]: MEMORY EMERGENCY IO-PAUSE (trip #13020, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 899ms wall clock time, 12.5M memory peak, 8.3M read from disk, 33.5M written to disk.
Nov 24 16:06:45 evo-x2 memory-emergency-guard-check[134570]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.70% sustained (max disk busy 93.4%, MemAvailable=55.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 16:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:15:17 evo-x2 memory-emergency-guard-check[664707]: sort: fflush failed: 'standard output': Broken pipe
Nov 24 16:15:17 evo-x2 memory-emergency-guard-check[664707]: sort: write error
Nov 24 16:15:17 evo-x2 memory-emergency-guard-check[663227]: MEMORY EMERGENCY IO-PAUSE (trip #13021, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 879ms CPU time over 1.144s wall clock time, 10.7M memory peak, 3M read from disk, 33.1M written to disk.
Nov 24 16:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:24:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:34:48 evo-x2 memory-emergency-guard-check[1413528]: MEMORY EMERGENCY IO-PAUSE (trip #13022, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 1.038s wall clock time, 12.3M memory peak, 17.8M read from disk, 45.4M written to disk.
Nov 24 16:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:36:47 evo-x2 memory-emergency-guard-check[1471364]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.21% sustained (max disk busy 27.2%, MemAvailable=54.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 16:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:40:56 evo-x2 memory-emergency-guard-check[1577981]: MEMORY EMERGENCY IO-PAUSE (trip #13023, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:40:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:40:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 798ms wall clock time, 11.4M memory peak, 640K read from disk, 15.7M written to disk.
Nov 24 16:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:44:31 evo-x2 memory-emergency-guard-check[1764728]: MEMORY EMERGENCY IO-PAUSE (trip #13024, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 841ms wall clock time, 12.5M memory peak, 1008K read from disk, 24.5M written to disk.
Nov 24 16:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:47:33 evo-x2 memory-emergency-guard-check[1904900]: MEMORY EMERGENCY IO-PAUSE (trip #13025, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 580ms CPU time over 863ms wall clock time, 12.9M memory peak, 1.1M read from disk, 27.7M written to disk.
Nov 24 16:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:52:07 evo-x2 memory-emergency-guard-check[2137069]: MEMORY EMERGENCY IO-PAUSE (trip #13026, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 16:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 615ms CPU time over 979ms wall clock time, 12.6M memory peak, 4.6M read from disk, 41.2M written to disk.
Nov 24 16:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:53:06 evo-x2 memory-emergency-guard-check[2199730]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.84% sustained (max disk busy 20.9%, MemAvailable=52.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 16:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 16:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:00:38 evo-x2 memory-emergency-guard-check[2471126]: MEMORY EMERGENCY IO-PAUSE (trip #13027, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 710ms CPU time over 1.502s wall clock time, 11.8M memory peak, 48.2M read from disk, 71.6M written to disk.
Nov 24 17:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:03:12 evo-x2 memory-emergency-guard-check[2539720]: MEMORY EMERGENCY IO-PAUSE (trip #13028, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.004s wall clock time, 12.3M memory peak, 17.2M read from disk, 50.8M written to disk.
Nov 24 17:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:04:42 evo-x2 memory-emergency-guard-check[2584740]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.36% sustained (max disk busy 27.5%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 17:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:05:43 evo-x2 memory-emergency-guard-check[2605568]: MEMORY EMERGENCY IO-PAUSE (trip #13029, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 746ms wall clock time, 11.2M memory peak, 3.5M read from disk, 32.4M written to disk.
Nov 24 17:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:10:48 evo-x2 memory-emergency-guard-check[2738093]: MEMORY EMERGENCY IO-PAUSE (trip #13030, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 591ms CPU time over 741ms wall clock time, 12.6M memory peak, 2.3M read from disk, 27.7M written to disk.
Nov 24 17:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:11:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:13:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:17:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:17:33 evo-x2 memory-emergency-guard-check[2912333]: MEMORY EMERGENCY IO-PAUSE (trip #13031, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 688ms wall clock time, 11.3M memory peak, 1.1M read from disk, 23.9M written to disk.
Nov 24 17:18:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:19:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:23:07 evo-x2 memory-emergency-guard-check[3049378]: MEMORY EMERGENCY IO-PAUSE (trip #13032, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 545ms CPU time over 609ms wall clock time, 11.6M memory peak, 112K read from disk, 10.8M written to disk.
Nov 24 17:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:24:37 evo-x2 memory-emergency-guard-check[3087762]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.21% sustained (max disk busy 21.0%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 17:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:26:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:27:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:28:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:37:16 evo-x2 memory-emergency-guard-check[3499701]: MEMORY EMERGENCY IO-PAUSE (trip #13033, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 729ms wall clock time, 12.5M memory peak, 1.1M read from disk, 34.1M written to disk.
Nov 24 17:37:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:38:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:38:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:39:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:45:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:47:30 evo-x2 memory-emergency-guard-check[3798531]: MEMORY EMERGENCY IO-PAUSE (trip #13034, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 703ms wall clock time, 12M memory peak, 2M read from disk, 32.9M written to disk.
Nov 24 17:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:52:03 evo-x2 memory-emergency-guard-check[3907151]: MEMORY EMERGENCY IO-PAUSE (trip #13035, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 960ms wall clock time, 13M memory peak, 1M read from disk, 28.3M written to disk.
Nov 24 17:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:54:34 evo-x2 memory-emergency-guard-check[3971475]: MEMORY EMERGENCY IO-PAUSE (trip #13036, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 648ms wall clock time, 11.2M memory peak, 784K read from disk, 21.1M written to disk.
Nov 24 17:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:55:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:57:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:58:05 evo-x2 memory-emergency-guard-check[4057179]: MEMORY EMERGENCY IO-PAUSE (trip #13037, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 17:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 557ms CPU time over 732ms wall clock time, 11.5M memory peak, 256K read from disk, 19.6M written to disk.
Nov 24 17:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 17:59:36 evo-x2 memory-emergency-guard-check[4095587]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.17% sustained (max disk busy 22.3%, MemAvailable=53.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (92s < 150s, 58s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 17:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:07:08 evo-x2 memory-emergency-guard-check[80598]: MEMORY EMERGENCY IO-PAUSE (trip #13038, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 597ms CPU time over 980ms wall clock time, 12.3M memory peak, 4M read from disk, 49.3M written to disk.
Nov 24 18:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:09:40 evo-x2 memory-emergency-guard-check[139351]: MEMORY EMERGENCY IO-PAUSE (trip #13039, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 558ms CPU time over 1.647s wall clock time, 12.3M memory peak, 272K read from disk, 29.3M written to disk.
Nov 24 18:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:13:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:13:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:14:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:15:45 evo-x2 memory-emergency-guard-check[287281]: MEMORY EMERGENCY IO-PAUSE (trip #13040, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 627ms wall clock time, 10.8M memory peak, 64K read from disk, 12.7M written to disk.
Nov 24 18:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:18:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:18:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:19:16 evo-x2 memory-emergency-guard-check[383895]: MEMORY EMERGENCY IO-PAUSE (trip #13041, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 764ms wall clock time, 10.9M memory peak, 528K read from disk, 25.8M written to disk.
Nov 24 18:19:46 evo-x2 memory-emergency-guard-check[400339]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.56% sustained (max disk busy 29.9%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 18:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:21:58 evo-x2 memory-emergency-guard-check[453300]: MEMORY EMERGENCY IO-PAUSE (trip #13042, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 1.004s wall clock time, 11.8M memory peak, 48K read from disk, 18.1M written to disk.
Nov 24 18:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:22:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:23:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:24:33 evo-x2 memory-emergency-guard-check[517729]: MEMORY EMERGENCY IO-PAUSE (trip #13043, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 664ms CPU time over 2.661s wall clock time, 13M memory peak, 11.3M read from disk, 55.6M written to disk.
Nov 24 18:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:27:32 evo-x2 memory-emergency-guard-check[594128]: MEMORY EMERGENCY IO-PAUSE (trip #13044, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 1.760s wall clock time, 11.6M memory peak, 544K read from disk, 26.6M written to disk.
Nov 24 18:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:30:03 evo-x2 memory-emergency-guard-check[653109]: MEMORY EMERGENCY IO-PAUSE (trip #13045, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 549ms CPU time over 901ms wall clock time, 11.9M memory peak, 32K read from disk, 19.9M written to disk.
Nov 24 18:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:31:02 evo-x2 memory-emergency-guard-check[684834]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.31% sustained (max disk busy 35.8%, MemAvailable=53.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 18:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:33:06 evo-x2 memory-emergency-guard-check[734414]: MEMORY EMERGENCY IO-PAUSE (trip #13046, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:33:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:33:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 566ms CPU time over 2.192s wall clock time, 11.3M memory peak, 544K read from disk, 23.4M written to disk.
Nov 24 18:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:37:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:38:07 evo-x2 memory-emergency-guard-check[851529]: MEMORY EMERGENCY IO-PAUSE (trip #13047, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 706ms wall clock time, 12.2M memory peak, 144K read from disk, 23.4M written to disk.
Nov 24 18:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:45:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:47:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:48:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:50:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:51:00 evo-x2 memory-emergency-guard-check[1151266]: MEMORY EMERGENCY IO-PAUSE (trip #13048, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 553ms CPU time over 613ms wall clock time, 11.2M memory peak, 112K read from disk, 19.5M written to disk.
Nov 24 18:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:52:00 evo-x2 memory-emergency-guard-check[1182432]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.42% sustained (max disk busy 23.6%, MemAvailable=53.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 18:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:54:32 evo-x2 memory-emergency-guard-check[1241554]: MEMORY EMERGENCY IO-PAUSE (trip #13049, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 702ms wall clock time, 10.8M memory peak, 400K read from disk, 23.9M written to disk.
Nov 24 18:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:57:03 evo-x2 memory-emergency-guard-check[1310858]: MEMORY EMERGENCY IO-PAUSE (trip #13050, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 18:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 586ms CPU time over 696ms wall clock time, 11.6M memory peak, 2M read from disk, 25.5M written to disk.
Nov 24 18:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 18:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:02:05 evo-x2 memory-emergency-guard-check[1476976]: MEMORY EMERGENCY IO-PAUSE (trip #13051, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 726ms CPU time over 1.133s wall clock time, 12.7M memory peak, 14.5M read from disk, 86.8M written to disk.
Nov 24 19:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:07:05 evo-x2 memory-emergency-guard-check[1718182]: MEMORY EMERGENCY IO-PAUSE (trip #13052, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 639ms CPU time over 869ms wall clock time, 12.3M memory peak, 5.6M read from disk, 51.4M written to disk.
Nov 24 19:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:08:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:09:38 evo-x2 memory-emergency-guard-check[1798465]: MEMORY EMERGENCY IO-PAUSE (trip #13053, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 1.952s wall clock time, 11.9M memory peak, 3.7M read from disk, 48.1M written to disk.
Nov 24 19:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:10:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:12:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:13:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:14:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:14:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:15:39 evo-x2 memory-emergency-guard-check[1968870]: MEMORY EMERGENCY IO-PAUSE (trip #13054, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 582ms CPU time over 673ms wall clock time, 12.5M memory peak, 624K read from disk, 21.9M written to disk.
Nov 24 19:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:17:08 evo-x2 memory-emergency-guard-check[2033203]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.33% sustained (max disk busy 22.6%, MemAvailable=56.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 19:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:18:11 evo-x2 memory-emergency-guard-check[2104870]: MEMORY EMERGENCY IO-PAUSE (trip #13055, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 836ms CPU time over 1.642s wall clock time, 11.4M memory peak, 2.4M read from disk, 52.1M written to disk.
Nov 24 19:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:21:45 evo-x2 memory-emergency-guard-check[2378189]: MEMORY EMERGENCY IO-PAUSE (trip #13056, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.221s CPU time over 3.048s wall clock time, 9.5M memory peak, 31.8M read from disk, 60.8M written to disk.
Nov 24 19:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:31:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:31:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:32:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:32:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:33:52 evo-x2 memory-emergency-guard-check[2814402]: MEMORY EMERGENCY IO-PAUSE (trip #13057, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 701ms wall clock time, 11.2M memory peak, 1.1M read from disk, 25.6M written to disk.
Nov 24 19:34:22 evo-x2 memory-emergency-guard-check[2831089]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.99% sustained (max disk busy 21.9%, MemAvailable=55.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 19:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:36:27 evo-x2 memory-emergency-guard-check[2880023]: MEMORY EMERGENCY IO-PAUSE (trip #13058, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 1.381s wall clock time, 12.7M memory peak, 2.7M read from disk, 33.2M written to disk.
Nov 24 19:36:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:37:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:37:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:38:59 evo-x2 memory-emergency-guard-check[2954853]: MEMORY EMERGENCY IO-PAUSE (trip #13059, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 691ms CPU time over 903ms wall clock time, 12.5M memory peak, 3.5M read from disk, 40.3M written to disk.
Nov 24 19:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:41:30 evo-x2 memory-emergency-guard-check[3019808]: MEMORY EMERGENCY IO-PAUSE (trip #13060, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 972ms wall clock time, 12.8M memory peak, 4M read from disk, 46.6M written to disk.
Nov 24 19:41:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:44:01 evo-x2 memory-emergency-guard-check[3089546]: MEMORY EMERGENCY IO-PAUSE (trip #13061, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 678ms CPU time over 821ms wall clock time, 12.9M memory peak, 2.3M read from disk, 38.5M written to disk.
Nov 24 19:44:31 evo-x2 memory-emergency-guard-check[3109720]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.59% sustained (max disk busy 26.0%, MemAvailable=54.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 19:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:46:33 evo-x2 memory-emergency-guard-check[3162046]: sort: fflush failed: 'standard output': Broken pipe
Nov 24 19:46:33 evo-x2 memory-emergency-guard-check[3162046]: sort: write error
Nov 24 19:46:33 evo-x2 memory-emergency-guard-check[3160326]: MEMORY EMERGENCY IO-PAUSE (trip #13062, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 987ms wall clock time, 12.4M memory peak, 3.2M read from disk, 50.6M written to disk.
Nov 24 19:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:50:05 evo-x2 memory-emergency-guard-check[3312000]: MEMORY EMERGENCY IO-PAUSE (trip #13063, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 971ms wall clock time, 12.7M memory peak, 5.8M read from disk, 49.3M written to disk.
Nov 24 19:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:53:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:53:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:55:07 evo-x2 memory-emergency-guard-check[3517140]: MEMORY EMERGENCY IO-PAUSE (trip #13064, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 668ms CPU time over 899ms wall clock time, 12.4M memory peak, 2.2M read from disk, 41.2M written to disk.
Nov 24 19:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:56:07 evo-x2 memory-emergency-guard-check[3558711]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.26% sustained (max disk busy 24.6%, MemAvailable=57.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 19:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:57:37 evo-x2 memory-emergency-guard-check[3601135]: MEMORY EMERGENCY IO-PAUSE (trip #13065, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 19:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 671ms CPU time over 868ms wall clock time, 11M memory peak, 2.3M read from disk, 40.8M written to disk.
Nov 24 19:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 19:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:00:09 evo-x2 memory-emergency-guard-check[3685261]: MEMORY EMERGENCY IO-PAUSE (trip #13066, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 1.676s wall clock time, 11.2M memory peak, 42.5M read from disk, 60.4M written to disk.
Nov 24 20:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:02:38 evo-x2 memory-emergency-guard-check[3759048]: MEMORY EMERGENCY IO-PAUSE (trip #13067, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 736ms wall clock time, 12.1M memory peak, 3.1M read from disk, 28.1M written to disk.
Nov 24 20:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:05:09 evo-x2 memory-emergency-guard-check[3824420]: MEMORY EMERGENCY IO-PAUSE (trip #13068, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 604ms CPU time over 737ms wall clock time, 11.1M memory peak, 2.2M read from disk, 23.7M written to disk.
Nov 24 20:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:08:13 evo-x2 memory-emergency-guard-check[3947166]: MEMORY EMERGENCY IO-PAUSE (trip #13069, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 923ms wall clock time, 11M memory peak, 8.1M read from disk, 42.8M written to disk.
Nov 24 20:08:43 evo-x2 memory-emergency-guard-check[3982897]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.18% sustained (max disk busy 46.1%, MemAvailable=45.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 20:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:10:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:11:17 evo-x2 memory-emergency-guard-check[4076035]: MEMORY EMERGENCY IO-PAUSE (trip #13070, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 770ms CPU time over 1.444s wall clock time, 11.7M memory peak, 43.1M read from disk, 78.3M written to disk.
Nov 24 20:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:13:51 evo-x2 memory-emergency-guard-check[82214]: MEMORY EMERGENCY IO-PAUSE (trip #13071, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.320s CPU time over 5.129s wall clock time, 8.4M memory peak, 16.2M read from disk, 73.7M written to disk.
Nov 24 20:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:17:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:19:18 evo-x2 memory-emergency-guard-check[560146]: MEMORY EMERGENCY IO-PAUSE (trip #13072, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:19:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:19:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 767ms wall clock time, 11.7M memory peak, 2M read from disk, 18.5M written to disk.
Nov 24 20:19:47 evo-x2 memory-emergency-guard-check[589357]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.37% sustained (max disk busy 99.1%, MemAvailable=50.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 20:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:21:49 evo-x2 memory-emergency-guard-check[782594]: MEMORY EMERGENCY IO-PAUSE (trip #13073, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:21:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 837ms CPU time over 1.323s wall clock time, 10.8M memory peak, 6.2M read from disk, 49.8M written to disk.
Nov 24 20:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:24:53 evo-x2 memory-emergency-guard-check[1028475]: MEMORY EMERGENCY IO-PAUSE (trip #13074, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.647s CPU time over 3.887s wall clock time, 11.5M memory peak, 25.8M read from disk, 100M written to disk.
Nov 24 20:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:27:20 evo-x2 memory-emergency-guard-check[1179008]: MEMORY EMERGENCY IO-PAUSE (trip #13075, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 784ms CPU time over 1.307s wall clock time, 11.5M memory peak, 22.7M read from disk, 49.7M written to disk.
Nov 24 20:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:29:54 evo-x2 memory-emergency-guard-check[1300266]: MEMORY EMERGENCY IO-PAUSE (trip #13076, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 794ms CPU time over 5.061s wall clock time, 11.7M memory peak, 2.4M read from disk, 30.1M written to disk.
Nov 24 20:30:19 evo-x2 memory-emergency-guard-check[1320649]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.38% sustained (max disk busy 100.0%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 20:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:32:25 evo-x2 memory-emergency-guard-check[1422894]: MEMORY EMERGENCY IO-PAUSE (trip #13077, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 785ms CPU time over 6.262s wall clock time, 10.4M memory peak, 3.1M read from disk, 42.7M written to disk.
Nov 24 20:32:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:34:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:34:54 evo-x2 memory-emergency-guard-check[1588416]: MEMORY EMERGENCY IO-PAUSE (trip #13078, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.164s CPU time over 5.002s wall clock time, 9M memory peak, 3.9M read from disk, 52.7M written to disk.
Nov 24 20:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:37:37 evo-x2 memory-emergency-guard-check[1714595]: MEMORY EMERGENCY IO-PAUSE (trip #13079, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 936ms CPU time over 17.301s wall clock time, 11.3M memory peak, 16.2M read from disk, 30M written to disk.
Nov 24 20:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:39:56 evo-x2 memory-emergency-guard-check[1826607]: MEMORY EMERGENCY IO-PAUSE (trip #13080, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.211s CPU time over 6.447s wall clock time, 11.1M memory peak, 33.5M read from disk, 42.9M written to disk.
Nov 24 20:40:24 evo-x2 memory-emergency-guard-check[1845479]: MEMORY EMERGENCY still active (I/O PSI some avg60=88.18% sustained (max disk busy 97.5%, MemAvailable=12.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (35s < 150s, 115s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 24 20:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:42:23 evo-x2 memory-emergency-guard-check[1928228]: MEMORY EMERGENCY IO-PAUSE (trip #13081, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 24 20:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 787ms CPU time over 3.354s wall clock time, 11.9M memory peak, 37.3M read from disk, 68.9M written to disk.
Nov 24 20:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 24 20:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Nov 23 21:17:16 evo-x2 thermal-pstate-guard-check[97723]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Nov 23 21:23:13 evo-x2 thermal-pstate-guard-check[169269]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=50C(hi:95/lo:80)
Nov 23 22:25:36 evo-x2 thermal-pstate-guard-check[827769]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 23 22:30:48 evo-x2 thermal-pstate-guard-check[1050570]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=65C(hi:95/lo:80)
Nov 23 22:32:31 evo-x2 thermal-pstate-guard-check[1084597]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 23 22:39:30 evo-x2 thermal-pstate-guard-check[1165523]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Nov 23 22:44:30 evo-x2 thermal-pstate-guard-check[1265303]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Nov 23 23:00:49 evo-x2 thermal-pstate-guard-check[1777176]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Nov 23 23:10:40 evo-x2 thermal-pstate-guard-check[1946014]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 23 23:18:10 evo-x2 thermal-pstate-guard-check[2037373]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=63C(hi:95/lo:80)
Nov 23 23:24:52 evo-x2 thermal-pstate-guard-check[2174693]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=99C(hi:95/lo:80)
Nov 23 23:26:53 evo-x2 thermal-pstate-guard-check[2199101]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=60C(hi:95/lo:80)
Nov 23 23:59:48 evo-x2 thermal-pstate-guard-check[2772878]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=99C(hi:95/lo:80)
Nov 24 02:42:58 evo-x2 thermal-pstate-guard-check[2879974]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=79C(hi:95/lo:80)
Nov 24 03:23:48 evo-x2 thermal-pstate-guard-check[4110624]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 24 03:49:53 evo-x2 thermal-pstate-guard-check[1115682]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Nov 24 03:58:57 evo-x2 thermal-pstate-guard-check[1412327]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 24 09:43:07 evo-x2 thermal-pstate-guard-check[1334767]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=72C(hi:95/lo:80)
Nov 24 11:31:16 evo-x2 thermal-pstate-guard-check[3929595]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Nov 24 12:53:50 evo-x2 thermal-pstate-guard-check[2918097]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)
Nov 24 14:00:47 evo-x2 thermal-pstate-guard-check[583257]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Nov 24 14:15:29 evo-x2 thermal-pstate-guard-check[1052263]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=75C(hi:95/lo:80)
Nov 24 15:08:40 evo-x2 thermal-pstate-guard-check[2311908]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 24 16:48:44 evo-x2 thermal-pstate-guard-check[1964338]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=78C(hi:95/lo:80)
Nov 24 17:00:32 evo-x2 thermal-pstate-guard-check[2469388]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 24 17:10:22 evo-x2 thermal-pstate-guard-check[2727667]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)
Nov 24 18:23:45 evo-x2 thermal-pstate-guard-check[500243]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 24 18:28:33 evo-x2 thermal-pstate-guard-check[623902]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=69C(hi:95/lo:80)
Nov 24 19:00:54 evo-x2 thermal-pstate-guard-check[1424208]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 23 21:13:15 evo-x2 kernel: Command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/19sgcfq2kypdgarvpasdjx6jhzb68ihc-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 23 21:13:15 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/19sgcfq2kypdgarvpasdjx6jhzb68ihc-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 23 21:13:15 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 23 21:13:17 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1795549458000000000 -> 1795549604000000000 epoch-ns UTC (2026-11-24 19:44:18 -> 2026-11-24 19:46:44 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
