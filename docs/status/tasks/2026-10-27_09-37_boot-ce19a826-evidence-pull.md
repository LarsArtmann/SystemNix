# Boot evidence pull: id8 ce19a826 (full: ce19a8269c8d4de9935ec7f2e5535e3a)

Pulled 2026-10-27 09:37 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-25 22:23:41 -> 2026-10-26 22:53:58 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 ce19a826 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 25 22:23:41 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Oct 25 22:23:41 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/nnzaz7jdk8mvy246dd60prar42hmimjy-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 25 22:23:41 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 26 22:53:54 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:54.710388244+01:00","level":"INFO","msg":"promql rule task","name":"01a00809-9481-73bc-9136-15fd93b319fb-groupname","eval_started_at":"2026-10-26T21:53:54.709099272Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Oct 26 22:53:54 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:54.710456092+01:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-9481-73bc-9136-15fd93b319fb","rule.query":"node_nvme_critical_warning","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Oct 26 22:53:54 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:54.724999028+01:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-9481-73bc-9136-15fd93b319fb","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
Oct 26 22:53:55 evo-x2 systemd[1880]: Detect niri DRM zombie state and restart niri skipped, unmet condition check ConditionEnvironment=XDG_SESSION_ID
Oct 26 22:53:56 evo-x2 cv[2147083]: INFO  Health check completed overall_status=warn checks_count=44 uptime=2h58m22s
Oct 26 22:53:56 evo-x2 cv[2147083]: INFO  request method=GET path=/health status=200 duration=248.732µs client_ip=127.0.0.1 request_id=6adfcbf400001a017e50bac82a48217f
Oct 26 22:53:57 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:57.259621586+01:00","level":"INFO","msg":"promql rule task","name":"01a17304-ef78-7004-b083-8c18d3fda9bc-groupname","eval_started_at":"2026-10-26T21:53:57.258620339Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
Oct 26 22:53:57 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:57.259724833+01:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a17304-ef78-7004-b083-8c18d3fda9bc","rule.query":"system_any_service_restart_churn","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
Oct 26 22:53:57 evo-x2 signoz-wrapper[2852416]: {"timestamp":"2026-10-26T22:53:57.27456189+01:00","level":"INFO","msg":"number of alerts found","rule.id":"01a17304-ef78-7004-b083-8c18d3fda9bc","alert.count":1,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
Oct 26 22:53:58 evo-x2 cv[2147083]: INFO  Health check completed overall_status=warn checks_count=44 uptime=2h58m22s
Oct 26 22:53:58 evo-x2 cv[2147083]: INFO  request method=GET path=/health status=200 duration=250.773µs client_ip=127.0.0.1 request_id=6adfcbf600001a0295d71c4f6a276722
Oct 26 22:53:58 evo-x2 smartd[1474]: Device: /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713 [SAT], SMART Usage Attribute: 194 Temperature_Celsius changed from 69 to 68
```

## Census
- oom-lines: 27
- guard-lines (memory-emergency-guard): 3173
- thermal-THROTTLE-lines: 5
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
Oct 26 16:01:35 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:01:36 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=15205,uid=1000
Oct 26 16:01:36 evo-x2 kernel: Out of memory: Killed process 15205 (llama-server) total-vm:41726972kB, anon-rss:1820kB, file-rss:3676kB, shmem-rss:0kB, UID:1000 pgtables:68028kB oom_score_adj:300
Oct 26 16:03:32 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/activitywatch-watcher-aw-watcher-utilization.service,task=.aw-watcher-uti,pid=2889600,uid=1000
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 2889600 (.aw-watcher-uti) total-vm:128756kB, anon-rss:0kB, file-rss:1928kB, shmem-rss:0kB, UID:1000 pgtables:160kB oom_score_adj:200
Oct 26 16:09:25 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=curl,pid=2168728,uid=1000
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 2168728 (curl) total-vm:23060kB, anon-rss:1464kB, file-rss:5432kB, shmem-rss:0kB, UID:1000 pgtables:84kB oom_score_adj:300
Oct 26 16:09:25 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=2168635,uid=1000
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 2168635 (llama-server) total-vm:4348728kB, anon-rss:2328kB, file-rss:3528kB, shmem-rss:0kB, UID:1000 pgtables:152kB oom_score_adj:300
Oct 26 16:09:25 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-embeddings.service,task=llama-server,pid=2170369,uid=1000
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 2170369 (llama-server) total-vm:31792kB, anon-rss:188kB, file-rss:4kB, shmem-rss:0kB, UID:1000 pgtables:88kB oom_score_adj:300
Oct 26 16:09:25 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-175.slice/user@175.service/session.slice/wireplumber.service,task=wireplumber,pid=4901,uid=175
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 4901 (wireplumber) total-vm:882648kB, anon-rss:548kB, file-rss:64kB, shmem-rss:0kB, UID:175 pgtables:252kB oom_score_adj:200
Oct 26 16:09:25 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:09:25 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/activitywatch.service,task=aw-server,pid=2889599,uid=1000
Oct 26 16:09:25 evo-x2 kernel: Out of memory: Killed process 2889599 (aw-server) total-vm:2131848kB, anon-rss:8kB, file-rss:52kB, shmem-rss:0kB, UID:1000 pgtables:368kB oom_score_adj:200
Oct 26 16:21:58 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:22:02 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=2175690,uid=1000
Oct 26 16:22:02 evo-x2 kernel: Out of memory: Killed process 2175690 (llama-server) total-vm:41726972kB, anon-rss:472kB, file-rss:9100kB, shmem-rss:0kB, UID:1000 pgtables:68004kB oom_score_adj:300
Oct 26 16:22:33 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 26 16:22:35 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-embeddings.service,task=llama-server,pid=2175963,uid=1000
Oct 26 16:22:35 evo-x2 kernel: Out of memory: Killed process 2175963 (llama-server) total-vm:7876896kB, anon-rss:615752kB, file-rss:144kB, shmem-rss:0kB, UID:1000 pgtables:2472kB oom_score_adj:300
```

## memory-emergency-guard lines (all)
```
Oct 25 22:27:18 evo-x2 memory-emergency-guard-check[16977]: MEMORY EMERGENCY io drained (io PSI some avg60=31.15% < 40%) — churn units re-armed (re-arm #485)
Oct 25 22:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:33:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:33:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:34:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:35:32 evo-x2 memory-emergency-guard-check[102591]: MEMORY EMERGENCY: I/O PSI some avg60=40.14% sustained (max disk busy 100.0%, MemAvailable=53.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 25 22:37:00 evo-x2 memory-emergency-guard-check[102591]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4381, zone 6)
Oct 25 22:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.164s CPU time over 1min 27.887s wall clock time, 12.2M memory peak, 26.3M written to disk.
Oct 25 22:37:22 evo-x2 memory-emergency-guard-check[129689]: MEMORY EMERGENCY io drained (io PSI some avg60=33.79% < 40%) — churn units re-armed (re-arm #486)
Oct 25 22:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:37:25 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 25 22:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:45:48 evo-x2 memory-emergency-guard-check[226894]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 22:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:46:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:46:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:53:39 evo-x2 btrfs-gc-admission[289935]: REFUSE: btrfs-compsize — memory-emergency-guard tripped 18 min ago (window 60 min).
Oct 25 22:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:56:02 evo-x2 memory-emergency-guard-check[311935]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 22:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 22:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:06:09 evo-x2 memory-emergency-guard-check[395487]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:16:09 evo-x2 memory-emergency-guard-check[474842]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:19:13 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: FLM RESTORE CAPPED; MEMORY GUARD DEAD" "FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (-1s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard".
Oct 25 23:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:20:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:21:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:22:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:23:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:24:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:26:11 evo-x2 memory-emergency-guard-check[556163]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:33:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:34:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:35:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:35:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:36:13 evo-x2 memory-emergency-guard-check[628113]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:36:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:36:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:37:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:41:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:41:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:42:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:46:20 evo-x2 memory-emergency-guard-check[698951]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:51:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:57:00 evo-x2 memory-emergency-guard-check[772468]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 25 23:57:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 25 23:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:00:30 evo-x2 memory-emergency-guard-check[795810]: MEMORY EMERGENCY cleared (MemAvailable=57.0%, zram=8.3%, PSI some avg10=3.51%, PSI some avg60=4.21%, io PSI some avg60=17.62%, 5098s since last trip, restore #148 today: 1) — sacrifice sockets restored
Oct 26 00:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:01:39 evo-x2 memory-emergency-guard-check[804026]: MEMORY EMERGENCY: I/O PSI some avg60=43.23% sustained (max disk busy 99.8%, MemAvailable=57.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 00:02:35 evo-x2 memory-emergency-guard-check[804026]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4382, zone 6) — top io since last trip: system.slice/io.stat +659540MB, system.slice/forgejo.service/io.stat +25717MB, system.slice/hermes.service/io.stat +12324MB
Oct 26 00:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 710ms CPU time over 56.164s wall clock time, 11.9M memory peak, 13.6M read from disk, 5.7M written to disk.
Oct 26 00:02:35 evo-x2 memory-emergency-guard-check[817673]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.61% sustained (max disk busy 99.9%, MemAvailable=57.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (56s < 600s, 544s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 00:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:02:37 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30".
Oct 26 00:03:37 evo-x2 memory-emergency-guard-check[821149]: MEMORY EMERGENCY io drained (io PSI some avg60=32.11% < 40%) — churn units re-armed (re-arm #487); btrfs-scrub left stopped (no-resume, freeze-#7): btrfs-scrub@-.service btrfs-scrub@data.service btrfs-scrub@mnt-pool.service
Oct 26 00:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:08:12 evo-x2 gatus[15323]: 2026/10/26 00:08:12 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 00:08:12 evo-x2 gatus[15323]: 2026/10/26 00:08:12 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 00:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:10:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:11:40 evo-x2 memory-emergency-guard-check[905071]: MEMORY EMERGENCY cleared (MemAvailable=56.2%, zram=8.1%, PSI some avg10=0.38%, PSI some avg60=1.93%, io PSI some avg60=17.67%, 601s since last trip, restore #149 today: 2) — sacrifice sockets restored
Oct 26 00:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:12:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:12:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:17:41 evo-x2 memory-emergency-guard-check[942346]: MEMORY EMERGENCY: I/O PSI some avg60=47.15% sustained (max disk busy 100.0%, MemAvailable=39.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 00:18:38 evo-x2 memory-emergency-guard-check[942346]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4383, zone 6) — top io since last trip: system.slice/io.stat +109705MB, system.slice/papdashboard.service/io.stat +5518MB, system.slice/nsfw-classifier.service/io.stat +4232MB
Oct 26 00:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 428ms CPU time over 57.565s wall clock time, 11.6M memory peak, 768K read from disk, 36.5M written to disk.
Oct 26 00:18:39 evo-x2 memory-emergency-guard-check[957973]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.74% sustained (max disk busy 100.0%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (57s < 600s, 543s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 00:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:19:53 evo-x2 memory-emergency-guard-check[970843]: MEMORY EMERGENCY io drained (io PSI some avg60=30.64% < 40%) — churn units re-armed (re-arm #488)
Oct 26 00:19:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:23:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:24:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:25:37 evo-x2 gatus[15323]: 2026/10/26 00:25:37 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=BTRFS Scrub Incomplete with description='BTRFS scrub is incomplete (never started or interrupted) WITHOUT a guard deferral — a silently wedged scrub, not the memory-guard churn-stop class (that sets btrfs_scrub_deferred_by_guard 1 and this check stays green). Check 'btrfs scrub status /' and '/data', memory-emergency-guard journal for recent trips; the next weekly autoScrub window retries.' has been TRIGGERED
Oct 26 00:25:37 evo-x2 gatus[15323]: 2026/10/26 00:25:37 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=BTRFS Scrub Incomplete with description='BTRFS scrub is incomplete (never started or interrupted) WITHOUT a guard deferral — a silently wedged scrub, not the memory-guard churn-stop class (that sets btrfs_scrub_deferred_by_guard 1 and this check stays green). Check 'btrfs scrub status /' and '/data', memory-emergency-guard journal for recent trips; the next weekly autoScrub window retries.' has been TRIGGERED
Oct 26 00:25:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:27:41 evo-x2 memory-emergency-guard-check[1084640]: MEMORY EMERGENCY cleared (MemAvailable=58.2%, zram=17.6%, PSI some avg10=1.67%, PSI some avg60=3.63%, io PSI some avg60=5.21%, 600s since last trip, restore #150 today: 3) — sacrifice sockets restored
Oct 26 00:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:34:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:36:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:41:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 00:59:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:09:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:33:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:36:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:37:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:38:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:38:34 evo-x2 memory-emergency-guard-check[2023794]: MEMORY EMERGENCY: I/O PSI some avg60=40.37% sustained (max disk busy 100.0%, MemAvailable=37.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 01:38:39 evo-x2 memory-emergency-guard-check[2023794]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4384, zone 6) — top io since last trip: system.slice/io.stat +367691MB, system.slice/monitor365-server.service/io.stat +217868MB, system.slice/cv-server.service/io.stat +41988MB
Oct 26 01:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 479ms CPU time over 5.182s wall clock time, 11.1M memory peak, 1.7M read from disk, 31.2M written to disk.
Oct 26 01:39:05 evo-x2 memory-emergency-guard-check[2031094]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.13% sustained (max disk busy 97.0%, MemAvailable=58.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 01:39:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:39:11 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 01:40:00 evo-x2 memory-emergency-guard-check[2034440]: MEMORY EMERGENCY io drained (io PSI some avg60=38.70% < 40%) — churn units re-armed (re-arm #489)
Oct 26 01:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:40:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:40:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:41:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:41:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:42:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:44:15 evo-x2 gatus[15323]: 2026/10/26 01:44:15 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 01:44:15 evo-x2 gatus[15323]: 2026/10/26 01:44:15 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 01:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:46:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:49:09 evo-x2 memory-emergency-guard-check[2201473]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 01:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:55:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:55:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:56:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:59:11 evo-x2 memory-emergency-guard-check[2319006]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 01:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 01:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:08:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:08:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:09:12 evo-x2 memory-emergency-guard-check[2399141]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 02:09:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:09:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:10:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:10:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:12:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:19:59 evo-x2 memory-emergency-guard-check[2489579]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 02:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:30:32 evo-x2 memory-emergency-guard-check[2592864]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 02:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:32:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:35:15 evo-x2 btrfs-gc-admission[2628086]: REFUSE: nix-build-cleanup — memory-emergency-guard tripped 56 min ago (window 60 min).
Oct 26 02:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:40:41 evo-x2 memory-emergency-guard-check[2672538]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 02:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:42:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:43:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:45:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:48:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:49:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:50:46 evo-x2 memory-emergency-guard-check[2742887]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 02:50:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:51:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:52:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 02:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:01:00 evo-x2 memory-emergency-guard-check[2824842]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:02:30 evo-x2 memory-emergency-guard-check[2836829]: MEMORY EMERGENCY: I/O PSI some avg60=46.88% sustained (max disk busy 100.0%, MemAvailable=57.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 03:02:32 evo-x2 memory-emergency-guard-check[2836829]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4385, zone 6) — top io since last trip: system.slice/io.stat +397716MB, system.slice/tq-agent-pool.service/io.stat +23114MB, system.slice/system-immich.slice/io.stat +12263MB
Oct 26 03:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 423ms CPU time over 2.187s wall clock time, 11.7M memory peak, 416K read from disk, 32.4M written to disk.
Oct 26 03:03:00 evo-x2 memory-emergency-guard-check[2845571]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.48% sustained (max disk busy 100.0%, MemAvailable=57.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 03:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:03:06 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 03:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:06:14 evo-x2 memory-emergency-guard-check[2871431]: MEMORY EMERGENCY io drained (io PSI some avg60=26.25% < 40%) — churn units re-armed (re-arm #490)
Oct 26 03:06:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:08:13 evo-x2 gatus[15323]: 2026/10/26 03:08:13 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 03:08:13 evo-x2 gatus[15323]: 2026/10/26 03:08:13 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 03:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:09:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:10:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:10:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:11:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:11:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:12:39 evo-x2 memory-emergency-guard-check[2925168]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:16:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:17:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:17:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:18:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:19:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:20:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:22:44 evo-x2 memory-emergency-guard-check[3015146]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:22:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:24:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:28:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:32:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:32:59 evo-x2 memory-emergency-guard-check[3224511]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:39:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:39:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:43:33 evo-x2 memory-emergency-guard-check[3292302]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:44:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:45:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:46:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:54:11 evo-x2 memory-emergency-guard-check[3366027]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 03:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:55:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:56:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:57:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:57:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:58:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:59:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 03:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:00:02 evo-x2 btrfs-gc-admission[3407669]: REFUSE: btrfs-balance-metadata — memory-emergency-guard tripped 57 min ago (window 60 min).
Oct 26 04:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:01:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:02:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:04:15 evo-x2 memory-emergency-guard-check[3435466]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 04:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:12:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:14:30 evo-x2 memory-emergency-guard-check[3503584]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 04:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:17:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:18:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:18:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:24:39 evo-x2 memory-emergency-guard-check[3583353]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 04:24:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:27:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:28:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:29:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:30:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:30:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:34:41 evo-x2 memory-emergency-guard-check[3664099]: MEMORY EMERGENCY: I/O PSI some avg60=46.24% sustained (max disk busy 100.0%, MemAvailable=57.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 04:34:45 evo-x2 memory-emergency-guard-check[3664099]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4386, zone 6) — top io since last trip: system.slice/io.stat +652936MB, system.slice/monitor365-server.service/io.stat +359705MB, system.slice/forgejo.service/io.stat +17053MB
Oct 26 04:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 434ms CPU time over 3.865s wall clock time, 12.3M memory peak, 1.6M read from disk, 24.4M written to disk.
Oct 26 04:35:34 evo-x2 memory-emergency-guard-check[3675128]: MEMORY EMERGENCY io drained (io PSI some avg60=33.02% < 40%) — churn units re-armed (re-arm #491)
Oct 26 04:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:35:37 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 04:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:37:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:38:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:38:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:39:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:39:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:40:12 evo-x2 gatus[15323]: 2026/10/26 04:40:12 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 04:40:12 evo-x2 gatus[15323]: 2026/10/26 04:40:12 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 04:40:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:44:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:45:26 evo-x2 memory-emergency-guard-check[3759564]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 04:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:48:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:53:38 evo-x2 btrfs-gc-admission[3832521]: REFUSE: btrfs-compsize — memory-emergency-guard tripped 18 min ago (window 60 min).
Oct 26 04:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:55:32 evo-x2 memory-emergency-guard-check[3848943]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 04:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 04:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:05:39 evo-x2 memory-emergency-guard-check[3926479]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:11:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:12:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:15:50 evo-x2 memory-emergency-guard-check[3991244]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:26:01 evo-x2 memory-emergency-guard-check[4064112]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:31:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:31:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:36:09 evo-x2 memory-emergency-guard-check[4140773]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:40:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:40:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:41:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:41:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:42:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:42:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:43:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:43:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:44:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:44:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:45:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:45:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:46:11 evo-x2 memory-emergency-guard-check[28961]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:46:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:46:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:47:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:47:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:48:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:48:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:51:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:53:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:53:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:54:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:57:13 evo-x2 memory-emergency-guard-check[113975]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 05:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:58:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 05:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:03:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:07:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:07:30 evo-x2 memory-emergency-guard-check[179115]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 06:07:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:08:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:11:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:17:39 evo-x2 memory-emergency-guard-check[244950]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 06:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:19:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:24:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:27:41 evo-x2 memory-emergency-guard-check[324375]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 06:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:29:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:36:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:37:50 evo-x2 memory-emergency-guard-check[400895]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 06:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:40:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:48:02 evo-x2 memory-emergency-guard-check[474567]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 06:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:53:39 evo-x2 memory-emergency-guard-check[513482]: MEMORY EMERGENCY: I/O PSI some avg60=41.68% sustained (max disk busy 100.0%, MemAvailable=55.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 06:55:28 evo-x2 memory-emergency-guard-check[513482]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4387, zone 6) — top io since last trip: system.slice/io.stat +902242MB, system.slice/monitor365-server.service/io.stat +322569MB, system.slice/forgejo.service/io.stat +21921MB
Oct 26 06:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.955s CPU time over 1min 48.972s wall clock time, 12M memory peak, 2.8M read from disk, 550.6M written to disk.
Oct 26 06:55:28 evo-x2 memory-emergency-guard-check[536813]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.46% sustained (max disk busy 99.4%, MemAvailable=49.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (109s < 600s, 491s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 06:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:55:54 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 06:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 06:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:00:13 evo-x2 gatus[15323]: 2026/10/26 07:00:13 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 07:00:13 evo-x2 gatus[15323]: 2026/10/26 07:00:13 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 07:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:03:41 evo-x2 memory-emergency-guard-check[648057]: MEMORY EMERGENCY: I/O PSI some avg60=46.85% sustained (max disk busy 94.6%, MemAvailable=54.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 07:05:39 evo-x2 memory-emergency-guard-check[648057]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4388, zone 6) — top io since last trip: system.slice/io.stat +17413MB, system.slice/forgejo.service/io.stat +6987MB, user.slice/io.stat +3983MB
Oct 26 07:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 778ms CPU time over 1min 58.156s wall clock time, 11.1M memory peak, 279M written to disk.
Oct 26 07:05:39 evo-x2 memory-emergency-guard-check[672547]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.67% sustained (max disk busy 100.0%, MemAvailable=54.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (118s < 600s, 482s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 07:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:10:03 evo-x2 memory-emergency-guard-check[717559]: MEMORY EMERGENCY io drained (io PSI some avg60=39.78% < 40%) — churn units re-armed (re-arm #492)
Oct 26 07:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:14:12 evo-x2 memory-emergency-guard-check[815918]: MEMORY EMERGENCY: I/O PSI some avg60=47.95% sustained (max disk busy 100.0%, MemAvailable=46.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 07:18:04 evo-x2 memory-emergency-guard-check[815918]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4389, zone 6) — top io since last trip: system.slice/io.stat +38194MB, user.slice/io.stat +6948MB, user.slice/user-1000.slice/io.stat +6543MB
Oct 26 07:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.592s CPU time over 3min 54.358s wall clock time, 11.5M memory peak, 3.7M read from disk, 525.8M written to disk.
Oct 26 07:18:04 evo-x2 memory-emergency-guard-check[880729]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.26% sustained (max disk busy 99.7%, MemAvailable=38.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (232s < 600s, 368s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 07:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:19:15 evo-x2 memory-emergency-guard-check[890470]: MEMORY EMERGENCY io drained (io PSI some avg60=33.36% < 40%) — churn units re-armed (re-arm #493)
Oct 26 07:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:19:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:24:28 evo-x2 memory-emergency-guard-check[980577]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 07:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:25:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:25:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:30:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:31:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:35:00 evo-x2 memory-emergency-guard-check[1089544]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 07:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:45:02 evo-x2 memory-emergency-guard-check[1211847]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 07:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 07:59:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:10:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:10:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:11:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:11:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:23:00 evo-x2 memory-emergency-guard-check[2184989]: MEMORY EMERGENCY: MemAvailable=3.2% below absolute floor — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 08:23:03 evo-x2 memory-emergency-guard-check[2184989]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4390, zone 1) — top io since last trip: system.slice/io.stat +437281MB, user.slice/io.stat +35494MB, user.slice/user-1000.slice/io.stat +31133MB
Oct 26 08:23:48 evo-x2 memory-emergency-guard-check[2184989]: MEMORY EMERGENCY io drained (io PSI some avg60=11.65% < 40%) — churn units re-armed (re-arm #494)
Oct 26 08:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 48.946s wall clock time, 10.4M memory peak, 17M read from disk, 33.5M written to disk.
Oct 26 08:23:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:23:55 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 08:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:25:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:28:12 evo-x2 gatus[15323]: 2026/10/26 08:28:12 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 08:28:12 evo-x2 gatus[15323]: 2026/10/26 08:28:12 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 08:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:33:02 evo-x2 memory-emergency-guard-check[2382381]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 08:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:37:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:42:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:43:09 evo-x2 memory-emergency-guard-check[2541469]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 08:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:46:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:47:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:48:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:51:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:53:30 evo-x2 memory-emergency-guard-check[2742652]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 08:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:55:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 08:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:02:23 evo-x2 systemnix-deploy-tail[2903197]: ✗ memory-emergency-guard tripped 1× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 26 09:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:03:36 evo-x2 memory-emergency-guard-check[2915227]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 09:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:11:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:13:41 evo-x2 memory-emergency-guard-check[3079248]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 09:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:18:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:23:45 evo-x2 memory-emergency-guard-check[3364996]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 09:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:25:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:32:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:34:00 evo-x2 memory-emergency-guard-check[794413]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 09:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:35:58 evo-x2 gatus[15323]: 2026/10/26 09:35:58 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 26 09:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:48:33 evo-x2 memory-emergency-guard-check[2588722]: MEMORY EMERGENCY: I/O PSI some avg60=47.72% sustained (max disk busy 99.8%, MemAvailable=31.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 09:48:40 evo-x2 memory-emergency-guard-check[2588722]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4391, zone 6) — top io since last trip: system.slice/io.stat +521021MB, user.slice/io.stat +36696MB, user.slice/user-1000.slice/io.stat +32525MB
Oct 26 09:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 7.044s wall clock time, 8.7M memory peak, 9.6M read from disk, 57.1M written to disk.
Oct 26 09:49:30 evo-x2 memory-emergency-guard-check[2622646]: MEMORY EMERGENCY io drained (io PSI some avg60=35.75% < 40%) — churn units re-armed (re-arm #495)
Oct 26 09:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:49:33 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 09:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:51:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:53:57 evo-x2 gatus[883921]: 2026/10/26 09:53:57 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 09:53:57 evo-x2 gatus[883921]: 2026/10/26 09:53:57 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 09:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:57:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:58:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:58:45 evo-x2 memory-emergency-guard-check[2786482]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 09:58:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 09:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:01:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:05:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:06:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:08:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:08:53 evo-x2 memory-emergency-guard-check[2903253]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 10:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:09:22 evo-x2 systemnix-deploy-tail[2907710]: ✗ memory-emergency-guard tripped 1× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 26 10:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:14:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:15:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:15:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:16:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:16:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:18:55 evo-x2 memory-emergency-guard-check[3051338]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 10:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:24:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:25:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:29:02 evo-x2 memory-emergency-guard-check[3201150]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 10:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:35:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:39:07 evo-x2 memory-emergency-guard-check[3444330]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 10:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:40:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:41:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:42:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:45:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:45:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:47:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:48:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:49:17 evo-x2 memory-emergency-guard-check[3823306]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 10:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:51:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:52:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:53:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:59:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 10:59:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:01:53 evo-x2 memory-emergency-guard-check[148508]: MEMORY EMERGENCY: I/O PSI some avg60=43.69% sustained (max disk busy 99.9%, MemAvailable=18.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 11:02:15 evo-x2 memory-emergency-guard-check[148508]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4392, zone 6) — top io since last trip: system.slice/io.stat +417750MB, system.slice/monitor365-server.service/io.stat +179552MB, user.slice/io.stat +40706MB
Oct 26 11:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 997ms CPU time over 22.567s wall clock time, 9.1M memory peak, 8M read from disk, 131.2M written to disk.
Oct 26 11:02:23 evo-x2 memory-emergency-guard-check[179273]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.31% sustained (max disk busy 97.4%, MemAvailable=36.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 11:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:02:24 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 11:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:04:15 evo-x2 memory-emergency-guard-check[289507]: MEMORY EMERGENCY io drained (io PSI some avg60=33.53% < 40%) — churn units re-armed (re-arm #496)
Oct 26 11:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:08:02 evo-x2 gatus[883921]: 2026/10/26 11:08:02 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 11:08:02 evo-x2 gatus[883921]: 2026/10/26 11:08:02 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 11:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:11:55 evo-x2 memory-emergency-guard-check[728259]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 11:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:15:26 evo-x2 memory-emergency-guard-check[904097]: MEMORY EMERGENCY: I/O PSI some avg60=42.14% sustained (max disk busy 98.2%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 11:15:31 evo-x2 memory-emergency-guard-check[904097]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4393, zone 6) — top io since last trip: system.slice/io.stat +74629MB, system.slice/monitor365-server.service/io.stat +23657MB, user.slice/io.stat +21570MB
Oct 26 11:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 596ms CPU time over 5.824s wall clock time, 11.3M memory peak, 9.8M read from disk, 20.2M written to disk.
Oct 26 11:15:56 evo-x2 memory-emergency-guard-check[925385]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.57% sustained (max disk busy 99.3%, MemAvailable=42.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 11:15:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:16:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:16:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:17:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:17:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:18:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:19:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:19:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:20:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:24:38 evo-x2 memory-emergency-guard-check[1276579]: MEMORY EMERGENCY io drained (io PSI some avg60=35.28% < 40%) — churn units re-armed (re-arm #497)
Oct 26 11:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:25:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:25:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:26:40 evo-x2 memory-emergency-guard-check[1395908]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 11:26:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:28:02 evo-x2 systemnix-deploy-tail[1453974]: ✗ memory-emergency-guard tripped 2× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 26 11:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:31:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:32:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:32:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:33:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:34:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:36:53 evo-x2 memory-emergency-guard-check[1699791]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 11:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:38:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:40:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:41:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:41:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:42:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:46:59 evo-x2 memory-emergency-guard-check[1891158]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 11:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 191ms CPU time over 307ms wall clock time, 7.7M memory peak, 1M read from disk, 4K written to disk.
Oct 26 11:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:49:15 evo-x2 gatus[883921]: 2026/10/26 11:49:15 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 26 11:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:53:02 evo-x2 memory-emergency-guard-check[2066543]: MEMORY EMERGENCY: I/O PSI some avg60=43.13% sustained (max disk busy 100.0%, MemAvailable=53.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 11:53:05 evo-x2 memory-emergency-guard-check[2066543]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4394, zone 6) — top io since last trip: system.slice/io.stat +303303MB, user.slice/io.stat +55257MB, user.slice/user-1000.slice/io.stat +35787MB
Oct 26 11:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 3.020s wall clock time, 11.1M memory peak, 2.5M read from disk, 25.9M written to disk.
Oct 26 11:54:19 evo-x2 memory-emergency-guard-check[2079342]: MEMORY EMERGENCY io drained (io PSI some avg60=39.69% < 40%) — churn units re-armed (re-arm #498)
Oct 26 11:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:54:19 evo-x2 memory-emergency-guard-check[2123196]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.13% sustained (max disk busy 98.7%, MemAvailable=49.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (77s < 600s, 523s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 11:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:54:21 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 3 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 11:54:31 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 3 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 11:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:55:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:55:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:56:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:57:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:58:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 11:59:25 evo-x2 gatus[2005067]: 2026/10/26 11:59:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 11:59:25 evo-x2 gatus[2005067]: 2026/10/26 11:59:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 11:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:00:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:03:22 evo-x2 memory-emergency-guard-check[2516548]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 12:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:07:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:13:25 evo-x2 memory-emergency-guard-check[2746331]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 12:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:14:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:15:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:16:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:17:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:18:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:19:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:19:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:20:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:21:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:22:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:22:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:23:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:24:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:26:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:26:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:27:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:31:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:31:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:40:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:43:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:55:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:56:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:57:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:57:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:58:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 12:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:02:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:03:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:11:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:15:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:20:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:32:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:39:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:40:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:41:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:41:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:43:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:45:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:46:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:48:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:49:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 13:59:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:14:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:17:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:18:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:30:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:31:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:36:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:37:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:38:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:39:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:46:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:51:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:52:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:52:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 14:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:04:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:08:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:08:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:12:02 evo-x2 memory-emergency-guard-check[1115276]: MEMORY EMERGENCY: I/O PSI some avg60=54.23% sustained (max disk busy 100.0%, MemAvailable=35.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 15:12:07 evo-x2 memory-emergency-guard-check[1115276]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4395, zone 6) — top io since last trip: system.slice/io.stat +1281484MB, user.slice/io.stat +44554MB, system.slice/forgejo.service/io.stat +37167MB
Oct 26 15:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 4.536s wall clock time, 10.4M memory peak, 24.7M read from disk, 41.9M written to disk.
Oct 26 15:12:35 evo-x2 memory-emergency-guard-check[1161136]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.38% sustained (max disk busy 99.2%, MemAvailable=55.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (33s < 600s, 567s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 15:12:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:12:39 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 15:13:49 evo-x2 memory-emergency-guard-check[1181353]: MEMORY EMERGENCY io drained (io PSI some avg60=36.20% < 40%) — churn units re-armed (re-arm #499)
Oct 26 15:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:14:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:14:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:15:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:15:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:16:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:17:25 evo-x2 gatus[2005067]: 2026/10/26 15:17:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 15:17:25 evo-x2 gatus[2005067]: 2026/10/26 15:17:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 15:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:18:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:20:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:22:28 evo-x2 memory-emergency-guard-check[1446339]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 15:22:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:22:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:23:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:23:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:27:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:32:35 evo-x2 memory-emergency-guard-check[1691375]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 15:32:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:38:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:39:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:40:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:41:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:41:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:42:48 evo-x2 memory-emergency-guard-check[1806960]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 15:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:52:51 evo-x2 memory-emergency-guard-check[1950006]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 15:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:57:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:58:21 evo-x2 memory-emergency-guard-check[2042175]: MEMORY EMERGENCY: I/O PSI some avg60=54.43% sustained (max disk busy 100.0%, MemAvailable=46.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 15:58:32 evo-x2 memory-emergency-guard-check[2042175]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4396, zone 6) — top io since last trip: system.slice/io.stat +290240MB, system.slice/monitor365-server.service/io.stat +269911MB, user.slice/io.stat +17883MB
Oct 26 15:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 10.966s wall clock time, 11.1M memory peak, 3M read from disk, 30.4M written to disk.
Oct 26 15:58:52 evo-x2 memory-emergency-guard-check[2059570]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.02% sustained (max disk busy 96.9%, MemAvailable=49.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 15:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:59:01 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 2 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 15:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 15:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 166ms CPU time over 436ms wall clock time, 12.9M memory peak, 7.2M read from disk, 4K written to disk.
Oct 26 16:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:08:42 evo-x2 gatus[2005067]: 2026/10/26 16:08:13 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 16:08:42 evo-x2 gatus[2005067]: 2026/10/26 16:08:13 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 16:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 127ms CPU time over 15.871s wall clock time, 8.4M memory peak, 1.3M read from disk, 4K written to disk.
Oct 26 16:09:25 evo-x2 memory-emergency-guard-check[2179437]: MEMORY EMERGENCY: MemAvailable=0.0% below absolute floor — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 16:09:25 evo-x2 memory-emergency-guard-check[2179437]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4397, zone 1) — top io since last trip: system.slice/io.stat +103444MB, user.slice/io.stat +101071MB, user.slice/user-1000.slice/io.stat +94590MB
Oct 26 16:09:25 evo-x2 memory-emergency-guard-check[2189797]: MEMORY EMERGENCY still active (MemAvailable=0.0% below absolute floor) but action cooldown active (31s < 600s, 569s remaining; last trip zone=1) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 16:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 20.114s wall clock time, 6.2M memory peak, 1.9M read from disk, 4K written to disk.
Oct 26 16:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 707ms CPU time over 12.026s wall clock time, 34.3M memory peak, 20.5M read from disk, 1.4M written to disk.
Oct 26 16:09:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:09:51 evo-x2 gatus[2005067]: 2026/10/26 16:09:51 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 26 16:09:51 evo-x2 gatus[2005067]: 2026/10/26 16:09:51 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 26 16:09:59 evo-x2 gatus[2005067]: 2026/10/26 16:09:59 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 26 16:09:59 evo-x2 gatus[2005067]: 2026/10/26 16:09:59 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 26 16:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:09:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 207ms wall clock time, 7.7M memory peak, 1.2M read from disk, 4K written to disk.
Oct 26 16:10:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:10:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:12:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:13:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:14:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:18:41 evo-x2 memory-emergency-guard-check[2463494]: MEMORY EMERGENCY: I/O PSI some avg60=61.93% sustained (max disk busy 99.3%, MemAvailable=52.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 16:18:48 evo-x2 memory-emergency-guard-check[2463494]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4398, zone 6) — top io since last trip: system.slice/io.stat +127074MB, user.slice/io.stat +21300MB, system.slice/nix-daemon.service/io.stat +19236MB
Oct 26 16:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:18:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 426ms CPU time over 6.441s wall clock time, 12.1M memory peak, 2.9M read from disk, 7.5M written to disk.
Oct 26 16:19:12 evo-x2 memory-emergency-guard-check[2475643]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.94% sustained (max disk busy 99.2%, MemAvailable=33.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 16:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:24:19 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; MEMORY GUARD DEAD; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 3 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | memory-emergency-guard metrics are missing/stale (306s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard | A monitored service is restart-looping (llama-chat) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u llama-chat -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 16:24:31 evo-x2 memory-emergency-guard-check[2479955]: MEMORY EMERGENCY io drained (io PSI some avg60=36.76% < 40%) — churn units re-armed (re-arm #500)
Oct 26 16:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:24:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:26:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:29:02 evo-x2 memory-emergency-guard-check[2606285]: MEMORY EMERGENCY: I/O PSI some avg60=61.32% sustained (max disk busy 100.0%, MemAvailable=65.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 16:29:06 evo-x2 memory-emergency-guard-check[2606285]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4399, zone 6) — top io since last trip: system.slice/io.stat +139302MB, user.slice/io.stat +94304MB, user.slice/user-1000.slice/io.stat +88630MB
Oct 26 16:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 402ms CPU time over 3.432s wall clock time, 11.1M memory peak, 96K read from disk, 4.1M written to disk.
Oct 26 16:29:32 evo-x2 memory-emergency-guard-check[2619520]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.91% sustained (max disk busy 99.9%, MemAvailable=62.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 16:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:30:39 evo-x2 memory-emergency-guard-check[2631495]: MEMORY EMERGENCY io drained (io PSI some avg60=27.65% < 40%) — churn units re-armed (re-arm #501)
Oct 26 16:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:32:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:34:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:36:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:38:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:39:19 evo-x2 memory-emergency-guard-check[2715444]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 16:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:49:21 evo-x2 memory-emergency-guard-check[2798404]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 16:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:53:40 evo-x2 btrfs-gc-admission[2835182]: REFUSE: btrfs-compsize — memory-emergency-guard tripped 24 min ago (window 60 min).
Oct 26 16:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:55:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 16:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:00:30 evo-x2 memory-emergency-guard-check[2903242]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:05:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:05:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:06:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:10:32 evo-x2 memory-emergency-guard-check[3001272]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:14:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:15:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:16:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:18:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:20:43 evo-x2 memory-emergency-guard-check[3102005]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:24:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:30:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:30:51 evo-x2 memory-emergency-guard-check[3255591]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 103ms CPU time over 158ms wall clock time, 7.7M memory peak, 1.1M read from disk, 4K written to disk.
Oct 26 17:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:32:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:38:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 209ms wall clock time, 7.4M memory peak, 1M read from disk, 4K written to disk.
Oct 26 17:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:40:54 evo-x2 memory-emergency-guard-check[3421008]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:40:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:41:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:41:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:42:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:42:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:43:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:43:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:44:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:45:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:47:28 evo-x2 memory-emergency-guard-check[3671634]: MEMORY EMERGENCY: I/O PSI some avg60=43.19% sustained (max disk busy 100.0%, MemAvailable=29.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 17:47:33 evo-x2 memory-emergency-guard-check[3671634]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4400, zone 6) — top io since last trip: system.slice/io.stat +543494MB, user.slice/io.stat +32993MB, user.slice/user-1000.slice/io.stat +30157MB
Oct 26 17:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.174s CPU time over 5.031s wall clock time, 9M memory peak, 29.9M read from disk, 55.1M written to disk.
Oct 26 17:47:58 evo-x2 memory-emergency-guard-check[3721111]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.89% sustained (max disk busy 99.0%, MemAvailable=28.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 17:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:48:05 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (llama-chat) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u llama-chat -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 17:49:07 evo-x2 systemnix-deploy-tail[3816244]: ✗ memory-emergency-guard tripped 1× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 26 17:49:11 evo-x2 memory-emergency-guard-check[3780580]: MEMORY EMERGENCY io drained (io PSI some avg60=35.11% < 40%) — churn units re-armed (re-arm #502)
Oct 26 17:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:49:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:49:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:50:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:51:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:53:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:53:25 evo-x2 gatus[2005067]: 2026/10/26 17:53:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 17:53:25 evo-x2 gatus[2005067]: 2026/10/26 17:53:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 17:53:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:57:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:57:50 evo-x2 memory-emergency-guard-check[3965485]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 17:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 165ms CPU time over 227ms wall clock time, 7M memory peak, 2M read from disk, 4K written to disk.
Oct 26 17:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 17:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 144ms wall clock time, 8.6M memory peak, 1.7M read from disk, 4K written to disk.
Oct 26 17:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:02:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:06:22 evo-x2 memory-emergency-guard-check[33220]: MEMORY EMERGENCY: I/O PSI some avg60=45.00% sustained (max disk busy 100.0%, MemAvailable=41.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 18:08:08 evo-x2 memory-emergency-guard-check[33220]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4401, zone 6) — top io since last trip: system.slice/io.stat +154208MB, user.slice/io.stat +23680MB, user.slice/user-1000.slice/io.stat +21633MB
Oct 26 18:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 812ms CPU time over 1min 45.939s wall clock time, 9.9M memory peak, 4.7M read from disk, 26.3M written to disk.
Oct 26 18:08:08 evo-x2 memory-emergency-guard-check[67500]: MEMORY EMERGENCY still active (I/O PSI some avg60=44.53% sustained (max disk busy 100.0%, MemAvailable=31.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (106s < 600s, 494s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 18:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:09:17 evo-x2 memory-emergency-guard-check[74596]: MEMORY EMERGENCY io drained (io PSI some avg60=31.94% < 40%) — churn units re-armed (re-arm #503)
Oct 26 18:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:09:43 evo-x2 systemnix-deploy-tail[145140]: ✗ memory-emergency-guard tripped 2× in the last 60 min — episodic IO-storm window (freeze #5 class)
Oct 26 18:09:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:11:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:12:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:14:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:14:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:15:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:16:50 evo-x2 memory-emergency-guard-check[340544]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 18:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:20:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:25:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:26:51 evo-x2 memory-emergency-guard-check[719216]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 18:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:36:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:37:25 evo-x2 memory-emergency-guard-check[939358]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 18:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:39:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:45:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:47:28 evo-x2 memory-emergency-guard-check[1191297]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 18:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:47:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:51:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:57:35 evo-x2 memory-emergency-guard-check[1374140]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 18:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 18:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:00:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:03:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:04:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:06:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:07:50 evo-x2 memory-emergency-guard-check[1522024]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 19:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:08:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:08:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:09:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:10:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:10:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:11:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:14:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:14:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:15:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:15:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:16:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:17:52 evo-x2 memory-emergency-guard-check[1634342]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 19:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:20:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:21:55 evo-x2 memory-emergency-guard-check[1711600]: MEMORY EMERGENCY: I/O PSI some avg60=48.51% sustained (max disk busy 97.3%, MemAvailable=44.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 19:22:01 evo-x2 memory-emergency-guard-check[1711600]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4402, zone 6) — top io since last trip: system.slice/io.stat +429857MB, user.slice/io.stat +44011MB, user.slice/user-1000.slice/io.stat +41793MB
Oct 26 19:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 796ms CPU time over 5.572s wall clock time, 9.8M memory peak, 3.2M read from disk, 30.6M written to disk.
Oct 26 19:22:49 evo-x2 memory-emergency-guard-check[1730573]: MEMORY EMERGENCY io drained (io PSI some avg60=37.20% < 40%) — churn units re-armed (re-arm #504)
Oct 26 19:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:22:57 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket".
Oct 26 19:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:25:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:25:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:27:25 evo-x2 gatus[2005067]: 2026/10/26 19:27:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 19:27:25 evo-x2 gatus[2005067]: 2026/10/26 19:27:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 19:27:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:28:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:32:03 evo-x2 memory-emergency-guard-check[1854061]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 19:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:33:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:33:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:36:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:38:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:41:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:42:17 evo-x2 memory-emergency-guard-check[1960656]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 19:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:52:24 evo-x2 memory-emergency-guard-check[2083274]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 19:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:56:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 19:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:02:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:20:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:25:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:27:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:28:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:28:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:37:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:47:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:49:44 evo-x2 memory-emergency-guard-check[3618134]: MEMORY EMERGENCY: I/O PSI some avg60=52.73% sustained (max disk busy 99.6%, MemAvailable=44.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 20:49:48 evo-x2 memory-emergency-guard-check[3618134]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4403, zone 6) — top io since last trip: system.slice/io.stat +684458MB, user.slice/io.stat +91741MB, user.slice/user-1000.slice/io.stat +86106MB
Oct 26 20:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 3.935s wall clock time, 10.4M memory peak, 10.3M read from disk, 59.5M written to disk.
Oct 26 20:50:15 evo-x2 memory-emergency-guard-check[3642928]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.26% sustained (max disk busy 100.0%, MemAvailable=49.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 20:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:50:27 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (fastflowlm) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u fastflowlm -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 20:50:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:51:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:52:52 evo-x2 memory-emergency-guard-check[3716416]: MEMORY EMERGENCY io drained (io PSI some avg60=35.16% < 40%) — churn units re-armed (re-arm #505)
Oct 26 20:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:55:25 evo-x2 gatus[2005067]: 2026/10/26 20:55:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 20:55:25 evo-x2 gatus[2005067]: 2026/10/26 20:55:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 26 20:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 20:59:59 evo-x2 memory-emergency-guard-check[4008149]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 20:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 227ms CPU time over 319ms wall clock time, 7.4M memory peak, 1.9M read from disk, 4K written to disk.
Oct 26 21:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 298ms wall clock time, 7.6M memory peak, 3.5M read from disk, 4K written to disk.
Oct 26 21:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 248ms CPU time over 364ms wall clock time, 8.3M memory peak, 2.2M read from disk, 4K written to disk.
Oct 26 21:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:10:07 evo-x2 memory-emergency-guard-check[5614]: MEMORY EMERGENCY restore capped (3 restores today >= 3) — FastFlowLM socket stays DOWN. Manual restart once memory AND I/O pressure are healthy: systemctl start fastflowlm.socket
Oct 26 21:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:13:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 128ms CPU time over 573ms wall clock time, 9.4M memory peak, 2.2M read from disk, 4K written to disk.
Oct 26 21:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:16:46 evo-x2 memory-emergency-guard-check[195042]: MEMORY EMERGENCY: I/O PSI some avg60=43.04% sustained (max disk busy 97.5%, MemAvailable=31.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 21:17:22 evo-x2 memory-emergency-guard-check[195042]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4404, zone 6) — top io since last trip: system.slice/io.stat +105158MB, user.slice/io.stat +43927MB, user.slice/user-1000.slice/io.stat +42945MB
Oct 26 21:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 954ms CPU time over 36.678s wall clock time, 10.4M memory peak, 10.9M read from disk, 16.8M written to disk.
Oct 26 21:17:22 evo-x2 memory-emergency-guard-check[214859]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.51% sustained (max disk busy 100.0%, MemAvailable=29.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (36s < 600s, 564s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 21:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:20:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:20:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:23:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:26:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:26:56 evo-x2 memory-emergency-guard-check[746040]: MEMORY EMERGENCY: I/O PSI some avg60=45.30% sustained (max disk busy 49.1%, MemAvailable=28.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 21:26:59 evo-x2 memory-emergency-guard-check[746040]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4405, zone 6) — top io since last trip: system.slice/io.stat +70508MB, user.slice/io.stat +37135MB, user.slice/user-1000.slice/io.stat +35568MB
Oct 26 21:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 869ms CPU time over 3.529s wall clock time, 7.3M memory peak, 2.5M read from disk, 20.3M written to disk.
Oct 26 21:30:13 evo-x2 memory-emergency-guard-check[766751]: MEMORY EMERGENCY io drained (io PSI some avg60=37.83% < 40%) — churn units re-armed (re-arm #506)
Oct 26 21:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:30:13 evo-x2 memory-emergency-guard-check[887664]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.01% sustained (max disk busy 72.1%, MemAvailable=24.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (197s < 600s, 403s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 21:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:32:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:33:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:34:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:36:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:36:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:37:15 evo-x2 memory-emergency-guard-check[1235059]: MEMORY EMERGENCY: I/O PSI some avg60=87.10% sustained (max disk busy 98.7%, MemAvailable=28.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 21:37:18 evo-x2 memory-emergency-guard-check[1235059]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4406, zone 6) — top io since last trip: system.slice/io.stat +112774MB, user.slice/io.stat +34473MB, user.slice/user-1000.slice/io.stat +34408MB
Oct 26 21:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.147s CPU time over 3.313s wall clock time, 8.1M memory peak, 13.5M read from disk, 32M written to disk.
Oct 26 21:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:39:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:40:17 evo-x2 memory-emergency-guard-check[1413327]: MEMORY EMERGENCY still active (I/O PSI some avg60=93.59% sustained (max disk busy 100.0%, MemAvailable=32.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (181s < 600s, 419s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 21:40:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:40:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:41:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:41:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:44:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 207ms CPU time over 337ms wall clock time, 8.5M memory peak, 2.4M read from disk, 4K written to disk.
Oct 26 21:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 172ms CPU time over 217ms wall clock time, 9.4M memory peak, 1.6M read from disk, 4K written to disk.
Oct 26 21:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 169ms CPU time over 210ms wall clock time, 6.7M memory peak, 1.3M read from disk, 4K written to disk.
Oct 26 21:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:47:17 evo-x2 memory-emergency-guard-check[1620603]: MEMORY EMERGENCY: I/O PSI some avg60=60.04% sustained (max disk busy 84.1%, MemAvailable=23.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 21:47:28 evo-x2 memory-emergency-guard-check[1620603]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4407, zone 6) — top io since last trip: system.slice/io.stat +96012MB, user.slice/io.stat +38310MB, user.slice/user-1000.slice/io.stat +36961MB
Oct 26 21:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 669ms CPU time over 10.396s wall clock time, 19.2M memory peak, 6.5M read from disk, 53.7M written to disk.
Oct 26 21:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:50:19 evo-x2 memory-emergency-guard-check[1682930]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.32% sustained (max disk busy 51.3%, MemAvailable=39.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (182s < 600s, 418s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 21:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:50:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:51:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:52:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:52:25 evo-x2 systemd[1873]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 4 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 26 21:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:53:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:55:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:55:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:56:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:57:20 evo-x2 memory-emergency-guard-check[1832993]: MEMORY EMERGENCY: I/O PSI some avg60=62.00% sustained (max disk busy 23.7%, MemAvailable=42.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 21:57:22 evo-x2 memory-emergency-guard-check[1832993]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4408, zone 6) — top io since last trip: system.slice/io.stat +105958MB, system.slice/forgejo.service/io.stat +10207MB, user.slice/io.stat +9336MB
Oct 26 21:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 1.996s wall clock time, 11.1M memory peak, 4.5M read from disk, 33.1M written to disk.
Oct 26 21:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 21:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:00:20 evo-x2 memory-emergency-guard-check[1886806]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.85% sustained (max disk busy 81.4%, MemAvailable=41.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (180s < 600s, 420s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 143ms wall clock time, 9M memory peak, 1.1M read from disk, 4K written to disk.
Oct 26 22:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:04:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:07:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:09:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:09:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:10:51 evo-x2 memory-emergency-guard-check[2040856]: MEMORY EMERGENCY: I/O PSI some avg60=70.50% sustained (max disk busy 43.1%, MemAvailable=41.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 22:11:08 evo-x2 memory-emergency-guard-check[2040856]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4409, zone 6) — top io since last trip: system.slice/io.stat +56091MB, user.slice/io.stat +3608MB, user.slice/user-1000.slice/io.stat +3583MB
Oct 26 22:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 582ms CPU time over 16.672s wall clock time, 11.7M memory peak, 816K read from disk, 17.5M written to disk.
Oct 26 22:11:21 evo-x2 memory-emergency-guard-check[2054324]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.12% sustained (max disk busy 85.1%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:15:27 evo-x2 gatus[2005067]: 2026/10/26 22:15:27 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 26 22:15:27 evo-x2 gatus[2005067]: 2026/10/26 22:15:27 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 26 22:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:19:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:20:53 evo-x2 memory-emergency-guard-check[2176349]: MEMORY EMERGENCY: I/O PSI some avg60=69.50% sustained (max disk busy 92.7%, MemAvailable=43.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 22:21:00 evo-x2 memory-emergency-guard-check[2176349]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4410, zone 6) — top io since last trip: system.slice/io.stat +39358MB, user.slice/io.stat +3468MB, user.slice/user-1000.slice/io.stat +3437MB
Oct 26 22:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 480ms CPU time over 7.385s wall clock time, 10.9M memory peak, 432K read from disk, 3.5M written to disk.
Oct 26 22:21:23 evo-x2 memory-emergency-guard-check[2187436]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.40% sustained (max disk busy 43.2%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:22:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:23:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:25:25 evo-x2 gatus[2005067]: 2026/10/26 22:25:25 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 26 22:25:25 evo-x2 gatus[2005067]: 2026/10/26 22:25:25 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 26 22:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:30:56 evo-x2 memory-emergency-guard-check[2313312]: MEMORY EMERGENCY: I/O PSI some avg60=68.60% sustained (max disk busy 26.0%, MemAvailable=43.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 22:30:58 evo-x2 memory-emergency-guard-check[2313312]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4411, zone 6) — top io since last trip: system.slice/io.stat +46472MB, system.slice/monitor365-server.service/io.stat +35730MB, system.slice/forgejo.service/io.stat +4676MB
Oct 26 22:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 581ms CPU time over 2.334s wall clock time, 10.6M memory peak, 4M read from disk, 61.7M written to disk.
Oct 26 22:31:26 evo-x2 memory-emergency-guard-check[2324790]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.60% sustained (max disk busy 27.8%, MemAvailable=41.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:33:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 141ms CPU time over 177ms wall clock time, 8.5M memory peak, 1.4M read from disk, 4K written to disk.
Oct 26 22:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:41:02 evo-x2 memory-emergency-guard-check[2545644]: MEMORY EMERGENCY: I/O PSI some avg60=79.12% sustained (max disk busy 99.9%, MemAvailable=43.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 22:41:05 evo-x2 memory-emergency-guard-check[2545644]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4412, zone 6) — top io since last trip: system.slice/io.stat +69989MB, user.slice/io.stat +18216MB, user.slice/user-1000.slice/io.stat +18109MB
Oct 26 22:41:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:41:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 2.911s wall clock time, 9.5M memory peak, 144K read from disk, 21.2M written to disk.
Oct 26 22:41:32 evo-x2 memory-emergency-guard-check[2570245]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.68% sustained (max disk busy 99.2%, MemAvailable=44.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:45:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:50:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:51:05 evo-x2 memory-emergency-guard-check[2739744]: MEMORY EMERGENCY: I/O PSI some avg60=69.80% sustained (max disk busy 24.9%, MemAvailable=58.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 26 22:51:07 evo-x2 memory-emergency-guard-check[2739744]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4413, zone 6) — top io since last trip: system.slice/io.stat +23706MB, user.slice/io.stat +9289MB, user.slice/user-1000.slice/io.stat +8288MB
Oct 26 22:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 563ms CPU time over 2.037s wall clock time, 11.3M memory peak, 2.5M read from disk, 29.8M written to disk.
Oct 26 22:51:36 evo-x2 memory-emergency-guard-check[2752991]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.14% sustained (max disk busy 21.0%, MemAvailable=58.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 26 22:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 26 22:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 26 05:44:12 evo-x2 thermal-pstate-guard-check[14892]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 26 10:11:13 evo-x2 thermal-pstate-guard-check[2926986]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=63C(hi:95/lo:80)
Oct 26 10:16:14 evo-x2 thermal-pstate-guard-check[2979113]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 26 16:28:12 evo-x2 thermal-pstate-guard-check[2595855]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
Oct 26 17:20:45 evo-x2 thermal-pstate-guard-check[3104809]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 25 22:23:41 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/nnzaz7jdk8mvy246dd60prar42hmimjy-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 25 22:23:41 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/nnzaz7jdk8mvy246dd60prar42hmimjy-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 25 22:23:41 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 25 22:23:43 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
