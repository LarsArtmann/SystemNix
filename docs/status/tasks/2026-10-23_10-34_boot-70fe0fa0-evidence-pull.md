# Boot evidence pull: id8 70fe0fa0 (full: 70fe0fa028034980846516cd80b5b82a)

Pulled 2026-10-23 10:34 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-20 14:42:24 -> 2026-10-20 14:56:17 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 70fe0fa0 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 20 14:42:24 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Oct 20 14:42:24 evo-x2 kernel: Command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/k7gahyil7vbz5crvvbh27izf51vv12wn-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 20 14:42:24 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 20 14:56:08 evo-x2 signoz-wrapper[13831]: {"timestamp":"2026-10-20T14:56:08.237923806+02:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a058f1-39ef-7eed-8b07-77b623d6fde9","rule.query":"signoz_traces_missing","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Oct 20 14:56:08 evo-x2 signoz-wrapper[13831]: {"timestamp":"2026-10-20T14:56:08.252785411+02:00","level":"INFO","msg":"number of alerts found","rule.id":"01a058f1-39ef-7eed-8b07-77b623d6fde9","alert.count":1,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
Oct 20 14:56:10 evo-x2 mr-sync[1373]: mr-sync: go-plugin-mvp was renamed to plugmarket on GitHub, but .mrconfig already tracks plugmarket; leaving go-plugin-mvp orphaned
Oct 20 14:56:10 evo-x2 tq[29517]: 2026/10/20 14:56:10 INFO harvest: skipped reason=paced count=263 example="paced: per-repo interval 10m0s (last enqueue 5m0s ago)"
Oct 20 14:56:10 evo-x2 tq[29517]: 2026/10/20 14:56:10 INFO harvest tick done repos=3 items=2212 enqueued=0 skipped=2212
Oct 20 14:56:10 evo-x2 mr-sync[1373]: mr-sync: hierarchical-errors was renamed to erraudit on GitHub, but .mrconfig already tracks erraudit; leaving hierarchical-errors orphaned
Oct 20 14:56:11 evo-x2 signoz-wrapper[13831]: {"timestamp":"2026-10-20T14:56:11.893486152+02:00","level":"INFO","msg":"promql rule task","name":"01a00809-96c5-79b1-b3f7-446de33e014e-groupname","eval_started_at":"2026-10-20T12:56:11.892355376Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Oct 20 14:56:11 evo-x2 signoz-wrapper[13831]: {"timestamp":"2026-10-20T14:56:11.893599363+02:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-96c5-79b1-b3f7-446de33e014e","rule.query":"node_systemd_unit_state{state=\"failed\"} == 1","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Oct 20 14:56:17 evo-x2 indexer[2143]: INFO request method=GET path=/ status=200 duration=2.473875ms client_ip=192.168.1.150 request_id=6ad764f10000002661b08900fa089291
Oct 20 14:56:17 evo-x2 crush-daily[4304]: time=2026-10-20T14:56:17.047+02:00 level=INFO msg="http request" method=GET path=/ status=200 duration=1.803238ms
Oct 20 14:56:17 evo-x2 crm-server[9319]: time=2026-10-20T14:56:17.052+02:00 level=INFO msg=request method=GET path=/ status=303 duration=31µs
Oct 20 14:56:17 evo-x2 crm-server[9319]: time=2026-10-20T14:56:17.052+02:00 level=INFO msg=request method=GET path=/login status=200 duration=90µs
```

## Census
- oom-lines: 0
- guard-lines (memory-emergency-guard): 25
- thermal-THROTTLE-lines: 1
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
```

## memory-emergency-guard lines (all)
```
Oct 20 14:44:22 evo-x2 memory-emergency-guard-check[13865]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.44% sustained (max disk busy -1%, MemAvailable=81.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (332s < 600s, 268s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 20 14:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:46:23 evo-x2 memory-emergency-guard-check[31111]: MEMORY EMERGENCY io drained (io PSI some avg60=35.96% < 40%) — churn units re-armed (re-arm #334)
Oct 20 14:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:48:54 evo-x2 memory-emergency-guard-check[50219]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory is healthy: systemctl start fastflowlm.socket
Oct 20 14:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:50:25 evo-x2 memory-emergency-guard-check[63362]: MEMORY EMERGENCY: I/O PSI some avg60=46.11% sustained (max disk busy 100.0%, MemAvailable=74.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 20 14:53:23 evo-x2 systemd[1925]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 20 14:53:28 evo-x2 memory-emergency-guard-check[63362]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #3796, zone 6)
Oct 20 14:53:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:53:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 701ms CPU time over 3min 2.675s wall clock time, 11.8M memory peak, 166.9M written to disk.
Oct 20 14:53:40 evo-x2 memory-emergency-guard-check[91366]: MEMORY EMERGENCY io drained (io PSI some avg60=27.80% < 40%) — churn units re-armed (re-arm #335)
Oct 20 14:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:55:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 20 14:55:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 20 14:52:16 evo-x2 thermal-pstate-guard-check[79763]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 20 14:42:24 evo-x2 kernel: Command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/k7gahyil7vbz5crvvbh27izf51vv12wn-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 20 14:42:24 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\zdhcqlzqxmjcs1090psy4rqb9p425n85-initrd-linux-7.2.10-initrd.efi init=/nix/store/k7gahyil7vbz5crvvbh27izf51vv12wn-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 20 14:42:24 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 20 14:42:26 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
