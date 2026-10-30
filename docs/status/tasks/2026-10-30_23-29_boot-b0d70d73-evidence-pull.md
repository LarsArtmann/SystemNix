# Boot evidence pull: id8 b0d70d73 (full: b0d70d73d1f14ee6954915145e26e46e)

Pulled 2026-10-30 23:29 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-10-28 00:42:49 -> 2026-10-30 03:32:02 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 b0d70d73 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Oct 28 00:42:49 evo-x2 kernel: Linux version 7.2.10 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1791725270
Oct 28 00:42:49 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/vv4ckkahmq31aq7a312rx2d13r308nv1-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 28 00:42:49 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Oct 30 03:32:02 evo-x2 file-renamer[1943247]: 2026-10-30T03:32:02+01:00 INFO  watcher: request method=GET path=/healthz status=200 duration=54.888µs client_ip=127.0.0.1 request_id=6ae401a20000006fac7345c52a1425fc
Oct 30 03:32:02 evo-x2 pocket-id-start[2636562]: Oct 30 03:32:02 INF HTTP request completed app=pocket-id version=2.18.0 request_id=4106f0e5-7492-40b1-8b16-65686c257e7d status=200 method=GET path=/ query="" route="" ip=192.168.1.150 latency=78.427µs referer="" user_agent=Go-http-client/1.1 body_size=5777
Oct 30 03:32:02 evo-x2 emeet-pixyd[7849]: 2026/10/30 03:32:02 INFO http request method=GET path=/ status=0 duration=142.264µs
Oct 30 03:32:02 evo-x2 browser-history-server[1994096]: {"time":"2026-10-30T03:32:02.419712582+01:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":77317,"request_id":"01M65ACRKKTESGX1N45R008DXX"}
Oct 30 03:32:02 evo-x2 browser-history-server[1994096]: {"time":"2026-10-30T03:32:02.421677208+01:00","level":"INFO","msg":"http request","method":"GET","path":"/login","status":302,"duration":34318,"request_id":"01M65ACRKNA9BPSN9TNM008DXY"}
Oct 30 03:32:02 evo-x2 browser-history-server[1994096]: {"time":"2026-10-30T03:32:02.424110927+01:00","level":"INFO","msg":"usermgmt: oauth_login_begin","event":"oauth_login_begin","user_id":null,"provider":"pocket-id"}
Oct 30 03:32:02 evo-x2 browser-history-server[1994096]: {"time":"2026-10-30T03:32:02.424168384+01:00","level":"INFO","msg":"http request","method":"GET","path":"/auth/oauth/pocket-id/begin","status":302,"duration":97437,"request_id":"01M65ACRKR84BS6JA6J4008DXZ"}
Oct 30 03:32:02 evo-x2 indexer[2189]: INFO request method=GET path=/ status=200 duration=2.534794ms client_ip=192.168.1.150 request_id=6ae401a2000025fedeb5dc7bb1e6f451
Oct 30 03:32:02 evo-x2 nsfw-server[1823946]: 2026/10/30 03:32:02 INFO  request method=GET path=/ status=200 duration=661.376µs client_ip=192.168.1.150
Oct 30 03:32:02 evo-x2 crush-daily[2234359]: time=2026-10-30T03:32:02.451+01:00 level=INFO msg="http request" method=GET path=/ status=200 duration=2.770215ms
Oct 30 03:32:02 evo-x2 crm-server[1993915]: time=2026-10-30T03:32:02.458+01:00 level=INFO msg=request method=GET path=/ status=303 duration=33µs
Oct 30 03:32:02 evo-x2 crm-server[1993915]: time=2026-10-30T03:32:02.459+01:00 level=INFO msg=request method=GET path=/login status=200 duration=99µs
```

## Census
- oom-lines: 92
- guard-lines (memory-emergency-guard): 7289
- thermal-THROTTLE-lines: 21
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
Oct 28 10:14:01 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 10:14:05 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/run-p3639162-i3650853.scope,task=bun,pid=3639162,uid=1000
Oct 28 10:14:05 evo-x2 kernel: Out of memory: Killed process 3639162 (bun) total-vm:6460716kB, anon-rss:6340kB, file-rss:9272kB, shmem-rss:0kB, UID:1000 pgtables:304kB oom_score_adj:1000
Oct 28 10:14:05 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 10:14:05 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/run-p3403769-i3304710.scope,task=bun,pid=3403769,uid=1000
Oct 28 10:14:05 evo-x2 kernel: Out of memory: Killed process 3403769 (bun) total-vm:6460200kB, anon-rss:5204kB, file-rss:9176kB, shmem-rss:0kB, UID:1000 pgtables:284kB oom_score_adj:1000
Oct 28 10:14:05 evo-x2 kernel: tq invoked oom-killer: gfp_mask=0x140cca(GFP_HIGHUSER_MOVABLE|__GFP_COMP), order=0, oom_score_adj=0
Oct 28 10:14:05 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=1453,uid=1000
Oct 28 10:14:05 evo-x2 kernel: Out of memory: Killed process 1453 (llama-server) total-vm:41726968kB, anon-rss:2236kB, file-rss:12kB, shmem-rss:0kB, UID:1000 pgtables:68008kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-975.slice/user@975.service/app.slice/hermes-worker-cron-f59d5d8cfb7b-exec-bc914a5abdee4e77bb5b714e20c0cd2b.scope,task=chromium,pid=44547,uid=975
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 44547 (chromium) total-vm:1518608588kB, anon-rss:924kB, file-rss:12kB, shmem-rss:16kB, UID:975 pgtables:820kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 10:15:23 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/session-74.scope,task=chromium,pid=3392891,uid=1000
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 3392891 (chromium) total-vm:1518605956kB, anon-rss:496kB, file-rss:12kB, shmem-rss:4kB, UID:1000 pgtables:812kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 3595707 (chrome-headless) total-vm:1518498916kB, anon-rss:488kB, file-rss:8kB, shmem-rss:0kB, UID:1000 pgtables:552kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 3592942 (chrome-headless) total-vm:1518498916kB, anon-rss:628kB, file-rss:8kB, shmem-rss:0kB, UID:1000 pgtables:540kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 10:15:23 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-embeddings.service,task=llama-server,pid=2627055,uid=1000
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 2627055 (llama-server) total-vm:11328kB, anon-rss:60kB, file-rss:4kB, shmem-rss:0kB, UID:1000 pgtables:52kB oom_score_adj:300
Oct 28 10:15:23 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 10:15:23 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.chromium.Chromium-7854.scope,task=helium,pid=7854,uid=1000
Oct 28 10:15:23 evo-x2 kernel: Out of memory: Killed process 7854 (helium) total-vm:56008976kB, anon-rss:84620kB, file-rss:44kB, shmem-rss:104kB, UID:1000 pgtables:3272kB oom_score_adj:200
Oct 28 19:15:57 evo-x2 kernel: go invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 28 19:15:57 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3859022,uid=1000
Oct 28 19:34:18 evo-x2 kernel: whisper-cli invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 28 19:34:18 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=536157,uid=1000
Oct 28 20:43:04 evo-x2 kernel: find invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 20:43:04 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3041302,uid=1000
Oct 28 23:59:07 evo-x2 kernel: unpaper invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 28 23:59:07 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/system-paperless.slice/paperless-task-queue.service,task_memcg=/system.slice/system-paperless.slice/paperless-task-queue.service,task=[celeryd: celer,pid=2370461,uid=315
Oct 29 01:47:48 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 01:47:48 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=458749,uid=1000
Oct 29 02:57:14 evo-x2 kernel: whisper-cli invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 02:57:14 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3266185,uid=1000
Oct 29 03:38:28 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 03:38:28 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=220624,uid=1000
Oct 29 04:24:04 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 04:24:05 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1486344,uid=1000
Oct 29 04:30:20 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 04:30:20 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1594234,uid=1000
Oct 29 04:40:07 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 04:40:07 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2069953,uid=1000
Oct 29 04:40:55 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 04:40:55 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2076214,uid=1000
Oct 29 05:22:27 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 05:22:27 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2832146,uid=1000
Oct 29 05:27:22 evo-x2 kernel: whisper-cli invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 05:27:22 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2929488,uid=1000
Oct 29 05:54:48 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 05:54:48 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3520715,uid=1000
Oct 29 05:55:47 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 05:55:47 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3595070,uid=1000
Oct 29 06:42:53 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 06:42:53 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=283352,uid=1000
Oct 29 06:43:26 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 06:43:26 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=340285,uid=1000
Oct 29 06:58:22 evo-x2 kernel: tesseract invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 06:58:22 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/system-paperless.slice/paperless-task-queue.service,task_memcg=/system.slice/system-paperless.slice/paperless-task-queue.service,task=convert,pid=657072,uid=315
Oct 29 07:19:47 evo-x2 kernel: whisper-cli invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 07:19:47 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1006088,uid=1000
Oct 29 07:24:50 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 07:24:50 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1126091,uid=1000
Oct 29 08:01:58 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 08:01:58 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1958488,uid=1000
Oct 29 08:04:48 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 08:04:48 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2074157,uid=1000
Oct 29 08:46:29 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 08:46:29 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2935058,uid=1000
Oct 29 08:51:26 evo-x2 kernel: whisper-cli invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Oct 29 08:51:26 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3038571,uid=1000
Oct 29 09:06:24 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 09:06:24 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3481191,uid=1000
Oct 29 09:07:15 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 09:07:15 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3541614,uid=1000
Oct 29 22:12:17 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 22:12:17 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=2627540,uid=1000
Oct 29 22:12:17 evo-x2 kernel: Out of memory: Killed process 2627540 (llama-server) total-vm:43146668kB, anon-rss:2368kB, file-rss:2032kB, shmem-rss:0kB, UID:1000 pgtables:70764kB oom_score_adj:300
Oct 29 22:20:58 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 22:20:58 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/fastflowlm.service,task=flm-real,pid=2342482,uid=1000
Oct 29 22:20:58 evo-x2 kernel: Out of memory: Killed process 2342482 (flm-real) total-vm:25928120kB, anon-rss:130744kB, file-rss:2348kB, shmem-rss:0kB, UID:1000 pgtables:50344kB oom_score_adj:300
Oct 29 23:02:43 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 29 23:02:44 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=4161668,uid=1000
Oct 29 23:02:44 evo-x2 kernel: Out of memory: Killed process 4161668 (llama-server) total-vm:41726968kB, anon-rss:10207644kB, file-rss:1676kB, shmem-rss:0kB, UID:1000 pgtables:68012kB oom_score_adj:300
Oct 30 03:15:35 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 30 03:15:47 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-chat.service,task=llama-server,pid=731372,uid=1000
Oct 30 03:15:47 evo-x2 kernel: Out of memory: Killed process 731372 (llama-server) total-vm:44623920kB, anon-rss:11471372kB, file-rss:2688kB, shmem-rss:0kB, UID:1000 pgtables:73652kB oom_score_adj:300
Oct 30 03:18:44 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 30 03:18:45 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-embeddings.service,task=llama-server,pid=1953501,uid=1000
Oct 30 03:18:45 evo-x2 kernel: Out of memory: Killed process 1953501 (llama-server) total-vm:9595060kB, anon-rss:1335316kB, file-rss:156kB, shmem-rss:0kB, UID:1000 pgtables:3880kB oom_score_adj:300
Oct 30 03:20:18 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Oct 30 03:20:19 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/fastflowlm.service,task=flm-real,pid=3719954,uid=1000
Oct 30 03:20:19 evo-x2 kernel: Out of memory: Killed process 3719954 (flm-real) total-vm:25764276kB, anon-rss:15028kB, file-rss:740kB, shmem-rss:0kB, UID:1000 pgtables:50076kB oom_score_adj:300
```

