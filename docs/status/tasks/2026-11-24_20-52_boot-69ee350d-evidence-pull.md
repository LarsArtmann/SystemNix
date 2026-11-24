# Boot evidence pull: id8 69ee350d (full: 69ee350d05dc455690e3d7230b71995f)

Pulled 2026-11-24 20:52 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-22 19:53:18 -> 2026-11-22 20:48:35 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 69ee350d — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 22 19:53:18 evo-x2 kernel: Linux version 7.3.5 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1794910461
Nov 22 19:53:18 evo-x2 kernel: Command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/pwwl6n66p1j34kb7rpmazndxyp41ijff-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 22 19:53:18 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 22 20:48:33 evo-x2 hermes[164235]: 2026-11-22 20:48:33,252 INFO cron.scheduler: Cron job 'a995833f3592' handed to restart-safe worker pid=3396700 execution=462d8a7615a1469faf9d849559809058 dispatch=scoped
Nov 22 20:48:33 evo-x2 hermes[164235]: 2026-11-22 20:48:33,558 INFO tui_gateway.ws: ws accepted peer=127.0.0.1:52324
Nov 22 20:48:33 evo-x2 inboxclean[2625498]: 2026/11/22 20:48:33 WARN paperless: attachment is password-protected and was NOT decrypted; uploading as-is with the "encrypted" tag filename=WYC2202400311792505.pdf reason="no decrypt password configured (PAPERLESS_DECRYPT_PASSWORD)"
Nov 22 20:48:33 evo-x2 forgejo[119143]: router: completed GET /api/v1/version for [::1]:60510, 200 OK in 0.1ms @ misc/version.go:15(misc.Version)
Nov 22 20:48:33 evo-x2 inboxclean[2625498]: 2026/11/22 20:48:33 WARN paperless: attachment is password-protected and was NOT decrypted; uploading as-is with the "encrypted" tag filename=ZO2202400318645039.pdf reason="no decrypt password configured (PAPERLESS_DECRYPT_PASSWORD)"
Nov 22 20:48:34 evo-x2 signoz-wrapper[99764]: {"timestamp":"2026-11-22T20:48:34.749516938+01:00","level":"INFO","msg":"promql rule task","name":"01a00809-974f-7ca5-ab98-b3bab9ef9c4b-groupname","eval_started_at":"2026-11-22T19:48:34.748029242Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Nov 22 20:48:34 evo-x2 signoz-wrapper[99764]: {"timestamp":"2026-11-22T20:48:34.749635215+01:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-974f-7ca5-ab98-b3bab9ef9c4b","rule.query":"sum(node_systemd_unit_state{state=\"failed\"})","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":99}
Nov 22 20:48:34 evo-x2 signoz-wrapper[99764]: {"timestamp":"2026-11-22T20:48:34.788362457+01:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-974f-7ca5-ab98-b3bab9ef9c4b","alert.count":1,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":242}
Nov 22 20:48:35 evo-x2 server[1768]: WARN AuditRun projection: unhandled event event_type=alert.resolved aggregate_id=01M82BT76A6N6D6VKGKC00002F
Nov 22 20:48:35 evo-x2 server[1768]: WARN Question projection: unhandled event event_type=alert.resolved aggregate_id=01M82BT76A6N6D6VKGKC00002F
Nov 22 20:48:35 evo-x2 server[1768]: WARN Notification projection: unhandled event event_type=alert.resolved aggregate_id=01M82BT76A6N6D6VKGKC00002F
Nov 22 20:48:35 evo-x2 server[1768]: INFO request method=GET path=/api/health status=200 duration=1.488023349s client_ip=::1 request_id=6b034711000003221696c4ac937c84c7
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 193
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
Nov 22 19:53:35 evo-x2 post-crash-calm-gate[1750]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 19:57:05 evo-x2 memory-emergency-guard-check[24412]: MEMORY EMERGENCY IO-PAUSE (trip #12483, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 19:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 783ms CPU time over 1min 48.331s wall clock time, 11.4M memory peak, 22.2M read from disk, 172.3M written to disk.
Nov 22 19:57:05 evo-x2 memory-emergency-guard-check[83500]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.52% sustained (max disk busy 100.0%, MemAvailable=81.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (108s < 150s, 42s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 22 19:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:58:09 evo-x2 memory-emergency-guard-check[133111]: MEMORY EMERGENCY IO-PAUSE (trip #12484, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 19:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 3.848s wall clock time, 11.5M memory peak, 11.5M read from disk, 43.3M written to disk.
Nov 22 19:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 19:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:00:51 evo-x2 memory-emergency-guard-check[234786]: MEMORY EMERGENCY IO-PAUSE (trip #12485, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 16.404s wall clock time, 12.8M memory peak, 33.2M written to disk.
Nov 22 20:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:03:08 evo-x2 memory-emergency-guard-check[284927]: MEMORY EMERGENCY IO-PAUSE (trip #12486, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 958ms CPU time over 2.911s wall clock time, 10.4M memory peak, 144K read from disk, 52.1M written to disk.
Nov 22 20:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:03:51 evo-x2 post-crash-calm-gate[330733]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:04:06 evo-x2 post-crash-calm-gate[355313]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:06:40 evo-x2 memory-emergency-guard-check[486124]: MEMORY EMERGENCY IO-PAUSE (trip #12487, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 2.074s CPU time over 1min 4.758s wall clock time, 8.9M memory peak, 2M read from disk, 543.1M written to disk.
Nov 22 20:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:06:52 evo-x2 post-crash-calm-gate[596641]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:07:07 evo-x2 post-crash-calm-gate[616239]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:07:10 evo-x2 memory-emergency-guard-check[622937]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.79% sustained (max disk busy 84.4%, MemAvailable=58.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (95s < 150s, 55s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 22 20:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:07:22 evo-x2 post-crash-calm-gate[648799]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:07:37 evo-x2 post-crash-calm-gate[676077]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:07:52 evo-x2 post-crash-calm-gate[706775]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:08:07 evo-x2 post-crash-calm-gate[727743]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:08:47 evo-x2 memory-emergency-guard-check[774454]: MEMORY EMERGENCY IO-PAUSE (trip #12488, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.190s CPU time over 6.536s wall clock time, 9.4M memory peak, 5.3M read from disk, 49.9M written to disk.
Nov 22 20:09:07 evo-x2 post-crash-calm-gate[815385]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:09:22 evo-x2 post-crash-calm-gate[836415]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:09:37 evo-x2 post-crash-calm-gate[856429]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:09:52 evo-x2 post-crash-calm-gate[887042]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:10:07 evo-x2 post-crash-calm-gate[901283]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:10:22 evo-x2 post-crash-calm-gate[940630]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:10:37 evo-x2 post-crash-calm-gate[974614]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:13:04 evo-x2 memory-emergency-guard-check[1109884]: MEMORY EMERGENCY IO-PAUSE (trip #12489, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.061s CPU time over 1min 22.966s wall clock time, 8.9M memory peak, 1.6M read from disk, 7.6M written to disk.
Nov 22 20:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:13:38 evo-x2 post-crash-calm-gate[1270586]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:13:53 evo-x2 post-crash-calm-gate[1296324]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:14:08 evo-x2 post-crash-calm-gate[1325803]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:14:23 evo-x2 post-crash-calm-gate[1343532]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:14:42 evo-x2 memory-emergency-guard-check[1357916]: MEMORY EMERGENCY IO-PAUSE (trip #12490, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.192s CPU time over 6.974s wall clock time, 8.9M memory peak, 2.6M read from disk, 4.9M written to disk.
Nov 22 20:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:15:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 159ms CPU time over 362ms wall clock time, 7.6M memory peak, 1.1M read from disk, 4K written to disk.
Nov 22 20:15:54 evo-x2 post-crash-calm-gate[1474892]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:16:09 evo-x2 post-crash-calm-gate[1496953]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:17:41 evo-x2 memory-emergency-guard-check[1596963]: MEMORY EMERGENCY IO-PAUSE (trip #12491, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 22.566s wall clock time, 11.8M memory peak, 12.2M read from disk, 56.7M written to disk.
Nov 22 20:17:48 evo-x2 memory-emergency-guard-check[1630872]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.24% sustained (max disk busy 98.1%, MemAvailable=56.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 22 20:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:18:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:21:13 evo-x2 memory-emergency-guard-check[1773553]: MEMORY EMERGENCY IO-PAUSE (trip #12492, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.108s CPU time over 1min 24.694s wall clock time, 12.9M memory peak, 49.4M read from disk, 35.9M written to disk.
Nov 22 20:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:23:06 evo-x2 memory-emergency-guard-check[1995563]: MEMORY EMERGENCY IO-PAUSE (trip #12493, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 896ms CPU time over 22.724s wall clock time, 10.2M memory peak, 7M read from disk, 29.4M written to disk.
Nov 22 20:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:24:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:25:20 evo-x2 memory-emergency-guard-check[2198123]: MEMORY EMERGENCY IO-PAUSE (trip #12494, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 794ms CPU time over 6.193s wall clock time, 12.7M memory peak, 12.5M read from disk, 47.2M written to disk.
Nov 22 20:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:27:48 evo-x2 memory-emergency-guard-check[2303410]: MEMORY EMERGENCY IO-PAUSE (trip #12495, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.147s CPU time over 3.743s wall clock time, 10.5M memory peak, 5M read from disk, 52.3M written to disk.
Nov 22 20:27:56 evo-x2 post-crash-calm-gate[2326496]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:28:11 evo-x2 post-crash-calm-gate[2341524]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:28:14 evo-x2 memory-emergency-guard-check[2343728]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.41% sustained (max disk busy 100.0%, MemAvailable=61.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 22 20:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:28:56 evo-x2 post-crash-calm-gate[2378161]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:29:11 evo-x2 post-crash-calm-gate[2389915]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:29:26 evo-x2 post-crash-calm-gate[2402531]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:29:41 evo-x2 post-crash-calm-gate[2411213]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:29:56 evo-x2 post-crash-calm-gate[2427488]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:30:11 evo-x2 post-crash-calm-gate[2439096]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:30:26 evo-x2 post-crash-calm-gate[2459149]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:30:41 evo-x2 post-crash-calm-gate[2468241]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:30:56 evo-x2 post-crash-calm-gate[2482563]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 22 20:31:11 evo-x2 post-crash-calm-gate[2494830]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 22 20:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:31:26 evo-x2 post-crash-calm-gate[2506272]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 22 20:31:49 evo-x2 memory-emergency-guard-check[2523122]: MEMORY EMERGENCY IO-PAUSE (trip #12496, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.156s CPU time over 4.884s wall clock time, 10.8M memory peak, 29.4M read from disk, 61M written to disk.
Nov 22 20:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:32:41 evo-x2 post-crash-calm-gate[2590414]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:32:56 evo-x2 post-crash-calm-gate[2608316]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:33:11 evo-x2 post-crash-calm-gate[2621598]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:33:26 evo-x2 post-crash-calm-gate[2635615]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:33:41 evo-x2 post-crash-calm-gate[2646507]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:33:56 evo-x2 post-crash-calm-gate[2665066]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:34:11 evo-x2 post-crash-calm-gate[2674539]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:34:26 evo-x2 post-crash-calm-gate[2688955]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:34:41 evo-x2 post-crash-calm-gate[2699923]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 22 20:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:34:56 evo-x2 post-crash-calm-gate[2718538]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 22 20:35:11 evo-x2 post-crash-calm-gate[2733466]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 22 20:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:35:47 evo-x2 memory-emergency-guard-check[2754604]: MEMORY EMERGENCY IO-PAUSE (trip #12497, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 868ms wall clock time, 12.5M memory peak, 8.6M read from disk, 34.3M written to disk.
Nov 22 20:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:36:42 evo-x2 post-crash-calm-gate[2807256]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 22 20:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:37:42 evo-x2 post-crash-calm-gate[2878104]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 22 20:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:38:19 evo-x2 memory-emergency-guard-check[2906153]: MEMORY EMERGENCY IO-PAUSE (trip #12498, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 783ms CPU time over 1.102s wall clock time, 12.4M memory peak, 5.7M read from disk, 32.6M written to disk.
Nov 22 20:38:48 evo-x2 memory-emergency-guard-check[2927428]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.95% sustained (max disk busy 100.0%, MemAvailable=45.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 22 20:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:41:03 evo-x2 memory-emergency-guard-check[2992850]: MEMORY EMERGENCY IO-PAUSE (trip #12499, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 2.967s CPU time over 14.903s wall clock time, 12.3M memory peak, 43.9M read from disk, 13.4M written to disk.
Nov 22 20:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:43:53 evo-x2 memory-emergency-guard-check[3093926]: MEMORY EMERGENCY IO-PAUSE (trip #12500, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.249s CPU time over 3.890s wall clock time, 10.3M memory peak, 8.6M read from disk, 37.6M written to disk.
Nov 22 20:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:46:24 evo-x2 memory-emergency-guard-check[3269138]: MEMORY EMERGENCY IO-PAUSE (trip #12501, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service llama-vlm-cap.service system-health-metrics.service crm-server.service) — pressure persists but nothing pausable
Nov 22 20:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.358s CPU time over 5.092s wall clock time, 8.7M memory peak, 13.8M read from disk, 58.4M written to disk.
Nov 22 20:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:47:10 evo-x2 systemd[1978]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=10.99%, MemAvailable=19.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4573 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 22 20:47:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 22 20:48:21 evo-x2 systemd[1978]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 4573 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
```

## THERMAL THROTTLE lines
```
Nov 22 19:57:30 evo-x2 thermal-pstate-guard-check[98802]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 22 19:53:18 evo-x2 kernel: Command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/pwwl6n66p1j34kb7rpmazndxyp41ijff-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 22 19:53:18 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi init=/nix/store/pwwl6n66p1j34kb7rpmazndxyp41ijff-nixos-system-evo-x2-26.11.20261119.0bb8272/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=512M nmi_watchdog=panic softlockup_panic=1
Nov 22 19:53:18 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 22 19:53:20 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1795376915000000000 -> 1795377071000000000 epoch-ns UTC (2026-11-22 19:48:35 -> 2026-11-22 19:51:11 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
