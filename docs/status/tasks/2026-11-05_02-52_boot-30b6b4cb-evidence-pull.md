# Boot evidence pull: id8 30b6b4cb (full: 30b6b4cba3fe475cb18119c5a5d1b876)

Pulled 2026-11-05 02:52 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-05 03:05:44 -> 2026-11-05 03:13:47 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 30b6b4cb — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 05 03:05:44 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Nov 05 03:05:44 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/rc87rnbc117k7rwdxa0kla5wg0azgm6r-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 03:05:44 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 05 03:13:46 evo-x2 systemd[1]: Finished SigNoz telemetry coverage collector (traces freshness per registered service).
Nov 05 03:13:46 evo-x2 systemd[1]: signoz-coverage-metrics.service: Consumed 627ms CPU time over 1min 3.673s wall clock time, 36.7M memory peak, 8K read from disk, 1.2M incoming IP traffic, 89K outgoing IP traffic.
Nov 05 03:13:46 evo-x2 paperless-triage-sweep[209042]: paperless-triage: WARN: admission gate refused - skipping sweep, last-sweep untouched (freshness alerts after 1h of skips): REFUSE: paperless-triage — IO PSI some avg10=98.42% (>= 75% band).
Nov 05 03:13:46 evo-x2 systemd[1]: paperless-triage.service: Deactivated successfully.
Nov 05 03:13:46 evo-x2 systemd[1]: Finished paperless-triage - confidence gate sweep in front of paperless-gpt.
Nov 05 03:13:46 evo-x2 systemd[1]: paperless-triage.service: Consumed 114ms CPU time over 216ms wall clock time, 7.4M memory peak, 16K read from disk, 7.8K incoming IP traffic, 413B outgoing IP traffic.
Nov 05 03:13:46 evo-x2 file-renamer[2010]: 2026-11-05T03:13:46+01:00 INFO  watcher: request method=GET path=/health status=200 duration=133.02µs client_ip=127.0.0.1 request_id=6aebe65a00000088b78718e2779ee445
Nov 05 03:13:46 evo-x2 file-renamer[8326]: 2026-11-05T03:13:46+01:00 INFO  watcher: request method=GET path=/health status=200 duration=103.74µs client_ip=127.0.0.1 request_id=6aebe65a00000091b0f024147a5c4061
Nov 05 03:13:46 evo-x2 discordsync[28979]: {"time":"2026-11-05T03:13:46.454719565+01:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/api.traceAwareLogging.func1.1","file":"github.com/larsartmann/DiscordSync/internal/api/middleware.go","line":59},"msg":"request","method":"GET","path":"/health","status":200,"duration":186811,"client_ip":"127.0.0.1","request_id":"6aebe65a0000008cec35a2be60f39914","trace_id":"dcc8ec4223cb5336b56adcb22750ff69","span_id":"63c802ca784d782a"}
Nov 05 03:13:47 evo-x2 signoz-wrapper[11598]: {"timestamp":"2026-11-05T03:13:47.0283767+01:00","level":"INFO","msg":"promql rule task","name":"01a14332-5c05-7e82-9dc9-81b56a0259c0-groupname","eval_started_at":"2026-11-05T02:13:47.026885254Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Nov 05 03:13:47 evo-x2 signoz-wrapper[11598]: {"timestamp":"2026-11-05T03:13:47.028473321+01:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a14332-5c05-7e82-9dc9-81b56a0259c0","rule.query":"node_systemd_unit_state{name=\"crowdsec.service\",state=\"active\"}","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Nov 05 03:13:47 evo-x2 signoz-wrapper[11598]: {"timestamp":"2026-11-05T03:13:47.057256255+01:00","level":"INFO","msg":"number of alerts found","rule.id":"01a14332-5c05-7e82-9dc9-81b56a0259c0","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
```

## Census
- oom-lines: 0
- oom kill-pass join: 0 killed process(es) — 0 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 13
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
Nov 05 03:07:55 evo-x2 memory-emergency-guard-check[30389]: MEMORY EMERGENCY IO-PAUSE (trip #6862, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 03:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 13.486s wall clock time, 10.7M memory peak, 28.9M read from disk, 66.3M written to disk.
Nov 05 03:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:09:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:13:35 evo-x2 memory-emergency-guard-check[72070]: MEMORY EMERGENCY IO-PAUSE (trip #6863, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 03:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 818ms CPU time over 3min 23.471s wall clock time, 10.3M memory peak, 2.4M read from disk, 64.7M written to disk.
Nov 05 03:13:41 evo-x2 memory-emergency-guard-check[192343]: MEMORY EMERGENCY IO-PAUSE (trip #6864, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable; escalation arms after 3 such trips
Nov 05 03:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 05 03:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 680ms CPU time over 5.224s wall clock time, 9.1M memory peak, 196K read from disk, 12.6M written to disk.
```

## THERMAL THROTTLE lines
```
Nov 05 03:07:12 evo-x2 thermal-pstate-guard-check[23527]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 05 03:05:44 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/rc87rnbc117k7rwdxa0kla5wg0azgm6r-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 03:05:44 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/rc87rnbc117k7rwdxa0kla5wg0azgm6r-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 05 03:05:44 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 05 03:05:46 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793844827000000000 -> 1793844987000000000 epoch-ns UTC (2026-11-05 02:13:47 -> 2026-11-05 02:16:27 UTC)
Pipeline ALIVE in this window — newest row: 1793844832628355000 (2026-11-05 02:13:52 UTC); rows fetched: 20 (last 20 by timestamp DESC). Per M22 pull BOTH sources: ClickHouse is fresher than the journal cut by the flush lag.

Last rows (timestamp<TAB>body, newest first):
```
1793844832628355000	Starting Detect niri DRM zombie state and restart niri...
1793844832532183000	time=2026-11-05T03:13:52.532+01:00 level=ERROR source=textfile.go:242 msg="failed to collect textfile data" collector=textfile file=crush_events.prom err="failed to open textfile data file \\"/var/lib/prometheus-node-exporter/textfile_collectors/crush_events.prom\\": open /var/lib/prometheus-node-exporter/textfile_collectors/crush_events.prom: permission denied"
1793844832456123000	{"time":"2026-11-05T03:13:52.455712608+01:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/api.traceAwareLogging.func1.1","file":"github.com/larsartmann/DiscordSync/internal/api/middleware.go","line":59},"msg":"request","method":"GET","path":"/health","status":200,"duration":193161,"client_ip":"127.0.0.1","request_id":"6aebe6600000008f8e2b256f5598f784","trace_id":"15c6ece643d35863884f6e6612ffdc56","span_id":"092350742ad38b0f"}
1793844832455993000	2026-11-05T03:13:52+01:00 INFO  watcher: request method=GET path=/health status=200 duration=105.54µs client_ip=127.0.0.1 request_id=6aebe660000000948aa8e605b5b093bd
1793844832455676000	2026-11-05T03:13:52+01:00 INFO  watcher: request method=GET path=/health status=200 duration=149.441µs client_ip=127.0.0.1 request_id=6aebe6600000008b7be219c7251570ff
1793844832284961000	2026-11-05T02:13:52.284495Z  INFO storage_collector: storage event change=zram zram0: 0% full (631881728 / 66745532416 bytes)
1793844832284961000	2026-11-05T02:13:52.284485Z  INFO storage_collector: storage event change=btrfs 0b629b65-a1b7-40df-a7dc-9ea5e0b04959 (unlabeled): metadata 55% full, 1048576 bytes device-unallocated
1793844832284961000	2026-11-05T02:13:52.284478Z  INFO storage_collector: storage event change=btrfs 0133106b-98b4-4a30-b629-a51e96f70be1 (rust-cache): metadata 13% full, 120849432576 bytes device-unallocated
1793844832284961000	2026-11-05T02:13:52.284487Z  INFO storage_collector: storage event change=btrfs ca83e15b-9a8b-43ae-a2ce-330c38c650d3 (tlc): metadata 89% full, 286140341760 bytes device-unallocated
1793844832284961000	2026-11-05T02:13:52.284482Z  INFO storage_collector: storage event change=btrfs 046ea663-da55-48b7-b516-0dcdb87ba710 (data): metadata 15% full, 235618172928 bytes device-unallocated
1793844832284961000	2026-11-05T02:13:52.284473Z  INFO storage_collector: storage event change=disk sdd: +17 reads +2523 writes (0 MiB read, 885 MiB written, 31630 ms busy), 1 in flight
1793844832284961000	2026-11-05T02:13:52.284491Z  INFO storage_collector: storage event change=btrfs f981fc51-e1c2-419d-8c5f-e7b2a6f6c00f (pool): metadata 99% full, 24101192204288 bytes device-unallocated
1793844832284845000	2026-11-05T02:13:52.284467Z  INFO storage_collector: storage event change=disk sda: +1122 reads +2477 writes (10 MiB read, 884 MiB written, 41448 ms busy), 10 in flight
1793844832284845000	2026-11-05T02:13:52.284440Z  INFO storage_collector: storage event change=disk loop3: +0 reads +0 writes (0 MiB read, 0 MiB written, 0 ms busy), 0 in flight
1793844832284845000	2026-11-05T02:13:52.284438Z  INFO storage_collector: storage event change=disk loop2: +0 reads +0 writes (0 MiB read, 0 MiB written, 0 ms busy), 0 in flight
1793844832284845000	2026-11-05T02:13:52.284435Z  INFO storage_collector: storage event change=disk loop1: +0 reads +0 writes (0 MiB read, 0 MiB written, 0 ms busy), 0 in flight
1793844832284845000	2026-11-05T02:13:52.284451Z  INFO storage_collector: storage event change=disk loop7: +0 reads +0 writes (0 MiB read, 0 MiB written, 0 ms busy), 0 in flight
1793844832284845000	2026-11-05T02:13:52.284461Z  INFO storage_collector: storage event change=disk sdc: +222 reads +9671 writes (3 MiB read, 1297 MiB written, 59656 ms busy), 2 in flight
1793844832284845000	2026-11-05T02:13:52.284454Z  INFO storage_collector: storage event change=disk sdb: +5043 reads +38 writes (83 MiB read, 11 MiB written, 60000 ms busy), 43 in flight
1793844832284845000	2026-11-05T02:13:52.284456Z  INFO storage_collector: storage event change=disk sdb1: +5043 reads +38 writes (83 MiB read, 11 MiB written, 60000 ms busy), 43 in flight
```