## memory-emergency-guard lines (all)
```
Oct 28 00:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:45:24 evo-x2 memory-emergency-guard-check[30439]: MEMORY EMERGENCY: I/O PSI some avg60=45.77% sustained (max disk busy 99.0%, MemAvailable=72.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:49:22 evo-x2 memory-emergency-guard-check[30439]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4508, zone 6)
Oct 28 00:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.486s CPU time over 3min 57.999s wall clock time, 11.4M memory peak, 216.2M written to disk.
Oct 28 00:49:22 evo-x2 memory-emergency-guard-check[81779]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.15% sustained (max disk busy 100.0%, MemAvailable=57.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (238s < 600s, 362s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:51:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:52:53 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 5 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 28 00:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:55:24 evo-x2 memory-emergency-guard-check[215108]: MEMORY EMERGENCY: I/O PSI some avg60=57.13% sustained (max disk busy 100.0%, MemAvailable=50.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 00:55:36 evo-x2 memory-emergency-guard-check[215108]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4509, zone 6) — top io since last trip: system.slice/io.stat +20030MB, user.slice/io.stat +9827MB, user.slice/user-1000.slice/io.stat +9808MB
Oct 28 00:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 597ms CPU time over 11.785s wall clock time, 9.7M memory peak, 2.3M read from disk, 22.2M written to disk.
Oct 28 00:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:59:26 evo-x2 memory-emergency-guard-check[329739]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.93% sustained (max disk busy 98.3%, MemAvailable=48.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (242s < 600s, 358s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 00:59:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 00:59:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:00:19 evo-x2 gatus[29181]: 2026/10/28 01:00:19 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 01:00:19 evo-x2 gatus[29181]: 2026/10/28 01:00:19 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 01:00:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:04:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:05:27 evo-x2 memory-emergency-guard-check[597965]: MEMORY EMERGENCY: I/O PSI some avg60=67.00% sustained (max disk busy 100.0%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 01:05:29 evo-x2 memory-emergency-guard-check[597965]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4510, zone 6) — top io since last trip: system.slice/io.stat +19303MB, user.slice/io.stat +10387MB, user.slice/user-1000.slice/io.stat +9947MB
Oct 28 01:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 1.961s wall clock time, 8.8M memory peak, 6.8M read from disk, 51.3M written to disk.
Oct 28 01:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:07:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:09:28 evo-x2 memory-emergency-guard-check[765438]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.19% sustained (max disk busy 100.0%, MemAvailable=42.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 01:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:10:18 evo-x2 gatus[29181]: 2026/10/28 01:10:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 01:10:18 evo-x2 gatus[29181]: 2026/10/28 01:10:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 01:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:11:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:12:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:15:29 evo-x2 memory-emergency-guard-check[947157]: MEMORY EMERGENCY: I/O PSI some avg60=63.37% sustained (max disk busy 99.5%, MemAvailable=38.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 01:15:35 evo-x2 memory-emergency-guard-check[947157]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4511, zone 6) — top io since last trip: system.slice/io.stat +27502MB, user.slice/io.stat +14987MB, user.slice/user-1000.slice/io.stat +14499MB
Oct 28 01:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.276s CPU time over 6.389s wall clock time, 6.4M memory peak, 11.3M read from disk, 11.6M written to disk.
Oct 28 01:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:19:29 evo-x2 memory-emergency-guard-check[1095014]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.56% sustained (max disk busy 100.0%, MemAvailable=38.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 01:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:25:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:25:30 evo-x2 memory-emergency-guard-check[1343894]: MEMORY EMERGENCY: I/O PSI some avg60=48.90% sustained (max disk busy 97.9%, MemAvailable=37.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 01:25:33 evo-x2 memory-emergency-guard-check[1343894]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4512, zone 6) — top io since last trip: system.slice/io.stat +28738MB, user.slice/io.stat +26404MB, user.slice/user-1000.slice/io.stat +25930MB
Oct 28 01:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 999ms CPU time over 3.986s wall clock time, 6M memory peak, 2.4M read from disk, 32.2M written to disk.
Oct 28 01:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:29:30 evo-x2 memory-emergency-guard-check[1642593]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.86% sustained (max disk busy 99.9%, MemAvailable=34.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (240s < 600s, 360s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 01:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:33:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:34:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:35:31 evo-x2 memory-emergency-guard-check[2021202]: MEMORY EMERGENCY: I/O PSI some avg60=65.53% sustained (max disk busy 100.0%, MemAvailable=27.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 01:35:55 evo-x2 memory-emergency-guard-check[2021202]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4513, zone 6) — top io since last trip: system.slice/io.stat +41043MB, user.slice/io.stat +23817MB, user.slice/user-1000.slice/io.stat +23428MB
Oct 28 01:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.042s CPU time over 23.652s wall clock time, 9.4M memory peak, 7.6M read from disk, 41.3M written to disk.
Oct 28 01:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:39:32 evo-x2 memory-emergency-guard-check[2244139]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.71% sustained (max disk busy 99.8%, MemAvailable=38.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 01:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 205ms CPU time over 398ms wall clock time, 10.4M memory peak, 4.8M read from disk, 4K written to disk.
Oct 28 01:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:45:32 evo-x2 memory-emergency-guard-check[2528296]: MEMORY EMERGENCY: I/O PSI some avg60=51.71% sustained (max disk busy 100.0%, MemAvailable=38.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 01:45:35 evo-x2 memory-emergency-guard-check[2528296]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4514, zone 6) — top io since last trip: system.slice/io.stat +52465MB, user.slice/io.stat +18344MB, user.slice/user-1000.slice/io.stat +18200MB
Oct 28 01:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 739ms CPU time over 2.389s wall clock time, 9.5M memory peak, 7.5M read from disk, 47.7M written to disk.
Oct 28 01:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:49:33 evo-x2 memory-emergency-guard-check[2651065]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.56% sustained (max disk busy 99.9%, MemAvailable=36.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (241s < 600s, 359s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 01:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:50:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:50:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:56:00 evo-x2 memory-emergency-guard-check[2917183]: MEMORY EMERGENCY io drained (io PSI some avg60=38.00% < 40%) — churn units re-armed (re-arm #531)
Oct 28 01:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:58:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:59:00 evo-x2 tq[3558]: 2026/10/28 01:59:00 WARN preflight refused; requeued without attempt burn task=000001a180047c159cd6129d107800000000 "retry after"=2m12.668883249s consecutive=1 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M  docs/planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md\n M modules/nixos/services/_forgejo-scripts.nix\n M modules/nixos/services/forgejo.nix\nM  modules/nixos/services/memory-emergency-guard.nix\n M platforms/nixos/system/configuration.nixdirty tree"
Oct 28 01:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 01:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:00:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:00:34 evo-x2 memory-emergency-guard-check[3067088]: MEMORY EMERGENCY: I/O PSI some avg60=40.53% sustained (max disk busy 99.9%, MemAvailable=33.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:00:35 evo-x2 memory-emergency-guard-check[3067088]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4515, zone 6) — top io since last trip: system.slice/io.stat +194254MB, system.slice/tq-agent-pool.service/io.stat +162365MB, user.slice/io.stat +20059MB
Oct 28 02:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 775ms CPU time over 1.574s wall clock time, 8.7M memory peak, 11.1M read from disk, 25.1M written to disk.
Oct 28 02:01:04 evo-x2 memory-emergency-guard-check[3093006]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.28% sustained (max disk busy 100.0%, MemAvailable=30.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:01:13 evo-x2 tq[3558]: 2026/10/28 02:01:13 WARN preflight refused; requeued without attempt burn task=000001a180047c159cd6129d107800000000 "retry after"=3m17.243716727s consecutive=2 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M  docs/planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md\n M modules/nixos/services/_forgejo-scripts.nix\n M modules/nixos/services/forgejo.nix\nM  modules/nixos/services/memory-emergency-guard.nix\n M platforms/nixos/system/configuration.nixdirty tree"
Oct 28 02:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:03:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:04:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:04:30 evo-x2 tq[3558]: 2026/10/28 02:04:30 WARN preflight refused; requeued without attempt burn task=000001a180047c159cd6129d107800000000 "retry after"=7m14.828828983s consecutive=3 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M  docs/planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md\n M flake/parts/checks/fixtures-forgejo.nix\n M modules/nixos/services/_forgejo-scripts.nix\n M modules/nixos/services/forgejo.nix\nM  modules/nixos/services/memory-emergency-guard.nix\n M platforms/nixos/system/configuration.nixdirty tree"
Oct 28 02:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:06:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:07:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:07:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:08:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:09:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:09:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:10:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:10:37 evo-x2 memory-emergency-guard-check[3505687]: MEMORY EMERGENCY: I/O PSI some avg60=62.07% sustained (max disk busy 100.0%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:10:44 evo-x2 memory-emergency-guard-check[3505687]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4516, zone 6) — top io since last trip: system.slice/io.stat +24136MB, user.slice/io.stat +16166MB, user.slice/user-1000.slice/io.stat +16055MB
Oct 28 02:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.180s CPU time over 7.756s wall clock time, 7.4M memory peak, 32.3M read from disk, 7.8M written to disk.
Oct 28 02:11:07 evo-x2 memory-emergency-guard-check[3531914]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.26% sustained (max disk busy 98.1%, MemAvailable=41.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:14:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:19:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:20:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:20:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 127ms CPU time over 163ms wall clock time, 8.1M memory peak, 1.1M read from disk, 4K written to disk.
Oct 28 02:20:41 evo-x2 memory-emergency-guard-check[3813523]: MEMORY EMERGENCY: I/O PSI some avg60=63.31% sustained (max disk busy 100.0%, MemAvailable=40.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:20:43 evo-x2 memory-emergency-guard-check[3813523]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4517, zone 6) — top io since last trip: system.slice/io.stat +29576MB, user.slice/io.stat +15179MB, user.slice/user-1000.slice/io.stat +14790MB
Oct 28 02:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 2.674s wall clock time, 9.5M memory peak, 12.4M read from disk, 36.1M written to disk.
Oct 28 02:21:11 evo-x2 memory-emergency-guard-check[3827811]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.68% sustained (max disk busy 100.0%, MemAvailable=41.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:21:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:24:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:25:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:30:44 evo-x2 memory-emergency-guard-check[4127201]: MEMORY EMERGENCY: I/O PSI some avg60=88.59% sustained (max disk busy 100.0%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:30:45 evo-x2 memory-emergency-guard-check[4127201]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4518, zone 6) — top io since last trip: system.slice/io.stat +20480MB, user.slice/io.stat +11122MB, user.slice/user-1000.slice/io.stat +10452MB
Oct 28 02:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 755ms CPU time over 1.057s wall clock time, 9.3M memory peak, 12.4M read from disk, 54.1M written to disk.
Oct 28 02:31:15 evo-x2 memory-emergency-guard-check[4153763]: MEMORY EMERGENCY still active (I/O PSI some avg60=88.41% sustained (max disk busy 100.0%, MemAvailable=37.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:33:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:34:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:40:50 evo-x2 memory-emergency-guard-check[233745]: MEMORY EMERGENCY: I/O PSI some avg60=50.63% sustained (max disk busy 98.5%, MemAvailable=37.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:40:51 evo-x2 memory-emergency-guard-check[233745]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4519, zone 6) — top io since last trip: system.slice/io.stat +15493MB, user.slice/io.stat +8826MB, user.slice/user-1000.slice/io.stat +8807MB
Oct 28 02:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 984ms wall clock time, 10.3M memory peak, 12.3M read from disk, 58.3M written to disk.
Oct 28 02:41:20 evo-x2 memory-emergency-guard-check[247957]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.98% sustained (max disk busy 95.2%, MemAvailable=37.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 132ms CPU time over 170ms wall clock time, 7.9M memory peak, 3.2M read from disk, 4K written to disk.
Oct 28 02:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:50:51 evo-x2 memory-emergency-guard-check[643258]: MEMORY EMERGENCY: I/O PSI some avg60=49.56% sustained (max disk busy 99.8%, MemAvailable=36.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 02:50:53 evo-x2 memory-emergency-guard-check[643258]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4520, zone 6) — top io since last trip: system.slice/io.stat +60432MB, user.slice/io.stat +30425MB, user.slice/user-1000.slice/io.stat +29858MB
Oct 28 02:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 690ms CPU time over 2.290s wall clock time, 10.1M memory peak, 5.5M read from disk, 34.3M written to disk.
Oct 28 02:51:21 evo-x2 memory-emergency-guard-check[659431]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.17% sustained (max disk busy 100.0%, MemAvailable=29.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 02:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 178ms CPU time over 228ms wall clock time, 11.3M memory peak, 3.7M read from disk, 4K written to disk.
Oct 28 02:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:56:18 evo-x2 gatus[29181]: 2026/10/28 02:56:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 02:56:18 evo-x2 gatus[29181]: 2026/10/28 02:56:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 02:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 02:59:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:00:53 evo-x2 memory-emergency-guard-check[1031547]: MEMORY EMERGENCY: I/O PSI some avg60=52.79% sustained (max disk busy 100.0%, MemAvailable=38.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:00:55 evo-x2 memory-emergency-guard-check[1031547]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4521, zone 6) — top io since last trip: system.slice/io.stat +46252MB, user.slice/io.stat +12389MB, user.slice/user-1000.slice/io.stat +12020MB
Oct 28 03:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:00:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.021s CPU time over 1.593s wall clock time, 7.7M memory peak, 3.5M read from disk, 39.5M written to disk.
Oct 28 03:01:23 evo-x2 memory-emergency-guard-check[1069360]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.14% sustained (max disk busy 99.9%, MemAvailable=42.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:03:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:04:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 254ms CPU time over 379ms wall clock time, 6.4M memory peak, 1.1M read from disk, 4K written to disk.
Oct 28 03:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:10:55 evo-x2 memory-emergency-guard-check[1528821]: MEMORY EMERGENCY: I/O PSI some avg60=82.66% sustained (max disk busy 97.7%, MemAvailable=36.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:10:57 evo-x2 memory-emergency-guard-check[1528821]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4522, zone 6) — top io since last trip: system.slice/io.stat +50995MB, system.slice/clickhouse.service/io.stat +11706MB, user.slice/io.stat +8846MB
Oct 28 03:10:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:10:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 831ms CPU time over 1.961s wall clock time, 10M memory peak, 9M read from disk, 68.3M written to disk.
Oct 28 03:11:25 evo-x2 memory-emergency-guard-check[1543337]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.76% sustained (max disk busy 100.0%, MemAvailable=28.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:14:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:15:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:20:58 evo-x2 memory-emergency-guard-check[1889258]: MEMORY EMERGENCY: I/O PSI some avg60=68.47% sustained (max disk busy 100.0%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:20:59 evo-x2 memory-emergency-guard-check[1889258]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4523, zone 6) — top io since last trip: system.slice/io.stat +30179MB, system.slice/nix-daemon.service/io.stat +12154MB, user.slice/io.stat +7859MB
Oct 28 03:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 797ms wall clock time, 10M memory peak, 4.7M read from disk, 33.7M written to disk.
Oct 28 03:21:28 evo-x2 memory-emergency-guard-check[1900925]: MEMORY EMERGENCY still active (I/O PSI some avg60=67.70% sustained (max disk busy 99.8%, MemAvailable=44.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:22:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:22:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:25:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:26:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:27:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:30:59 evo-x2 memory-emergency-guard-check[2115105]: MEMORY EMERGENCY: I/O PSI some avg60=79.58% sustained (max disk busy 99.8%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:31:01 evo-x2 memory-emergency-guard-check[2115105]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4524, zone 6) — top io since last trip: system.slice/io.stat +19238MB, user.slice/io.stat +5267MB, user.slice/user-1000.slice/io.stat +5227MB
Oct 28 03:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 1.368s wall clock time, 11M memory peak, 528K read from disk, 20.1M written to disk.
Oct 28 03:31:29 evo-x2 memory-emergency-guard-check[2126303]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.63% sustained (max disk busy 100.0%, MemAvailable=40.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:31:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:33:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:38:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:40:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:41:01 evo-x2 memory-emergency-guard-check[2413720]: MEMORY EMERGENCY: I/O PSI some avg60=72.43% sustained (max disk busy 100.0%, MemAvailable=45.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:41:03 evo-x2 memory-emergency-guard-check[2413720]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4525, zone 6) — top io since last trip: system.slice/io.stat +24248MB, user.slice/io.stat +5538MB, user.slice/user-1000.slice/io.stat +5299MB
Oct 28 03:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 760ms CPU time over 1.867s wall clock time, 11M memory peak, 31.1M read from disk, 73.7M written to disk.
Oct 28 03:41:31 evo-x2 memory-emergency-guard-check[2426384]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.34% sustained (max disk busy 100.0%, MemAvailable=45.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:50:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:51:02 evo-x2 memory-emergency-guard-check[2883257]: MEMORY EMERGENCY: I/O PSI some avg60=70.86% sustained (max disk busy 97.9%, MemAvailable=44.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 03:51:03 evo-x2 memory-emergency-guard-check[2883257]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4526, zone 6) — top io since last trip: system.slice/io.stat +94877MB, system.slice/forgejo.service/io.stat +16988MB, system.slice/nix-daemon.service/io.stat +7567MB
Oct 28 03:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 943ms CPU time over 1.558s wall clock time, 8.6M memory peak, 13M read from disk, 59.4M written to disk.
Oct 28 03:51:32 evo-x2 memory-emergency-guard-check[2923000]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.51% sustained (max disk busy 34.3%, MemAvailable=44.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 03:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:56:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:59:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 03:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:01:03 evo-x2 memory-emergency-guard-check[3273742]: MEMORY EMERGENCY: I/O PSI some avg60=54.66% sustained (max disk busy 87.5%, MemAvailable=40.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:01:05 evo-x2 memory-emergency-guard-check[3273742]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4527, zone 6) — top io since last trip: system.slice/io.stat +14014MB, user.slice/io.stat +12845MB, user.slice/user-1000.slice/io.stat +12837MB
Oct 28 04:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 718ms CPU time over 1.319s wall clock time, 10.1M memory peak, 10.7M read from disk, 46.7M written to disk.
Oct 28 04:01:33 evo-x2 memory-emergency-guard-check[3296983]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.02% sustained (max disk busy 99.9%, MemAvailable=45.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:02:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:02:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:05:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:06:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:11:04 evo-x2 memory-emergency-guard-check[3566947]: MEMORY EMERGENCY: I/O PSI some avg60=62.70% sustained (max disk busy 88.9%, MemAvailable=44.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:11:05 evo-x2 memory-emergency-guard-check[3566947]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4528, zone 6) — top io since last trip: system.slice/io.stat +144310MB, system.slice/tq-agent-pool.service/io.stat +103617MB, system.slice/monitor365-server.service/io.stat +12778MB
Oct 28 04:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 569ms CPU time over 1.187s wall clock time, 9.3M memory peak, 8.4M read from disk, 27.5M written to disk.
Oct 28 04:11:34 evo-x2 memory-emergency-guard-check[3598998]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.05% sustained (max disk busy 97.1%, MemAvailable=40.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 169ms wall clock time, 9.3M memory peak, 1.6M read from disk, 4K written to disk.
Oct 28 04:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:18:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:21:06 evo-x2 memory-emergency-guard-check[3938504]: MEMORY EMERGENCY: I/O PSI some avg60=56.47% sustained (max disk busy 60.2%, MemAvailable=47.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:21:06 evo-x2 memory-emergency-guard-check[3938504]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4529, zone 6) — top io since last trip: system.slice/io.stat +185620MB, system.slice/tq-agent-pool.service/io.stat +95205MB, system.slice/nix-optimise.service/io.stat +34859MB
Oct 28 04:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 627ms CPU time over 890ms wall clock time, 10.6M memory peak, 15.7M read from disk, 42.7M written to disk.
Oct 28 04:21:36 evo-x2 memory-emergency-guard-check[3970929]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.85% sustained (max disk busy 51.0%, MemAvailable=46.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:23:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:24:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 152ms CPU time over 217ms wall clock time, 8.9M memory peak, 2.5M read from disk, 4K written to disk.
Oct 28 04:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:28:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:31:07 evo-x2 memory-emergency-guard-check[160808]: MEMORY EMERGENCY: I/O PSI some avg60=80.21% sustained (max disk busy 100.0%, MemAvailable=45.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:31:10 evo-x2 memory-emergency-guard-check[160808]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4530, zone 6) — top io since last trip: system.slice/io.stat +91453MB, system.slice/nix-optimise.service/io.stat +37509MB, system.slice/monitor365-server.service/io.stat +13241MB
Oct 28 04:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 777ms CPU time over 3.171s wall clock time, 7.7M memory peak, 624K read from disk, 14.8M written to disk.
Oct 28 04:31:37 evo-x2 memory-emergency-guard-check[177807]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.82% sustained (max disk busy 99.9%, MemAvailable=45.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:35:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:35:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:36:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:36:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:37:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:37:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:38:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:38:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:39:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:39:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:40:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:41:08 evo-x2 memory-emergency-guard-check[402974]: MEMORY EMERGENCY: I/O PSI some avg60=52.44% sustained (max disk busy 61.7%, MemAvailable=39.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:41:09 evo-x2 memory-emergency-guard-check[402974]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4531, zone 6) — top io since last trip: system.slice/io.stat +46467MB, system.slice/tq-agent-pool.service/io.stat +16474MB, user.slice/io.stat +6552MB
Oct 28 04:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 715ms CPU time over 1.156s wall clock time, 9.2M memory peak, 18M read from disk, 66M written to disk.
Oct 28 04:41:39 evo-x2 memory-emergency-guard-check[428190]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.61% sustained (max disk busy 63.9%, MemAvailable=40.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:42:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:42:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:43:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:47:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:52:09 evo-x2 memory-emergency-guard-check[607242]: MEMORY EMERGENCY: I/O PSI some avg60=52.42% sustained (max disk busy 21.7%, MemAvailable=40.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 04:52:10 evo-x2 memory-emergency-guard-check[607242]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4532, zone 6) — top io since last trip: system.slice/io.stat +177039MB, system.slice/tq-agent-pool.service/io.stat +152100MB, system.slice/forgejo.service/io.stat +6891MB
Oct 28 04:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 493ms CPU time over 916ms wall clock time, 10.2M memory peak, 208K read from disk, 11.5M written to disk.
Oct 28 04:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:53:39 evo-x2 memory-emergency-guard-check[632783]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.12% sustained (max disk busy 20.1%, MemAvailable=39.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 600s, 510s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 04:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:55:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:56:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:57:40 evo-x2 memory-emergency-guard-check[702794]: MEMORY EMERGENCY io drained (io PSI some avg60=38.84% < 40%) — churn units re-armed (re-arm #532)
Oct 28 04:57:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 04:59:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:04:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:17:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:22:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:38:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:38:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:43:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:44:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:45:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:46:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:46:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:50:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:51:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:52:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:53:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 05:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:05:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:05:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:06:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:06:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:07:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:08:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:08:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:09:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:10:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:10:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:11:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:12:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:12:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:14:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:14:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:15:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:15:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:16:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:17:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:17:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:19:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:20:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:26:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:28:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:29:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:33:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:35:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:37:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:37:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:38:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:38:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:39:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:40:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:41:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:41:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:42:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:42:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:43:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:44:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:44:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:45:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:46:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:46:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:47:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:51:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:52:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:52:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:53:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:53:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:54:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:54:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:55:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:56:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 06:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:01:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:02:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:04:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:04:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:05:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:05:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:07:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:08:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:08:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:09:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:10:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:10:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:11:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:12:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:14:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:14:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:15:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:15:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:16:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:16:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:17:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:18:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:18:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:19:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:20:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:22:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:22:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:23:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:24:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:27:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:27:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:28:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:28:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:29:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:30:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:32:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:32:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:33:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:33:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:34:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:34:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:36:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:36:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:37:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:38:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:39:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:39:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:40:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:42:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:42:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:43:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:44:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:50:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:51:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:52:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:53:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:56:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:57:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 07:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:03:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:03:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:04:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:04:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:07:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:08:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:08:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:09:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:10:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:11:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:11:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:12:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:12:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:13:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:13:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:14:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:15:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:17:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:18:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:19:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:20:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:27:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:28:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:29:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:33:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:34:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:37:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:38:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:39:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:40:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:47:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:47:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:48:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:50:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:51:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:56:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:56:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:57:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:58:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:58:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:59:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 08:59:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:00:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:01:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:04:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:08:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:19:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:20:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:20:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:21:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:22:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:22:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:23:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:23:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:25:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:26:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:27:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:27:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:28:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:28:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:33:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:33:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:34:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:37:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:38:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:38:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:39:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:39:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:40:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:41:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:42:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:44:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:45:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:45:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:46:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:47:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:47:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:48:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:50:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:50:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:51:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:51:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:52:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:55:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:56:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:56:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 101ms CPU time over 148ms wall clock time, 11.9M memory peak, 2.3M read from disk, 4K written to disk.
Oct 28 09:57:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:57:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 213ms wall clock time, 12.3M memory peak, 3.4M read from disk, 4K written to disk.
Oct 28 09:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 09:59:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:00:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:00:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:01:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:01:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:07:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:07:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:08:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:11:09 evo-x2 memory-emergency-guard-check[2473298]: MEMORY EMERGENCY: I/O PSI some avg60=41.85% sustained (max disk busy 98.6%, MemAvailable=38.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 10:11:10 evo-x2 memory-emergency-guard-check[2473298]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4533, zone 6) — top io since last trip: system.slice/io.stat +1310350MB, system.slice/tq-agent-pool.service/io.stat +1105664MB, system.slice/forgejo.service/io.stat +52962MB
Oct 28 10:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:11:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.191s CPU time over 1.937s wall clock time, 7.5M memory peak, 6.7M read from disk, 40.7M written to disk.
Oct 28 10:11:39 evo-x2 memory-emergency-guard-check[2499618]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.66% sustained (max disk busy 85.7%, MemAvailable=28.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 10:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:11:42 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30".
Oct 28 10:12:11 evo-x2 memory-emergency-guard-check[2534938]: MEMORY EMERGENCY io drained (io PSI some avg60=39.64% < 40%) — churn units re-armed (re-arm #533)
Oct 28 10:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 411ms CPU time over 858ms wall clock time, 5.4M memory peak, 1.3M read from disk, 4K written to disk.
Oct 28 10:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 2.366s wall clock time, 10.9M memory peak, 3.3M read from disk, 4K written to disk.
Oct 28 10:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 1.843s wall clock time, 8.1M memory peak, 2.6M read from disk, 4K written to disk.
Oct 28 10:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:16:18 evo-x2 gatus[29181]: 2026/10/28 10:16:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 10:16:18 evo-x2 gatus[29181]: 2026/10/28 10:16:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 10:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 306ms CPU time over 734ms wall clock time, 7.4M memory peak, 2.4M read from disk, 4K written to disk.
Oct 28 10:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:19:32 evo-x2 tq[3558]: 2026/10/28 10:19:32 WARN preflight refused; requeued without attempt burn task=000001a181b7a97aeb4cb13fda9400000000 "retry after"=1m45.074811653s consecutive=1 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M CHANGELOG.md\n M TODO_LIST.md\n M docs/agents/stability.md\n M docs/todo/stability.md\n M flake/parts/checks/selftests.nix\n M modules/nixos/services/memory-emergency-guard.nixdirty tree"
Oct 28 10:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:21:10 evo-x2 memory-emergency-guard-check[2911161]: MEMORY EMERGENCY: I/O PSI some avg60=48.25% sustained (max disk busy 98.1%, MemAvailable=41.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 10:21:21 evo-x2 memory-emergency-guard-check[2911161]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4534, zone 6) — top io since last trip: system.slice/io.stat +148961MB, user.slice/io.stat +52875MB, user.slice/user-1000.slice/io.stat +50326MB
Oct 28 10:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 841ms CPU time over 10.980s wall clock time, 9.1M memory peak, 9.9M read from disk, 9.6M written to disk.
Oct 28 10:21:26 evo-x2 tq[3558]: 2026/10/28 10:21:26 WARN preflight refused; requeued without attempt burn task=000001a181b7a97aeb4cb13fda9400000000 "retry after"=3m24.94548078s consecutive=2 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M CHANGELOG.md\n M TODO_LIST.md\n M docs/agents/stability.md\n M docs/services/dnsblockd.md\n M docs/todo/stability.md\n M flake/parts/checks/selftests.nix\n M modules/nixos/services/memory-emergency-guard.nix\n?? docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.htmldirty tree"
Oct 28 10:21:41 evo-x2 memory-emergency-guard-check[2927757]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.80% sustained (max disk busy 100.0%, MemAvailable=42.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 10:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:22:41 evo-x2 memory-emergency-guard-check[2956854]: MEMORY EMERGENCY io drained (io PSI some avg60=37.35% < 40%) — churn units re-armed (re-arm #534)
Oct 28 10:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:24:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:24:54 evo-x2 tq[3558]: 2026/10/28 10:24:54 WARN preflight refused; requeued without attempt burn task=000001a181b7a97aeb4cb13fda9400000000 "retry after"=8m26.856007457s consecutive=3 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M CHANGELOG.md\n M TODO_LIST.md\n M docs/agents/stability.md\n M docs/services/dnsblockd.md\n M docs/todo/services.md\n M docs/todo/stability.md\n M flake/parts/checks/selftests.nix\n M modules/nixos/services/memory-emergency-guard.nix\n M platforms/nixos/system/configuration.nix\n?? docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.htmldirty tree"
Oct 28 10:25:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:27:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:27:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:28:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:28:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:29:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:30:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:30:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:31:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:31:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:33:26 evo-x2 tq[3558]: 2026/10/28 10:33:26 WARN preflight refused; requeued without attempt burn task=000001a181b7a97aeb4cb13fda9400000000 "retry after"=15m44.888188058s consecutive=4 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M modules/nixos/services/memory-emergency-guard.nixdirty tree"
Oct 28 10:33:44 evo-x2 memory-emergency-guard-check[3286682]: MEMORY EMERGENCY: I/O PSI some avg60=48.60% sustained (max disk busy 92.7%, MemAvailable=41.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 10:33:47 evo-x2 memory-emergency-guard-check[3286682]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4535, zone 6) — top io since last trip: system.slice/io.stat +52474MB, system.slice/nix-daemon.service/io.stat +12555MB, user.slice/io.stat +11830MB
Oct 28 10:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 968ms CPU time over 3.236s wall clock time, 8.1M memory peak, 8.5M read from disk, 39.1M written to disk.
Oct 28 10:34:14 evo-x2 memory-emergency-guard-check[3317817]: MEMORY EMERGENCY still active (I/O PSI some avg60=51.15% sustained (max disk busy 100.0%, MemAvailable=39.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 10:34:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:34:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:35:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:35:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:36:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:36:45 evo-x2 memory-emergency-guard-check[3459432]: MEMORY EMERGENCY io drained (io PSI some avg60=39.00% < 40%) — churn units re-armed (re-arm #535)
Oct 28 10:36:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:37:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:37:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:38:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:38:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:39:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:40:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:41:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:42:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:43:48 evo-x2 memory-emergency-guard-check[3790023]: MEMORY EMERGENCY: I/O PSI some avg60=42.80% sustained (max disk busy 67.0%, MemAvailable=33.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 10:43:53 evo-x2 memory-emergency-guard-check[3790023]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4536, zone 6) — top io since last trip: system.slice/io.stat +26550MB, user.slice/io.stat +21051MB, user.slice/user-1000.slice/io.stat +20245MB
Oct 28 10:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.142s CPU time over 5.350s wall clock time, 7.6M memory peak, 11.3M read from disk, 17.6M written to disk.
Oct 28 10:44:19 evo-x2 memory-emergency-guard-check[3814307]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.87% sustained (max disk busy 62.6%, MemAvailable=33.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 10:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:45:19 evo-x2 memory-emergency-guard-check[3848670]: MEMORY EMERGENCY io drained (io PSI some avg60=38.01% < 40%) — churn units re-armed (re-arm #536)
Oct 28 10:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 191ms CPU time over 343ms wall clock time, 6.3M memory peak, 1.6M read from disk, 4K written to disk.
Oct 28 10:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:49:14 evo-x2 tq[3558]: 2026/10/28 10:49:14 WARN preflight refused; requeued without attempt burn task=000001a181b7a97aeb4cb13fda9400000000 "retry after"=12m52.962350245s consecutive=5 reason="agent: repo /home/lars/projects/SystemNix has uncommitted changes; refusing to run agent (commit/stash first, or set require_clean=false): M TODO_LIST.md\nA  docs/planning/2026-10-28_10-40_SUPERB-dnsblockd-integration-plan.md\nA  docs/planning/2026-10-28_10-45_role-split-decision-brief.md\n M docs/services/memory-emergency-guard.md\n M docs/status/2026-10-28_10-32_dnsblockd-integration-review-status-and-self-review.md\n M docs/todo/services.md\nM  flake/parts/checks/selftests.nix\nM  modules/nixos/services/memory-emergency-guard.nix\nM  modules/nixos/services/mr-sync.nix\nM  modules/nixos/services/system-health.nixdirty tree"
Oct 28 10:49:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 10:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:00:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:01:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:01:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:02:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 167ms CPU time over 256ms wall clock time, 10.1M memory peak, 4.2M read from disk, 4K written to disk.
Oct 28 11:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:21:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:22:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:24:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:24:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:25:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:26:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:26:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:27:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:27:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:28:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:29:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:29:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:30:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:33:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:33:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:34:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:35:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:36:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:39:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:41:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:42:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:43:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:43:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:44:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:44:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:45:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:45:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:46:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:46:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:51:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:52:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:54:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:54:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:55:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:55:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:56:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 11:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:05:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:06:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:18:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:19:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:20:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:21:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:22:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:23:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:23:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:31:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:32:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:47:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:47:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:49:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:50:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:51:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:52:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:53:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:56:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:58:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:59:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 12:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:00:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:01:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:02:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:05:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:06:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:06:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:07:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:09:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:09:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:10:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:10:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:11:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:15:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:18:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:26:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:28:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:32:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:33:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:34:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:34:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:35:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:35:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:36:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:37:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:37:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:38:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:45:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:45:53 evo-x2 memory-emergency-guard-check[3702453]: MEMORY EMERGENCY: I/O PSI some avg60=55.89% sustained (max disk busy 95.7%, MemAvailable=37.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 13:45:54 evo-x2 memory-emergency-guard-check[3702453]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4537, zone 6) — top io since last trip: system.slice/io.stat +304819MB, user.slice/io.stat +98807MB, user.slice/user-1000.slice/io.stat +94982MB
Oct 28 13:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:45:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 664ms CPU time over 1.182s wall clock time, 10.8M memory peak, 2.3M read from disk, 40.9M written to disk.
Oct 28 13:46:23 evo-x2 memory-emergency-guard-check[3733586]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.53% sustained (max disk busy 42.7%, MemAvailable=38.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 13:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:46:32 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30".
Oct 28 13:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:47:24 evo-x2 memory-emergency-guard-check[3800859]: MEMORY EMERGENCY io drained (io PSI some avg60=36.82% < 40%) — churn units re-armed (re-arm #537)
Oct 28 13:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:52:18 evo-x2 gatus[29181]: 2026/10/28 13:52:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 13:52:18 evo-x2 gatus[29181]: 2026/10/28 13:52:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 13:52:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:53:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:54:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:54:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 13:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:02:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:04:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:18:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:21:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:23:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:24:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:26:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:27:12 evo-x2 memory-emergency-guard-check[648640]: MEMORY EMERGENCY: I/O PSI some avg60=44.20% sustained (max disk busy 97.5%, MemAvailable=39.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 14:27:12 evo-x2 memory-emergency-guard-check[648640]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4538, zone 6) — top io since last trip: system.slice/io.stat +14192MB, system.slice/forgejo.service/io.stat +7526MB, user.slice/io.stat +4616MB
Oct 28 14:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 556ms CPU time over 818ms wall clock time, 10.7M memory peak, 2.2M read from disk, 29.8M written to disk.
Oct 28 14:27:42 evo-x2 memory-emergency-guard-check[664870]: MEMORY EMERGENCY io drained (io PSI some avg60=37.96% < 40%) — churn units re-armed (re-arm #538)
Oct 28 14:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:27:52 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 2 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 28 14:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:28:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:29:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:30:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:30:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:31:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:31:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:32:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:32:18 evo-x2 gatus[29181]: 2026/10/28 14:32:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 14:32:18 evo-x2 gatus[29181]: 2026/10/28 14:32:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 14:32:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:33:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:33:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:34:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:36:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:37:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:37:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:38:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:38:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:39:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:39:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:40:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:40:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:47:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:47:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:48:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:48:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:49:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:53:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:53:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:54:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 14:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:02:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:04:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:13:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:13:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:14:26 evo-x2 memory-emergency-guard-check[1571067]: MEMORY EMERGENCY: I/O PSI some avg60=64.34% sustained (max disk busy 26.2%, MemAvailable=43.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 15:14:27 evo-x2 memory-emergency-guard-check[1571067]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4539, zone 6) — top io since last trip: system.slice/io.stat +36708MB, system.slice/system-paperless.slice/io.stat +9504MB, system.slice/system-paperless.slice/paperless-task-queue.service/io.stat +9498MB
Oct 28 15:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 536ms CPU time over 732ms wall clock time, 11.5M memory peak, 3.7M read from disk, 31.6M written to disk.
Oct 28 15:14:56 evo-x2 memory-emergency-guard-check[1582555]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.19% sustained (max disk busy 92.2%, MemAvailable=40.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 15:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:14:57 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 2 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 28 15:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:16:27 evo-x2 memory-emergency-guard-check[1609969]: MEMORY EMERGENCY io drained (io PSI some avg60=36.33% < 40%) — churn units re-armed (re-arm #539)
Oct 28 15:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:18:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:20:18 evo-x2 gatus[29181]: 2026/10/28 15:20:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 15:20:18 evo-x2 gatus[29181]: 2026/10/28 15:20:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 15:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:24:30 evo-x2 memory-emergency-guard-check[1975185]: MEMORY EMERGENCY: I/O PSI some avg60=52.73% sustained (max disk busy 99.6%, MemAvailable=14.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 15:24:33 evo-x2 memory-emergency-guard-check[1975185]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4540, zone 6) — top io since last trip: user.slice/io.stat +20903MB, user.slice/user-1000.slice/io.stat +20821MB, system.slice/io.stat +13626MB
Oct 28 15:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.186s CPU time over 4.126s wall clock time, 8.1M memory peak, 12.2M read from disk, 41.3M written to disk.
Oct 28 15:25:00 evo-x2 memory-emergency-guard-check[2011379]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.87% sustained (max disk busy 99.0%, MemAvailable=14.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 15:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:27:00 evo-x2 memory-emergency-guard-check[2133943]: MEMORY EMERGENCY io drained (io PSI some avg60=39.92% < 40%) — churn units re-armed (re-arm #540)
Oct 28 15:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:29:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:37:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:38:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:39:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:39:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:40:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:43:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:44:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:45:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:45:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:46:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:47:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:47:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:48:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 159ms wall clock time, 8.5M memory peak, 1.5M read from disk, 4K written to disk.
Oct 28 15:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:48:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 143ms CPU time over 206ms wall clock time, 14.4M memory peak, 1M read from disk, 4K written to disk.
Oct 28 15:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:50:10 evo-x2 memory-emergency-guard-check[2903213]: MEMORY EMERGENCY: I/O PSI some avg60=40.28% sustained (max disk busy 69.9%, MemAvailable=31.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 15:50:13 evo-x2 memory-emergency-guard-check[2903213]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4541, zone 6) — top io since last trip: system.slice/io.stat +73539MB, user.slice/io.stat +60573MB, user.slice/user-1000.slice/io.stat +58754MB
Oct 28 15:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:50:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.087s CPU time over 3.320s wall clock time, 9.3M memory peak, 36.4M read from disk, 70.4M written to disk.
Oct 28 15:50:40 evo-x2 memory-emergency-guard-check[2932734]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.48% sustained (max disk busy 66.3%, MemAvailable=31.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already stopped the sockets, this line is the guard's heartbeat
Oct 28 15:50:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:52:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:52:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:53:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:53:42 evo-x2 memory-emergency-guard-check[3118664]: MEMORY EMERGENCY io drained (io PSI some avg60=35.20% < 40%) — churn units re-armed (re-arm #541)
Oct 28 15:53:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:54:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:55:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:55:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:56:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:57:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 15:59:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:00:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:00:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:01:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:02:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:03:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:03:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:04:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:04:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:05:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:05:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:07:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:07:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:08:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:09:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:10:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:10:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:12:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:13:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:13:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:14:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:14:51 evo-x2 memory-emergency-guard-check[3939247]: MEMORY EMERGENCY: I/O PSI some avg60=45.52% sustained (max disk busy 97.7%, MemAvailable=33.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 16:14:53 evo-x2 memory-emergency-guard-check[3939247]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4542, zone 6) — top io since last trip: system.slice/io.stat +97217MB, user.slice/io.stat +25954MB, user.slice/user-1000.slice/io.stat +25103MB
Oct 28 16:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:14:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 942ms CPU time over 2.065s wall clock time, 8M memory peak, 4.4M read from disk, 36.4M written to disk.
Oct 28 16:15:21 evo-x2 memory-emergency-guard-check[3993642]: MEMORY EMERGENCY io drained (io PSI some avg60=39.73% < 40%) — churn units re-armed (re-arm #542)
Oct 28 16:15:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:18:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:19:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:19:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:20:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:20:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:21:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 171ms CPU time over 257ms wall clock time, 6.6M memory peak, 1.5M read from disk, 4K written to disk.
Oct 28 16:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 160ms wall clock time, 15M memory peak, 6.5M read from disk, 4K written to disk.
Oct 28 16:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:25:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:27:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:30:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:31:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:32:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:33:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:33:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:34:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:35:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:35:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:36:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:36:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:37:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:37:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:38:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:38:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:39:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:39:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:40:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:40:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:41:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:42:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:42:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:46:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:46:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:47:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:49:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:49:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:52:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:52:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:55:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 16:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:06:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:07:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:08:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:12:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 165ms wall clock time, 15.2M memory peak, 5.5M read from disk, 4K written to disk.
Oct 28 17:18:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 177ms wall clock time, 13.1M memory peak, 4M read from disk, 4K written to disk.
Oct 28 17:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:23:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:23:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:24:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:25:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:25:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:27:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:29:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:32:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:33:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:34:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:35:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:35:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:37:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:38:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:39:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:40:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:46:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:47:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:48:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:48:44 evo-x2 gatus[29181]: 2026/10/28 17:48:44 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 28 17:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:51:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:51:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:52:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:52:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:53:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:54:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:56:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 108ms CPU time over 173ms wall clock time, 11.2M memory peak, 3.6M read from disk, 4K written to disk.
Oct 28 17:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:58:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 17:59:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:00:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 153ms wall clock time, 10.1M memory peak, 1.6M read from disk, 4K written to disk.
Oct 28 18:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:02:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:02:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:03:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:04:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:06:02 evo-x2 memory-emergency-guard-check[2235869]: MEMORY EMERGENCY IO-PAUSE (trip #4543, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 18:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 806ms wall clock time, 10.2M memory peak, 388K read from disk, 10.6M written to disk.
Oct 28 18:06:31 evo-x2 memory-emergency-guard-check[2260819]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.70% sustained (max disk busy 100.0%, MemAvailable=21.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 18:06:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:07:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:08:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 175ms wall clock time, 8.5M memory peak, 1.3M read from disk, 4K written to disk.
Oct 28 18:09:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:11:11 evo-x2 gatus[1850404]: 2026/10/28 18:11:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 18:11:11 evo-x2 gatus[1850404]: 2026/10/28 18:11:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 18:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:14:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 162ms CPU time over 234ms wall clock time, 12.3M memory peak, 5.4M read from disk, 4K written to disk.
Oct 28 18:15:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:15:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:16:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:16:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:17:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:17:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:18:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:18:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:19:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:19:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:20:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 158ms wall clock time, 11.1M memory peak, 1.8M read from disk, 4K written to disk.
Oct 28 18:21:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 151ms wall clock time, 9.2M memory peak, 1.8M read from disk, 4K written to disk.
Oct 28 18:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:24:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:24:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:25:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:29:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:29:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:30:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:30:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 157ms wall clock time, 9.1M memory peak, 1.9M read from disk, 4K written to disk.
Oct 28 18:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 170ms wall clock time, 8.6M memory peak, 2.5M read from disk, 4K written to disk.
Oct 28 18:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:32:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:32:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:33:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:34:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:34:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:35:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:35:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:36:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:36:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:37:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:37:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:38:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:38:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:39:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:39:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:40:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 184ms wall clock time, 9.6M memory peak, 1.7M read from disk, 4K written to disk.
Oct 28 18:40:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:41:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 165ms CPU time over 334ms wall clock time, 10.5M memory peak, 3.5M read from disk, 4K written to disk.
Oct 28 18:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 162ms wall clock time, 10.3M memory peak, 1.9M read from disk, 4K written to disk.
Oct 28 18:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:49:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:50:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:50:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:51:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:51:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:52:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:52:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:53:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:53:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:54:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:54:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:55:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:55:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:56:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:57:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:57:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:58:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:58:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:59:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 18:59:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:00:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:01:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:02:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:02:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:02:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 182ms wall clock time, 9.2M memory peak, 1.1M read from disk, 4K written to disk.
Oct 28 19:03:15 evo-x2 memory-emergency-guard-check[3973245]: MEMORY EMERGENCY IO-PAUSE (trip #4544, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 680ms CPU time over 1.280s wall clock time, 9.5M memory peak, 15.5M read from disk, 34.8M written to disk.
Oct 28 19:03:44 evo-x2 memory-emergency-guard-check[4025838]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.31% sustained (max disk busy 88.4%, MemAvailable=14.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:03:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 184ms CPU time over 308ms wall clock time, 6.6M memory peak, 1.6M read from disk, 4K written to disk.
Oct 28 19:04:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 144ms CPU time over 249ms wall clock time, 9.4M memory peak, 3.6M read from disk, 4K written to disk.
Oct 28 19:05:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:05:46 evo-x2 memory-emergency-guard-check[4123801]: MEMORY EMERGENCY IO-PAUSE (trip #4545, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 996ms CPU time over 2.346s wall clock time, 9.5M memory peak, 54.5M read from disk, 31.7M written to disk.
Oct 28 19:06:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:06:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:07:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:08:15 evo-x2 memory-emergency-guard-check[4192482]: MEMORY EMERGENCY IO-PAUSE (trip #4546, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 1.468s wall clock time, 11.1M memory peak, 11.3M read from disk, 29M written to disk.
Oct 28 19:08:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:09:11 evo-x2 gatus[1850404]: 2026/10/28 19:09:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 19:09:11 evo-x2 gatus[1850404]: 2026/10/28 19:09:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 19:09:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:10:45 evo-x2 memory-emergency-guard-check[164506]: MEMORY EMERGENCY IO-PAUSE (trip #4547, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:10:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 757ms CPU time over 1.678s wall clock time, 13.6M memory peak, 21M read from disk, 16.1M written to disk.
Oct 28 19:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:13:35 evo-x2 memory-emergency-guard-check[236444]: MEMORY EMERGENCY IO-PAUSE (trip #4548, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 901ms CPU time over 20.907s wall clock time, 12.1M memory peak, 22.4M read from disk, 3.1M written to disk.
Oct 28 19:13:44 evo-x2 memory-emergency-guard-check[268449]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.25% sustained (max disk busy 99.9%, MemAvailable=15.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:13:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:14:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 150ms CPU time over 393ms wall clock time, 8.8M memory peak, 2.3M read from disk, 4K written to disk.
Oct 28 19:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:15:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:16:27 evo-x2 memory-emergency-guard-check[340642]: MEMORY EMERGENCY IO-PAUSE (trip #4549, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 849ms CPU time over 43.299s wall clock time, 12M memory peak, 20.6M read from disk, 23.1M written to disk.
Oct 28 19:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:18:46 evo-x2 memory-emergency-guard-check[471801]: MEMORY EMERGENCY IO-PAUSE (trip #4550, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 826ms CPU time over 18.670s wall clock time, 14.2M memory peak, 13.4M read from disk, 2.4M written to disk.
Oct 28 19:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 140ms CPU time over 202ms wall clock time, 11.1M memory peak, 4.1M read from disk, 4K written to disk.
Oct 28 19:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:21:11 evo-x2 gatus[1850404]: 2026/10/28 19:21:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 19:21:11 evo-x2 gatus[1850404]: 2026/10/28 19:21:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 19:21:17 evo-x2 memory-emergency-guard-check[566951]: MEMORY EMERGENCY IO-PAUSE (trip #4551, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:21:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:21:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 19.648s wall clock time, 11.3M memory peak, 10.1M read from disk, 43.3M written to disk.
Oct 28 19:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:23:44 evo-x2 memory-emergency-guard-check[654308]: MEMORY EMERGENCY IO-PAUSE (trip #4552, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 757ms CPU time over 15.026s wall clock time, 12.8M memory peak, 13M read from disk, 23.9M written to disk.
Oct 28 19:23:59 evo-x2 memory-emergency-guard-check[678332]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.25% sustained (max disk busy 100.0%, MemAvailable=14.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:25:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:26:47 evo-x2 memory-emergency-guard-check[747155]: MEMORY EMERGENCY IO-PAUSE (trip #4553, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 829ms CPU time over 47.693s wall clock time, 13.5M memory peak, 23.7M read from disk, 19.6M written to disk.
Oct 28 19:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:27:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:29:09 evo-x2 memory-emergency-guard-check[828204]: MEMORY EMERGENCY IO-PAUSE (trip #4554, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 950ms CPU time over 21.825s wall clock time, 10.4M memory peak, 9.7M read from disk, 3M written to disk.
Oct 28 19:29:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:29:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:30:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:31:54 evo-x2 memory-emergency-guard-check[923871]: MEMORY EMERGENCY IO-PAUSE (trip #4555, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 880ms CPU time over 36.962s wall clock time, 11.4M memory peak, 8.8M read from disk, 33M written to disk.
Oct 28 19:31:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:34:46 evo-x2 memory-emergency-guard-check[1015430]: MEMORY EMERGENCY IO-PAUSE (trip #4556, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 691ms CPU time over 51.658s wall clock time, 13.6M memory peak, 20.4M read from disk, 1.6M written to disk.
Oct 28 19:34:46 evo-x2 memory-emergency-guard-check[1050069]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.98% sustained (max disk busy 99.4%, MemAvailable=20.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (52s < 150s, 98s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:37:19 evo-x2 memory-emergency-guard-check[1103660]: MEMORY EMERGENCY IO-PAUSE (trip #4557, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 745ms CPU time over 32.809s wall clock time, 13.7M memory peak, 35M read from disk, 12.3M written to disk.
Oct 28 19:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 191ms CPU time over 631ms wall clock time, 6M memory peak, 1.4M read from disk, 4K written to disk.
Oct 28 19:43:23 evo-x2 memory-emergency-guard-check[1358344]: MEMORY EMERGENCY IO-PAUSE (trip #4558, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 951ms CPU time over 1.954s wall clock time, 8.5M memory peak, 28.1M read from disk, 15.6M written to disk.
Oct 28 19:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:44:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:44:54 evo-x2 memory-emergency-guard-check[1465499]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.47% sustained (max disk busy 97.4%, MemAvailable=13.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (92s < 150s, 58s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:44:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:45:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:45:56 evo-x2 memory-emergency-guard-check[1555175]: MEMORY EMERGENCY IO-PAUSE (trip #4559, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.036s CPU time over 2.778s wall clock time, 9M memory peak, 31.6M read from disk, 33.4M written to disk.
Oct 28 19:46:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:48:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:48:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:49:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 192ms CPU time over 357ms wall clock time, 6.1M memory peak, 1.3M read from disk, 4K written to disk.
Oct 28 19:53:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:55:09 evo-x2 memory-emergency-guard-check[1940585]: MEMORY EMERGENCY IO-PAUSE (trip #4560, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 19:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 734ms CPU time over 44.117s wall clock time, 12.1M memory peak, 26.8M read from disk, 3.4M written to disk.
Oct 28 19:55:09 evo-x2 memory-emergency-guard-check[1971575]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.47% sustained (max disk busy 100.0%, MemAvailable=18.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (44s < 150s, 106s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 19:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:56:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:57:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 19:59:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 123ms CPU time over 165ms wall clock time, 8.9M memory peak, 1.2M read from disk, 4K written to disk.
Oct 28 20:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:03:23 evo-x2 memory-emergency-guard-check[2200965]: MEMORY EMERGENCY IO-PAUSE (trip #4561, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 20:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:03:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 821ms CPU time over 12.638s wall clock time, 11M memory peak, 26.7M read from disk, 14.8M written to disk.
Oct 28 20:03:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:05:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:06:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:06:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 186ms wall clock time, 8.8M memory peak, 1.7M read from disk, 4K written to disk.
Oct 28 20:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:07:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 177ms wall clock time, 10.6M memory peak, 4.5M read from disk, 4K written to disk.
Oct 28 20:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:08:51 evo-x2 memory-emergency-guard-check[2384212]: MEMORY EMERGENCY IO-PAUSE (trip #4562, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 20:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 801ms CPU time over 8.254s wall clock time, 11.5M memory peak, 25.2M read from disk, 23M written to disk.
Oct 28 20:09:13 evo-x2 memory-emergency-guard-check[2405036]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.04% sustained (max disk busy 98.8%, MemAvailable=17.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 20:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:09:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:10:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:12:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:12:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:13:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:14:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:21:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:22:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:22:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:23:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:24:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:24:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 172ms wall clock time, 9.1M memory peak, 2.3M read from disk, 4K written to disk.
Oct 28 20:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:25:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 154ms CPU time over 201ms wall clock time, 9.6M memory peak, 1.8M read from disk, 4K written to disk.
Oct 28 20:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 332ms wall clock time, 8.1M memory peak, 1.9M read from disk, 4K written to disk.
Oct 28 20:26:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:27:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:28:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:30:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:30:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:32:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:34:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:49:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:50:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:50:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:51:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:51:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:52:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 20:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:02:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:03:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:05:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:06:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:12:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:12:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:13:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:15:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:15:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:24:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:24:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:25:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:26:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:34:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:34:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:35:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:35:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:36:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:36:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:37:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:39:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:39:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:41:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:42:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:42:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:52:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:52:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:53:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:54:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:54:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:55:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 21:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:01:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:02:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:02:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:03:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:03:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 206ms CPU time over 795ms wall clock time, 8.1M memory peak, 4.4M read from disk, 4K written to disk.
Oct 28 22:04:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:04:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:05:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:06:16 evo-x2 memory-emergency-guard-check[2065499]: MEMORY EMERGENCY IO-PAUSE (trip #4563, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.418s CPU time over 34.645s wall clock time, 7.8M memory peak, 23.2M read from disk, 36.6M written to disk.
Oct 28 22:06:16 evo-x2 memory-emergency-guard-check[2121112]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.91% sustained (max disk busy 98.6%, MemAvailable=16.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (35s < 150s, 115s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 22:06:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:07:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:07:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 163ms CPU time over 553ms wall clock time, 7M memory peak, 1M read from disk, 4K written to disk.
Oct 28 22:08:30 evo-x2 memory-emergency-guard-check[2209004]: MEMORY EMERGENCY IO-PAUSE (trip #4564, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:08:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.089s CPU time over 14.234s wall clock time, 8.5M memory peak, 14.7M read from disk, 39.3M written to disk.
Oct 28 22:08:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:09:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:09:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:11:11 evo-x2 gatus[1850404]: 2026/10/28 22:11:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 22:11:12 evo-x2 gatus[1850404]: 2026/10/28 22:11:12 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 28 22:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:11:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 140ms CPU time over 228ms wall clock time, 11.1M memory peak, 6.4M read from disk, 4K written to disk.
Oct 28 22:11:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:12:29 evo-x2 memory-emergency-guard-check[2366027]: MEMORY EMERGENCY IO-PAUSE (trip #4565, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.092s CPU time over 11.197s wall clock time, 12M memory peak, 19.6M read from disk, 25.4M written to disk.
Oct 28 22:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 141ms CPU time over 538ms wall clock time, 8.3M memory peak, 4.7M read from disk, 4K written to disk.
Oct 28 22:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:15:16 evo-x2 memory-emergency-guard-check[2493274]: MEMORY EMERGENCY IO-PAUSE (trip #4566, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 808ms CPU time over 27.576s wall clock time, 10M memory peak, 18.4M read from disk, 23.3M written to disk.
Oct 28 22:15:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 189ms wall clock time, 9M memory peak, 1M read from disk, 4K written to disk.
Oct 28 22:16:19 evo-x2 memory-emergency-guard-check[2577898]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.07% sustained (max disk busy 100.0%, MemAvailable=14.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 22:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:16:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:17:36 evo-x2 memory-emergency-guard-check[2617271]: MEMORY EMERGENCY IO-PAUSE (trip #4567, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 823ms CPU time over 17.223s wall clock time, 11.5M memory peak, 17.2M read from disk, 12.8M written to disk.
Oct 28 22:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 172ms CPU time over 495ms wall clock time, 5.4M memory peak, 1.5M read from disk, 4K written to disk.
Oct 28 22:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:19:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:20:10 evo-x2 memory-emergency-guard-check[2724499]: MEMORY EMERGENCY IO-PAUSE (trip #4568, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.141s CPU time over 19.979s wall clock time, 10.5M memory peak, 7.3M read from disk, 29.4M written to disk.
Oct 28 22:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:23:50 evo-x2 memory-emergency-guard-check[2873385]: MEMORY EMERGENCY IO-PAUSE (trip #4569, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 868ms CPU time over 1min 29.572s wall clock time, 12.3M memory peak, 26.3M read from disk, 35.3M written to disk.
Oct 28 22:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:24:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:25:11 evo-x2 gatus[1850404]: 2026/10/28 22:25:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 22:25:11 evo-x2 gatus[1850404]: 2026/10/28 22:25:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 28 22:25:38 evo-x2 memory-emergency-guard-check[3037981]: MEMORY EMERGENCY IO-PAUSE (trip #4570, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 840ms CPU time over 17.771s wall clock time, 13M memory peak, 9.5M read from disk, 34.3M written to disk.
Oct 28 22:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:26:21 evo-x2 memory-emergency-guard-check[3110302]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.70% sustained (max disk busy 100.0%, MemAvailable=18.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 22:26:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:27:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:27:52 evo-x2 memory-emergency-guard-check[3185365]: MEMORY EMERGENCY IO-PAUSE (trip #4571, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:27:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 981ms CPU time over 1.336s wall clock time, 14.1M memory peak, 3.4M read from disk, 70.9M written to disk.
Oct 28 22:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:29:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:31:46 evo-x2 memory-emergency-guard-check[3321044]: MEMORY EMERGENCY IO-PAUSE (trip #4572, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 963ms CPU time over 1min 24.593s wall clock time, 13.4M memory peak, 13.4M read from disk, 96.9M written to disk.
Oct 28 22:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 148ms CPU time over 182ms wall clock time, 7.3M memory peak, 1.9M read from disk, 4K written to disk.
Oct 28 22:33:21 evo-x2 memory-emergency-guard-check[3447469]: MEMORY EMERGENCY IO-PAUSE (trip #4573, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 791ms CPU time over 5.163s wall clock time, 12.9M memory peak, 47.7M read from disk, 37.3M written to disk.
Oct 28 22:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 207ms wall clock time, 8.5M memory peak, 2.7M read from disk, 4K written to disk.
Oct 28 22:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:34:21 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 11 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (fastflowlm) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u fastflowlm -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 28 22:34:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:40:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 178ms CPU time over 315ms wall clock time, 10.4M memory peak, 3.2M read from disk, 4K written to disk.
Oct 28 22:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:45:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:46:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:46:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 204ms CPU time over 428ms wall clock time, 11.7M memory peak, 4.1M read from disk, 4K written to disk.
Oct 28 22:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:49:54 evo-x2 memory-emergency-guard-check[4176095]: MEMORY EMERGENCY: MemAvailable=3.1% below absolute floor — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 28 22:49:57 evo-x2 memory-emergency-guard-check[4176095]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4574, zone 1) — top io since last trip: system.slice/io.stat +95795MB, user.slice/io.stat +32407MB, user.slice/user-1000.slice/io.stat +30434MB
Oct 28 22:50:50 evo-x2 memory-emergency-guard-check[4176095]: MEMORY EMERGENCY io drained (io PSI some avg60=35.30% < 40%) — churn units re-armed (re-arm #543)
Oct 28 22:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.125s CPU time over 59.114s wall clock time, 9.8M memory peak, 59.2M read from disk, 69M written to disk.
Oct 28 22:50:50 evo-x2 memory-emergency-guard-check[45272]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.15% sustained (max disk busy 100.0%, MemAvailable=20.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (59s < 150s, 91s remaining; last trip zone=1) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 22:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:52:52 evo-x2 memory-emergency-guard-check[125748]: MEMORY EMERGENCY IO-PAUSE (trip #4575, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:52:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 739ms CPU time over 1.072s wall clock time, 11.3M memory peak, 17M read from disk, 49.7M written to disk.
Oct 28 22:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:54:26 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 13 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 28 22:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:57:23 evo-x2 memory-emergency-guard-check[294827]: MEMORY EMERGENCY IO-PAUSE (trip #4576, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 995ms CPU time over 1.514s wall clock time, 14M memory peak, 12.4M read from disk, 31.5M written to disk.
Oct 28 22:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:58:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:58:38 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 14 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (monitor365-server) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u monitor365-server -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=2.26%, MemAvailable=9.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 28 22:58:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:59:54 evo-x2 memory-emergency-guard-check[393523]: MEMORY EMERGENCY IO-PAUSE (trip #4577, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 22:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 22:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 884ms CPU time over 2.297s wall clock time, 10.3M memory peak, 24.2M read from disk, 7.3M written to disk.
Oct 28 23:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:00:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 186ms CPU time over 632ms wall clock time, 8.6M memory peak, 1.8M read from disk, 4K written to disk.
Oct 28 23:00:52 evo-x2 memory-emergency-guard-check[429914]: MEMORY EMERGENCY still active (MemAvailable=6.8% AND zram=93.7% (shmem-unevictable trap: model pages cannot evict with full zram)) but action cooldown active (60s < 600s, 540s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 23:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 135ms CPU time over 246ms wall clock time, 11.7M memory peak, 4.2M read from disk, 4K written to disk.
Oct 28 23:03:12 evo-x2 memory-emergency-guard-check[507035]: MEMORY EMERGENCY IO-PAUSE (trip #4578, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.311s CPU time over 23.200s wall clock time, 10.1M memory peak, 10.6M read from disk, 16.7M written to disk.
Oct 28 23:03:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:03:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:04:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:05:57 evo-x2 memory-emergency-guard-check[659522]: MEMORY EMERGENCY IO-PAUSE (trip #4579, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 919ms CPU time over 38.473s wall clock time, 13M memory peak, 28.6M read from disk, 28M written to disk.
Oct 28 23:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 138ms CPU time over 306ms wall clock time, 14.9M memory peak, 8M read from disk, 4K written to disk.
Oct 28 23:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:07:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:08:37 evo-x2 memory-emergency-guard-check[783493]: MEMORY EMERGENCY IO-PAUSE (trip #4580, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 862ms CPU time over 39.588s wall clock time, 17.5M memory peak, 27.7M read from disk, 10M written to disk.
Oct 28 23:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:11:07 evo-x2 memory-emergency-guard-check[871082]: MEMORY EMERGENCY IO-PAUSE (trip #4581, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:11:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 908ms CPU time over 29.127s wall clock time, 11.2M memory peak, 17.5M read from disk, 12.6M written to disk.
Oct 28 23:11:08 evo-x2 memory-emergency-guard-check[899001]: MEMORY EMERGENCY still active (I/O PSI some avg60=55.34% sustained (max disk busy 100.0%, MemAvailable=25.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 23:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 142ms CPU time over 209ms wall clock time, 6.3M memory peak, 1.2M read from disk, 4K written to disk.
Oct 28 23:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:13:24 evo-x2 memory-emergency-guard-check[965475]: MEMORY EMERGENCY IO-PAUSE (trip #4582, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 799ms CPU time over 15.659s wall clock time, 10.1M memory peak, 9.1M read from disk, 16.6M written to disk.
Oct 28 23:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:13:44 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 17 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (monitor365-server) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u monitor365-server -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 28 23:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:16:05 evo-x2 memory-emergency-guard-check[1055507]: MEMORY EMERGENCY IO-PAUSE (trip #4583, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 905ms CPU time over 26.135s wall clock time, 10.3M memory peak, 19.9M read from disk, 7.8M written to disk.
Oct 28 23:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 124ms CPU time over 164ms wall clock time, 8.3M memory peak, 1.2M read from disk, 4K written to disk.
Oct 28 23:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 180ms CPU time over 1.178s wall clock time, 8.5M memory peak, 4.3M read from disk, 4K written to disk.
Oct 28 23:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:21:02 evo-x2 memory-emergency-guard-check[1237077]: MEMORY EMERGENCY IO-PAUSE (trip #4584, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:21:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 900ms CPU time over 23.501s wall clock time, 11.9M memory peak, 35.9M read from disk, 8.6M written to disk.
Oct 28 23:21:09 evo-x2 memory-emergency-guard-check[1260082]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.63% sustained (max disk busy 99.8%, MemAvailable=22.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 23:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:22:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:23:34 evo-x2 memory-emergency-guard-check[1310783]: MEMORY EMERGENCY IO-PAUSE (trip #4585, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.216s CPU time over 24.924s wall clock time, 10.1M memory peak, 35.9M read from disk, 48.1M written to disk.
Oct 28 23:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 137ms CPU time over 281ms wall clock time, 10.1M memory peak, 5.4M read from disk, 4K written to disk.
Oct 28 23:24:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:24:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:26:02 evo-x2 memory-emergency-guard-check[1408220]: MEMORY EMERGENCY IO-PAUSE (trip #4586, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 852ms CPU time over 22.860s wall clock time, 12.5M memory peak, 32.3M read from disk, 34.7M written to disk.
Oct 28 23:26:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:26:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:27:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:27:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:28:12 evo-x2 memory-emergency-guard-check[1503335]: MEMORY EMERGENCY IO-PAUSE (trip #4587, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:28:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 830ms CPU time over 2.250s wall clock time, 10.8M memory peak, 17.5M read from disk, 16.4M written to disk.
Oct 28 23:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:28:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 173ms CPU time over 239ms wall clock time, 8.3M memory peak, 1.5M read from disk, 4K written to disk.
Oct 28 23:29:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:29:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:30:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:31:10 evo-x2 memory-emergency-guard-check[1589469]: MEMORY EMERGENCY IO-PAUSE (trip #4588, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 741ms CPU time over 29.784s wall clock time, 13.9M memory peak, 46.2M read from disk, 4.8M written to disk.
Oct 28 23:31:11 evo-x2 memory-emergency-guard-check[1610874]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.21% sustained (max disk busy 100.0%, MemAvailable=21.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 28 23:31:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:31:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:32:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 108ms CPU time over 143ms wall clock time, 9.3M memory peak, 1.4M read from disk, 4K written to disk.
Oct 28 23:33:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:33:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:34:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 110ms CPU time over 430ms wall clock time, 8.4M memory peak, 1.2M read from disk, 4K written to disk.
Oct 28 23:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:37:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:38:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:39:48 evo-x2 memory-emergency-guard-check[1863700]: MEMORY EMERGENCY IO-PAUSE (trip #4589, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 28 23:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 718ms CPU time over 6.116s wall clock time, 11.2M memory peak, 4.1M read from disk, 29.9M written to disk.
Oct 28 23:40:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:42:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 140ms wall clock time, 8.7M memory peak, 3.2M read from disk, 4K written to disk.
Oct 28 23:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:43:19 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 16 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=12.74%, MemAvailable=22.5%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 28 23:43:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:43:49 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 16 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 28 23:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:44:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:45:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:45:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:46:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:47:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:47:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:48:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:48:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:49:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:51:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:51:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:52:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:52:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:53:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:54:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:54:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:55:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:55:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:56:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:57:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:57:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:58:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:58:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:59:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 28 23:59:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:00:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:00:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 153ms wall clock time, 9.6M memory peak, 2.2M read from disk, 4K written to disk.
Oct 29 00:00:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:00:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 443ms wall clock time, 17M memory peak, 11.1M read from disk, 4K written to disk.
Oct 29 00:01:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:02:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:03:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:03:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:04:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:07:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:07:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:08:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:09:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:13:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:15:43 evo-x2 memory-emergency-guard-check[2739762]: MEMORY EMERGENCY IO-PAUSE (trip #4590, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:15:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:15:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 583ms CPU time over 1.056s wall clock time, 10.4M memory peak, 2.4M read from disk, 43.8M written to disk.
Oct 29 00:16:12 evo-x2 memory-emergency-guard-check[2750746]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.31% sustained (max disk busy 94.1%, MemAvailable=42.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 00:16:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:16:17 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 7 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (monitor365-server) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u monitor365-server -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 00:16:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:17:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:18:14 evo-x2 memory-emergency-guard-check[2774127]: MEMORY EMERGENCY IO-PAUSE (trip #4591, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:18:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 905ms wall clock time, 10.8M memory peak, 944K read from disk, 31.4M written to disk.
Oct 29 00:18:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:19:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:20:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:20:45 evo-x2 memory-emergency-guard-check[2812820]: MEMORY EMERGENCY IO-PAUSE (trip #4592, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:20:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 669ms wall clock time, 10.1M memory peak, 160K read from disk, 19.8M written to disk.
Oct 29 00:21:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:22:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:23:17 evo-x2 memory-emergency-guard-check[2851008]: MEMORY EMERGENCY IO-PAUSE (trip #4593, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:23:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 1.218s wall clock time, 10.9M memory peak, 3.7M read from disk, 68.3M written to disk.
Oct 29 00:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:25:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:26:03 evo-x2 memory-emergency-guard-check[2890940]: MEMORY EMERGENCY IO-PAUSE (trip #4594, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:26:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 16.614s wall clock time, 12M memory peak, 1.4M read from disk, 61.1M written to disk.
Oct 29 00:26:17 evo-x2 memory-emergency-guard-check[2903866]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.90% sustained (max disk busy 100.0%, MemAvailable=42.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 00:26:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:26:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:27:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:28:24 evo-x2 memory-emergency-guard-check[2930243]: MEMORY EMERGENCY IO-PAUSE (trip #4595, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 646ms CPU time over 6.200s wall clock time, 12.2M memory peak, 3M read from disk, 66.4M written to disk.
Oct 29 00:28:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:29:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:29:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:30:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:30:49 evo-x2 memory-emergency-guard-check[2977533]: MEMORY EMERGENCY IO-PAUSE (trip #4596, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 00:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:30:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 644ms CPU time over 916ms wall clock time, 9.9M memory peak, 544K read from disk, 45.3M written to disk.
Oct 29 00:31:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:31:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:32:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:32:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:33:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:33:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:34:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:34:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:35:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:35:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:36:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:40:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:40:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:41:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:47:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:48:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:48:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:49:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:49:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:50:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:55:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:55:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 00:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:00:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:01:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:01:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:02:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:03:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:04:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:07:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:08:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:08:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:09:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:11:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:11:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:12:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:12:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:13:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:13:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:14:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:14:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:15:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:17:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:18:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:18:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:19:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:19:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:20:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:21:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:21:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:22:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:22:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:23:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:23:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:25:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:25:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:26:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:26:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:27:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:27:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:28:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:29:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:29:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:30:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:30:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:31:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:32:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:32:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:33:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:33:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:34:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:34:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:35:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:35:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:36:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:37:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:37:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:38:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:39:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:39:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:42:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:44:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:49:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 143ms CPU time over 253ms wall clock time, 7.2M memory peak, 1.7M read from disk, 4K written to disk.
Oct 29 01:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:57:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:57:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:58:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:58:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 01:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:07:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:08:18 evo-x2 memory-emergency-guard-check[1647709]: MEMORY EMERGENCY IO-PAUSE (trip #4597, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.022s CPU time over 8.792s wall clock time, 10.7M memory peak, 28.7M read from disk, 38.6M written to disk.
Oct 29 02:08:40 evo-x2 memory-emergency-guard-check[1671657]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.23% sustained (max disk busy 97.0%, MemAvailable=19.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 02:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:10:46 evo-x2 memory-emergency-guard-check[1751782]: MEMORY EMERGENCY IO-PAUSE (trip #4598, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 5.338s wall clock time, 10.5M memory peak, 10.5M read from disk, 32.9M written to disk.
Oct 29 02:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:12:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:12:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:13:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:13:12 evo-x2 gatus[1850404]: 2026/10/29 02:13:12 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 02:13:12 evo-x2 gatus[1850404]: 2026/10/29 02:13:12 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 02:13:54 evo-x2 memory-emergency-guard-check[1843368]: MEMORY EMERGENCY IO-PAUSE (trip #4599, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 760ms CPU time over 13.201s wall clock time, 10.8M memory peak, 18.9M read from disk, 12.6M written to disk.
Oct 29 02:14:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:14:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:15:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:15:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:16:29 evo-x2 memory-emergency-guard-check[1919948]: MEMORY EMERGENCY IO-PAUSE (trip #4600, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:16:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 739ms CPU time over 17.615s wall clock time, 11.3M memory peak, 19.4M read from disk, 7.6M written to disk.
Oct 29 02:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:19:13 evo-x2 memory-emergency-guard-check[1999384]: MEMORY EMERGENCY IO-PAUSE (trip #4601, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.022s CPU time over 31.085s wall clock time, 9.8M memory peak, 15.3M read from disk, 12.2M written to disk.
Oct 29 02:19:13 evo-x2 memory-emergency-guard-check[2027391]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.28% sustained (max disk busy 99.9%, MemAvailable=17.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 02:19:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:19:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:20:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 112ms CPU time over 281ms wall clock time, 9M memory peak, 3M read from disk, 4K written to disk.
Oct 29 02:20:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:21:35 evo-x2 memory-emergency-guard-check[2082508]: MEMORY EMERGENCY IO-PAUSE (trip #4602, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:21:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:21:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 705ms CPU time over 21.896s wall clock time, 11.1M memory peak, 21.9M read from disk, 10.3M written to disk.
Oct 29 02:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 165ms wall clock time, 9.8M memory peak, 1.6M read from disk, 4K written to disk.
Oct 29 02:22:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:22:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:23:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:23:56 evo-x2 memory-emergency-guard-check[2164088]: MEMORY EMERGENCY IO-PAUSE (trip #4603, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:23:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 657ms CPU time over 12.197s wall clock time, 12.6M memory peak, 22M read from disk, 23.6M written to disk.
Oct 29 02:24:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:25:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:25:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 156ms CPU time over 222ms wall clock time, 8.3M memory peak, 2.4M read from disk, 4K written to disk.
Oct 29 02:26:23 evo-x2 memory-emergency-guard-check[2242669]: MEMORY EMERGENCY IO-PAUSE (trip #4604, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 753ms CPU time over 9.289s wall clock time, 10.4M memory peak, 30.6M read from disk, 25.4M written to disk.
Oct 29 02:26:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:27:11 evo-x2 gatus[1850404]: 2026/10/29 02:27:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 02:27:11 evo-x2 gatus[1850404]: 2026/10/29 02:27:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 02:27:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:28:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:28:47 evo-x2 memory-emergency-guard-check[2309361]: MEMORY EMERGENCY IO-PAUSE (trip #4605, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:28:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 731ms CPU time over 2.400s wall clock time, 11.6M memory peak, 23.7M read from disk, 41.4M written to disk.
Oct 29 02:29:15 evo-x2 memory-emergency-guard-check[2333496]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.70% sustained (max disk busy 88.6%, MemAvailable=21.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 02:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:32:22 evo-x2 memory-emergency-guard-check[2451903]: MEMORY EMERGENCY IO-PAUSE (trip #4606, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 707ms CPU time over 7.486s wall clock time, 11.1M memory peak, 2.8M read from disk, 22.8M written to disk.
Oct 29 02:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:35:12 evo-x2 memory-emergency-guard-check[2508262]: MEMORY EMERGENCY IO-PAUSE (trip #4607, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:35:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 700ms CPU time over 26.668s wall clock time, 11.8M memory peak, 21.4M read from disk, 37.1M written to disk.
Oct 29 02:35:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:35:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:36:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:37:20 evo-x2 memory-emergency-guard-check[2586127]: MEMORY EMERGENCY IO-PAUSE (trip #4608, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 736ms CPU time over 4.418s wall clock time, 10.2M memory peak, 2.1M read from disk, 31.2M written to disk.
Oct 29 02:37:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:38:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:38:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:39:16 evo-x2 memory-emergency-guard-check[2656926]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.99% sustained (max disk busy 97.8%, MemAvailable=23.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 02:39:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:39:49 evo-x2 memory-emergency-guard-check[2663528]: MEMORY EMERGENCY IO-PAUSE (trip #4609, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 2.671s wall clock time, 11.2M memory peak, 1.3M read from disk, 25.1M written to disk.
Oct 29 02:40:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:40:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:41:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:41:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:42:17 evo-x2 memory-emergency-guard-check[2779701]: MEMORY EMERGENCY IO-PAUSE (trip #4610, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:42:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 548ms CPU time over 796ms wall clock time, 10.2M memory peak, 964K read from disk, 7.2M written to disk.
Oct 29 02:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:43:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:44:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:44:48 evo-x2 memory-emergency-guard-check[2840851]: MEMORY EMERGENCY IO-PAUSE (trip #4611, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:44:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.379s wall clock time, 9.3M memory peak, 508K read from disk, 14.1M written to disk.
Oct 29 02:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:45:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:47:18 evo-x2 memory-emergency-guard-check[2981788]: MEMORY EMERGENCY IO-PAUSE (trip #4612, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 539ms CPU time over 596ms wall clock time, 9.7M memory peak, 48K read from disk, 6.9M written to disk.
Oct 29 02:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:48:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:50:20 evo-x2 memory-emergency-guard-check[3085330]: MEMORY EMERGENCY IO-PAUSE (trip #4613, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 02:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 935ms CPU time over 1.867s wall clock time, 9.5M memory peak, 22.8M read from disk, 19.5M written to disk.
Oct 29 02:50:48 evo-x2 memory-emergency-guard-check[3121280]: MEMORY EMERGENCY still active (MemAvailable=9.1% AND zram=92.4% (shmem-unevictable trap: model pages cannot evict with full zram)) but action cooldown active (30s < 600s, 570s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 02:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:51:22 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 17 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=0.54%, MemAvailable=8.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 02:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:51:53 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 17 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 02:52:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:53:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:54:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:54:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:55:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:56:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:57:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 02:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:00:21 evo-x2 memory-emergency-guard-check[3575695]: MEMORY EMERGENCY: MemAvailable=6.5% AND zram=92.3% (shmem-unevictable trap: model pages cannot evict with full zram) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 29 03:00:25 evo-x2 memory-emergency-guard-check[3575695]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4614, zone 2) — top io since last trip: system.slice/io.stat +71468MB, system.slice/nix-daemon.service/io.stat +11770MB, user.slice/io.stat +4047MB
Oct 29 03:01:45 evo-x2 memory-emergency-guard-check[3575695]: MEMORY EMERGENCY io drained (io PSI some avg60=25.62% < 40%) — churn units re-armed (re-arm #544)
Oct 29 03:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 880ms CPU time over 1min 25.249s wall clock time, 8.5M memory peak, 3.1M read from disk, 14.1M written to disk.
Oct 29 03:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:02:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:02:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:03:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:03:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:05:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:06:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:07:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:07:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:08:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:08:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:09:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:11:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:12:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:12:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:14:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:14:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:17:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:21:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:22:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:24:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:24:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:25:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:26:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:26:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:28:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:29:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:29:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:30:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:30:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:32:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:33:25 evo-x2 memory-emergency-guard-check[225985]: MEMORY EMERGENCY: MemAvailable=7.7% AND zram=92.7% (shmem-unevictable trap: model pages cannot evict with full zram) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 29 03:33:33 evo-x2 memory-emergency-guard-check[225985]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4615, zone 2) — top io since last trip: system.slice/io.stat +162111MB, system.slice/clickhouse.service/io.stat +13896MB, system.slice/system-immich.slice/io.stat +11425MB
Oct 29 03:34:20 evo-x2 memory-emergency-guard-check[225985]: MEMORY EMERGENCY io drained (io PSI some avg60=31.06% < 40%) — churn units re-armed (re-arm #545)
Oct 29 03:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.518s CPU time over 55.061s wall clock time, 10.1M memory peak, 38.1M read from disk, 51.8M written to disk.
Oct 29 03:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:34:26 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 9 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 03:34:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:38:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:38:37 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 7 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 29 03:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:44:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:47:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:48:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:48:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:49:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:52:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:53:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:54:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:54:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 192ms wall clock time, 12.7M memory peak, 5M read from disk, 4K written to disk.
Oct 29 03:55:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:55:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 223ms wall clock time, 9.1M memory peak, 1M read from disk, 4K written to disk.
Oct 29 03:56:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:56:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:57:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:57:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:58:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:59:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 03:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:01:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:02:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 132ms CPU time over 484ms wall clock time, 7.5M memory peak, 2.6M read from disk, 4K written to disk.
Oct 29 04:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:03:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:03:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:04:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:05:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:05:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 123ms CPU time over 224ms wall clock time, 13M memory peak, 4.3M read from disk, 4K written to disk.
Oct 29 04:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:06:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:07:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:07:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:08:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:08:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 167ms wall clock time, 12.4M memory peak, 4.1M read from disk, 4K written to disk.
Oct 29 04:09:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:09:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:10:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:11:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:11:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:12:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:12:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:13:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:15:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:15:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:16:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:16:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:19:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:28:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:29:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:35:02 evo-x2 memory-emergency-guard-check[1921986]: MEMORY EMERGENCY IO-PAUSE (trip #4616, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 04:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 642ms wall clock time, 11M memory peak, 592K read from disk, 11.7M written to disk.
Oct 29 04:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:35:40 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 04:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:41:11 evo-x2 gatus[1850404]: 2026/10/29 04:41:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 04:41:11 evo-x2 gatus[1850404]: 2026/10/29 04:41:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 04:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:42:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:42:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:43:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:44:04 evo-x2 memory-emergency-guard-check[2128128]: MEMORY EMERGENCY IO-PAUSE (trip #4617, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 04:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 961ms wall clock time, 11.5M memory peak, 17.7M read from disk, 53.8M written to disk.
Oct 29 04:44:33 evo-x2 memory-emergency-guard-check[2142515]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.05% sustained (max disk busy 34.4%, MemAvailable=42.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 04:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:47:04 evo-x2 memory-emergency-guard-check[2174547]: MEMORY EMERGENCY IO-PAUSE (trip #4618, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 04:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 971ms wall clock time, 11.2M memory peak, 8.7M read from disk, 42M written to disk.
Oct 29 04:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:48:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:48:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:51:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:52:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:52:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:53:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:55:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:56:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:57:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:58:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:58:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 04:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:02:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:03:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:03:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:04:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:05:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:05:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:06:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:06:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:08:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:08:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:09:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:10:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:13:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:13:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:14:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:14:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:15:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:15:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:16:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:16:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:17:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:18:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:19:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:19:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:21:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:22:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:22:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:23:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:29:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:29:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:31:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:31:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:32:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:32:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:33:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:33:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:34:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:34:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:35:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:35:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:36:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:38:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:38:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:39:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:40:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:41:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:42:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:42:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:43:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:43:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:44:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:46:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:47:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:48:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:49:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:49:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:54:52 evo-x2 memory-emergency-guard-check[3595170]: MEMORY EMERGENCY IO-PAUSE (trip #4619, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 05:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 752ms wall clock time, 11.2M memory peak, 3.2M read from disk, 40.1M written to disk.
Oct 29 05:55:21 evo-x2 memory-emergency-guard-check[3608031]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.00% sustained (max disk busy 99.9%, MemAvailable=36.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 05:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:55:27 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 05:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:57:22 evo-x2 memory-emergency-guard-check[3635134]: MEMORY EMERGENCY IO-PAUSE (trip #4620, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 05:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 600ms CPU time over 872ms wall clock time, 12.6M memory peak, 664K read from disk, 20.6M written to disk.
Oct 29 05:57:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:58:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:59:52 evo-x2 memory-emergency-guard-check[3675253]: MEMORY EMERGENCY IO-PAUSE (trip #4621, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 05:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 05:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 518ms CPU time over 651ms wall clock time, 11.4M memory peak, 416K read from disk, 17.3M written to disk.
Oct 29 06:00:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:01:11 evo-x2 gatus[1850404]: 2026/10/29 06:01:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 06:01:11 evo-x2 gatus[1850404]: 2026/10/29 06:01:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 06:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:01:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:02:22 evo-x2 memory-emergency-guard-check[3710796]: MEMORY EMERGENCY IO-PAUSE (trip #4622, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 06:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 545ms CPU time over 715ms wall clock time, 11.4M memory peak, 3.7M read from disk, 19.1M written to disk.
Oct 29 06:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:03:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:04:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:04:52 evo-x2 memory-emergency-guard-check[3744750]: MEMORY EMERGENCY IO-PAUSE (trip #4623, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 06:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 489ms CPU time over 529ms wall clock time, 10.7M memory peak, 32K read from disk, 9.3M written to disk.
Oct 29 06:05:21 evo-x2 memory-emergency-guard-check[3754948]: MEMORY EMERGENCY still active (I/O PSI some avg60=77.42% sustained (max disk busy 69.3%, MemAvailable=41.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 06:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:06:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:07:22 evo-x2 memory-emergency-guard-check[3776934]: MEMORY EMERGENCY IO-PAUSE (trip #4624, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 06:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 552ms wall clock time, 11.2M memory peak, 32K read from disk, 11M written to disk.
Oct 29 06:07:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:08:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:08:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:09:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:09:52 evo-x2 memory-emergency-guard-check[3808159]: MEMORY EMERGENCY IO-PAUSE (trip #4625, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 06:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:09:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 513ms CPU time over 563ms wall clock time, 11.2M memory peak, 80K read from disk, 15.5M written to disk.
Oct 29 06:10:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:10:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:11:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:11:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:12:22 evo-x2 memory-emergency-guard-check[3842893]: MEMORY EMERGENCY IO-PAUSE (trip #4626, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 06:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:12:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 514ms CPU time over 583ms wall clock time, 11.7M memory peak, 256K read from disk, 14.5M written to disk.
Oct 29 06:12:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:13:11 evo-x2 gatus[1850404]: 2026/10/29 06:13:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 06:13:11 evo-x2 gatus[1850404]: 2026/10/29 06:13:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 06:13:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:13:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:14:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:14:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:15:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:15:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:16:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:16:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:17:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:17:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:18:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:19:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:19:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:21:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:22:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:23:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:23:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:24:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:28:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:28:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:29:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:30:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:30:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:31:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:31:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:33:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:38:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:40:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:40:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:41:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:41:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:42:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:42:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:43:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:43:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:44:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:44:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:45:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:45:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:46:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:47:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:48:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:48:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:49:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:49:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:51:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:55:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:55:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:56:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:59:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 06:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:00:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:00:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:01:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:01:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:02:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:02:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:04:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:05:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:06:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:06:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:07:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:07:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:08:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:08:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:09:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:09:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:10:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:10:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:11:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:12:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:12:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:13:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:13:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:14:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:17:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:21:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:22:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:25:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:26:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:26:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:27:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:27:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:29:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:30:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:40:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:43:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:44:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:44:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:45:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:47:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:48:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:49:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:49:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:50:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:53:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:53:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:54:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:54:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:57:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:59:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 07:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:00:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:01:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 111ms CPU time over 142ms wall clock time, 12.3M memory peak, 2.7M read from disk, 4K written to disk.
Oct 29 08:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:02:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:04:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:04:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:05:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:05:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:06:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:09:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:10:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:11:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:11:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:12:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:12:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:13:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:13:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:15:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:15:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:16:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:16:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:17:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:18:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:19:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:19:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:20:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:20:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:21:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:23:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:24:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:24:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:25:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:25:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:30:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:33:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:36:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:37:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:37:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:40:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:41:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:46:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:48:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 139ms wall clock time, 9.3M memory peak, 1.4M read from disk, 4K written to disk.
Oct 29 08:49:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 158ms wall clock time, 9M memory peak, 1.2M read from disk, 4K written to disk.
Oct 29 08:50:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:51:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:52:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:52:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:53:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 111ms CPU time over 152ms wall clock time, 10.9M memory peak, 3M read from disk, 4K written to disk.
Oct 29 08:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 148ms wall clock time, 11.9M memory peak, 2.9M read from disk, 4K written to disk.
Oct 29 08:54:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:55:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:55:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:56:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:56:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:58:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:59:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 08:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:00:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:00:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:01:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:01:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:03:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:03:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:04:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:07:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 142ms wall clock time, 9.2M memory peak, 1M read from disk, 4K written to disk.
Oct 29 09:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:15:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:17:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:18:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:18:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:21:06 evo-x2 memory-emergency-guard-check[3789582]: MEMORY EMERGENCY IO-PAUSE (trip #4627, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 09:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 516ms CPU time over 564ms wall clock time, 10.8M memory peak, 288K read from disk, 20.5M written to disk.
Oct 29 09:21:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:21:37 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 09:22:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:22:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:23:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:25:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:27:11 evo-x2 gatus[1850404]: 2026/10/29 09:27:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 09:27:11 evo-x2 gatus[1850404]: 2026/10/29 09:27:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 09:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:34:09 evo-x2 memory-emergency-guard-check[3947497]: MEMORY EMERGENCY IO-PAUSE (trip #4628, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 09:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 509ms CPU time over 559ms wall clock time, 11.8M memory peak, 336K read from disk, 19.7M written to disk.
Oct 29 09:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:39:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:40:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:41:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:41:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:42:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:43:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:43:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:44:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:44:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:45:15 evo-x2 memory-emergency-guard-check[4085365]: MEMORY EMERGENCY IO-PAUSE (trip #4629, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 09:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:45:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 555ms wall clock time, 10.4M memory peak, 11.2M written to disk.
Oct 29 09:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:46:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:47:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:48:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:49:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:51:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:52:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:53:49 evo-x2 memory-emergency-guard-check[4191589]: MEMORY EMERGENCY IO-PAUSE (trip #4630, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 09:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 992ms wall clock time, 12.1M memory peak, 5.3M read from disk, 41.5M written to disk.
Oct 29 09:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:56:52 evo-x2 memory-emergency-guard-check[37771]: MEMORY EMERGENCY IO-PAUSE (trip #4631, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 09:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:56:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 519ms CPU time over 3.152s wall clock time, 12.9M memory peak, 1.2M read from disk, 30.1M written to disk.
Oct 29 09:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 09:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:00:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:00:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:01:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:01:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:02:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:02:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:03:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:04:30 evo-x2 memory-emergency-guard-check[122952]: MEMORY EMERGENCY IO-PAUSE (trip #4632, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 10:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:04:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 9.071s wall clock time, 11.5M memory peak, 36.5M read from disk, 34.1M written to disk.
Oct 29 10:04:52 evo-x2 memory-emergency-guard-check[135351]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.88% sustained (max disk busy 29.2%, MemAvailable=40.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 10:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:05:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:05:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:06:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:06:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:07:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:09:11 evo-x2 gatus[1850404]: 2026/10/29 10:09:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 10:09:11 evo-x2 gatus[1850404]: 2026/10/29 10:09:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 10:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:09:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:14:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:14:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:15:26 evo-x2 memory-emergency-guard-check[250545]: MEMORY EMERGENCY IO-PAUSE (trip #4633, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 10:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:15:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 457ms CPU time over 506ms wall clock time, 11.3M memory peak, 16K read from disk, 12.5M written to disk.
Oct 29 10:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:18:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:29:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:29:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:30:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:31:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:32:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:35:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:36:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:37:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:37:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:38:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:38:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:39:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:39:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:40:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:40:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:41:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:41:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:42:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:42:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:43:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:43:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:44:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:44:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:45:07 evo-x2 memory-emergency-guard-check[586934]: MEMORY EMERGENCY IO-PAUSE (trip #4634, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 10:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 492ms CPU time over 536ms wall clock time, 11.3M memory peak, 48K read from disk, 16.2M written to disk.
Oct 29 10:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:46:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:49:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:49:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:50:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:50:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:51:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:51:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:53:39 evo-x2 memory-emergency-guard-check[689966]: MEMORY EMERGENCY IO-PAUSE (trip #4635, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 10:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 538ms CPU time over 589ms wall clock time, 11.6M memory peak, 384K read from disk, 23.7M written to disk.
Oct 29 10:54:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:55:09 evo-x2 memory-emergency-guard-check[717149]: MEMORY EMERGENCY still active (I/O PSI some avg60=86.20% sustained (max disk busy 22.2%, MemAvailable=40.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 10:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:56:39 evo-x2 memory-emergency-guard-check[735964]: MEMORY EMERGENCY IO-PAUSE (trip #4636, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 10:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:56:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 536ms CPU time over 575ms wall clock time, 11.6M memory peak, 18.2M written to disk.
Oct 29 10:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:58:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 10:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:05:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:10:17 evo-x2 memory-emergency-guard-check[903271]: MEMORY EMERGENCY IO-PAUSE (trip #4637, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 498ms CPU time over 555ms wall clock time, 11.5M memory peak, 16.6M written to disk.
Oct 29 11:10:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:14:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:14:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:15:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:15:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:16:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:16:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:18:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:19:20 evo-x2 memory-emergency-guard-check[1015736]: MEMORY EMERGENCY IO-PAUSE (trip #4638, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 757ms wall clock time, 9.8M memory peak, 2M read from disk, 28.8M written to disk.
Oct 29 11:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:20:20 evo-x2 memory-emergency-guard-check[1041966]: MEMORY EMERGENCY still active (I/O PSI some avg60=66.35% sustained (max disk busy 22.1%, MemAvailable=41.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 11:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:21:52 evo-x2 memory-emergency-guard-check[1068186]: MEMORY EMERGENCY IO-PAUSE (trip #4639, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:21:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 753ms wall clock time, 11M memory peak, 6.8M read from disk, 41.1M written to disk.
Oct 29 11:22:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:22:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:24:24 evo-x2 memory-emergency-guard-check[1262510]: MEMORY EMERGENCY IO-PAUSE (trip #4640, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:24:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.021s CPU time over 2.689s wall clock time, 8.1M memory peak, 20.3M read from disk, 16.1M written to disk.
Oct 29 11:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:25:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:26:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:26:56 evo-x2 memory-emergency-guard-check[1429274]: MEMORY EMERGENCY IO-PAUSE (trip #4641, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:26:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.385s CPU time over 3.269s wall clock time, 7.9M memory peak, 27M read from disk, 33.8M written to disk.
Oct 29 11:27:11 evo-x2 gatus[1850404]: 2026/10/29 11:27:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 11:27:11 evo-x2 gatus[1850404]: 2026/10/29 11:27:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 11:27:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:27:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:28:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:28:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:29:24 evo-x2 memory-emergency-guard-check[1612900]: MEMORY EMERGENCY IO-PAUSE (trip #4642, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 981ms CPU time over 1.991s wall clock time, 8.3M memory peak, 38.3M read from disk, 39.4M written to disk.
Oct 29 11:29:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:30:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:30:53 evo-x2 memory-emergency-guard-check[1688861]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.87% sustained (max disk busy 65.5%, MemAvailable=36.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 11:30:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:31:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:31:55 evo-x2 memory-emergency-guard-check[1743681]: MEMORY EMERGENCY IO-PAUSE (trip #4643, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:31:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 918ms CPU time over 1.285s wall clock time, 8.7M memory peak, 10.3M read from disk, 40.5M written to disk.
Oct 29 11:32:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:32:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:33:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:33:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:34:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:34:56 evo-x2 memory-emergency-guard-check[1837484]: MEMORY EMERGENCY IO-PAUSE (trip #4644, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:34:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.025s CPU time over 1.987s wall clock time, 8M memory peak, 7.1M read from disk, 31.7M written to disk.
Oct 29 11:35:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:35:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:36:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:36:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:37:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:37:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:38:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:39:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:40:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:40:57 evo-x2 memory-emergency-guard-check[2010925]: MEMORY EMERGENCY IO-PAUSE (trip #4645, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:40:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 807ms CPU time over 1.236s wall clock time, 8.3M memory peak, 11.8M read from disk, 37.5M written to disk.
Oct 29 11:41:26 evo-x2 memory-emergency-guard-check[2030050]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.89% sustained (max disk busy 78.4%, MemAvailable=41.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 11:41:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 165ms CPU time over 220ms wall clock time, 7.5M memory peak, 3.8M read from disk, 4K written to disk.
Oct 29 11:42:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:43:28 evo-x2 memory-emergency-guard-check[2103162]: MEMORY EMERGENCY IO-PAUSE (trip #4646, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:43:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 999ms CPU time over 1.474s wall clock time, 9.1M memory peak, 14.2M read from disk, 43.1M written to disk.
Oct 29 11:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:43:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 166ms wall clock time, 7.8M memory peak, 3.8M read from disk, 4K written to disk.
Oct 29 11:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 167ms wall clock time, 8M memory peak, 3.8M read from disk, 4K written to disk.
Oct 29 11:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 138ms CPU time over 220ms wall clock time, 5.8M memory peak, 1.8M read from disk, 4K written to disk.
Oct 29 11:45:59 evo-x2 memory-emergency-guard-check[2173703]: MEMORY EMERGENCY IO-PAUSE (trip #4647, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:45:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 677ms CPU time over 1.095s wall clock time, 9.2M memory peak, 13.4M read from disk, 30M written to disk.
Oct 29 11:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 174ms CPU time over 289ms wall clock time, 5M memory peak, 1.4M read from disk, 4K written to disk.
Oct 29 11:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:48:31 evo-x2 memory-emergency-guard-check[2367585]: MEMORY EMERGENCY IO-PAUSE (trip #4648, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:48:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.254s CPU time over 2.220s wall clock time, 8.1M memory peak, 18.5M read from disk, 45.7M written to disk.
Oct 29 11:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:49:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:51:01 evo-x2 memory-emergency-guard-check[2491940]: MEMORY EMERGENCY IO-PAUSE (trip #4649, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 11:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.166s CPU time over 1.722s wall clock time, 8.9M memory peak, 22.5M read from disk, 48.7M written to disk.
Oct 29 11:51:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:52:30 evo-x2 memory-emergency-guard-check[2546923]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.49% sustained (max disk busy 26.8%, MemAvailable=28.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 11:52:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:53:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:53:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:54:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:54:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:55:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:55:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:56:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:57:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:58:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 11:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:00:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:00:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:01:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 259ms CPU time over 445ms wall clock time, 5.3M memory peak, 1M read from disk, 4K written to disk.
Oct 29 12:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 221ms CPU time over 406ms wall clock time, 5.2M memory peak, 1M read from disk, 4K written to disk.
Oct 29 12:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 219ms CPU time over 470ms wall clock time, 8.4M memory peak, 3M read from disk, 4K written to disk.
Oct 29 12:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 210ms CPU time over 511ms wall clock time, 7.9M memory peak, 2.2M read from disk, 4K written to disk.
Oct 29 12:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:07:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:08:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:11:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:13:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:15:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:18:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:20:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:20:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:21:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:21:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:22:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:22:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 215ms CPU time over 311ms wall clock time, 6.6M memory peak, 2.2M read from disk, 4K written to disk.
Oct 29 12:22:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:23:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:23:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:24:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:24:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:25:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:25:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:26:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:26:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:27:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:27:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:28:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:28:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:29:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:29:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:30:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:30:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:31:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:31:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:34:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:39:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:41:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:44:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:45:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:46:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:46:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:48:41 evo-x2 memory-emergency-guard-check[4129867]: MEMORY EMERGENCY: MemAvailable=6.7% AND zram=92.5% (shmem-unevictable trap: model pages cannot evict with full zram) — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 29 12:48:42 evo-x2 memory-emergency-guard-check[4129867]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4650, zone 2) — top io since last trip: system.slice/io.stat +163198MB, system.slice/nix-daemon.service/io.stat +78927MB, system.slice/forgejo.service/io.stat +27942MB
Oct 29 12:49:45 evo-x2 memory-emergency-guard-check[4129867]: MEMORY EMERGENCY io drained (io PSI some avg60=36.14% < 40%) — churn units re-armed (re-arm #546)
Oct 29 12:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 1min 4.276s wall clock time, 10.9M memory peak, 6.7M read from disk, 3.8M written to disk.
Oct 29 12:49:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:49:52 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 2 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 12:50:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:50:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:51:16 evo-x2 memory-emergency-guard-check[4174831]: MEMORY EMERGENCY IO-PAUSE (trip #4651, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 12:51:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:51:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 813ms CPU time over 1.013s wall clock time, 9.5M memory peak, 6.7M read from disk, 17.6M written to disk.
Oct 29 12:51:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:52:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:52:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:53:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:53:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:54:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:54:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:55:11 evo-x2 gatus[1850404]: 2026/10/29 12:55:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 12:55:11 evo-x2 gatus[1850404]: 2026/10/29 12:55:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Emergency Guard with description='Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers AND sustained io PSI drains below the restore bar (restoreIoSomeAvg60ThresholdPercent, 20); until then LLM clients get connection-refused by design. If memory_emergency_guard_churn_mode is 1 this alert is SUPPRESSED (see 'Memory Guard Trip Churn'). Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)' has been TRIGGERED
Oct 29 12:55:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:55:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:56:18 evo-x2 memory-emergency-guard-check[82129]: MEMORY EMERGENCY IO-PAUSE (trip #4652, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 12:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 791ms wall clock time, 10.5M memory peak, 12.3M read from disk, 28.8M written to disk.
Oct 29 12:56:47 evo-x2 memory-emergency-guard-check[114734]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.25% sustained (max disk busy 21.5%, MemAvailable=23.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 12:56:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:57:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:57:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:58:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:58:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:59:20 evo-x2 memory-emergency-guard-check[217090]: MEMORY EMERGENCY IO-PAUSE (trip #4653, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 12:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 12:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 2.337s wall clock time, 11M memory peak, 47.3M read from disk, 78.7M written to disk.
Oct 29 12:59:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:00:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:00:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:01:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:01:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:02:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:03:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:03:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:04:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:04:50 evo-x2 memory-emergency-guard-check[310284]: MEMORY EMERGENCY IO-PAUSE (trip #4654, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:04:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 558ms CPU time over 635ms wall clock time, 10.6M memory peak, 272K read from disk, 11.1M written to disk.
Oct 29 13:05:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:05:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:06:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:06:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:07:20 evo-x2 memory-emergency-guard-check[405096]: MEMORY EMERGENCY IO-PAUSE (trip #4655, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:07:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 532ms CPU time over 636ms wall clock time, 11M memory peak, 1008K read from disk, 22.2M written to disk.
Oct 29 13:07:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:08:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:08:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:09:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:09:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:10:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:10:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:11:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:12:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:12:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:13:11 evo-x2 gatus[1850404]: 2026/10/29 13:13:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 13:13:11 evo-x2 gatus[1850404]: 2026/10/29 13:13:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 13:13:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:13:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:14:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:14:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:15:21 evo-x2 memory-emergency-guard-check[539368]: MEMORY EMERGENCY IO-PAUSE (trip #4656, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:15:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 538ms CPU time over 1.151s wall clock time, 11.2M memory peak, 992K read from disk, 23.3M written to disk.
Oct 29 13:15:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:16:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:16:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:17:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:17:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:18:22 evo-x2 memory-emergency-guard-check[669171]: MEMORY EMERGENCY IO-PAUSE (trip #4657, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:18:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 939ms CPU time over 1.355s wall clock time, 9.5M memory peak, 8.1M read from disk, 30.6M written to disk.
Oct 29 13:18:51 evo-x2 memory-emergency-guard-check[691650]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.04% sustained (max disk busy 64.6%, MemAvailable=40.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 13:18:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:19:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:19:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:20:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:20:52 evo-x2 memory-emergency-guard-check[723071]: MEMORY EMERGENCY IO-PAUSE (trip #4658, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:20:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 583ms CPU time over 687ms wall clock time, 11.5M memory peak, 2.1M read from disk, 34M written to disk.
Oct 29 13:21:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:21:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:22:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:22:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:23:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:23:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:24:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:24:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:25:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:25:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:26:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:27:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:27:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:28:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:30:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:31:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:34:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:35:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:35:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:36:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:38:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:40:31 evo-x2 memory-emergency-guard-check[981339]: MEMORY EMERGENCY IO-PAUSE (trip #4659, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 13:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:40:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 703ms wall clock time, 11.6M memory peak, 2.3M read from disk, 35.7M written to disk.
Oct 29 13:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:41:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:42:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:43:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:46:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:46:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:48:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:48:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:49:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:49:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:50:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:50:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:51:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:51:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:54:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:56:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:57:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:57:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:58:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 13:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:01:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:02:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:03:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:06:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:07:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:08:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:09:41 evo-x2 memory-emergency-guard-check[1369392]: MEMORY EMERGENCY IO-PAUSE (trip #4660, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:09:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 711ms wall clock time, 10.9M memory peak, 3.8M read from disk, 40.8M written to disk.
Oct 29 14:10:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:11:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:11:41 evo-x2 memory-emergency-guard-check[1400129]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.06% sustained (max disk busy 22.3%, MemAvailable=40.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 14:11:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:13:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:13:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:15:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:15:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:16:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:16:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:17:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:19:17 evo-x2 memory-emergency-guard-check[1510873]: MEMORY EMERGENCY IO-PAUSE (trip #4661, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 820ms CPU time over 1.511s wall clock time, 9.5M memory peak, 14.7M read from disk, 57.3M written to disk.
Oct 29 14:19:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:20:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:21:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:22:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:23:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:23:50 evo-x2 memory-emergency-guard-check[1617647]: MEMORY EMERGENCY IO-PAUSE (trip #4662, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 658ms CPU time over 996ms wall clock time, 14.3M memory peak, 23.2M read from disk, 48.2M written to disk.
Oct 29 14:24:19 evo-x2 memory-emergency-guard-check[1676571]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.19% sustained (max disk busy 69.8%, MemAvailable=38.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 14:24:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:24:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:25:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:25:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:26:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:26:50 evo-x2 memory-emergency-guard-check[1767527]: MEMORY EMERGENCY IO-PAUSE (trip #4663, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:26:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 559ms CPU time over 626ms wall clock time, 14.8M memory peak, 2.3M read from disk, 23.8M written to disk.
Oct 29 14:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:28:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:29:21 evo-x2 memory-emergency-guard-check[1826372]: MEMORY EMERGENCY IO-PAUSE (trip #4664, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:29:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 1.087s wall clock time, 10.6M memory peak, 12.5M read from disk, 48.7M written to disk.
Oct 29 14:29:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:30:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:31:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:33:53 evo-x2 memory-emergency-guard-check[2041385]: MEMORY EMERGENCY IO-PAUSE (trip #4665, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:33:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 705ms CPU time over 1.004s wall clock time, 11.7M memory peak, 8M read from disk, 46.5M written to disk.
Oct 29 14:34:23 evo-x2 memory-emergency-guard-check[2070989]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.67% sustained (max disk busy 23.4%, MemAvailable=36.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 14:34:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:34:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:35:11 evo-x2 gatus[1850404]: 2026/10/29 14:35:11 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 14:35:11 evo-x2 gatus[1850404]: 2026/10/29 14:35:11 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Trip Churn with description='Memory guard TRIP CHURN (>=6 trips in the last hour — the 2026-09-14 Zone 6 storm class; per-trip Discord pings are suppressed while this is active, this is the ONLY storm alert): a repeating trip→restore→re-trip loop is burning the restore budget and the machine is in a sustained storm. This is one message for the whole storm, NOT one per trip. Check, in order: (1) memory_emergency_guard_zone_trips_last_hour — which zone dominates; (2) the guard's per-trip io.stat attribution lines: journalctl -u memory-emergency-guard --since -2h | grep 'top io'; (3) whether the sev1 desktop notify-tier churn context actually fired: journalctl -u sev1-bridge --since -2h | grep -i churn (it gates at >=2 trips/hour — if absent, the bridge is dead and Discord is the only channel); (4) restore state: memory_emergency_guard_restore_capped / trips_last_hour. Do NOT chase individual trips — shed the driver load the io.stat lines name, or wait for the drain (churn_mode returns to 0 and this alert resolves).' has been TRIGGERED
Oct 29 14:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:36:24 evo-x2 memory-emergency-guard-check[2178170]: MEMORY EMERGENCY IO-PAUSE (trip #4666, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:36:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 855ms CPU time over 1.250s wall clock time, 8.9M memory peak, 1M read from disk, 28.9M written to disk.
Oct 29 14:36:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:37:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:38:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:38:55 evo-x2 memory-emergency-guard-check[2320965]: MEMORY EMERGENCY IO-PAUSE (trip #4667, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:38:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 667ms CPU time over 880ms wall clock time, 9.4M memory peak, 2.3M read from disk, 26.6M written to disk.
Oct 29 14:39:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:39:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:39:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 146ms wall clock time, 8.8M memory peak, 1.5M read from disk, 4K written to disk.
Oct 29 14:40:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:41:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 174ms wall clock time, 11.1M memory peak, 4.2M read from disk, 4K written to disk.
Oct 29 14:42:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:42:57 evo-x2 memory-emergency-guard-check[2490482]: MEMORY EMERGENCY IO-PAUSE (trip #4668, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:42:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 549ms CPU time over 646ms wall clock time, 11.4M memory peak, 1.1M read from disk, 25.7M written to disk.
Oct 29 14:43:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:44:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:44:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:45:27 evo-x2 memory-emergency-guard-check[2540559]: MEMORY EMERGENCY IO-PAUSE (trip #4669, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:45:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 544ms CPU time over 740ms wall clock time, 10.9M memory peak, 3.4M read from disk, 34.8M written to disk.
Oct 29 14:45:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:46:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:47:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:47:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:48:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:48:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:51:01 evo-x2 memory-emergency-guard-check[2607393]: MEMORY EMERGENCY IO-PAUSE (trip #4670, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:51:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 533ms CPU time over 581ms wall clock time, 10.3M memory peak, 320K read from disk, 18M written to disk.
Oct 29 14:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:53:02 evo-x2 memory-emergency-guard-check[2634221]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.68% sustained (max disk busy 27.6%, MemAvailable=41.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 14:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:53:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 103ms CPU time over 183ms wall clock time, 8.1M memory peak, 1.3M read from disk, 4K written to disk.
Oct 29 14:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:55:03 evo-x2 memory-emergency-guard-check[2660450]: MEMORY EMERGENCY IO-PAUSE (trip #4671, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 14:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:55:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 675ms wall clock time, 10.9M memory peak, 1.9M read from disk, 30.6M written to disk.
Oct 29 14:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:56:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:56:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:57:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:57:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:58:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:58:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:59:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 14:59:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:00:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:00:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:01:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:01:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:02:36 evo-x2 memory-emergency-guard-check[2787800]: MEMORY EMERGENCY IO-PAUSE (trip #4672, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:02:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 765ms CPU time over 931ms wall clock time, 9.5M memory peak, 3.9M read from disk, 20.5M written to disk.
Oct 29 15:03:06 evo-x2 memory-emergency-guard-check[2800234]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.17% sustained (max disk busy 82.9%, MemAvailable=25.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 15:03:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:03:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:04:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:05:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:05:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:06:07 evo-x2 memory-emergency-guard-check[2866022]: MEMORY EMERGENCY IO-PAUSE (trip #4673, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:06:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 778ms wall clock time, 10.8M memory peak, 9.8M read from disk, 24.6M written to disk.
Oct 29 15:06:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:07:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:07:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:08:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:08:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:09:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:09:39 evo-x2 memory-emergency-guard-check[2948252]: MEMORY EMERGENCY IO-PAUSE (trip #4674, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:09:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 510ms CPU time over 1.103s wall clock time, 10.9M memory peak, 2.6M read from disk, 22.7M written to disk.
Oct 29 15:10:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:10:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:11:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:11:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:12:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:12:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:13:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:13:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:14:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:14:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:15:10 evo-x2 memory-emergency-guard-check[3028630]: MEMORY EMERGENCY IO-PAUSE (trip #4675, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:15:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 505ms CPU time over 590ms wall clock time, 9.5M memory peak, 912K read from disk, 13.1M written to disk.
Oct 29 15:15:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:16:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:16:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:17:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:17:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:18:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:18:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:19:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:19:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:20:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:20:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:21:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:21:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:22:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:22:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:23:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:23:44 evo-x2 memory-emergency-guard-check[3126521]: MEMORY EMERGENCY IO-PAUSE (trip #4676, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 597ms wall clock time, 11M memory peak, 1.5M read from disk, 20.1M written to disk.
Oct 29 15:24:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:24:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:25:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:25:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:26:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:26:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:27:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:27:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:28:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:28:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:29:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:29:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:30:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:31:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:31:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:32:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:32:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:33:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:33:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:35:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:35:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:36:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:36:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:37:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:37:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:38:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:38:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:39:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:39:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:40:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:40:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:41:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:41:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:42:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:42:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:43:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:43:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:44:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:45:20 evo-x2 memory-emergency-guard-check[3349681]: MEMORY EMERGENCY IO-PAUSE (trip #4677, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:45:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 480ms CPU time over 570ms wall clock time, 10.4M memory peak, 64K read from disk, 6.1M written to disk.
Oct 29 15:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:46:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:47:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:47:51 evo-x2 memory-emergency-guard-check[3385553]: MEMORY EMERGENCY IO-PAUSE (trip #4678, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:47:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 905ms CPU time over 1.671s wall clock time, 8.2M memory peak, 5M read from disk, 37.1M written to disk.
Oct 29 15:48:20 evo-x2 memory-emergency-guard-check[3398718]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.09% sustained (max disk busy 89.0%, MemAvailable=39.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 15:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:48:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:49:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:50:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:50:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:51:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:51:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:52:22 evo-x2 memory-emergency-guard-check[3475636]: MEMORY EMERGENCY IO-PAUSE (trip #4679, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:52:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 577ms CPU time over 766ms wall clock time, 11.5M memory peak, 7.5M read from disk, 43.6M written to disk.
Oct 29 15:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:54:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:54:52 evo-x2 memory-emergency-guard-check[3515177]: MEMORY EMERGENCY IO-PAUSE (trip #4680, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:54:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 521ms CPU time over 603ms wall clock time, 10.7M memory peak, 464K read from disk, 20.2M written to disk.
Oct 29 15:55:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:57:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:58:55 evo-x2 memory-emergency-guard-check[3637244]: MEMORY EMERGENCY IO-PAUSE (trip #4681, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 15:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:58:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 665ms CPU time over 889ms wall clock time, 9.4M memory peak, 5.1M read from disk, 40.5M written to disk.
Oct 29 15:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 15:59:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:00:25 evo-x2 memory-emergency-guard-check[3666858]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.32% sustained (max disk busy 31.6%, MemAvailable=38.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:00:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:01:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:03:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:04:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:04:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:05:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:06:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:06:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:07:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:07:31 evo-x2 memory-emergency-guard-check[3884746]: MEMORY EMERGENCY IO-PAUSE (trip #4682, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:07:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 718ms wall clock time, 10.9M memory peak, 2.1M read from disk, 36.4M written to disk.
Oct 29 16:08:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:08:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:09:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:09:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:10:03 evo-x2 memory-emergency-guard-check[3938165]: MEMORY EMERGENCY IO-PAUSE (trip #4683, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 716ms CPU time over 1.242s wall clock time, 10.3M memory peak, 4.6M read from disk, 37.5M written to disk.
Oct 29 16:10:32 evo-x2 memory-emergency-guard-check[3971564]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.52% sustained (max disk busy 99.9%, MemAvailable=38.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:12:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:13:03 evo-x2 memory-emergency-guard-check[4031579]: MEMORY EMERGENCY IO-PAUSE (trip #4684, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:13:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 601ms CPU time over 755ms wall clock time, 10.7M memory peak, 3.3M read from disk, 48.7M written to disk.
Oct 29 16:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:14:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:15:35 evo-x2 memory-emergency-guard-check[4069647]: MEMORY EMERGENCY IO-PAUSE (trip #4685, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 530ms CPU time over 611ms wall clock time, 10.6M memory peak, 1.6M read from disk, 29.8M written to disk.
Oct 29 16:16:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:16:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:18:36 evo-x2 memory-emergency-guard-check[4109101]: MEMORY EMERGENCY IO-PAUSE (trip #4686, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 506ms CPU time over 563ms wall clock time, 10.9M memory peak, 240K read from disk, 17.6M written to disk.
Oct 29 16:19:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:20:36 evo-x2 memory-emergency-guard-check[4159422]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.32% sustained (max disk busy 38.9%, MemAvailable=39.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:22:07 evo-x2 memory-emergency-guard-check[11701]: MEMORY EMERGENCY IO-PAUSE (trip #4687, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 571ms CPU time over 977ms wall clock time, 10.8M memory peak, 1.6M read from disk, 36.7M written to disk.
Oct 29 16:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:25:08 evo-x2 memory-emergency-guard-check[57170]: MEMORY EMERGENCY IO-PAUSE (trip #4688, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 529ms CPU time over 754ms wall clock time, 9.9M memory peak, 304K read from disk, 18.2M written to disk.
Oct 29 16:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:28:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:29:39 evo-x2 memory-emergency-guard-check[194061]: MEMORY EMERGENCY IO-PAUSE (trip #4689, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 737ms wall clock time, 10.7M memory peak, 2.5M read from disk, 41.1M written to disk.
Oct 29 16:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:30:39 evo-x2 memory-emergency-guard-check[226390]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.79% sustained (max disk busy 24.3%, MemAvailable=39.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:32:11 evo-x2 memory-emergency-guard-check[285985]: MEMORY EMERGENCY IO-PAUSE (trip #4690, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:32:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 1.029s wall clock time, 11.5M memory peak, 24.1M read from disk, 67.3M written to disk.
Oct 29 16:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:33:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:34:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:35:11 evo-x2 memory-emergency-guard-check[366036]: MEMORY EMERGENCY IO-PAUSE (trip #4691, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 554ms CPU time over 629ms wall clock time, 12M memory peak, 480K read from disk, 21.8M written to disk.
Oct 29 16:35:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:37:42 evo-x2 memory-emergency-guard-check[421277]: MEMORY EMERGENCY IO-PAUSE (trip #4692, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:37:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 519ms CPU time over 564ms wall clock time, 10.8M memory peak, 368K read from disk, 19.6M written to disk.
Oct 29 16:38:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:38:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:39:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:40:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:41:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:41:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:42:47 evo-x2 memory-emergency-guard-check[517111]: MEMORY EMERGENCY IO-PAUSE (trip #4693, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 1.328s wall clock time, 10.3M memory peak, 3.8M read from disk, 36.3M written to disk.
Oct 29 16:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:43:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:44:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:44:46 evo-x2 memory-emergency-guard-check[565403]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.40% sustained (max disk busy 33.0%, MemAvailable=37.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:44:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:45:17 evo-x2 memory-emergency-guard-check[573616]: MEMORY EMERGENCY IO-PAUSE (trip #4694, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 542ms CPU time over 772ms wall clock time, 10.7M memory peak, 1.1M read from disk, 23.2M written to disk.
Oct 29 16:45:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:46:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:46:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:47:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:47:48 evo-x2 memory-emergency-guard-check[626561]: MEMORY EMERGENCY IO-PAUSE (trip #4695, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:47:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 563ms CPU time over 856ms wall clock time, 11.1M memory peak, 1.3M read from disk, 23.1M written to disk.
Oct 29 16:48:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:49:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:50:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:51:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:52:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:52:50 evo-x2 memory-emergency-guard-check[782734]: MEMORY EMERGENCY IO-PAUSE (trip #4696, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:52:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 809ms wall clock time, 10.8M memory peak, 13M read from disk, 38.2M written to disk.
Oct 29 16:53:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:53:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:54:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:54:50 evo-x2 memory-emergency-guard-check[874487]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.81% sustained (max disk busy 97.5%, MemAvailable=38.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 16:54:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:55:21 evo-x2 memory-emergency-guard-check[895605]: MEMORY EMERGENCY IO-PAUSE (trip #4697, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 937ms wall clock time, 11M memory peak, 21.5M read from disk, 11.8M written to disk.
Oct 29 16:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:56:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:56:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:57:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:57:52 evo-x2 memory-emergency-guard-check[965633]: MEMORY EMERGENCY IO-PAUSE (trip #4698, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 16:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:57:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 840ms wall clock time, 10.9M memory peak, 13.3M read from disk, 49.5M written to disk.
Oct 29 16:58:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:58:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:59:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 16:59:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:00:23 evo-x2 memory-emergency-guard-check[1025216]: MEMORY EMERGENCY IO-PAUSE (trip #4699, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 692ms CPU time over 1.033s wall clock time, 11.2M memory peak, 11.7M read from disk, 56.3M written to disk.
Oct 29 17:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:02:53 evo-x2 memory-emergency-guard-check[1154477]: MEMORY EMERGENCY IO-PAUSE (trip #4700, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:02:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 713ms CPU time over 1.393s wall clock time, 11.3M memory peak, 38.1M read from disk, 42.5M written to disk.
Oct 29 17:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:04:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:05:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:07:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:09:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:09:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:10:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:10:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:11:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:11:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:12:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:12:56 evo-x2 memory-emergency-guard-check[1372920]: MEMORY EMERGENCY IO-PAUSE (trip #4701, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:12:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 636ms wall clock time, 11M memory peak, 896K read from disk, 32.9M written to disk.
Oct 29 17:13:26 evo-x2 memory-emergency-guard-check[1382162]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.53% sustained (max disk busy 83.2%, MemAvailable=39.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 17:13:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:14:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:15:27 evo-x2 memory-emergency-guard-check[1448956]: MEMORY EMERGENCY IO-PAUSE (trip #4702, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 703ms wall clock time, 10.2M memory peak, 464K read from disk, 19.5M written to disk.
Oct 29 17:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:18:59 evo-x2 memory-emergency-guard-check[1564677]: MEMORY EMERGENCY IO-PAUSE (trip #4703, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 517ms CPU time over 643ms wall clock time, 10.5M memory peak, 128K read from disk, 10.3M written to disk.
Oct 29 17:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:20:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:21:29 evo-x2 memory-emergency-guard-check[1640386]: MEMORY EMERGENCY IO-PAUSE (trip #4704, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:21:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 523ms CPU time over 722ms wall clock time, 10.7M memory peak, 288K read from disk, 18.5M written to disk.
Oct 29 17:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:22:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:22:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:23:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:24:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:24:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:28:31 evo-x2 memory-emergency-guard-check[1738286]: MEMORY EMERGENCY IO-PAUSE (trip #4705, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:28:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 541ms CPU time over 793ms wall clock time, 11.7M memory peak, 784K read from disk, 25.6M written to disk.
Oct 29 17:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:30:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:32:33 evo-x2 memory-emergency-guard-check[1852246]: MEMORY EMERGENCY IO-PAUSE (trip #4706, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:32:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 560ms CPU time over 733ms wall clock time, 11.3M memory peak, 10.2M read from disk, 28.4M written to disk.
Oct 29 17:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:34:32 evo-x2 memory-emergency-guard-check[1899155]: MEMORY EMERGENCY still active (I/O PSI some avg60=78.95% sustained (max disk busy 44.6%, MemAvailable=39.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 17:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:35:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:35:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:36:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:36:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:37:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:37:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:38:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:38:35 evo-x2 memory-emergency-guard-check[1955885]: MEMORY EMERGENCY IO-PAUSE (trip #4707, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 478ms CPU time over 556ms wall clock time, 10.5M memory peak, 384K read from disk, 9.1M written to disk.
Oct 29 17:39:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:39:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:40:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:40:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:41:36 evo-x2 memory-emergency-guard-check[2014695]: MEMORY EMERGENCY IO-PAUSE (trip #4708, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:41:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 610ms CPU time over 730ms wall clock time, 9.9M memory peak, 1.6M read from disk, 19.9M written to disk.
Oct 29 17:42:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:42:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:43:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:44:08 evo-x2 memory-emergency-guard-check[2195190]: MEMORY EMERGENCY IO-PAUSE (trip #4709, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:44:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 1.033s wall clock time, 9.1M memory peak, 6.4M read from disk, 32.9M written to disk.
Oct 29 17:44:37 evo-x2 memory-emergency-guard-check[2220801]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.49% sustained (max disk busy 100.0%, MemAvailable=36.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 17:44:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:45:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:45:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:46:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:46:38 evo-x2 memory-emergency-guard-check[2288707]: MEMORY EMERGENCY IO-PAUSE (trip #4710, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:46:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 886ms wall clock time, 10.8M memory peak, 17M read from disk, 34.6M written to disk.
Oct 29 17:47:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:48:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:48:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:49:09 evo-x2 memory-emergency-guard-check[2351829]: MEMORY EMERGENCY IO-PAUSE (trip #4711, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:49:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 650ms CPU time over 868ms wall clock time, 11.1M memory peak, 6.5M read from disk, 38M written to disk.
Oct 29 17:49:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:50:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:50:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:51:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:51:40 evo-x2 memory-emergency-guard-check[2413815]: MEMORY EMERGENCY IO-PAUSE (trip #4712, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:51:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.110s CPU time over 1.511s wall clock time, 8.4M memory peak, 2.4M read from disk, 28.2M written to disk.
Oct 29 17:52:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:52:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:53:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:53:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:54:10 evo-x2 memory-emergency-guard-check[2476366]: MEMORY EMERGENCY IO-PAUSE (trip #4713, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:54:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 964ms wall clock time, 9.7M memory peak, 2.4M read from disk, 27.9M written to disk.
Oct 29 17:54:39 evo-x2 memory-emergency-guard-check[2509973]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.35% sustained (max disk busy 77.7%, MemAvailable=33.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 17:54:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:55:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:55:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:56:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:56:43 evo-x2 memory-emergency-guard-check[2572668]: sort: write failed: 'standard output': Broken pipe
Oct 29 17:56:43 evo-x2 memory-emergency-guard-check[2572668]: sort: write error
Oct 29 17:56:43 evo-x2 memory-emergency-guard-check[2566080]: MEMORY EMERGENCY IO-PAUSE (trip #4714, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:56:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.022s CPU time over 4.145s wall clock time, 10.1M memory peak, 53.9M read from disk, 75.1M written to disk.
Oct 29 17:57:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:57:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:58:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:58:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:59:10 evo-x2 memory-emergency-guard-check[2682993]: MEMORY EMERGENCY IO-PAUSE (trip #4715, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 17:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 17:59:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 1.045s wall clock time, 10.4M memory peak, 29.6M read from disk, 54.2M written to disk.
Oct 29 17:59:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:00:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:00:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:01:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:01:42 evo-x2 memory-emergency-guard-check[2751777]: MEMORY EMERGENCY IO-PAUSE (trip #4716, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 1.353s wall clock time, 11M memory peak, 23.7M read from disk, 53.7M written to disk.
Oct 29 18:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:04:13 evo-x2 memory-emergency-guard-check[2858651]: MEMORY EMERGENCY IO-PAUSE (trip #4717, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 605ms CPU time over 700ms wall clock time, 10.8M memory peak, 3.1M read from disk, 27.2M written to disk.
Oct 29 18:04:43 evo-x2 memory-emergency-guard-check[2880659]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.73% sustained (max disk busy 28.6%, MemAvailable=32.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:04:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:05:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:05:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:06:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:06:45 evo-x2 memory-emergency-guard-check[2984588]: MEMORY EMERGENCY IO-PAUSE (trip #4718, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 812ms wall clock time, 9.6M memory peak, 1.7M read from disk, 21.9M written to disk.
Oct 29 18:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:07:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:07:54 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 18 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=7.21%, MemAvailable=17.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 18:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:09:18 evo-x2 memory-emergency-guard-check[3158260]: MEMORY EMERGENCY IO-PAUSE (trip #4719, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:09:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:09:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.092s CPU time over 2.582s wall clock time, 8.7M memory peak, 36.1M read from disk, 17.6M written to disk.
Oct 29 18:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 218ms CPU time over 427ms wall clock time, 6.1M memory peak, 1.4M read from disk, 4K written to disk.
Oct 29 18:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:14:46 evo-x2 memory-emergency-guard-check[3382043]: MEMORY EMERGENCY still active (MemAvailable=1.8% below absolute floor) but action cooldown active (330s < 600s, 270s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:14:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:15:17 evo-x2 memory-emergency-guard-check[3391478]: MEMORY EMERGENCY IO-PAUSE (trip #4720, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:15:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 1.021s wall clock time, 10M memory peak, 11.9M read from disk, 27.2M written to disk.
Oct 29 18:15:26 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 19 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 18:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:16:14 evo-x2 gatus[1850404]: 2026/10/29 18:16:14 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 29 18:16:14 evo-x2 gatus[1850404]: 2026/10/29 18:16:14 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 29 18:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:17:57 evo-x2 memory-emergency-guard-check[3497256]: MEMORY EMERGENCY IO-PAUSE (trip #4721, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:17:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.027s CPU time over 10.910s wall clock time, 9M memory peak, 34.6M read from disk, 10M written to disk.
Oct 29 18:18:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:18:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:19:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:20:22 evo-x2 memory-emergency-guard-check[3608373]: MEMORY EMERGENCY IO-PAUSE (trip #4722, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:20:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 918ms CPU time over 4.480s wall clock time, 10.6M memory peak, 16.7M read from disk, 46.2M written to disk.
Oct 29 18:20:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:21:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:21:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:22:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:22:57 evo-x2 memory-emergency-guard-check[3761977]: MEMORY EMERGENCY IO-PAUSE (trip #4723, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.212s CPU time over 9.254s wall clock time, 10.8M memory peak, 46.9M read from disk, 62.8M written to disk.
Oct 29 18:23:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:23:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:24:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:24:48 evo-x2 memory-emergency-guard-check[3884208]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.29% sustained (max disk busy 100.0%, MemAvailable=28.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:24:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:25:22 evo-x2 memory-emergency-guard-check[3916557]: MEMORY EMERGENCY IO-PAUSE (trip #4724, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:25:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 4.012s wall clock time, 9.7M memory peak, 18.2M read from disk, 61.9M written to disk.
Oct 29 18:25:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:26:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:26:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:27:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:27:50 evo-x2 memory-emergency-guard-check[4049592]: MEMORY EMERGENCY IO-PAUSE (trip #4725, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 600ms CPU time over 1.786s wall clock time, 9.9M memory peak, 3.9M read from disk, 36M written to disk.
Oct 29 18:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:28:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:29:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:29:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:30:22 evo-x2 memory-emergency-guard-check[4098111]: MEMORY EMERGENCY IO-PAUSE (trip #4726, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 867ms CPU time over 2.478s wall clock time, 9.9M memory peak, 16M read from disk, 33.7M written to disk.
Oct 29 18:30:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:31:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:31:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:32:56 evo-x2 memory-emergency-guard-check[4179483]: MEMORY EMERGENCY IO-PAUSE (trip #4727, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:32:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 636ms CPU time over 4.526s wall clock time, 10.4M memory peak, 16M read from disk, 34.7M written to disk.
Oct 29 18:33:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:34:52 evo-x2 memory-emergency-guard-check[50691]: MEMORY EMERGENCY still active (I/O PSI some avg60=57.42% sustained (max disk busy 34.9%, MemAvailable=18.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (121s < 150s, 29s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:35:23 evo-x2 memory-emergency-guard-check[63008]: MEMORY EMERGENCY IO-PAUSE (trip #4728, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:35:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 573ms CPU time over 671ms wall clock time, 10.1M memory peak, 4.8M read from disk, 24M written to disk.
Oct 29 18:35:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:37:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:37:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:38:26 evo-x2 memory-emergency-guard-check[153472]: MEMORY EMERGENCY IO-PAUSE (trip #4729, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 915ms CPU time over 2.360s wall clock time, 8.8M memory peak, 10.8M read from disk, 27.7M written to disk.
Oct 29 18:38:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:39:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:39:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:40:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:40:55 evo-x2 memory-emergency-guard-check[194846]: MEMORY EMERGENCY IO-PAUSE (trip #4730, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:40:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 829ms CPU time over 967ms wall clock time, 10.4M memory peak, 2.9M read from disk, 21.8M written to disk.
Oct 29 18:41:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:41:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:42:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:42:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:43:26 evo-x2 memory-emergency-guard-check[286379]: MEMORY EMERGENCY IO-PAUSE (trip #4731, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:43:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 1.041s wall clock time, 9.5M memory peak, 22.9M read from disk, 38.2M written to disk.
Oct 29 18:43:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:44:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:44:56 evo-x2 memory-emergency-guard-check[401156]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.90% sustained (max disk busy 93.1%, MemAvailable=31.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:44:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:45:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:46:27 evo-x2 memory-emergency-guard-check[474704]: MEMORY EMERGENCY IO-PAUSE (trip #4732, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:46:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 708ms CPU time over 891ms wall clock time, 9.1M memory peak, 4.2M read from disk, 28.7M written to disk.
Oct 29 18:46:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:47:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:47:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:48:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:48:58 evo-x2 memory-emergency-guard-check[606962]: MEMORY EMERGENCY IO-PAUSE (trip #4733, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:48:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:48:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 1.030s wall clock time, 9.6M memory peak, 22.7M read from disk, 39.4M written to disk.
Oct 29 18:49:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:49:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:50:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:51:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:51:58 evo-x2 memory-emergency-guard-check[749331]: MEMORY EMERGENCY IO-PAUSE (trip #4734, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:51:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:51:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 688ms CPU time over 1.039s wall clock time, 10.6M memory peak, 19.6M read from disk, 39.9M written to disk.
Oct 29 18:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:53:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:54:28 evo-x2 memory-emergency-guard-check[804424]: MEMORY EMERGENCY IO-PAUSE (trip #4735, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 635ms CPU time over 803ms wall clock time, 10.8M memory peak, 8.1M read from disk, 34.5M written to disk.
Oct 29 18:54:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:55:28 evo-x2 memory-emergency-guard-check[835054]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.95% sustained (max disk busy 75.9%, MemAvailable=37.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 18:55:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:55:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:56:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:57:02 evo-x2 memory-emergency-guard-check[878475]: MEMORY EMERGENCY IO-PAUSE (trip #4736, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 965ms CPU time over 3.617s wall clock time, 9.2M memory peak, 11.8M read from disk, 43.6M written to disk.
Oct 29 18:57:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:57:32 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 22 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=14.07%, MemAvailable=34.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 18:57:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:58:02 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 22 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 18:58:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:59:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:59:35 evo-x2 memory-emergency-guard-check[1097415]: MEMORY EMERGENCY IO-PAUSE (trip #4737, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 18:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 18:59:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.217s CPU time over 5.606s wall clock time, 8.8M memory peak, 28.4M read from disk, 58.6M written to disk.
Oct 29 18:59:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:00:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:01:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:01:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:02:05 evo-x2 memory-emergency-guard-check[1224857]: MEMORY EMERGENCY IO-PAUSE (trip #4738, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:02:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 754ms CPU time over 4.769s wall clock time, 11.5M memory peak, 27.5M read from disk, 66.9M written to disk.
Oct 29 19:02:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:03:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:03:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:04:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:04:35 evo-x2 memory-emergency-guard-check[1336736]: MEMORY EMERGENCY IO-PAUSE (trip #4739, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:04:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 869ms CPU time over 4.558s wall clock time, 8.5M memory peak, 18.2M read from disk, 42.1M written to disk.
Oct 29 19:05:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:05:31 evo-x2 memory-emergency-guard-check[1375363]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.12% sustained (max disk busy 31.5%, MemAvailable=35.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 19:05:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:07:05 evo-x2 memory-emergency-guard-check[1410926]: MEMORY EMERGENCY IO-PAUSE (trip #4740, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:07:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 2.674s wall clock time, 10M memory peak, 21.8M read from disk, 63.9M written to disk.
Oct 29 19:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:09:33 evo-x2 memory-emergency-guard-check[1488966]: MEMORY EMERGENCY IO-PAUSE (trip #4741, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 719ms CPU time over 1.044s wall clock time, 11.8M memory peak, 16.1M read from disk, 66.8M written to disk.
Oct 29 19:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:12:05 evo-x2 memory-emergency-guard-check[1533068]: MEMORY EMERGENCY IO-PAUSE (trip #4742, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:12:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 626ms CPU time over 788ms wall clock time, 11M memory peak, 5M read from disk, 46.2M written to disk.
Oct 29 19:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:13:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:14:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:15:06 evo-x2 memory-emergency-guard-check[1596277]: MEMORY EMERGENCY IO-PAUSE (trip #4743, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:15:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 712ms wall clock time, 10M memory peak, 2M read from disk, 32.8M written to disk.
Oct 29 19:15:35 evo-x2 memory-emergency-guard-check[1610786]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.74% sustained (max disk busy 84.4%, MemAvailable=36.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 19:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:17:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:17:37 evo-x2 memory-emergency-guard-check[1650720]: MEMORY EMERGENCY IO-PAUSE (trip #4744, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:17:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 565ms CPU time over 1.886s wall clock time, 10.3M memory peak, 11.9M read from disk, 6.5M written to disk.
Oct 29 19:18:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:18:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:20:07 evo-x2 memory-emergency-guard-check[1737414]: MEMORY EMERGENCY IO-PAUSE (trip #4745, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 927ms wall clock time, 10.9M memory peak, 14.9M read from disk, 40.3M written to disk.
Oct 29 19:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:21:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:22:37 evo-x2 memory-emergency-guard-check[1781751]: MEMORY EMERGENCY IO-PAUSE (trip #4746, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 614ms CPU time over 896ms wall clock time, 12.3M memory peak, 13.3M read from disk, 27.3M written to disk.
Oct 29 19:23:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:23:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:24:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:24:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:25:08 evo-x2 memory-emergency-guard-check[1887033]: MEMORY EMERGENCY IO-PAUSE (trip #4747, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 647ms CPU time over 901ms wall clock time, 12.4M memory peak, 7.5M read from disk, 29.9M written to disk.
Oct 29 19:25:37 evo-x2 memory-emergency-guard-check[1906900]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.17% sustained (max disk busy 24.4%, MemAvailable=27.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 19:25:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:26:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:27:39 evo-x2 memory-emergency-guard-check[1948826]: MEMORY EMERGENCY IO-PAUSE (trip #4748, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:27:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 877ms wall clock time, 11.9M memory peak, 13.2M read from disk, 26.3M written to disk.
Oct 29 19:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:31:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:32:40 evo-x2 memory-emergency-guard-check[2061176]: MEMORY EMERGENCY IO-PAUSE (trip #4749, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:32:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 686ms CPU time over 1.543s wall clock time, 11.3M memory peak, 48.4M read from disk, 70.8M written to disk.
Oct 29 19:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:33:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:34:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:35:11 evo-x2 memory-emergency-guard-check[2140790]: MEMORY EMERGENCY IO-PAUSE (trip #4750, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:35:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 1.382s wall clock time, 11M memory peak, 13.4M read from disk, 42.6M written to disk.
Oct 29 19:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:36:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:36:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:37:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:37:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:38:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:38:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:39:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:39:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:40:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:41:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:41:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:42:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:42:45 evo-x2 memory-emergency-guard-check[2315486]: MEMORY EMERGENCY IO-PAUSE (trip #4751, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:42:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 553ms CPU time over 657ms wall clock time, 10.8M memory peak, 2.5M read from disk, 27.3M written to disk.
Oct 29 19:43:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:43:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:44:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:44:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:45:16 evo-x2 memory-emergency-guard-check[2358476]: MEMORY EMERGENCY IO-PAUSE (trip #4752, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:45:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 647ms CPU time over 923ms wall clock time, 10.7M memory peak, 14M read from disk, 20.3M written to disk.
Oct 29 19:45:45 evo-x2 memory-emergency-guard-check[2380467]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.04% sustained (max disk busy 67.1%, MemAvailable=20.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 19:45:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:48:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:48:45 evo-x2 gatus[1850404]: 2026/10/29 19:48:45 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 29 19:48:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:48:58 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 20 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 29 19:49:18 evo-x2 memory-emergency-guard-check[2474434]: MEMORY EMERGENCY IO-PAUSE (trip #4753, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 711ms CPU time over 1.492s wall clock time, 12.5M memory peak, 57.2M read from disk, 91.2M written to disk.
Oct 29 19:49:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:50:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:50:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:51:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:51:48 evo-x2 memory-emergency-guard-check[2517250]: MEMORY EMERGENCY IO-PAUSE (trip #4754, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 689ms CPU time over 973ms wall clock time, 9.1M memory peak, 8.3M read from disk, 27.5M written to disk.
Oct 29 19:52:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:52:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:54:18 evo-x2 memory-emergency-guard-check[2569643]: MEMORY EMERGENCY IO-PAUSE (trip #4755, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 641ms CPU time over 744ms wall clock time, 9.9M memory peak, 1.4M read from disk, 17M written to disk.
Oct 29 19:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:55:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:55:48 evo-x2 memory-emergency-guard-check[2627786]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.85% sustained (max disk busy 82.4%, MemAvailable=18.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 19:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:56:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:56:49 evo-x2 memory-emergency-guard-check[2686941]: MEMORY EMERGENCY IO-PAUSE (trip #4756, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 1.058s wall clock time, 10.1M memory peak, 37.9M read from disk, 40.8M written to disk.
Oct 29 19:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:57:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:59:21 evo-x2 memory-emergency-guard-check[2812637]: MEMORY EMERGENCY IO-PAUSE (trip #4757, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 19:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 19:59:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 561ms CPU time over 668ms wall clock time, 9.8M memory peak, 3.9M read from disk, 8.6M written to disk.
Oct 29 19:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:00:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:00:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:01:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:01:52 evo-x2 memory-emergency-guard-check[2889473]: MEMORY EMERGENCY IO-PAUSE (trip #4758, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 662ms CPU time over 1.099s wall clock time, 10.6M memory peak, 42.6M read from disk, 61.6M written to disk.
Oct 29 20:02:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:02:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:02:53 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 20 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=2.21%, MemAvailable=2.2%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 20:03:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:03:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:04:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:04:52 evo-x2 memory-emergency-guard-check[2938461]: MEMORY EMERGENCY IO-PAUSE (trip #4759, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 590ms CPU time over 784ms wall clock time, 10.9M memory peak, 24.9M read from disk, 29M written to disk.
Oct 29 20:04:54 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 20 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 20:05:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:05:51 evo-x2 memory-emergency-guard-check[2959001]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.81% sustained (max disk busy 60.2%, MemAvailable=18.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:05:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:06:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:06:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:07:22 evo-x2 memory-emergency-guard-check[2978657]: MEMORY EMERGENCY IO-PAUSE (trip #4760, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:07:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 696ms wall clock time, 11.3M memory peak, 11M read from disk, 24M written to disk.
Oct 29 20:07:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:08:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:08:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:09:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:09:54 evo-x2 memory-emergency-guard-check[3042708]: MEMORY EMERGENCY IO-PAUSE (trip #4761, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 585ms CPU time over 741ms wall clock time, 11.7M memory peak, 13.5M read from disk, 21.2M written to disk.
Oct 29 20:10:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:10:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:11:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 100ms CPU time over 500ms wall clock time, 11.4M memory peak, 4.9M read from disk, 4K written to disk.
Oct 29 20:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:12:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 101ms CPU time over 494ms wall clock time, 7.6M memory peak, 1.2M read from disk, 4K written to disk.
Oct 29 20:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:12:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 105ms CPU time over 1.183s wall clock time, 9.7M memory peak, 4.7M read from disk, 4K written to disk.
Oct 29 20:13:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:13:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:14:19 evo-x2 gatus[2494881]: 2026/10/29 20:14:18 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 29 20:14:19 evo-x2 gatus[2494881]: 2026/10/29 20:14:18 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 29 20:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:14:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 261ms wall clock time, 7.5M memory peak, 1.3M read from disk, 4K written to disk.
Oct 29 20:14:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:15:55 evo-x2 memory-emergency-guard-check[3132048]: MEMORY EMERGENCY still active (MemAvailable=1.6% below absolute floor) but action cooldown active (362s < 600s, 238s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:15:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 100ms CPU time over 486ms wall clock time, 8.5M memory peak, 1.1M read from disk, 4K written to disk.
Oct 29 20:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 103ms CPU time over 160ms wall clock time, 9M memory peak, 1.1M read from disk, 4K written to disk.
Oct 29 20:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 167ms wall clock time, 9.3M memory peak, 1M read from disk, 4K written to disk.
Oct 29 20:17:23 evo-x2 gatus[2494881]: 2026/10/29 20:17:23 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 29 20:17:23 evo-x2 gatus[2494881]: 2026/10/29 20:17:23 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 29 20:17:25 evo-x2 memory-emergency-guard-check[3154954]: MEMORY EMERGENCY IO-PAUSE (trip #4762, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:17:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 872ms wall clock time, 10.2M memory peak, 21.3M read from disk, 28.3M written to disk.
Oct 29 20:17:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:18:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:19:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:19:56 evo-x2 memory-emergency-guard-check[3208553]: MEMORY EMERGENCY IO-PAUSE (trip #4763, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:19:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:19:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 826ms wall clock time, 10.7M memory peak, 22M read from disk, 35.1M written to disk.
Oct 29 20:20:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:21:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:21:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:22:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:22:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:23:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:23:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:24:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:24:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:25:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:25:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:26:59 evo-x2 memory-emergency-guard-check[3400052]: MEMORY EMERGENCY IO-PAUSE (trip #4764, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:26:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 910ms wall clock time, 11.1M memory peak, 22.1M read from disk, 37.2M written to disk.
Oct 29 20:27:28 evo-x2 memory-emergency-guard-check[3416348]: MEMORY EMERGENCY still active (I/O PSI some avg60=71.94% sustained (max disk busy 60.5%, MemAvailable=18.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:27:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:27:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:28:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:30:30 evo-x2 memory-emergency-guard-check[3511938]: MEMORY EMERGENCY IO-PAUSE (trip #4765, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:30:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 889ms wall clock time, 12M memory peak, 17.3M read from disk, 34.9M written to disk.
Oct 29 20:30:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:31:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:32:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:32:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:33:01 evo-x2 memory-emergency-guard-check[3593367]: MEMORY EMERGENCY IO-PAUSE (trip #4766, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 654ms CPU time over 936ms wall clock time, 11.7M memory peak, 16.4M read from disk, 28.9M written to disk.
Oct 29 20:33:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:34:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:36:02 evo-x2 memory-emergency-guard-check[3690444]: MEMORY EMERGENCY IO-PAUSE (trip #4767, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 813ms wall clock time, 10.3M memory peak, 3M read from disk, 52.3M written to disk.
Oct 29 20:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:37:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:37:32 evo-x2 memory-emergency-guard-check[3726141]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.54% sustained (max disk busy 96.3%, MemAvailable=14.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:38:39 evo-x2 memory-emergency-guard-check[3742057]: MEMORY EMERGENCY IO-PAUSE (trip #4768, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 633ms CPU time over 7.478s wall clock time, 11.8M memory peak, 12.3M read from disk, 39.8M written to disk.
Oct 29 20:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:41:06 evo-x2 memory-emergency-guard-check[3783537]: MEMORY EMERGENCY IO-PAUSE (trip #4769, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:41:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 599ms CPU time over 4.223s wall clock time, 10.9M memory peak, 7.5M read from disk, 27.4M written to disk.
Oct 29 20:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:43:37 evo-x2 memory-emergency-guard-check[3834508]: MEMORY EMERGENCY IO-PAUSE (trip #4770, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:43:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 636ms CPU time over 4.596s wall clock time, 12.5M memory peak, 3.3M read from disk, 43.8M written to disk.
Oct 29 20:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:46:05 evo-x2 memory-emergency-guard-check[3878362]: MEMORY EMERGENCY IO-PAUSE (trip #4771, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 2.026s wall clock time, 11.5M memory peak, 2.8M read from disk, 29.3M written to disk.
Oct 29 20:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:47:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:47:33 evo-x2 memory-emergency-guard-check[3907623]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.51% sustained (max disk busy 99.0%, MemAvailable=17.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:48:57 evo-x2 memory-emergency-guard-check[3926571]: MEMORY EMERGENCY IO-PAUSE (trip #4772, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:48:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 751ms CPU time over 23.275s wall clock time, 12.1M memory peak, 26.7M read from disk, 7.1M written to disk.
Oct 29 20:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 337ms wall clock time, 9.6M memory peak, 2.1M read from disk, 4K written to disk.
Oct 29 20:49:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:51:10 evo-x2 memory-emergency-guard-check[3975805]: MEMORY EMERGENCY IO-PAUSE (trip #4773, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 683ms CPU time over 6.721s wall clock time, 11.6M memory peak, 18.2M read from disk, 27M written to disk.
Oct 29 20:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:52:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:53:38 evo-x2 memory-emergency-guard-check[4026790]: MEMORY EMERGENCY IO-PAUSE (trip #4774, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:53:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 690ms CPU time over 4.251s wall clock time, 11.4M memory peak, 2.9M read from disk, 52M written to disk.
Oct 29 20:54:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:54:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:55:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:55:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:56:10 evo-x2 memory-emergency-guard-check[4106131]: MEMORY EMERGENCY IO-PAUSE (trip #4775, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 5.805s wall clock time, 12.9M memory peak, 15.4M read from disk, 30.5M written to disk.
Oct 29 20:56:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:57:35 evo-x2 memory-emergency-guard-check[4139021]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.62% sustained (max disk busy 99.3%, MemAvailable=17.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 20:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:58:37 evo-x2 memory-emergency-guard-check[4152761]: MEMORY EMERGENCY IO-PAUSE (trip #4776, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 20:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:58:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 1.062s wall clock time, 10.7M memory peak, 3M read from disk, 46.8M written to disk.
Oct 29 20:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 20:59:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:00:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:00:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:01:08 evo-x2 memory-emergency-guard-check[52675]: MEMORY EMERGENCY IO-PAUSE (trip #4777, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:01:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 573ms CPU time over 746ms wall clock time, 11.5M memory peak, 1008K read from disk, 13.2M written to disk.
Oct 29 21:01:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:02:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:02:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:03:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:03:39 evo-x2 memory-emergency-guard-check[190390]: MEMORY EMERGENCY IO-PAUSE (trip #4778, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:03:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 600ms CPU time over 734ms wall clock time, 10.5M memory peak, 8M read from disk, 20.4M written to disk.
Oct 29 21:04:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:04:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:05:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:05:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:06:10 evo-x2 memory-emergency-guard-check[277011]: MEMORY EMERGENCY IO-PAUSE (trip #4779, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:06:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 666ms CPU time over 981ms wall clock time, 10.8M memory peak, 14.9M read from disk, 36.5M written to disk.
Oct 29 21:06:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:07:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:07:39 evo-x2 memory-emergency-guard-check[326064]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.57% sustained (max disk busy 98.5%, MemAvailable=17.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 21:07:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:08:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:08:41 evo-x2 memory-emergency-guard-check[363700]: MEMORY EMERGENCY IO-PAUSE (trip #4780, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:08:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 851ms CPU time over 1.177s wall clock time, 10M memory peak, 1.5M read from disk, 27.7M written to disk.
Oct 29 21:09:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:09:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:10:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:10:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:11:14 evo-x2 memory-emergency-guard-check[408954]: MEMORY EMERGENCY IO-PAUSE (trip #4781, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:11:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 3.147s wall clock time, 11.2M memory peak, 9.4M read from disk, 27M written to disk.
Oct 29 21:11:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:12:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:12:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:13:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:13:49 evo-x2 memory-emergency-guard-check[482584]: MEMORY EMERGENCY IO-PAUSE (trip #4782, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:13:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 617ms CPU time over 6.577s wall clock time, 11.8M memory peak, 15.9M read from disk, 27.8M written to disk.
Oct 29 21:14:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:14:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:14:46 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 21 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (fastflowlm) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u fastflowlm -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=3.43%, MemAvailable=1.9%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 21:15:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:15:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:16:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 1.634s wall clock time, 9.2M memory peak, 2.4M read from disk, 4K written to disk.
Oct 29 21:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:17:34 evo-x2 memory-emergency-guard-check[539122]: MEMORY EMERGENCY IO-PAUSE (trip #4783, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:17:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 613ms CPU time over 5.396s wall clock time, 11.5M memory peak, 1.9M read from disk, 15.9M written to disk.
Oct 29 21:17:35 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 21 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (fastflowlm) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u fastflowlm -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 21:17:59 evo-x2 memory-emergency-guard-check[554941]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.53% sustained (max disk busy 100.0%, MemAvailable=15.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 21:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:20:03 evo-x2 memory-emergency-guard-check[610683]: MEMORY EMERGENCY IO-PAUSE (trip #4784, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:20:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 4.589s wall clock time, 11.5M memory peak, 6.4M read from disk, 19.7M written to disk.
Oct 29 21:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:21:18 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 21 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 29 21:21:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:22:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:22:56 evo-x2 memory-emergency-guard-check[696318]: MEMORY EMERGENCY IO-PAUSE (trip #4785, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:22:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 645ms CPU time over 26.377s wall clock time, 11.6M memory peak, 11.5M read from disk, 21.2M written to disk.
Oct 29 21:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:25:10 evo-x2 memory-emergency-guard-check[751402]: MEMORY EMERGENCY IO-PAUSE (trip #4786, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:25:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 738ms CPU time over 9.680s wall clock time, 11.9M memory peak, 25.4M read from disk, 4.3M written to disk.
Oct 29 21:25:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:26:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:27:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:27:46 evo-x2 memory-emergency-guard-check[805320]: MEMORY EMERGENCY IO-PAUSE (trip #4787, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 14.554s wall clock time, 12.9M memory peak, 16.7M read from disk, 26.1M written to disk.
Oct 29 21:28:02 evo-x2 memory-emergency-guard-check[826341]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.83% sustained (max disk busy 100.0%, MemAvailable=16.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 21:28:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:29:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:29:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:30:15 evo-x2 memory-emergency-guard-check[877206]: MEMORY EMERGENCY IO-PAUSE (trip #4788, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:30:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 670ms CPU time over 13.515s wall clock time, 11.4M memory peak, 11.6M read from disk, 15.1M written to disk.
Oct 29 21:30:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:31:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:32:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:32:43 evo-x2 memory-emergency-guard-check[957729]: MEMORY EMERGENCY IO-PAUSE (trip #4789, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:32:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 619ms CPU time over 10.817s wall clock time, 11.9M memory peak, 7.9M read from disk, 7.5M written to disk.
Oct 29 21:33:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:34:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:34:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:36:01 evo-x2 memory-emergency-guard-check[1011632]: MEMORY EMERGENCY IO-PAUSE (trip #4790, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 905ms CPU time over 58.367s wall clock time, 11.7M memory peak, 23M read from disk, 31.4M written to disk.
Oct 29 21:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:36:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:38:25 evo-x2 memory-emergency-guard-check[1122833]: MEMORY EMERGENCY IO-PAUSE (trip #4791, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:38:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 828ms CPU time over 24.493s wall clock time, 12M memory peak, 26.4M read from disk, 10.3M written to disk.
Oct 29 21:38:31 evo-x2 memory-emergency-guard-check[1169035]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.74% sustained (max disk busy 99.6%, MemAvailable=14.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 21:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:39:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:39:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:40:43 evo-x2 memory-emergency-guard-check[1266837]: MEMORY EMERGENCY IO-PAUSE (trip #4792, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:40:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 890ms CPU time over 11.044s wall clock time, 11.8M memory peak, 10.8M read from disk, 32.2M written to disk.
Oct 29 21:41:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:43:14 evo-x2 memory-emergency-guard-check[1352756]: MEMORY EMERGENCY IO-PAUSE (trip #4793, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:43:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:43:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 809ms CPU time over 11.851s wall clock time, 11.1M memory peak, 9M read from disk, 10.5M written to disk.
Oct 29 21:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:44:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:44:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:45:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:46:16 evo-x2 memory-emergency-guard-check[1474983]: MEMORY EMERGENCY IO-PAUSE (trip #4794, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 910ms CPU time over 42.722s wall clock time, 12.2M memory peak, 36.3M read from disk, 4.5M written to disk.
Oct 29 21:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:46:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 137ms CPU time over 238ms wall clock time, 7.8M memory peak, 1.4M read from disk, 4K written to disk.
Oct 29 21:46:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:47:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 152ms CPU time over 247ms wall clock time, 8.3M memory peak, 1.5M read from disk, 4K written to disk.
Oct 29 21:47:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:48:55 evo-x2 memory-emergency-guard-check[1581837]: MEMORY EMERGENCY IO-PAUSE (trip #4795, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.107s CPU time over 39.617s wall clock time, 10.2M memory peak, 21M read from disk, 12.2M written to disk.
Oct 29 21:48:56 evo-x2 memory-emergency-guard-check[1634250]: MEMORY EMERGENCY still active (I/O PSI some avg60=81.09% sustained (max disk busy 99.2%, MemAvailable=5.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (40s < 150s, 110s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 21:48:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:49:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:49:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:50:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 198ms CPU time over 1.208s wall clock time, 5.7M memory peak, 1.1M read from disk, 4K written to disk.
Oct 29 21:50:32 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=2.41%, MemAvailable=2.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 21:50:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:51:53 evo-x2 memory-emergency-guard-check[1748088]: MEMORY EMERGENCY IO-PAUSE (trip #4796, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 27.562s wall clock time, 11.2M memory peak, 9.6M read from disk, 16.1M written to disk.
Oct 29 21:51:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:52:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:53:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:54:29 evo-x2 memory-emergency-guard-check[1833746]: MEMORY EMERGENCY IO-PAUSE (trip #4797, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 747ms CPU time over 32.005s wall clock time, 11.2M memory peak, 18.3M read from disk, 18M written to disk.
Oct 29 21:54:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:54:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:55:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:56:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:57:19 evo-x2 memory-emergency-guard-check[1953696]: MEMORY EMERGENCY IO-PAUSE (trip #4798, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 21:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 923ms CPU time over 50.077s wall clock time, 9.7M memory peak, 26.5M read from disk, 11.7M written to disk.
Oct 29 21:57:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:58:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 21:58:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:00:01 evo-x2 memory-emergency-guard-check[2086192]: MEMORY EMERGENCY IO-PAUSE (trip #4799, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 727ms CPU time over 40.326s wall clock time, 11.8M memory peak, 19.8M read from disk, 13.9M written to disk.
Oct 29 22:00:01 evo-x2 memory-emergency-guard-check[2118128]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.40% sustained (max disk busy 98.4%, MemAvailable=16.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (41s < 150s, 109s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:00:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:00:02 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 22:00:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:01:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:01:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:02:13 evo-x2 memory-emergency-guard-check[2209919]: MEMORY EMERGENCY IO-PAUSE (trip #4800, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:02:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 998ms CPU time over 11.746s wall clock time, 10.8M memory peak, 18.8M read from disk, 28.4M written to disk.
Oct 29 22:02:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:03:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:03:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:04:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:04:44 evo-x2 memory-emergency-guard-check[2349934]: MEMORY EMERGENCY IO-PAUSE (trip #4801, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:04:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.051s CPU time over 12.473s wall clock time, 10.1M memory peak, 22.5M read from disk, 8.4M written to disk.
Oct 29 22:05:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:05:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:06:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:06:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:07:29 evo-x2 memory-emergency-guard-check[2498954]: MEMORY EMERGENCY IO-PAUSE (trip #4802, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:07:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 858ms CPU time over 26.822s wall clock time, 10.6M memory peak, 28.1M read from disk, 13.9M written to disk.
Oct 29 22:07:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:08:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:08:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:09:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 158ms wall clock time, 7.5M memory peak, 1M read from disk, 4K written to disk.
Oct 29 22:09:46 evo-x2 memory-emergency-guard-check[2632909]: MEMORY EMERGENCY IO-PAUSE (trip #4803, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 959ms CPU time over 14.124s wall clock time, 7.8M memory peak, 6.7M read from disk, 32M written to disk.
Oct 29 22:10:03 evo-x2 memory-emergency-guard-check[2660336]: MEMORY EMERGENCY still active (MemAvailable=3.2% below absolute floor) but action cooldown active (31s < 600s, 569s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 149ms CPU time over 1.253s wall clock time, 7.4M memory peak, 3M read from disk, 4K written to disk.
Oct 29 22:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:11:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:12:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 806ms wall clock time, 8.1M memory peak, 1.5M read from disk, 4K written to disk.
Oct 29 22:13:30 evo-x2 memory-emergency-guard-check[2710803]: MEMORY EMERGENCY IO-PAUSE (trip #4804, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 975ms CPU time over 35.838s wall clock time, 9.3M memory peak, 12.3M read from disk, 15.4M written to disk.
Oct 29 22:13:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:14:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:14:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:15:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:15:49 evo-x2 memory-emergency-guard-check[2844155]: MEMORY EMERGENCY IO-PAUSE (trip #4805, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.199s CPU time over 19.154s wall clock time, 9.2M memory peak, 19.6M read from disk, 30.9M written to disk.
Oct 29 22:16:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:16:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:17:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:17:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:19:04 evo-x2 memory-emergency-guard-check[2989021]: MEMORY EMERGENCY IO-PAUSE (trip #4806, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 934ms CPU time over 1min 3.247s wall clock time, 12.2M memory peak, 18.6M read from disk, 14.2M written to disk.
Oct 29 22:19:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:19:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:20:04 evo-x2 memory-emergency-guard-check[3073838]: MEMORY EMERGENCY still active (MemAvailable=1.4% below absolute floor) but action cooldown active (123s < 600s, 477s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:20:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:20:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 1.663s wall clock time, 6.1M memory peak, 1.2M read from disk, 4K written to disk.
Oct 29 22:21:40 evo-x2 memory-emergency-guard-check[3094226]: MEMORY EMERGENCY IO-PAUSE (trip #4807, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:21:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 781ms CPU time over 36.387s wall clock time, 11.8M memory peak, 15.4M read from disk, 21.2M written to disk.
Oct 29 22:21:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:22:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 177ms CPU time over 323ms wall clock time, 6.8M memory peak, 1.1M read from disk, 4K written to disk.
Oct 29 22:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:23:44 evo-x2 memory-emergency-guard-check[3217171]: MEMORY EMERGENCY IO-PAUSE (trip #4808, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:23:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 918ms CPU time over 2.998s wall clock time, 10.6M memory peak, 14.2M read from disk, 29.5M written to disk.
Oct 29 22:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:24:17 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=9.31%, MemAvailable=3.2%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 22:24:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:25:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:25:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 131ms CPU time over 475ms wall clock time, 8M memory peak, 1.5M read from disk, 4K written to disk.
Oct 29 22:26:54 evo-x2 memory-emergency-guard-check[3403685]: MEMORY EMERGENCY IO-PAUSE (trip #4809, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:26:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 932ms CPU time over 43.743s wall clock time, 10.5M memory peak, 25.1M read from disk, 13.8M written to disk.
Oct 29 22:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:27:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 215ms CPU time over 671ms wall clock time, 6.1M memory peak, 2.5M read from disk, 4K written to disk.
Oct 29 22:29:26 evo-x2 memory-emergency-guard-check[3632212]: MEMORY EMERGENCY IO-PAUSE (trip #4810, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 757ms CPU time over 30.948s wall clock time, 13.7M memory peak, 27.3M read from disk, 17.1M written to disk.
Oct 29 22:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:29:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:30:26 evo-x2 memory-emergency-guard-check[3746751]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.70% sustained (max disk busy 99.9%, MemAvailable=31.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:34:00 evo-x2 memory-emergency-guard-check[3786828]: MEMORY EMERGENCY IO-PAUSE (trip #4811, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:34:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.962s CPU time over 2min 32.920s wall clock time, 10M memory peak, 100.4M read from disk, 19.2M written to disk.
Oct 29 22:34:10 evo-x2 memory-emergency-guard-check[3919388]: MEMORY EMERGENCY IO-PAUSE (trip #4812, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 996ms CPU time over 9.630s wall clock time, 8.7M memory peak, 280K read from disk, 19M written to disk.
Oct 29 22:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:36:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:37:14 evo-x2 memory-emergency-guard-check[4098028]: MEMORY EMERGENCY IO-PAUSE (trip #4813, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 928ms CPU time over 43.431s wall clock time, 11.9M memory peak, 41.7M read from disk, 69.8M written to disk.
Oct 29 22:37:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:37:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:38:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 150ms wall clock time, 8.7M memory peak, 1.5M read from disk, 4K written to disk.
Oct 29 22:38:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:39:17 evo-x2 memory-emergency-guard-check[4188171]: MEMORY EMERGENCY IO-PAUSE (trip #4814, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:39:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:39:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.053s CPU time over 2.861s wall clock time, 13.1M memory peak, 33.1M read from disk, 23.8M written to disk.
Oct 29 22:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:39:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 139ms CPU time over 626ms wall clock time, 9.9M memory peak, 4.4M read from disk, 4K written to disk.
Oct 29 22:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:40:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 192ms CPU time over 662ms wall clock time, 8.2M memory peak, 3.7M read from disk, 4K written to disk.
Oct 29 22:40:45 evo-x2 memory-emergency-guard-check[42296]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.88% sustained (max disk busy 99.6%, MemAvailable=26.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:40:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 144ms CPU time over 281ms wall clock time, 9.7M memory peak, 2.5M read from disk, 4K written to disk.
Oct 29 22:41:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:42:15 evo-x2 memory-emergency-guard-check[75528]: MEMORY EMERGENCY IO-PAUSE (trip #4815, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:42:15 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 30.270s wall clock time, 11.8M memory peak, 37.2M read from disk, 3.7M written to disk.
Oct 29 22:42:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:42:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:43:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 137ms CPU time over 221ms wall clock time, 8.8M memory peak, 3M read from disk, 4K written to disk.
Oct 29 22:43:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:44:49 evo-x2 memory-emergency-guard-check[191898]: MEMORY EMERGENCY IO-PAUSE (trip #4816, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:44:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 768ms CPU time over 33.364s wall clock time, 13.8M memory peak, 25.1M read from disk, 23.5M written to disk.
Oct 29 22:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:44:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 116ms CPU time over 461ms wall clock time, 7.5M memory peak, 1.3M read from disk, 4K written to disk.
Oct 29 22:45:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:45:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:46:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:47:04 evo-x2 memory-emergency-guard-check[328524]: MEMORY EMERGENCY IO-PAUSE (trip #4817, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:47:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.032s CPU time over 14.456s wall clock time, 10.1M memory peak, 26.4M read from disk, 6.7M written to disk.
Oct 29 22:47:07 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 29 22:47:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:47:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:48:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:48:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:49:27 evo-x2 sudo[402375]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Oct 29 22:49:27 evo-x2 sudo[402378]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/journalctl -u memory-emergency-guard --since today -o cat --no-pager
Oct 29 22:49:34 evo-x2 memory-emergency-guard-check[390471]: MEMORY EMERGENCY IO-PAUSE (trip #4818, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 760ms CPU time over 14.550s wall clock time, 12.5M memory peak, 32.9M read from disk, 18.4M written to disk.
Oct 29 22:49:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:50:50 evo-x2 memory-emergency-guard-check[457599]: MEMORY EMERGENCY still active (I/O PSI some avg60=74.64% sustained (max disk busy 100.0%, MemAvailable=18.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 22:50:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:51:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:51:59 evo-x2 memory-emergency-guard-check[481850]: MEMORY EMERGENCY IO-PAUSE (trip #4819, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:51:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 706ms CPU time over 9.044s wall clock time, 11.7M memory peak, 18.5M read from disk, 31.1M written to disk.
Oct 29 22:52:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:52:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:53:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:53:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:54:32 evo-x2 memory-emergency-guard-check[531286]: MEMORY EMERGENCY IO-PAUSE (trip #4820, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 11.019s wall clock time, 10.8M memory peak, 30.2M read from disk, 10.6M written to disk.
Oct 29 22:54:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:55:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:55:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:56:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:56:53 evo-x2 memory-emergency-guard-check[603865]: MEMORY EMERGENCY IO-PAUSE (trip #4821, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 656ms CPU time over 966ms wall clock time, 11.4M memory peak, 24.4M read from disk, 39M written to disk.
Oct 29 22:57:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:57:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 158ms wall clock time, 9.7M memory peak, 1.2M read from disk, 4K written to disk.
Oct 29 22:59:54 evo-x2 memory-emergency-guard-check[687385]: MEMORY EMERGENCY IO-PAUSE (trip #4822, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 22:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 22:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 652ms CPU time over 1.031s wall clock time, 12M memory peak, 31.1M read from disk, 38.4M written to disk.
Oct 29 23:00:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:00:54 evo-x2 memory-emergency-guard-check[706659]: MEMORY EMERGENCY still active (I/O PSI some avg60=63.25% sustained (max disk busy 97.9%, MemAvailable=9.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (61s < 150s, 89s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:01:26 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=0.54%, MemAvailable=6.5%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 23:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 172ms CPU time over 287ms wall clock time, 7.3M memory peak, 3.4M read from disk, 4K written to disk.
Oct 29 23:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 2.933s wall clock time, 17.5M memory peak, 9.7M read from disk, 4K written to disk.
Oct 29 23:02:57 evo-x2 memory-emergency-guard-check[731748]: MEMORY EMERGENCY IO-PAUSE (trip #4823, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 861ms CPU time over 2.827s wall clock time, 13.6M memory peak, 48.3M read from disk, 56.8M written to disk.
Oct 29 23:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 143ms CPU time over 452ms wall clock time, 14.1M memory peak, 5.6M read from disk, 4K written to disk.
Oct 29 23:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 118ms CPU time over 1.498s wall clock time, 17.3M memory peak, 7.8M read from disk, 4K written to disk.
Oct 29 23:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:04:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 125ms CPU time over 504ms wall clock time, 13.1M memory peak, 4.9M read from disk, 4K written to disk.
Oct 29 23:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:04:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 317ms wall clock time, 8.8M memory peak, 1M read from disk, 4K written to disk.
Oct 29 23:05:25 evo-x2 memory-emergency-guard-check[772290]: MEMORY EMERGENCY IO-PAUSE (trip #4824, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 713ms CPU time over 1.365s wall clock time, 15.2M memory peak, 61M read from disk, 65.1M written to disk.
Oct 29 23:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:05:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 116ms CPU time over 345ms wall clock time, 13.9M memory peak, 5M read from disk, 4K written to disk.
Oct 29 23:06:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:06:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 105ms CPU time over 409ms wall clock time, 17.3M memory peak, 7.8M read from disk, 4K written to disk.
Oct 29 23:07:55 evo-x2 memory-emergency-guard-check[811931]: MEMORY EMERGENCY IO-PAUSE (trip #4825, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 579ms CPU time over 710ms wall clock time, 11M memory peak, 5.1M read from disk, 14.3M written to disk.
Oct 29 23:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:08:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 114ms CPU time over 154ms wall clock time, 12.3M memory peak, 4.1M read from disk, 4K written to disk.
Oct 29 23:10:27 evo-x2 memory-emergency-guard-check[873113]: MEMORY EMERGENCY IO-PAUSE (trip #4826, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 781ms CPU time over 1.156s wall clock time, 11.1M memory peak, 34M read from disk, 46.3M written to disk.
Oct 29 23:10:56 evo-x2 memory-emergency-guard-check[889377]: MEMORY EMERGENCY still active (I/O PSI some avg60=79.33% sustained (max disk busy 100.0%, MemAvailable=22.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:10:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:11:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:11:31 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30".
Oct 29 23:11:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:12:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:13:02 evo-x2 memory-emergency-guard-check[926533]: MEMORY EMERGENCY IO-PAUSE (trip #4827, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 5.272s wall clock time, 12M memory peak, 21.7M read from disk, 5.6M written to disk.
Oct 29 23:13:04 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; ZRAM SWAP CRITICAL" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 23 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=1.91%, MemAvailable=14.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now.".
Oct 29 23:13:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:13:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:14:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:15:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:15:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:16:50 evo-x2 memory-emergency-guard-check[1004232]: MEMORY EMERGENCY IO-PAUSE (trip #4828, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 21.836s wall clock time, 16.9M memory peak, 31.2M read from disk, 12.9M written to disk.
Oct 29 23:16:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:17:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:17:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:19:17 evo-x2 memory-emergency-guard-check[1108614]: MEMORY EMERGENCY IO-PAUSE (trip #4829, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:19:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.017s CPU time over 18.654s wall clock time, 9.5M memory peak, 23.3M read from disk, 5M written to disk.
Oct 29 23:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:20:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:20:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:21:00 evo-x2 memory-emergency-guard-check[1258649]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.74% sustained (max disk busy 100.0%, MemAvailable=19.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:21:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:21:34 evo-x2 memory-emergency-guard-check[1305970]: MEMORY EMERGENCY IO-PAUSE (trip #4830, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.362s CPU time over 4.749s wall clock time, 8.5M memory peak, 7.2M read from disk, 38.3M written to disk.
Oct 29 23:21:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:22:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 134ms CPU time over 247ms wall clock time, 9M memory peak, 2.6M read from disk, 4K written to disk.
Oct 29 23:23:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:23:21 evo-x2 sudo[1479008]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/journalctl -u memory-emergency-guard --since today -o cat --no-pager
Oct 29 23:23:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:24:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:24:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 154ms CPU time over 494ms wall clock time, 8.4M memory peak, 3.3M read from disk, 4K written to disk.
Oct 29 23:25:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:25:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 170ms CPU time over 1.141s wall clock time, 7M memory peak, 2.8M read from disk, 4K written to disk.
Oct 29 23:26:03 evo-x2 memory-emergency-guard-check[1712904]: MEMORY EMERGENCY IO-PAUSE (trip #4831, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:26:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 876ms CPU time over 1.640s wall clock time, 10.2M memory peak, 47.7M read from disk, 58.7M written to disk.
Oct 29 23:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:26:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 238ms CPU time over 417ms wall clock time, 5.5M memory peak, 2.7M read from disk, 4K written to disk.
Oct 29 23:27:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:27:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:28:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:28:32 evo-x2 memory-emergency-guard-check[1863342]: MEMORY EMERGENCY IO-PAUSE (trip #4832, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:28:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.031s CPU time over 1.382s wall clock time, 9.8M memory peak, 20.2M read from disk, 37.6M written to disk.
Oct 29 23:29:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:29:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:30:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:30:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:31:02 evo-x2 memory-emergency-guard-check[1997111]: MEMORY EMERGENCY IO-PAUSE (trip #4833, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:31:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.052s CPU time over 1.470s wall clock time, 14.1M memory peak, 42.6M read from disk, 52.3M written to disk.
Oct 29 23:31:31 evo-x2 memory-emergency-guard-check[2012633]: MEMORY EMERGENCY still active (I/O PSI some avg60=45.22% sustained (max disk busy 73.4%, MemAvailable=6.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:31:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:32:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 165ms CPU time over 294ms wall clock time, 9.5M memory peak, 4.7M read from disk, 4K written to disk.
Oct 29 23:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:32:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 163ms CPU time over 247ms wall clock time, 8.2M memory peak, 3.4M read from disk, 4K written to disk.
Oct 29 23:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:33:32 evo-x2 memory-emergency-guard-check[2078906]: MEMORY EMERGENCY IO-PAUSE (trip #4834, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:33:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 731ms wall clock time, 10.4M memory peak, 4.7M read from disk, 10.3M written to disk.
Oct 29 23:34:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:34:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:35:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:35:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:36:02 evo-x2 memory-emergency-guard-check[2149946]: MEMORY EMERGENCY IO-PAUSE (trip #4835, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:36:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 709ms CPU time over 1.006s wall clock time, 10.8M memory peak, 34.6M read from disk, 48.8M written to disk.
Oct 29 23:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:36:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 193ms CPU time over 285ms wall clock time, 7.5M memory peak, 2.6M read from disk, 4K written to disk.
Oct 29 23:37:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:37:14 evo-x2 gatus[2494881]: 2026/10/29 23:37:13 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 29 23:37:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:38:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:38:33 evo-x2 memory-emergency-guard-check[2302656]: MEMORY EMERGENCY IO-PAUSE (trip #4836, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:38:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.252s CPU time over 1.937s wall clock time, 7.9M memory peak, 6.2M read from disk, 32.2M written to disk.
Oct 29 23:39:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:39:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:40:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:40:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:41:04 evo-x2 memory-emergency-guard-check[2407344]: MEMORY EMERGENCY IO-PAUSE (trip #4837, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:41:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 824ms CPU time over 2.142s wall clock time, 11M memory peak, 38M read from disk, 43.7M written to disk.
Oct 29 23:41:32 evo-x2 memory-emergency-guard-check[2422664]: MEMORY EMERGENCY still active (I/O PSI some avg60=73.25% sustained (max disk busy 100.0%, MemAvailable=38.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:41:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:42:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:42:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:43:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:43:33 evo-x2 memory-emergency-guard-check[2492355]: MEMORY EMERGENCY IO-PAUSE (trip #4838, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:43:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 993ms CPU time over 1.300s wall clock time, 9.6M memory peak, 3.1M read from disk, 30.5M written to disk.
Oct 29 23:44:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:44:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:45:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:45:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:46:05 evo-x2 memory-emergency-guard-check[2637453]: MEMORY EMERGENCY IO-PAUSE (trip #4839, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:46:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 962ms CPU time over 2.737s wall clock time, 11.2M memory peak, 43.6M read from disk, 13.9M written to disk.
Oct 29 23:46:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:47:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:47:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:48:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:49:03 evo-x2 memory-emergency-guard-check[2725297]: MEMORY EMERGENCY IO-PAUSE (trip #4840, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:49:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 31.015s wall clock time, 11.5M memory peak, 17.6M read from disk, 26.5M written to disk.
Oct 29 23:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:49:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:50:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:50:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:51:13 evo-x2 memory-emergency-guard-check[2789056]: MEMORY EMERGENCY IO-PAUSE (trip #4841, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 725ms CPU time over 9.754s wall clock time, 11M memory peak, 8.7M read from disk, 14.1M written to disk.
Oct 29 23:51:34 evo-x2 memory-emergency-guard-check[2807239]: MEMORY EMERGENCY still active (I/O PSI some avg60=64.73% sustained (max disk busy 99.8%, MemAvailable=17.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 29 23:51:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:52:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:52:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:53:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:53:50 evo-x2 memory-emergency-guard-check[2871483]: MEMORY EMERGENCY IO-PAUSE (trip #4842, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:53:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 859ms CPU time over 16.167s wall clock time, 9.7M memory peak, 18.9M read from disk, 8.3M written to disk.
Oct 29 23:54:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:55:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:55:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:56:31 evo-x2 memory-emergency-guard-check[3008070]: MEMORY EMERGENCY IO-PAUSE (trip #4843, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:56:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.044s CPU time over 26.802s wall clock time, 9.4M memory peak, 25.5M read from disk, 12.1M written to disk.
Oct 29 23:56:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:57:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:57:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 143ms CPU time over 256ms wall clock time, 8.3M memory peak, 1.2M read from disk, 4K written to disk.
Oct 29 23:58:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:59:07 evo-x2 memory-emergency-guard-check[3102474]: MEMORY EMERGENCY IO-PAUSE (trip #4844, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 29 23:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 916ms CPU time over 31.898s wall clock time, 13.9M memory peak, 39.3M read from disk, 8.4M written to disk.
Oct 29 23:59:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 29 23:59:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:00:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:00:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 159ms CPU time over 281ms wall clock time, 6.4M memory peak, 1.2M read from disk, 4K written to disk.
Oct 30 00:02:18 evo-x2 memory-emergency-guard-check[3177354]: MEMORY EMERGENCY IO-PAUSE (trip #4845, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:02:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:02:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 857ms CPU time over 1min 9.968s wall clock time, 11M memory peak, 33.5M read from disk, 2.6M written to disk.
Oct 30 00:02:19 evo-x2 memory-emergency-guard-check[3203245]: MEMORY EMERGENCY still active (I/O PSI some avg60=83.52% sustained (max disk busy 99.5%, MemAvailable=18.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (70s < 150s, 80s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:02:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 134ms CPU time over 704ms wall clock time, 9.4M memory peak, 7M read from disk, 4K written to disk.
Oct 30 00:02:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:03:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:03:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 595ms wall clock time, 12.7M memory peak, 7.1M read from disk, 4K written to disk.
Oct 30 00:05:05 evo-x2 memory-emergency-guard-check[3227861]: MEMORY EMERGENCY IO-PAUSE (trip #4846, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 797ms CPU time over 1min 16.841s wall clock time, 10.5M memory peak, 23.1M read from disk, 15.2M written to disk.
Oct 30 00:05:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:05:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:06:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:07:14 evo-x2 memory-emergency-guard-check[3294196]: MEMORY EMERGENCY IO-PAUSE (trip #4847, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 803ms CPU time over 39.447s wall clock time, 12M memory peak, 16.5M read from disk, 19.5M written to disk.
Oct 30 00:07:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:07:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:10:01 evo-x2 memory-emergency-guard-check[3377361]: MEMORY EMERGENCY IO-PAUSE (trip #4848, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:10:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 835ms CPU time over 46.893s wall clock time, 12.3M memory peak, 3.1M read from disk, 24.7M written to disk.
Oct 30 00:10:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:10:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:11:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:11:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:12:21 evo-x2 memory-emergency-guard-check[3482848]: MEMORY EMERGENCY IO-PAUSE (trip #4849, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:12:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.228s CPU time over 19.739s wall clock time, 10.1M memory peak, 34.5M read from disk, 23.1M written to disk.
Oct 30 00:12:32 evo-x2 memory-emergency-guard-check[3511419]: MEMORY EMERGENCY still active (I/O PSI some avg60=85.79% sustained (max disk busy 96.5%, MemAvailable=14.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:12:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 127ms CPU time over 245ms wall clock time, 8.5M memory peak, 1.3M read from disk, 4K written to disk.
Oct 30 00:13:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:13:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:14:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:14:55 evo-x2 memory-emergency-guard-check[3603874]: MEMORY EMERGENCY IO-PAUSE (trip #4850, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 23.478s wall clock time, 11M memory peak, 14.8M read from disk, 4.6M written to disk.
Oct 30 00:15:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:15:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:16:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:16:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:17:38 evo-x2 memory-emergency-guard-check[3676003]: MEMORY EMERGENCY IO-PAUSE (trip #4851, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:17:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.120s CPU time over 36.874s wall clock time, 11M memory peak, 23.2M read from disk, 3.8M written to disk.
Oct 30 00:17:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:18:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:18:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:19:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:20:02 evo-x2 memory-emergency-guard-check[3766875]: MEMORY EMERGENCY IO-PAUSE (trip #4852, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:20:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 763ms CPU time over 23.866s wall clock time, 11.4M memory peak, 10M read from disk, 980K written to disk.
Oct 30 00:20:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:20:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:21:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 119ms CPU time over 170ms wall clock time, 9.8M memory peak, 1.7M read from disk, 4K written to disk.
Oct 30 00:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:22:40 evo-x2 memory-emergency-guard-check[3846928]: MEMORY EMERGENCY IO-PAUSE (trip #4853, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:22:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:22:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 807ms CPU time over 31.753s wall clock time, 12M memory peak, 21.1M read from disk, 13.4M written to disk.
Oct 30 00:22:41 evo-x2 memory-emergency-guard-check[3869720]: MEMORY EMERGENCY still active (I/O PSI some avg60=94.27% sustained (max disk busy 100.0%, MemAvailable=13.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:22:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:23:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:23:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:24:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:25:34 evo-x2 memory-emergency-guard-check[3924264]: MEMORY EMERGENCY IO-PAUSE (trip #4854, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:25:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 982ms CPU time over 53.714s wall clock time, 9.8M memory peak, 25.6M read from disk, 17.4M written to disk.
Oct 30 00:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:25:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 130ms CPU time over 434ms wall clock time, 10.2M memory peak, 4.5M read from disk, 4K written to disk.
Oct 30 00:26:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:26:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:27:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:28:08 evo-x2 memory-emergency-guard-check[4064160]: MEMORY EMERGENCY IO-PAUSE (trip #4855, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 909ms CPU time over 33.275s wall clock time, 11.6M memory peak, 22.6M read from disk, 12.5M written to disk.
Oct 30 00:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:29:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:30:56 evo-x2 memory-emergency-guard-check[37776]: MEMORY EMERGENCY IO-PAUSE (trip #4856, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 830ms CPU time over 10.216s wall clock time, 10.5M memory peak, 3.5M read from disk, 25.7M written to disk.
Oct 30 00:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:32:47 evo-x2 memory-emergency-guard-check[125239]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.08% sustained (max disk busy 97.1%, MemAvailable=14.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:34:30 evo-x2 memory-emergency-guard-check[142482]: MEMORY EMERGENCY IO-PAUSE (trip #4857, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.023s CPU time over 43.432s wall clock time, 10.9M memory peak, 29.8M read from disk, 13M written to disk.
Oct 30 00:34:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:35:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:35:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 150ms CPU time over 796ms wall clock time, 10.6M memory peak, 4.7M read from disk, 4K written to disk.
Oct 30 00:36:51 evo-x2 memory-emergency-guard-check[240952]: MEMORY EMERGENCY IO-PAUSE (trip #4858, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:36:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 831ms CPU time over 21.476s wall clock time, 10.7M memory peak, 18.1M read from disk, 17.7M written to disk.
Oct 30 00:37:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:37:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:38:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 205ms CPU time over 324ms wall clock time, 7.5M memory peak, 1.4M read from disk, 4K written to disk.
Oct 30 00:39:11 evo-x2 memory-emergency-guard-check[343081]: MEMORY EMERGENCY IO-PAUSE (trip #4859, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:39:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 983ms CPU time over 11.476s wall clock time, 11.2M memory peak, 8.9M read from disk, 18.1M written to disk.
Oct 30 00:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:40:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:41:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:42:00 evo-x2 memory-emergency-guard-check[416416]: MEMORY EMERGENCY IO-PAUSE (trip #4860, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.196s CPU time over 29.583s wall clock time, 9.1M memory peak, 25.5M read from disk, 18.4M written to disk.
Oct 30 00:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:43:00 evo-x2 memory-emergency-guard-check[471158]: MEMORY EMERGENCY still active (I/O PSI some avg60=80.29% sustained (max disk busy 100.0%, MemAvailable=13.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:44:51 evo-x2 memory-emergency-guard-check[526469]: MEMORY EMERGENCY IO-PAUSE (trip #4861, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.150s CPU time over 50.645s wall clock time, 9.5M memory peak, 40.8M read from disk, 884K written to disk.
Oct 30 00:44:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:45:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:45:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:46:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:47:33 evo-x2 memory-emergency-guard-check[674530]: MEMORY EMERGENCY IO-PAUSE (trip #4862, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:47:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.228s CPU time over 42.465s wall clock time, 16.1M memory peak, 30.6M read from disk, 8.8M written to disk.
Oct 30 00:47:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:48:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:48:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:49:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:49:35 evo-x2 gatus[2236212]: 2026/10/30 00:49:35 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 00:49:35 evo-x2 gatus[2236212]: 2026/10/30 00:49:35 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 00:50:31 evo-x2 memory-emergency-guard-check[766970]: MEMORY EMERGENCY IO-PAUSE (trip #4863, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:50:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.078s CPU time over 58.113s wall clock time, 11.5M memory peak, 66.4M read from disk, 15M written to disk.
Oct 30 00:50:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:52:38 evo-x2 gatus[2236212]: 2026/10/30 00:52:38 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 00:52:39 evo-x2 gatus[2236212]: 2026/10/30 00:52:39 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 00:54:11 evo-x2 memory-emergency-guard-check[885652]: MEMORY EMERGENCY IO-PAUSE (trip #4864, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.149s CPU time over 1min 38.956s wall clock time, 10.7M memory peak, 47.8M read from disk, 16.3M written to disk.
Oct 30 00:54:11 evo-x2 memory-emergency-guard-check[946662]: MEMORY EMERGENCY still active (I/O PSI some avg60=84.76% sustained (max disk busy 100.0%, MemAvailable=10.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (99s < 150s, 51s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 00:54:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:54:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:55:37 evo-x2 memory-emergency-guard-check[976017]: MEMORY EMERGENCY IO-PAUSE (trip #4865, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 884ms CPU time over 25.895s wall clock time, 10.2M memory peak, 19.9M read from disk, 33.4M written to disk.
Oct 30 00:55:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:56:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:56:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:57:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:58:12 evo-x2 memory-emergency-guard-check[1050795]: MEMORY EMERGENCY IO-PAUSE (trip #4866, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 00:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.297s CPU time over 30.880s wall clock time, 10.3M memory peak, 34.6M read from disk, 21.4M written to disk.
Oct 30 00:58:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:58:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:59:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 00:59:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:00:35 evo-x2 memory-emergency-guard-check[1179120]: MEMORY EMERGENCY IO-PAUSE (trip #4867, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:00:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 994ms CPU time over 23.309s wall clock time, 12.7M memory peak, 23.6M read from disk, 25.8M written to disk.
Oct 30 01:00:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:01:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:01:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:02:56 evo-x2 memory-emergency-guard-check[1287216]: MEMORY EMERGENCY IO-PAUSE (trip #4868, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:02:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 14.092s wall clock time, 12.9M memory peak, 4.2M read from disk, 28.3M written to disk.
Oct 30 01:03:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:04:13 evo-x2 memory-emergency-guard-check[1335803]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.87% sustained (max disk busy 96.6%, MemAvailable=14.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:04:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 115ms CPU time over 423ms wall clock time, 10.5M memory peak, 3.1M read from disk, 4K written to disk.
Oct 30 01:04:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:05:45 evo-x2 memory-emergency-guard-check[1350237]: MEMORY EMERGENCY IO-PAUSE (trip #4869, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 680ms CPU time over 32.949s wall clock time, 12.6M memory peak, 24.4M read from disk, 6.1M written to disk.
Oct 30 01:05:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:06:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:06:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:08:03 evo-x2 memory-emergency-guard-check[1390540]: MEMORY EMERGENCY IO-PAUSE (trip #4870, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 642ms CPU time over 18.065s wall clock time, 11.3M memory peak, 8.5M read from disk, 10.9M written to disk.
Oct 30 01:08:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:08:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:09:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:09:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:10:21 evo-x2 memory-emergency-guard-check[1438125]: MEMORY EMERGENCY IO-PAUSE (trip #4871, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:10:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 552ms CPU time over 6.062s wall clock time, 11.5M memory peak, 592K read from disk, 8.2M written to disk.
Oct 30 01:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:13:07 evo-x2 memory-emergency-guard-check[1490734]: MEMORY EMERGENCY IO-PAUSE (trip #4872, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:13:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 712ms CPU time over 20.981s wall clock time, 12.2M memory peak, 33.5M read from disk, 30.3M written to disk.
Oct 30 01:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:14:17 evo-x2 memory-emergency-guard-check[1519682]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.23% sustained (max disk busy 100.0%, MemAvailable=17.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:15:31 evo-x2 memory-emergency-guard-check[1537526]: MEMORY EMERGENCY IO-PAUSE (trip #4873, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:15:31 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 637ms CPU time over 13.836s wall clock time, 11.7M memory peak, 16.9M read from disk, 7.8M written to disk.
Oct 30 01:15:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:16:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:16:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:17:28 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 22 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 30 01:17:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:18:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 104ms CPU time over 1.946s wall clock time, 7.5M memory peak, 1.7M read from disk, 4K written to disk.
Oct 30 01:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:18:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 105ms CPU time over 2.242s wall clock time, 7.7M memory peak, 1.9M read from disk, 4K written to disk.
Oct 30 01:19:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:20:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 4.526s wall clock time, 8.7M memory peak, 2.1M read from disk, 4K written to disk.
Oct 30 01:21:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:21:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:22:56 evo-x2 gatus[2236212]: 2026/10/30 01:22:56 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 01:22:56 evo-x2 gatus[2236212]: 2026/10/30 01:22:56 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 01:23:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:25:07 evo-x2 memory-emergency-guard-check[1674561]: MEMORY EMERGENCY still active (MemAvailable=0.8% below absolute floor) but action cooldown active (553s < 600s, 47s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:24:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 2.078s wall clock time, 8.4M memory peak, 2.2M read from disk, 4K written to disk.
Oct 30 01:24:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:25:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 107ms CPU time over 4.465s wall clock time, 8.5M memory peak, 1.4M read from disk, 4K written to disk.
Oct 30 01:26:15 evo-x2 memory-emergency-guard-check[1689671]: MEMORY EMERGENCY: MemAvailable=2.0% below absolute floor — stopping sockets + 'fastflowlm@*.service' 'fastflowlm.service' to prevent kernel freeze (2026-08-22 incident class). The socket stays down until memory recovers; flm cold-loads once on restore.
Oct 30 01:26:54 evo-x2 gatus[2236212]: 2026/10/30 01:26:54 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 01:26:54 evo-x2 gatus[2236212]: 2026/10/30 01:26:54 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 01:28:19 evo-x2 memory-emergency-guard-check[1689671]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4874, zone 1) — top io since last trip: system.slice/io.stat +113076MB, user.slice/io.stat +24447MB, user.slice/user-1000.slice/io.stat +20468MB
Oct 30 01:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 733ms CPU time over 2min 5.521s wall clock time, 14.1M memory peak, 42.4M read from disk, 5.6M written to disk.
Oct 30 01:28:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:29:35 evo-x2 memory-emergency-guard-check[1736638]: MEMORY EMERGENCY IO-PAUSE (trip #4875, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 46.317s wall clock time, 13M memory peak, 19.5M read from disk, 29.7M written to disk.
Oct 30 01:29:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:30:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:30:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:31:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:31:42 evo-x2 memory-emergency-guard-check[1789912]: MEMORY EMERGENCY IO-PAUSE (trip #4876, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 653ms CPU time over 6.350s wall clock time, 12.4M memory peak, 4M read from disk, 25.9M written to disk.
Oct 30 01:32:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:32:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:33:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:33:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:34:22 evo-x2 memory-emergency-guard-check[1830378]: MEMORY EMERGENCY IO-PAUSE (trip #4877, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 16.347s wall clock time, 11.5M memory peak, 1.3M read from disk, 16.4M written to disk.
Oct 30 01:34:36 evo-x2 memory-emergency-guard-check[1845818]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.86% sustained (max disk busy 100.0%, MemAvailable=27.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:34:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:35:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:35:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:36:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:36:40 evo-x2 memory-emergency-guard-check[1871843]: MEMORY EMERGENCY IO-PAUSE (trip #4878, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 4.118s wall clock time, 11.5M memory peak, 7.2M read from disk, 21.9M written to disk.
Oct 30 01:37:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:37:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:38:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:38:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:40:20 evo-x2 memory-emergency-guard-check[1910430]: MEMORY EMERGENCY IO-PAUSE (trip #4879, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:40:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 629ms CPU time over 1min 14.276s wall clock time, 13.1M memory peak, 6.4M read from disk, 26.2M written to disk.
Oct 30 01:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:40:27 evo-x2 gatus[2236212]: 2026/10/30 01:40:27 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Oct 30 01:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:41:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:42:12 evo-x2 memory-emergency-guard-check[1962882]: MEMORY EMERGENCY IO-PAUSE (trip #4880, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:42:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 600ms CPU time over 21.525s wall clock time, 11M memory peak, 1.2M read from disk, 21.2M written to disk.
Oct 30 01:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:43:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:47:07 evo-x2 memory-emergency-guard-check[2032855]: MEMORY EMERGENCY IO-PAUSE (trip #4881, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:47:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.475s CPU time over 2min 47.895s wall clock time, 15.8M memory peak, 276.8M read from disk, 93.7M written to disk.
Oct 30 01:47:53 evo-x2 memory-emergency-guard-check[2069177]: MEMORY EMERGENCY IO-PAUSE (trip #4882, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.253s CPU time over 44.957s wall clock time, 13.1M memory peak, 127.1M read from disk, 1.7M written to disk.
Oct 30 01:47:54 evo-x2 memory-emergency-guard-check[2083878]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.84% sustained (max disk busy 95.4%, MemAvailable=15.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (45s < 150s, 105s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:47:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:48:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:48:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:49:58 evo-x2 memory-emergency-guard-check[2117148]: MEMORY EMERGENCY IO-PAUSE (trip #4883, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:49:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 789ms CPU time over 4.471s wall clock time, 11M memory peak, 7.5M read from disk, 67.5M written to disk.
Oct 30 01:50:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:50:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:51:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:52:27 evo-x2 memory-emergency-guard-check[2163335]: MEMORY EMERGENCY IO-PAUSE (trip #4884, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:52:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 750ms CPU time over 3.354s wall clock time, 9.9M memory peak, 18M read from disk, 29.1M written to disk.
Oct 30 01:52:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:53:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:53:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:54:57 evo-x2 memory-emergency-guard-check[2220385]: MEMORY EMERGENCY IO-PAUSE (trip #4885, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:54:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 846ms CPU time over 3.235s wall clock time, 10.1M memory peak, 22M read from disk, 60.8M written to disk.
Oct 30 01:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:56:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:56:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:57:28 evo-x2 memory-emergency-guard-check[2307065]: MEMORY EMERGENCY IO-PAUSE (trip #4886, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 01:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:57:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 702ms CPU time over 4.058s wall clock time, 9.9M memory peak, 6.7M read from disk, 21.5M written to disk.
Oct 30 01:57:54 evo-x2 memory-emergency-guard-check[2327686]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.34% sustained (max disk busy 98.9%, MemAvailable=13.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 01:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:58:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:58:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 01:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:01:57 evo-x2 memory-emergency-guard-check[2383303]: MEMORY EMERGENCY IO-PAUSE (trip #4887, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:01:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 758ms CPU time over 2min 3.579s wall clock time, 12.5M memory peak, 19.1M read from disk, 31.8M written to disk.
Oct 30 02:01:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:02:32 evo-x2 memory-emergency-guard-check[2436320]: MEMORY EMERGENCY IO-PAUSE (trip #4888, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:02:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 687ms CPU time over 5.106s wall clock time, 11.3M memory peak, 2.2M read from disk, 16.3M written to disk.
Oct 30 02:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:02:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 312ms wall clock time, 11.2M memory peak, 3.2M read from disk, 4K written to disk.
Oct 30 02:03:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:04:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 128ms CPU time over 177ms wall clock time, 9.2M memory peak, 2.2M read from disk, 4K written to disk.
Oct 30 02:05:10 evo-x2 memory-emergency-guard-check[2499270]: MEMORY EMERGENCY IO-PAUSE (trip #4889, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:05:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 731ms CPU time over 12.612s wall clock time, 13.9M memory peak, 22.5M read from disk, 34.1M written to disk.
Oct 30 02:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:06:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:06:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 126ms CPU time over 613ms wall clock time, 8.2M memory peak, 1.6M read from disk, 4K written to disk.
Oct 30 02:08:16 evo-x2 memory-emergency-guard-check[2564169]: MEMORY EMERGENCY IO-PAUSE (trip #4890, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.064s CPU time over 48.796s wall clock time, 14.2M memory peak, 34.2M read from disk, 34.4M written to disk.
Oct 30 02:08:17 evo-x2 memory-emergency-guard-check[2591227]: MEMORY EMERGENCY still active (I/O PSI some avg60=70.95% sustained (max disk busy 100.0%, MemAvailable=12.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (48s < 150s, 102s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:10:24 evo-x2 memory-emergency-guard-check[2622969]: MEMORY EMERGENCY IO-PAUSE (trip #4891, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:10:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 681ms CPU time over 7.951s wall clock time, 11.1M memory peak, 4.8M read from disk, 15.9M written to disk.
Oct 30 02:10:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:12:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:13:16 evo-x2 memory-emergency-guard-check[2678564]: MEMORY EMERGENCY IO-PAUSE (trip #4892, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 789ms CPU time over 29.646s wall clock time, 10.9M memory peak, 12.9M read from disk, 21.6M written to disk.
Oct 30 02:13:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:13:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:14:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:15:53 evo-x2 memory-emergency-guard-check[2818905]: MEMORY EMERGENCY IO-PAUSE (trip #4893, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:15:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.128s CPU time over 36.530s wall clock time, 8.3M memory peak, 12.6M read from disk, 5.3M written to disk.
Oct 30 02:15:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:16:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:16:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:17:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:18:24 evo-x2 memory-emergency-guard-check[2886929]: MEMORY EMERGENCY IO-PAUSE (trip #4894, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 672ms CPU time over 31.126s wall clock time, 12.7M memory peak, 11.5M read from disk, 19.7M written to disk.
Oct 30 02:18:24 evo-x2 memory-emergency-guard-check[2903065]: MEMORY EMERGENCY still active (I/O PSI some avg60=76.04% sustained (max disk busy 99.9%, MemAvailable=11.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:18:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:18:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:19:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:19:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:20:37 evo-x2 memory-emergency-guard-check[2958644]: MEMORY EMERGENCY IO-PAUSE (trip #4895, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 697ms CPU time over 12.767s wall clock time, 11.7M memory peak, 3.9M read from disk, 8.3M written to disk.
Oct 30 02:20:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:21:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:21:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:22:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:23:12 evo-x2 memory-emergency-guard-check[3052164]: MEMORY EMERGENCY IO-PAUSE (trip #4896, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:23:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 709ms CPU time over 17.927s wall clock time, 12.6M memory peak, 15.3M read from disk, 30.7M written to disk.
Oct 30 02:23:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:25:42 evo-x2 memory-emergency-guard-check[3110374]: MEMORY EMERGENCY IO-PAUSE (trip #4897, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:25:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 643ms CPU time over 17.802s wall clock time, 11.9M memory peak, 4M read from disk, 8.1M written to disk.
Oct 30 02:25:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:27:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:28:20 evo-x2 memory-emergency-guard-check[3163112]: MEMORY EMERGENCY IO-PAUSE (trip #4898, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:28:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 756ms CPU time over 25.900s wall clock time, 13.7M memory peak, 10.3M read from disk, 26.8M written to disk.
Oct 30 02:28:25 evo-x2 memory-emergency-guard-check[3184323]: MEMORY EMERGENCY still active (I/O PSI some avg60=72.58% sustained (max disk busy 100.0%, MemAvailable=11.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:28:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:28:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:29:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:29:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:30:57 evo-x2 memory-emergency-guard-check[3227351]: MEMORY EMERGENCY IO-PAUSE (trip #4899, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.227s CPU time over 32.209s wall clock time, 11.1M memory peak, 19.6M read from disk, 14.3M written to disk.
Oct 30 02:30:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:32:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:33:07 evo-x2 memory-emergency-guard-check[3299517]: MEMORY EMERGENCY IO-PAUSE (trip #4900, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:33:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 728ms CPU time over 10.079s wall clock time, 11M memory peak, 6M read from disk, 20.7M written to disk.
Oct 30 02:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:33:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 148ms CPU time over 434ms wall clock time, 11.2M memory peak, 5M read from disk, 4K written to disk.
Oct 30 02:33:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:34:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:36:22 evo-x2 memory-emergency-guard-check[3373575]: MEMORY EMERGENCY IO-PAUSE (trip #4901, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.062s CPU time over 55.288s wall clock time, 10.8M memory peak, 25.9M read from disk, 15M written to disk.
Oct 30 02:36:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:36:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:37:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:39:21 evo-x2 memory-emergency-guard-check[3503628]: MEMORY EMERGENCY IO-PAUSE (trip #4902, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 816ms CPU time over 58.409s wall clock time, 11.7M memory peak, 20.1M read from disk, 12.8M written to disk.
Oct 30 02:39:21 evo-x2 memory-emergency-guard-check[3539083]: MEMORY EMERGENCY still active (I/O PSI some avg60=75.98% sustained (max disk busy 99.0%, MemAvailable=10.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (59s < 150s, 91s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:39:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:39:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:41:49 evo-x2 memory-emergency-guard-check[3605830]: MEMORY EMERGENCY IO-PAUSE (trip #4903, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:41:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 743ms CPU time over 28.495s wall clock time, 11M memory peak, 16.5M read from disk, 10.3M written to disk.
Oct 30 02:41:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:42:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:42:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:43:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:45:36 evo-x2 memory-emergency-guard-check[3681027]: MEMORY EMERGENCY IO-PAUSE (trip #4904, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 963ms CPU time over 1min 44.412s wall clock time, 9.7M memory peak, 12.2M read from disk, 16.2M written to disk.
Oct 30 02:45:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:46:58 evo-x2 memory-emergency-guard-check[3821784]: MEMORY EMERGENCY IO-PAUSE (trip #4905, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:46:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 983ms CPU time over 22.087s wall clock time, 13.3M memory peak, 10.4M read from disk, 12.8M written to disk.
Oct 30 02:47:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:47:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:48:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:48:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:49:25 evo-x2 memory-emergency-guard-check[3933081]: MEMORY EMERGENCY IO-PAUSE (trip #4906, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:49:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.002s CPU time over 18.033s wall clock time, 8.8M memory peak, 988K read from disk, 12.8M written to disk.
Oct 30 02:49:37 evo-x2 memory-emergency-guard-check[3967339]: MEMORY EMERGENCY still active (I/O PSI some avg60=65.35% sustained (max disk busy 99.9%, MemAvailable=14.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:49:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:50:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:50:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:51:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:52:00 evo-x2 memory-emergency-guard-check[4029005]: MEMORY EMERGENCY IO-PAUSE (trip #4907, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:52:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 718ms CPU time over 23.182s wall clock time, 13.3M memory peak, 8M read from disk, 10M written to disk.
Oct 30 02:52:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:52:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:53:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:53:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:54:35 evo-x2 memory-emergency-guard-check[4140023]: MEMORY EMERGENCY IO-PAUSE (trip #4908, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:54:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 798ms CPU time over 27.919s wall clock time, 10M memory peak, 9.8M read from disk, 25.9M written to disk.
Oct 30 02:54:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:55:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:55:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:56:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:57:56 evo-x2 memory-emergency-guard-check[62213]: MEMORY EMERGENCY IO-PAUSE (trip #4909, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:57:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.072s CPU time over 1min 19.024s wall clock time, 9.9M memory peak, 23M read from disk, 13.5M written to disk.
Oct 30 02:57:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:58:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 122ms CPU time over 165ms wall clock time, 12M memory peak, 4.2M read from disk, 4K written to disk.
Oct 30 02:58:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:59:33 evo-x2 memory-emergency-guard-check[157192]: MEMORY EMERGENCY IO-PAUSE (trip #4910, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 02:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 02:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.080s CPU time over 6.693s wall clock time, 9M memory peak, 7.4M read from disk, 23.9M written to disk.
Oct 30 02:59:57 evo-x2 memory-emergency-guard-check[180051]: MEMORY EMERGENCY still active (I/O PSI some avg60=50.23% sustained (max disk busy 97.1%, MemAvailable=9.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 02:59:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:00:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:00:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:01:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:02:10 evo-x2 memory-emergency-guard-check[229103]: MEMORY EMERGENCY IO-PAUSE (trip #4911, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:02:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.139s CPU time over 13.360s wall clock time, 8.9M memory peak, 6.4M read from disk, 23.5M written to disk.
Oct 30 03:02:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:02:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:03:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:03:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:04:33 evo-x2 memory-emergency-guard-check[304108]: MEMORY EMERGENCY IO-PAUSE (trip #4912, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 966ms CPU time over 5.985s wall clock time, 9.3M memory peak, 2M read from disk, 18.5M written to disk.
Oct 30 03:04:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:05:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 212ms CPU time over 515ms wall clock time, 8.3M memory peak, 2.8M read from disk, 4K written to disk.
Oct 30 03:05:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:06:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:08:37 evo-x2 memory-emergency-guard-check[405438]: MEMORY EMERGENCY IO-PAUSE (trip #4913, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 761ms CPU time over 1min 39.463s wall clock time, 9.2M memory peak, 7.9M read from disk, 7.5M written to disk.
Oct 30 03:08:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:09:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:10:17 evo-x2 memory-emergency-guard-check[547953]: MEMORY EMERGENCY IO-PAUSE (trip #4914, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 801ms CPU time over 39.418s wall clock time, 10.4M memory peak, 7.1M read from disk, 7M written to disk.
Oct 30 03:10:27 evo-x2 memory-emergency-guard-check[588546]: MEMORY EMERGENCY still active (I/O PSI some avg60=68.97% sustained (max disk busy 100.0%, MemAvailable=13.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (49s < 150s, 101s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 03:10:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:10:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:11:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:17:13 evo-x2 memory-emergency-guard-check[682901]: MEMORY EMERGENCY IO-PAUSE (trip #4915, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:17:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.195s CPU time over 4min 55.818s wall clock time, 9.4M memory peak, 43.8M read from disk, 5.5M written to disk.
Oct 30 03:17:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:17:13 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY GUARD DEAD; UNIT CRASH LOOP" "memory-emergency-guard metrics are missing/stale (325s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 30 03:17:24 evo-x2 gatus[1944965]: 2026/10/30 03:17:24 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 03:17:24 evo-x2 gatus[1944965]: 2026/10/30 03:17:24 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Oct 30 03:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:18:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 182ms CPU time over 2.934s wall clock time, 5.9M memory peak, 1.1M read from disk, 4K written to disk.
Oct 30 03:18:18 evo-x2 systemd[1765]: Started [systemd-run] /nix/store/9yrxszw0fbyx68dbr4nbcnb408vqxgya-libnotify-0.8.8/bin/notify-send -u normal -t 30000 "SEV1: MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP" "The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets). TRIP CHURN: 21 trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (opencloud) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u opencloud -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading.".
Oct 30 03:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:19:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:20:32 evo-x2 gatus[1944965]: 2026/10/30 03:20:32 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 03:20:33 evo-x2 gatus[1944965]: 2026/10/30 03:20:33 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Oct 30 03:21:34 evo-x2 memory-emergency-guard-check[861644]: MEMORY EMERGENCY IO-PAUSE (trip #4916, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.070s CPU time over 1min 28.576s wall clock time, 12M memory peak, 49.3M read from disk, 14.2M written to disk.
Oct 30 03:21:34 evo-x2 memory-emergency-guard-check[907284]: MEMORY EMERGENCY still active (I/O PSI some avg60=92.66% sustained (max disk busy 99.7%, MemAvailable=10.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (77s < 150s, 73s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 03:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:21:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 171ms CPU time over 439ms wall clock time, 7.5M memory peak, 1.3M read from disk, 4K written to disk.
Oct 30 03:22:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:22:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 136ms CPU time over 415ms wall clock time, 7.5M memory peak, 1M read from disk, 4K written to disk.
Oct 30 03:23:06 evo-x2 memory-emergency-guard-check[941733]: MEMORY EMERGENCY IO-PAUSE (trip #4917, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:23:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.045s CPU time over 2.329s wall clock time, 9.5M memory peak, 32.3M read from disk, 31.7M written to disk.
Oct 30 03:23:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:24:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:24:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:25:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:26:11 evo-x2 memory-emergency-guard-check[1103035]: MEMORY EMERGENCY IO-PAUSE (trip #4918, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:26:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.000s CPU time over 37.345s wall clock time, 10.6M memory peak, 21.4M read from disk, 41.4M written to disk.
Oct 30 03:26:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:26:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:27:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:27:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:28:26 evo-x2 memory-emergency-guard-check[1286275]: MEMORY EMERGENCY IO-PAUSE (trip #4919, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:28:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 921ms CPU time over 14.885s wall clock time, 9.7M memory peak, 11.5M read from disk, 9.7M written to disk.
Oct 30 03:28:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:29:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:29:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:30:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:31:03 evo-x2 memory-emergency-guard-check[1461707]: MEMORY EMERGENCY IO-PAUSE (trip #4920, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-) — pressure persists but nothing pausable; escalation arms after 3 such trips
Oct 30 03:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:31:03 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 842ms CPU time over 21.283s wall clock time, 11.3M memory peak, 33.7M read from disk, 5.7M written to disk.
Oct 30 03:31:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Oct 30 03:31:42 evo-x2 memory-emergency-guard-check[1501193]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.96% sustained (max disk busy 100.0%, MemAvailable=13.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (60s < 150s, 90s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Oct 30 03:31:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
```

