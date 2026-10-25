# Boot evidence pull: id8 daecca67 (full: daecca673c17444a94079ea7212824f7)

Pulled 2026-10-25 03:49 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-18 00:42:21 -> 2026-10-18 03:03:38 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 daecca67 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 18 00:42:21 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Oct 18 00:42:21 evo-x2 kernel: Command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/xriv7zkqjz8p38a4a77jdkwscqr3a7lm-nixos-system-evo-x2-26.11.20261014.55bfb4d/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 18 00:42:21 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 18 03:03:28 evo-x2 signoz-wrapper[20909]: {"timestamp":"2026-10-18T03:03:28.975677019+02:00","level":"INFO","msg":"promql rule task","name":"01a00809-8f9c-706c-bf13-e17b9da4bbdf-groupname","eval_started_at":"2026-10-18T01:03:28.975074948Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Oct 18 03:03:28 evo-x2 signoz-wrapper[20909]: {"timestamp":"2026-10-18T03:03:28.975800997+02:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-8f9c-706c-bf13-e17b9da4bbdf","rule.query":"100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Oct 18 03:03:28 evo-x2 signoz-wrapper[20909]: {"timestamp":"2026-10-18T03:03:28.997354255+02:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-8f9c-706c-bf13-e17b9da4bbdf","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
Oct 18 03:03:29 evo-x2 cv[6539]: INFO  Health check completed overall_status=warn checks_count=42 uptime=2h20m28s
Oct 18 03:03:31 evo-x2 indexer[1994]: INFO request method=GET path=/ status=200 duration=2.683185ms client_ip=192.168.1.150 request_id=6ad41ae3000001aec9b78ffdf38be4c5
Oct 18 03:03:31 evo-x2 crush-daily[3184]: time=2026-10-18T03:03:31.131+02:00 level=INFO msg="http request" method=GET path=/ status=200 duration=2.509089ms
Oct 18 03:03:31 evo-x2 crm-server[632948]: time=2026-10-18T03:03:31.144+02:00 level=INFO msg=request method=GET path=/ status=303 duration=38µs
Oct 18 03:03:31 evo-x2 crm-server[632948]: time=2026-10-18T03:03:31.147+02:00 level=INFO msg=request method=GET path=/login status=200 duration=158µs
Oct 18 03:03:31 evo-x2 file-renamer[1870345]: 2026-10-18T03:03:31+02:00 INFO  watcher: request method=GET path=/ status=200 duration=1.576458ms client_ip=192.168.1.150 request_id=6ad41ae3000000e4e3303178aa6152f9
Oct 18 03:03:31 evo-x2 emeet-pixyd[7606]: 2026/10/18 03:03:31 INFO http request method=GET path=/ status=0 duration=162.617µs
Oct 18 03:03:35 evo-x2 niri-session-manager[7612]: 2026-10-18T01:03:35.697448Z  INFO niri_session_manager::session: Deduped 3 extra surface(s) of single-instance apps sharing one process
Oct 18 03:03:38 evo-x2 tq[2618446]: 2026/10/18 03:03:38 WARN environmental requeue streak burned the attempt task=000001a14c7e79e9fead8ae3463500000000 streak=3 code=env-streak "retry after"=4s
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 347
- thermal-THROTTLE-lines: 3
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 18 00:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:44:49 evo-x2 memory-emergency-guard-check[27416]: MEMORY EMERGENCY: I/O PSI some avg60=63.92% sustained (max disk busy 100.0%, MemAvailable=73.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 00:44:54 evo-x2 memory-emergency-guard-check[27416]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3477, zone 6)
Oct 18 00:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 517ms CPU time over 5.096s wall clock time, 11.2M memory peak, 18.2M read from disk, 56M written to disk.
Oct 18 00:45:19 evo-x2 memory-emergency-guard-check[37688]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.94% sustained (max disk busy 99.8%, MemAvailable=72.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 00:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:52:23 evo-x2 systemd[2466]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 18 00:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:55:10 evo-x2 memory-emergency-guard-check[297602]: MEMORY EMERGENCY: I/O PSI some avg60=47.94% sustained (max disk busy 97.1%, MemAvailable=43.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 00:56:06 evo-x2 memory-emergency-guard-check[297602]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3478, zone 6) — top io since last trip: system.slice/io.stat +29221MB, user.slice/io.stat +25665MB, user.slice/user-1000.slice/io.stat +24943MB
Oct 18 00:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 877ms CPU time over 56.504s wall clock time, 8M memory peak, 832K read from disk, 91M written to disk.
Oct 18 00:56:06 evo-x2 memory-emergency-guard-check[348778]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.87% sustained (max disk busy 100.0%, MemAvailable=42.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (56s < 600s, 544s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 00:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 00:59:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 263ms CPU time over 1.046s wall clock time, 8M memory peak, 2.3M read from disk, 4K written to disk.
Oct 18 00:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 338ms CPU time over 570ms wall clock time, 8M memory peak, 2.9M read from disk, 4K written to disk.
Oct 18 01:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:03:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:04:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:05:38 evo-x2 memory-emergency-guard-check[692007]: MEMORY EMERGENCY: I/O PSI some avg60=85.31% sustained (max disk busy 99.3%, MemAvailable=55.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:06:32 evo-x2 memory-emergency-guard-check[692007]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3479, zone 6) — top io since last trip: system.slice/io.stat +113871MB, user.slice/io.stat +74170MB, user.slice/user-1000.slice/io.stat +72725MB
Oct 18 01:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.006s CPU time over 53.801s wall clock time, 7.9M memory peak, 16.4M read from disk, 33.7M written to disk.
Oct 18 01:06:32 evo-x2 memory-emergency-guard-check[725833]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.67% sustained (max disk busy 99.7%, MemAvailable=42.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (54s < 600s, 546s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:08:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:09:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 176ms CPU time over 247ms wall clock time, 7M memory peak, 1.1M read from disk, 4K written to disk.
Oct 18 01:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:16:06 evo-x2 memory-emergency-guard-check[1010518]: MEMORY EMERGENCY: I/O PSI some avg60=79.81% sustained (max disk busy 100.0%, MemAvailable=28.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:16:25 evo-x2 memory-emergency-guard-check[1010518]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3480, zone 6) — top io since last trip: system.slice/io.stat +65238MB, user.slice/io.stat +45705MB, user.slice/user-1000.slice/io.stat +44361MB
Oct 18 01:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 932ms CPU time over 19.826s wall clock time, 9.2M memory peak, 16.5M read from disk, 8.8M written to disk.
Oct 18 01:16:36 evo-x2 memory-emergency-guard-check[1024792]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.69% sustained (max disk busy 100.0%, MemAvailable=30.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:19:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:26:09 evo-x2 memory-emergency-guard-check[1315015]: MEMORY EMERGENCY: I/O PSI some avg60=69.03% sustained (max disk busy 99.8%, MemAvailable=45.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:26:14 evo-x2 memory-emergency-guard-check[1315015]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3481, zone 6) — top io since last trip: user.slice/io.stat +52999MB, user.slice/user-1000.slice/io.stat +52082MB, system.slice/io.stat +49013MB
Oct 18 01:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.210s CPU time over 5.426s wall clock time, 8.6M memory peak, 15.4M read from disk, 51.2M written to disk.
Oct 18 01:26:39 evo-x2 memory-emergency-guard-check[1329984]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.18% sustained (max disk busy 100.0%, MemAvailable=40.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 239ms wall clock time, 8.6M memory peak, 2.5M read from disk, 4K written to disk.
Oct 18 01:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:33:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:34:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:34:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:35:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:36:13 evo-x2 memory-emergency-guard-check[1640035]: MEMORY EMERGENCY: I/O PSI some avg60=59.70% sustained (max disk busy 100.0%, MemAvailable=43.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:36:23 evo-x2 memory-emergency-guard-check[1640035]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3482, zone 6) — top io since last trip: system.slice/io.stat +63203MB, user.slice/io.stat +29212MB, user.slice/user-1000.slice/io.stat +28500MB
Oct 18 01:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 782ms CPU time over 10.147s wall clock time, 9.4M memory peak, 54.8M read from disk, 5.9M written to disk.
Oct 18 01:36:43 evo-x2 memory-emergency-guard-check[1661510]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.25% sustained (max disk busy 100.0%, MemAvailable=36.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:36:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:37:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:39:27 evo-x2 memory-emergency-guard-check[1718718]: MEMORY EMERGENCY io drained (io PSI some avg60=38.73% < 40%) — churn units re-armed (re-arm #157)
Oct 18 01:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 207ms CPU time over 1min 14.407s wall clock time, 5.6M memory peak, 1.1M read from disk, 4K written to disk.
Oct 18 01:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 177ms CPU time over 427ms wall clock time, 7.8M memory peak, 2.9M read from disk, 4K written to disk.
Oct 18 01:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 202ms CPU time over 458ms wall clock time, 5.7M memory peak, 1.8M read from disk, 4K written to disk.
Oct 18 01:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:42:26 evo-x2 gatus[7870]: 2026/10/18 01:42:26 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 18 01:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:43:32 evo-x2 systemd[2466]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 18 01:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:46:29 evo-x2 memory-emergency-guard-check[1969292]: MEMORY EMERGENCY: I/O PSI some avg60=86.71% sustained (max disk busy 100.0%, MemAvailable=33.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:46:34 evo-x2 memory-emergency-guard-check[1969292]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3483, zone 6) — top io since last trip: system.slice/io.stat +124769MB, user.slice/io.stat +73235MB, user.slice/user-1000.slice/io.stat +72642MB
Oct 18 01:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 703ms CPU time over 5.638s wall clock time, 8.9M memory peak, 9.5M read from disk, 23.6M written to disk.
Oct 18 01:46:59 evo-x2 memory-emergency-guard-check[1994345]: MEMORY EMERGENCY still active (I/O PSI some avg60=89.63% sustained (max disk busy 97.5%, MemAvailable=55.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:50:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:50:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:52:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:56:30 evo-x2 memory-emergency-guard-check[2381280]: MEMORY EMERGENCY: I/O PSI some avg60=61.55% sustained (max disk busy 98.0%, MemAvailable=50.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 01:56:33 evo-x2 memory-emergency-guard-check[2381280]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3484, zone 6) — top io since last trip: system.slice/io.stat +55413MB, user.slice/io.stat +24796MB, user.slice/user-1000.slice/io.stat +23850MB
Oct 18 01:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 828ms CPU time over 3.343s wall clock time, 8M memory peak, 19.8M read from disk, 8.7M written to disk.
Oct 18 01:57:00 evo-x2 memory-emergency-guard-check[2399845]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.22% sustained (max disk busy 100.0%, MemAvailable=55.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 01:57:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 01:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:02:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:03:32 evo-x2 memory-emergency-guard-check[2646980]: MEMORY EMERGENCY io drained (io PSI some avg60=39.00% < 40%) — churn units re-armed (re-arm #158)
Oct 18 02:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:06:32 evo-x2 memory-emergency-guard-check[2768056]: MEMORY EMERGENCY: I/O PSI some avg60=64.48% sustained (max disk busy 99.8%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 02:06:36 evo-x2 memory-emergency-guard-check[2768056]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3485, zone 6) — top io since last trip: system.slice/io.stat +48635MB, user.slice/io.stat +16946MB, user.slice/user-1000.slice/io.stat +16838MB
Oct 18 02:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 773ms CPU time over 3.489s wall clock time, 10.4M memory peak, 16.5M read from disk, 19.8M written to disk.
Oct 18 02:07:02 evo-x2 memory-emergency-guard-check[2779755]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.04% sustained (max disk busy 100.0%, MemAvailable=33.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 02:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:08:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:14:17 evo-x2 memory-emergency-guard-check[3048637]: MEMORY EMERGENCY io drained (io PSI some avg60=38.68% < 40%) — churn units re-armed (re-arm #159)
Oct 18 02:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:16:48 evo-x2 memory-emergency-guard-check[3188173]: MEMORY EMERGENCY: I/O PSI some avg60=88.22% sustained (max disk busy 99.8%, MemAvailable=45.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 02:17:26 evo-x2 memory-emergency-guard-check[3188173]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3486, zone 6) — top io since last trip: system.slice/io.stat +238650MB, system.slice/tq-agent-pool.service/io.stat +163450MB, user.slice/io.stat +29826MB
Oct 18 02:17:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:17:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 887ms CPU time over 38.863s wall clock time, 9.2M memory peak, 5.5M read from disk, 68.5M written to disk.
Oct 18 02:17:27 evo-x2 memory-emergency-guard-check[3234427]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.72% sustained (max disk busy 100.0%, MemAvailable=45.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (38s < 600s, 562s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 02:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 216ms CPU time over 350ms wall clock time, 8M memory peak, 6.4M read from disk, 4K written to disk.
Oct 18 02:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:20:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:21:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:21:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:22:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:24:03 evo-x2 gatus[2001919]: 2026/10/18 02:24:03 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 18 02:24:03 evo-x2 gatus[2001919]: 2026/10/18 02:24:03 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 18 02:24:49 evo-x2 memory-emergency-guard-check[3529713]: MEMORY EMERGENCY io drained (io PSI some avg60=38.84% < 40%) — churn units re-armed (re-arm #160)
Oct 18 02:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:26:05 evo-x2 gatus[2001919]: 2026/10/18 02:26:05 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 18 02:26:06 evo-x2 gatus[2001919]: 2026/10/18 02:26:06 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 18 02:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:26:49 evo-x2 memory-emergency-guard-check[3607905]: MEMORY EMERGENCY: I/O PSI some avg60=56.67% sustained (max disk busy 100.0%, MemAvailable=34.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 02:29:46 evo-x2 memory-emergency-guard-check[3607905]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3487, zone 6) — top io since last trip: system.slice/io.stat +218751MB, system.slice/tq-agent-pool.service/io.stat +132753MB, user.slice/io.stat +14009MB
Oct 18 02:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 572ms CPU time over 2min 56.984s wall clock time, 12.8M memory peak, 3.6M read from disk, 34.5M written to disk.
Oct 18 02:29:46 evo-x2 memory-emergency-guard-check[3746615]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.99% sustained (max disk busy 99.9%, MemAvailable=59.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (177s < 600s, 423s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 02:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:32:10 evo-x2 memory-emergency-guard-check[3833328]: MEMORY EMERGENCY io drained (io PSI some avg60=37.08% < 40%) — churn units re-armed (re-arm #161)
Oct 18 02:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:37:18 evo-x2 memory-emergency-guard-check[4124344]: MEMORY EMERGENCY cleared (MemAvailable=54.5%, zram=14.5%, PSI some avg10=0.46%, PSI some avg60=0.29%, 629s since last trip, restore #124 today: 1) — sacrifice sockets restored
Oct 18 02:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 139ms CPU time over 199ms wall clock time, 9.7M memory peak, 1.6M read from disk, 4K written to disk.
Oct 18 02:38:49 evo-x2 memory-emergency-guard-check[4190073]: MEMORY EMERGENCY: I/O PSI some avg60=48.15% sustained (max disk busy 97.1%, MemAvailable=40.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 02:39:38 evo-x2 memory-emergency-guard-check[4190073]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3488, zone 6) — top io since last trip: system.slice/io.stat +87729MB, system.slice/llama-chat.service/io.stat +21419MB, system.slice/inboxclean-web.service/io.stat +10404MB
Oct 18 02:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 483ms CPU time over 49.502s wall clock time, 11.3M memory peak, 1.9M read from disk, 1.9M written to disk.
Oct 18 02:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:39:40 evo-x2 systemd[2466]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 6 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 18 02:40:08 evo-x2 memory-emergency-guard-check[56289]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.96% sustained (max disk busy 74.3%, MemAvailable=56.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (79s < 600s, 521s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 02:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:41:40 evo-x2 memory-emergency-guard-check[118244]: MEMORY EMERGENCY io drained (io PSI some avg60=34.80% < 40%) — churn units re-armed (re-arm #162)
Oct 18 02:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:43:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:44:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:44:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:45:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:48:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:49:12 evo-x2 memory-emergency-guard-check[412039]: MEMORY EMERGENCY: I/O PSI some avg60=44.85% sustained (max disk busy 98.2%, MemAvailable=28.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 02:49:15 evo-x2 memory-emergency-guard-check[412039]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3489, zone 6) — top io since last trip: system.slice/io.stat +50199MB, system.slice/inboxclean-web.service/io.stat +10996MB, system.slice/monitor365-server.service/io.stat +7950MB
Oct 18 02:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 537ms CPU time over 3.208s wall clock time, 12.2M memory peak, 5.3M read from disk, 27.7M written to disk.
Oct 18 02:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:50:12 evo-x2 memory-emergency-guard-check[448898]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.85% sustained (max disk busy 99.8%, MemAvailable=38.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 02:50:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:50:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:52:11 evo-x2 memory-emergency-guard-check[468828]: MEMORY EMERGENCY io drained (io PSI some avg60=39.89% < 40%) — churn units re-armed (re-arm #163)
Oct 18 02:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:54:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:56:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:56:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:57:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:57:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 02:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 148ms CPU time over 400ms wall clock time, 8.6M memory peak, 2.7M read from disk, 4K written to disk.
Oct 18 02:59:14 evo-x2 memory-emergency-guard-check[670030]: MEMORY EMERGENCY: I/O PSI some avg60=56.01% sustained (max disk busy 99.3%, MemAvailable=32.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 18 03:00:23 evo-x2 memory-emergency-guard-check[670030]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3490, zone 6) — top io since last trip: system.slice/io.stat +104118MB, system.slice/inboxclean-web.service/io.stat +14064MB, user.slice/io.stat +13781MB
Oct 18 03:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.232s CPU time over 1min 8.358s wall clock time, 10.6M memory peak, 67.3M read from disk, 147.9M written to disk.
Oct 18 03:00:23 evo-x2 memory-emergency-guard-check[731699]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.41% sustained (max disk busy 98.9%, MemAvailable=51.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (69s < 600s, 531s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 18 03:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 18 03:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 18 00:47:33 evo-x2 thermal-pstate-guard-check[75966]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 18 00:58:59 evo-x2 thermal-pstate-guard-check[486506]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Oct 18 01:05:50 evo-x2 thermal-pstate-guard-check[706291]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 18 00:42:21 evo-x2 kernel: Command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/xriv7zkqjz8p38a4a77jdkwscqr3a7lm-nixos-system-evo-x2-26.11.20261014.55bfb4d/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 18 00:42:21 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/xriv7zkqjz8p38a4a77jdkwscqr3a7lm-nixos-system-evo-x2-26.11.20261014.55bfb4d/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 18 00:42:21 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 18 00:42:23 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