## THERMAL THROTTLE lines
```
Oct 28 00:50:10 evo-x2 thermal-pstate-guard-check[97980]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 28 13:14:47 evo-x2 thermal-pstate-guard-check[2990887]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=75C(hi:95/lo:80)
Oct 28 13:31:16 evo-x2 thermal-pstate-guard-check[3262261]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 28 14:21:30 evo-x2 thermal-pstate-guard-check[473384]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=79C(hi:95/lo:80)
Oct 28 14:24:46 evo-x2 thermal-pstate-guard-check[587264]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=99C(hi:95/lo:80)
Oct 28 14:46:40 evo-x2 thermal-pstate-guard-check[1088701]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Oct 28 14:58:48 evo-x2 thermal-pstate-guard-check[1289243]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 28 15:04:28 evo-x2 thermal-pstate-guard-check[1381565]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)
Oct 28 15:14:37 evo-x2 thermal-pstate-guard-check[1578946]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 29 04:42:57 evo-x2 thermal-pstate-guard-check[2110597]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=67C(hi:95/lo:80)
Oct 29 05:54:37 evo-x2 thermal-pstate-guard-check[3593715]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 29 09:10:28 evo-x2 thermal-pstate-guard-check[3672868]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=66C(hi:95/lo:80)
Oct 29 11:21:43 evo-x2 thermal-pstate-guard-check[1066702]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Oct 29 13:32:35 evo-x2 thermal-pstate-guard-check[891988]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Oct 29 14:18:58 evo-x2 thermal-pstate-guard-check[1498904]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 29 14:48:54 evo-x2 thermal-pstate-guard-check[2582299]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
Oct 29 15:00:09 evo-x2 thermal-pstate-guard-check[2760086]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 29 15:17:24 evo-x2 thermal-pstate-guard-check[3062254]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=67C(hi:95/lo:80)
Oct 29 15:48:44 evo-x2 thermal-pstate-guard-check[3407649]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 29 17:07:24 evo-x2 thermal-pstate-guard-check[1237568]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=78C(hi:95/lo:80)
Oct 29 17:11:21 evo-x2 thermal-pstate-guard-check[1332171]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Oct 28 00:42:49 evo-x2 kernel: Command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/vv4ckkahmq31aq7a312rx2d13r308nv1-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 28 00:42:49 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\xpvzphn667b393ssv59h1rz61b7nsdw0-initrd-linux-7.2.10-initrd.efi init=/nix/store/vv4ckkahmq31aq7a312rx2d13r308nv1-nixos-system-evo-x2-26.11.20261015.fe13242/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 28 00:42:49 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Oct 28 00:42:51 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1793327522000000000 -> 1793327629000000000 epoch-ns UTC (2026-10-30 02:32:02 -> 2026-10-30 02:33:49 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
